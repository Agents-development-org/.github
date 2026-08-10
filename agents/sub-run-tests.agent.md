---
name: sub-run-tests
description: Run the pre-written TDD test suite against completed production code, fix failures, and confirm a green build
model: Bedrock-Kimi-dev (litellm)
tools:
  - read/readFile
  - edit
  - search/codebase
  - search/textSearch
  - search/fileSearch
  - terminal
  - agent/runSubagent
user-invocable: false
argument-hint: "<CODE-CHANGES> <TEST-FILES>"
---

# Sub-Agent: Run Tests

Single responsibility: run the test suite written by `sub-write-tests` against the production code produced by `sub-write-code`, fix any failures, and confirm a green build.

## Inputs Expected

The calling agent must provide:
1. `CODE-CHANGES` — structured output from `sub-write-code` (list of files created/modified)
2. `TEST-FILES` — structured output from `sub-write-tests` (list of test files and what they cover)

## Workflow

### Step 1: Confirm Tests Now Compile

Before running, verify that the production classes referenced in the test files now exist (they are listed in `CODE-CHANGES`). If any referenced class is missing, stop and return an error listing the missing items — do not attempt to run.

### Step 2: Run the Full Test Suite

```
dotnet test --logger "console;verbosity=normal"
```

Capture all output.

### Step 3: Triage Failures

For each failing test, classify the failure:

| Failure type | Action |
|--------------|--------|
| Production code does not satisfy the AC | Fix the production code in the relevant file from `CODE-CHANGES` |
| Test assertion is incorrect (wrong expected value, wrong mock setup) | Fix the test |
| Test references a class/method that was renamed during implementation | Update the test to match the actual name |
| Unrelated pre-existing failure | Note it in FLAGGED ISSUES, do not fix |

### Step 4: Fix and Re-run

Apply fixes and re-run:
```
dotnet test --logger "console;verbosity=normal"
```

Repeat until all tests introduced by this ticket pass. Do not attempt to fix pre-existing failures unrelated to this ticket.

### Step 5: Return Summary

```
TEST RUN RESULTS
================
TICKET: {KEY}

OUTCOME: PASSED | FAILED

TESTS RUN: {total}
PASSED: {count}
FAILED: {count}
SKIPPED: {count}

FAILURES FIXED:
  - {test method}: {root cause} -> {fix applied}

FLAGGED ISSUES (not fixed):
  - {pre-existing failure or out-of-scope issue}

PRODUCTION FILES MODIFIED DURING FIX:
  {list, or "None" -- any production code changes must be minimal and directly caused by a failing test}

FINAL STATE: All ticket tests GREEN | Residual failures exist (see flagged issues)
```

## Safety Constraints

Do NOT:
- **Force-pass tests by weakening assertions.** If a test is failing because the implementation is wrong, fix the production code — not the assertion. The only exception is correcting a genuinely wrong expected value (see triage table).
- **Run `git` commands.** Only `dotnet test` is permitted in this agent.
- **Modify test files outside `TEST-FILES`.** Do not touch test files that belong to other features or pre-existing test suites.
- **Mark pre-existing failures as fixed** unless this ticket's code changes directly caused the regression.
- **Make live network calls.** Do not add, modify, or enable any code path that calls `pwapi.peoplewith.com` or any external service during the test run.

## Notes

- Do NOT modify production code beyond what is necessary to make a failing test pass
- Do NOT delete or skip tests to achieve a green build — fix the underlying issue
- Do NOT run `dotnet build` separately; `dotnet test` builds implicitly
- Pre-existing failures in unrelated tests must be flagged, not fixed
