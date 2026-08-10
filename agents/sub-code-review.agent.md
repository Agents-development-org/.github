---
name: sub-code-review
description: Review .NET code changes against the ticket requirements and codebase conventions, and return structured feedback
model: Bedrock-Kimi-dev (litellm)
tools:
  - read/readFile
  - search/changes
  - search/codebase
  - search/textSearch
  - agent/runSubagent
user-invocable: false
argument-hint: "<TICKET-DATA> <CODE-CHANGES-SUMMARY>"
---

# Sub-Agent: Code Review

Single responsibility: review the code changes against the ticket requirements and org conventions, and return structured feedback.

## Inputs Expected

The calling agent must provide:
1. `TICKET-DATA` — structured output from `sub-read-jira`
2. `CODE-CHANGES-SUMMARY` — structured output from `sub-write-code`

## Workflow

### Step 1: Read Project Conventions

**First action:** Read `.github/skills/peoplewith-coding-standards/SKILL.md` using `readFile`. This is the authoritative coding standards reference defining naming conventions, architecture patterns, and constraints for this project. Do this once before reviewing any code.

### Step 2: Read All Changed Files

Use `search/changes` to list changed files, then read each one in full.

### Step 3: Review Against Checklist

Evaluate the changes against:

**Requirements**
- [ ] All acceptance criteria from the ticket are met
- [ ] No out-of-scope changes included

**Code Quality**
- [ ] Naming follows existing conventions
- [ ] No unnecessary complexity or duplication
- [ ] No commented-out code or debug statements
- [ ] Appropriate null/error handling at boundaries

**Architecture**
- [ ] Code-behind MVVM-lite pattern used (no separate ViewModel layer)
- [ ] Static `APICalls` class used for all API calls (no DI container)
- [ ] `CrashDetected.NotasyncMethod(ex)` used for all exception handling
- [ ] `BaseNotify` used for `INotifyPropertyChanged`
- [ ] `ObservableCollection<T>` used for list bindings

**Security (OWASP Top 10)**
- [ ] No injection vulnerabilities (SQL, LDAP, etc.)
- [ ] No sensitive data exposed in logs or responses
- [ ] Input validated at system boundaries
- [ ] No hardcoded secrets or credentials

**Tests**
- [ ] New/changed logic has test coverage
- [ ] Tests are meaningful, not trivial

### Step 3: Return Structured Feedback

```
CODE REVIEW
===========
VERDICT: APPROVED | APPROVED WITH COMMENTS | CHANGES REQUESTED

ISSUES:
{severity: BLOCKER | MAJOR | MINOR}
{file path + line reference}
{description of the issue and suggested fix}

POSITIVES:
{notable good practices observed}

SUMMARY:
{one-paragraph overall assessment}
```

## Notes

- BLOCKER issues must be resolved before a PR is created
- MINOR issues may be addressed as follow-up tickets
- Do NOT modify any files directly
