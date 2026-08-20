---
name: sub-plan-draft
description: Draft or revise an implementation plan for a Jira ticket, then persist it to a temporary workspace file for the evaluate agent to read
model: Coder-thinking-1 (litellm)
tools:
  - read/readFile
  - edit
  - execute/runInTerminal
  - search/codebase
  - search/textSearch
  - search/fileSearch
user-invocable: false
argument-hint: "<TICKET-DATA> <CODEBASE-SUMMARY> [EVALUATION]"
---

# Sub-Agent: Plan Draft

Single responsibility: produce a structured implementation plan from ticket requirements and codebase context, save it to a temp file, and return the path.

## Inputs Expected

The calling agent must provide **concise references, not full text dumps**. Keep the invocation prompt small — this agent reads the skill file and explores the codebase itself (Steps 1 & 4), so large embedded context is unnecessary and can cause oversized-request failures.

1. `TICKET-KEY` + `TICKET-SUMMARY` — the Jira key plus a short (few-line) summary of the requirements and acceptance criteria. Do NOT paste the full `sub-read-jira` output; the plan document and ticket data already live in the workspace.
2. `TARGET-PROJECT` — the exact workspace-relative `.csproj` path selected by `sub-explore-codebase`.
3. `PROJECT-TYPE` + `PROJECT-EVIDENCE` — the explorer's classification and concrete evidence from that project.
4. `CODEBASE-POINTERS` — a brief list of the key file paths and pattern names relevant to this task (e.g. `Models/userfitnessdata.cs (two-tier pattern)`, `APICalls.cs`, `Helpers/ActivityNotifications.cs`). Do NOT paste full file contents or the entire `sub-explore-codebase` summary — this agent will read/verify these paths itself using its `read` and `search` tools.
5. `EVALUATION` *(optional)* — when this is a revision pass, pass only the rubric dimensions scoring below 4 and the specific issues to address, not the full critique.

If `TARGET-PROJECT`, `PROJECT-TYPE`, or `PROJECT-EVIDENCE` is missing, STOP and return `ERROR: authoritative project identity missing from discovery inputs`.

**Guideline:** Keep the total invocation prompt to a short brief. If more detail is needed, this agent reads it directly from the matching coding-standards skill (see Step 1), the ticket data, and the codebase.

## Workflow

### Step 1: Determine Project Type, Load the Matching Conventions & Draft Mode

**First action — determine the project type from hard evidence, then load the matching coding-standards skill.** The plan MUST follow the .NET conventions (structure, naming, and test patterns) for the project type it targets. **Do NOT infer the stack from the ticket wording, the feature name, or assumptions — and never default to MVC or MAUI.** You MUST confirm the stack by inspecting the actual project file before drafting.

**Stack detection (mandatory, evidence-based):**
1. Read `TARGET-PROJECT` directly and verify that it owns the files in `CODEBASE-POINTERS`. Do not run a workspace-wide `.csproj` search to select a different project.
2. Classify **only** from concrete signals found in that project file / its source tree:

| Signal (must be observed in the actual files) | Project type | Skill to read (authoritative) |
|--------|--------------|-------------------------------|
| `Microsoft.NET.Sdk.Web`, `AddControllersWithViews`, `Controller` base classes, Razor `.cshtml` views, `DbContext`, any `*.Mvc.csproj` | **ASP.NET Core MVC** | `.github/skills/dotnet-mvc-coding-standards/SKILL.md` |
| `UseMaui`/`<UseMaui>true`, `net*-android`/`-ios`/`-maccatalyst` TFMs, `.xaml` + `.xaml.cs` code-behind views, `APICalls.cs`, Syncfusion (`Syncfusion.Maui.*`) controls | **.NET MAUI** | `.github/skills/peoplewith-coding-standards/SKILL.md` |

3. Compare the verified classification with `PROJECT-TYPE` and `PROJECT-EVIDENCE`. If they disagree, **STOP** and return `ERROR: discovery project identity conflicts with TARGET-PROJECT evidence` rather than guessing or selecting another project.
4. If you cannot find or read `TARGET-PROJECT`, **STOP** and return `ERROR: cannot determine project type — TARGET-PROJECT is unreadable` rather than guessing.

Read the matching skill **once** using `readFile` — it is the sole authoritative reference for that project type's coding standards, naming conventions, architecture patterns, project structure, and test conventions. If a solution genuinely contains both stacks, apply the skill matching the specific `.csproj` that owns each changed file, and record which stack you selected (and the `.csproj` evidence) in NOTES.

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

Using `CODEBASE-POINTERS` and the Feature Scaffold Guide from the skill you loaded in Step 1, determine the required file categories **for the project type**. Use the scaffold matching the project type; do not mix MAUI and MVC file categories.

**.NET MAUI scaffold:**

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

MAUI naming conventions (apply strictly):
- Model filenames and properties: **lowercase** (`waterintake.cs`, `userid`, `amount`)
- View files: **PascalCase** (`AddWaterIntake.xaml`)
- Methods: **PascalCase** (`LoadData()`)
- API constants: **PascalCase** (`GetWaterIntake`, `InsertWaterIntake`)

**ASP.NET Core MVC scaffold:**

