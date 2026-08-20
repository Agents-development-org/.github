---
name: sub-explore-codebase
description: Explore a .NET codebase and return a structured summary of relevant files, projects, and patterns for a given task
model: Coder-fast-2 (litellm)
tools:
  - search/fileSearch
  - search/textSearch
  - search/listDirectory
  - search/usages
  - read/readFile
  - run/terminal
  - agent/runSubagent
user-invocable: false
argument-hint: "<TASK-DESCRIPTION>"
---

# Sub-Agent: Explore Codebase

Single responsibility: explore the codebase and return a structured summary of relevant files, projects, and patterns for a given task.

**Use targeted file/text search — never read entire files.** Search for the specific symbols and file names the task needs, then read only the relevant line ranges.

## Token Budget — STRICT
- **Max tool calls: 7** total for the entire exploration
- **Max files to read: 4** — pick only the most directly relevant
- **Max lines per file: 80** — use line ranges, never read an entire file
- **Stop early**: if 1–2 searches plus 0–1 file reads answers the task, stop and return
- Do NOT chain searches speculatively — each search must target a specific known need
- Do NOT read config files, test files, or boilerplate unless the task explicitly requires it

## Workflow

### Step 0: Understand the Task (0 tool calls)

Parse the task description. Identify:
- The domain/feature area (e.g. medications, notifications)
- 2–3 key symbol names, concepts, or file names to search for
- Formulate 1–2 concrete search terms that describe what you need to find

### Step 1: Targeted search (max 3 tool calls)

The first search MUST locate the `.csproj` that owns the feature files. Read its framework-defining lines (`Sdk`, `TargetFramework(s)`, `UseMaui`, and relevant package references) before classifying the application. If multiple projects exist, select the project containing or nearest to the relevant files; never classify from a skill description or ticket wording.

Then run targeted searches for candidate files:
- Use file name search first, then text search if needed
- Stop searching once you have 4 candidate files

### Step 2: Read Key Files (max 4 files, 80 lines each)

Read only the sections needed — target the exact locations the search returned in Step 1:
- The model: first 50 lines (properties only)
- The service/API: search for the specific method, read ±20 lines around it
- Skip any file that is not directly modified by the task

### Step 3: Return Structured Summary

Return the following structure, clearly labelled. Keep it under 800 tokens total — use bullet points, no prose.

```
CODEBASE SUMMARY
================
SOURCE: {file search | text search | targeted reads}

TARGET PROJECT: {workspace-relative path to the owning .csproj}
PROJECT TYPE: {.NET MAUI | ASP.NET Core MVC | other}
PROJECT EVIDENCE: {exact signals read from the owning .csproj/source tree}

SOLUTION STRUCTURE:
{list of projects and their roles — one line each}

RELEVANT FILES:
{file paths with one-line descriptions — max 8 files}

KEY PATTERNS:
{naming conventions, DI patterns — max 6 bullet points}

KEY RELATIONSHIPS (graph only):
{A --uses--> B [EXTRACTED|INFERRED] — max 5; omit this section entirely if grep fallback was used}

TEST PATTERNS:
{test framework, mocking library, naming convention — 3 bullet points max. If no tests found: "xUnit + Moq (default)"}

ENTRY POINTS:
{controller actions, service methods, or other entry points most relevant to the task}

NOTES:
{anything unusual or important for the implementor to know}
```

## Notes

- Do NOT modify any files
- Do NOT make assumptions about the task — only report what exists
- Never report a project type without `TARGET PROJECT` and `PROJECT EVIDENCE`
- Prefer breadth over depth in the first pass; the calling agent will direct deeper reads if needed
