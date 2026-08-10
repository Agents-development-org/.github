---
name: sub-plan-draft
description: Draft or revise an implementation plan for a Jira ticket, then persist it to a temporary workspace file for the evaluate agent to read
model: Bedrock-Kimi-dev (litellm)
tools:
  - read/readFile
  - edit
  - execute/runInTerminal
  - search/codebase
  - search/textSearch
  - search/fileSearch
  - agent/runSubagent
user-invocable: false
argument-hint: "<TICKET-DATA> <CODEBASE-SUMMARY> [EVALUATION]"
---

# Sub-Agent: Plan Draft

Single responsibility: produce a structured implementation plan from ticket requirements and codebase context, save it to a temp file, and return the path.

## Inputs Expected

The calling agent must provide **concise references, not full text dumps**. Keep the invocation prompt small — this agent reads the skill file and explores the codebase itself (Steps 1 & 4), so large embedded context is unnecessary and can cause oversized-request failures.

1. `TICKET-KEY` + `TICKET-SUMMARY` — the Jira key plus a short (few-line) summary of the requirements and acceptance criteria. Do NOT paste the full `sub-read-jira` output; the plan document and ticket data already live in the workspace.
2. `CODEBASE-POINTERS` — a brief list of the key file paths and pattern names relevant to this task (e.g. `Models/userfitnessdata.cs (two-tier pattern)`, `APICalls.cs`, `Helpers/ActivityNotifications.cs`). Do NOT paste full file contents or the entire `sub-explore-codebase` summary — this agent will read/verify these paths itself using its graph, `read`, and `search` tools.
3. `GRAPH-STATUS` *(optional)* — the status string from `sub-graphify-setup` (passed through by the orchestrator). If it reports the graph is available (`SUCCESS`/`PARTIAL`), Step 4 queries `graphify` first; if it says `FAILED`/absent, Step 4 goes straight to `read`/`search`.
4. `EVALUATION` *(optional)* — when this is a revision pass, pass only the rubric dimensions scoring below 4 and the specific issues to address, not the full critique.

**Guideline:** Keep the total invocation prompt to a short brief. If more detail is needed, this agent reads it directly from `.github/skills/peoplewith-coding-standards/SKILL.md`, the ticket data, and the codebase.

## Workflow

### Step 1: Load Conventions & Determine Draft Mode

**First action:** Read `.github/skills/peoplewith-coding-standards/SKILL.md` using `readFile`. This is the sole authoritative reference for all coding standards, naming conventions, architecture patterns, and project structure. Do this once at the start.

**Determine draft mode:**

If `EVALUATION` is provided, this is a **revision pass**:
- Read the existing plan from `.agent-workspace/{TICKET-KEY}/IMPL-PLAN-{TICKET-KEY}.md`
- Read the `EVALUATION` critique carefully
- Focus changes only on dimensions that scored below 4
- Do not re-draft sections that already scored 4 or 5

If no `EVALUATION` is provided, this is a **first draft** — start from scratch.

### Step 2: Parse the Ticket

From `TICKET-SUMMARY` (and the ticket data on disk if more detail is needed), extract:
- Every acceptance criterion as a discrete, testable requirement
- Out-of-scope items (do not plan these)
- The feature domain name to determine folder/naming conventions

### Step 3: Map to the Codebase Scaffold

Using `CODEBASE-POINTERS` and the Feature Scaffold Guide from the skill, determine the required file categories:

| Need | File to create |
|------|----------------|
| User-specific data | `Models/user{feature}.cs` |
| Catalog/reference data | `Models/{feature}.cs` |
| List screen | `Views/{Feature}/All{Feature}.xaml` + `.xaml.cs` |
| Add screen | `Views/{Feature}/Add{Feature}.xaml` + `.xaml.cs` |
| Detail screen | `Views/{Feature}/Single{Feature}.xaml` + `.xaml.cs` |
| API endpoints | New constants in `APICalls.cs` |
| List refresh logic | `Update{Feature}.cs` |
| Display transformation | `Helpers/{Feature}Converter.cs` |

Apply naming conventions strictly:
- Model filenames and properties: **lowercase** (`waterintake.cs`, `userid`, `amount`)
- View files: **PascalCase** (`AddWaterIntake.xaml`)
- Methods: **PascalCase** (`LoadData()`)
- API constants: **PascalCase** (`GetWaterIntake`, `InsertWaterIntake`)