| Need | File to create |
|------|----------------|
| Domain entity | `Domain/{Feature}.cs` |
| EF Core mapping | New `DbSet<{Feature}>` in `Data/AppDbContext.cs` (+ migration) |
| Request/response DTO | `Models/{Feature}/{Feature}Dto.cs` |
| Data access | `Repositories/I{Feature}Repository.cs` + `Repositories/{Feature}Repository.cs` |
| Business logic | `Services/I{Feature}Service.cs` + `Services/{Feature}Service.cs` |
| HTTP endpoints | `Controllers/{Feature}Controller.cs` |
| Razor views | `Views/{Feature}/Index.cshtml`, `Details.cshtml`, `Create.cshtml`, `Edit.cshtml` |
| DI registration | `AddScoped<...>` entries in `Program.cs` |

MVC naming conventions (apply strictly):
- Types, files, properties, and methods: **PascalCase** (`MedicationController`, `MedicationDto`, `GetByIdAsync`)
- Controllers suffixed `Controller`; services/repositories as interface + implementation
- Actions named by intent (`Index`, `Details`, `Create`, `Edit`, `Delete`), decorated with the HTTP verb
- `async Task<IActionResult>` for data-access actions; never bind or return entities \u2014 DTOs only

### Step 4: Verify Against Codebase

Before writing the plan, cross-check every reference against `CODEBASE-POINTERS` and the conventions from the skill. Use `read`, `search/fileSearch`, and `search/textSearch` to confirm each reference — target the specific symbol or file you need rather than reading whole files.

Confirm all of the following before writing the plan:
- Confirm any existing files referenced exist at the stated paths (e.g. MAUI `APICalls.cs`/`BaseNotify.cs`; MVC `AppDbContext.cs`/`Program.cs`)
- Confirm namespaces match the folder structure for the project type (flat `PeopleWith` for MAUI; folder-based namespaces for MVC)
- Confirm any UI components cited are already used in the project (e.g. MAUI `SfLinearProgressBar`; MVC Tag Helpers / shared layout)
- Confirm planned file names and patterns align with the naming conventions from the skill you loaded in Step 1
- Flag anything that cannot be verified in NOTES rather than assuming it exists

### Step 5: Write the Plan

Produce the plan in the following structure. The `MODEL` and `API/ENDPOINTS` sections are shown for both project types \u2014 use the block matching the project type determined in Step 1 and omit the other.

```
PLAN
====
TICKET: {KEY}
PROJECT TYPE: {.NET MAUI | ASP.NET Core MVC}
TARGET PROJECT: {workspace-relative .csproj path}
PROJECT EVIDENCE: {verified framework signals from TARGET PROJECT}
FEATURE: {feature name, e.g. WaterIntake}
ITERATION: {N}

OVERVIEW:
{2-3 sentence description of what is being built and why}

OUT OF SCOPE:
{items explicitly excluded by the ticket}

AC MAPPING:
AC1: "{acceptance criterion text}" -> Steps {N, M, ...}
AC2: ...

MODEL / DOMAIN:
# .NET MAUI:
File: PeopleWith/Models/user{feature}.cs
Properties:
  - {propertyname}: {type}  ({purpose})   # lowercase names
# ASP.NET Core MVC:
Entity: {Project}/Domain/{Feature}.cs
DTO:    {Project}/Models/{Feature}/{Feature}Dto.cs
Properties:
  - {PropertyName}: {type}  ({purpose})   # PascalCase names

DATA ACCESS:
# .NET MAUI \u2014 API ENDPOINTS (add to PeopleWith/APICalls.cs):
  - {ConstantName} = "{full URL}" -- {HTTP method}, {purpose}
# ASP.NET Core MVC \u2014 endpoints + persistence:
  - {Feature}Controller.{Action} [{HttpVerb}] -- {route}, {purpose}
  - {I}{Feature}Repository / {Feature}Service methods -- {purpose}
  - DbSet<{Feature}> in AppDbContext (+ migration) -- {purpose}

FILES TO CREATE:
  - {relative path} -- {one-line description}

FILES TO MODIFY:
  - {relative path} -- {specific change description}

TESTS:
  - Framework: {xUnit + Moq for MVC | test conventions from the loaded skill}
  - {test file path} -- {AC covered, scenario, expected result}
  # Follow the test conventions of the project type's skill (e.g. MVC controllers
  # tested via ControllerContext with mocked repositories; never a real DbContext).

IMPLEMENTATION ORDER:
1. {step} [no dependencies]
2. {step} [depends on step 1]
...

PATTERNS TO FOLLOW:
  - {specific pattern from codebase, with source file reference}

NOTES:
  {unverified references, risks, or important decisions, including the project-type
   determination if signals were ambiguous}
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
- Always determine the project type first and follow the .NET conventions (structure, naming, and tests) for **that** project type — never default to MAUI when the target is MVC (or vice versa)
- Do NOT include items marked out of scope in the ticket
- If codebase summary is insufficient to verify a path or pattern, flag it in NOTES rather than guessing
- Keep the invocation prompt small — rely on reading the matching skill file, ticket data, and codebase directly rather than large embedded context, to avoid oversized-request failures