### Step 4: Verify Against Codebase

Before writing the plan, cross-check every reference against `CODEBASE-POINTERS` and the conventions from the skill. **Query the graphify knowledge graph first, `search`/`read` second** — the graph answers structural questions (where a symbol lives, what connects to what, exact `file:line`) in one local, LLM-free command, which is cheaper than chained searches.

**Step 4a — Graph first (preferred).** Only if the graph exists — trust `GRAPH-STATUS` when provided (`SUCCESS`/`PARTIAL` → proceed; `FAILED`/absent → skip to Step 4b), otherwise probe once with `Test-Path graphify-out/graph.json`. When available, run only the queries you need (each is local, LLM-free, non-interactive):

```powershell
graphify explain "<key symbol>"           # a symbol's connections, source file:line, community
graphify query "<question about the area>" # scoped subgraph: relevant nodes + files
graphify path "<SymbolA>" "<SymbolB>"      # how two areas connect (only if the task spans two)
```

Use the returned `file:line` locations to confirm references directly, often without any file search. **On Windows/PowerShell use `graphify .` — never `/graphify`.** If a query errors or returns nothing useful, do not retry variants — fall through to Step 4b once.

**Step 4b — `search`/`read` fallback.** When the graph is unavailable, incomplete, or a specific detail (an exact signature, a field default) is missing, use `read`, `search/fileSearch`, and `search/textSearch`.

Either way, confirm all of the following before writing the plan:
- Confirm any existing files referenced (e.g. `APICalls.cs`, `BaseNotify.cs`) exist at the stated paths
- Confirm namespaces match the folder structure
- Confirm any UI components cited (e.g. `SfLinearProgressBar`) are already used in the project
- Confirm planned file names and patterns align with the naming conventions from the skill
- Flag anything that cannot be verified in NOTES rather than assuming it exists

### Step 5: Write the Plan

Produce the plan in the following structure:

```
PLAN
====
TICKET: {KEY}
FEATURE: {feature name, e.g. WaterIntake}
ITERATION: {N}

OVERVIEW:
{2-3 sentence description of what is being built and why}

OUT OF SCOPE:
{items explicitly excluded by the ticket}

AC MAPPING:
AC1: "{acceptance criterion text}" -> Steps {N, M, ...}
AC2: ...

MODEL:
File: PeopleWith/Models/user{feature}.cs
Properties:
  - {propertyname}: {type}  ({purpose})

API ENDPOINTS (add to PeopleWith/APICalls.cs):
  - {ConstantName} = "{full URL}" -- {HTTP method}, {purpose}

FILES TO CREATE:
  - {relative path} -- {one-line description}

FILES TO MODIFY:
  - {relative path} -- {specific change description}

IMPLEMENTATION ORDER:
1. {step} [no dependencies]
2. {step} [depends on step 1]
...

PATTERNS TO FOLLOW:
  - {specific pattern from codebase, with source file reference}

NOTES:
  {unverified references, risks, or important decisions}
```

### Step 6: Save Plan to the Implementation Plan Document

Write the plan to:
```
.agent-workspace/{TICKET-KEY}/IMPL-PLAN-{TICKET-KEY}.md
```
Where `{TICKET-KEY}` is the Jira ticket key (e.g. `IMPL-PLAN-GPP-123.md`). Create the directory if it does not exist. Overwrite any existing file from a previous iteration.

### Step 7: Return

```
PLAN DRAFT COMPLETE
===================
TICKET: {KEY}
ITERATION: {N}
PLAN PATH: .agent-workspace/{TICKET-KEY}/IMPL-PLAN-{TICKET-KEY}.md

SUMMARY OF CHANGES FROM PREVIOUS ITERATION (if revision):
{list of what changed, keyed to the rubric dimension that triggered the change}
```

## Notes

- Do NOT write any production code — planning only
- Do NOT include items marked out of scope in the ticket
- If codebase summary is insufficient to verify a path or pattern, flag it in NOTES rather than guessing
- Keep the invocation prompt small — rely on reading the skill file, ticket data, and codebase directly rather than large embedded context, to avoid oversized-request failures
