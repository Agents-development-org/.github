---
name: sub-plan-evaluate
description: Evaluate a drafted implementation plan using rubric scoring and return a structured critique for the calling agent
model: Coder-fast-2 (litellm)
tools:
  - read/readFile
  - search/fileSearch
user-invocable: false
argument-hint: "<TICKET-KEY> <TICKET-DATA>"
---

# Sub-Agent: Plan Evaluate

Single responsibility: read the current draft plan from the temp workspace, score it against a rubric, and return a structured evaluation.

## Inputs Expected

The calling agent must provide:
1. `TICKET-KEY` — the Jira ticket key (e.g. `GPP-123`), used to locate the plan file
2. `TICKET-DATA` — structured output from `sub-read-jira`, used to verify AC coverage
3. `TARGET-PROJECT` — the exact workspace-relative `.csproj` path selected during discovery
4. `PROJECT-TYPE` + `PROJECT-EVIDENCE` — the discovery classification and its concrete evidence
5. `CODEBASE-POINTERS` — relevant files owned by the target project

If `TARGET-PROJECT`, `PROJECT-TYPE`, or `PROJECT-EVIDENCE` is missing, stop and return:
`ERROR: authoritative project identity missing from evaluation inputs`.

## Workflow

### Step 1: Detect the Stack, Load the Matching Conventions & Read the Plan

**First action — read the plan, then verify the supplied target project from hard evidence, exactly as `sub-plan-draft` does.** Do NOT assume MAUI and do not search the workspace for a replacement project.

1. Read `.agent-workspace/{TICKET-KEY}/IMPL-PLAN-{TICKET-KEY}.md`.
2. Read `TARGET-PROJECT` directly and verify that it owns the plan's files and `CODEBASE-POINTERS`.
3. Classify from concrete signals in that project only:

| Signal (observed in the actual project) | Project type | Matching skill folder (discovered at runtime) |
|--------|--------------|-----------------------------------------------|
| `Microsoft.NET.Sdk.Web`, `AddControllersWithViews`, `Controller` base classes, `.cshtml` views, `DbContext`, any `*.Mvc.csproj` | **ASP.NET Core MVC** | The skill under `.github/skills/` whose content describes MVC conventions (e.g. `dotnet-mvc-coding-standards`) |
| `UseMaui`, `net*-android`/`-ios`/`-maccatalyst` TFMs, `.xaml` + `.xaml.cs`, `APICalls.cs`, `Syncfusion.Maui.*` | **.NET MAUI** | The skill under `.github/skills/` whose content describes MAUI/PeopleWith conventions (e.g. `peoplewith-coding-standards`) |

Compare the verified classification with the supplied `PROJECT-TYPE`, `PROJECT-EVIDENCE`, and the plan's `PROJECT TYPE`/`TARGET PROJECT` fields. If any disagree, stop and return:
`ERROR: project identity conflict — TARGET-PROJECT evidence does not match discovery or plan`.

**Load only the matching conventions skill.** Discover skill metadata, select the skill matching the verified target stack, and do not load the body of the non-matching framework skill:
1. Enumerate all skill files: `fileSearch` `.github/skills/**/SKILL.md`.
2. Read only enough frontmatter (`name:` and `description:`) to identify the matching framework skill.
3. Read the full matching skill and use it as the conventions reference for Dimension 1 and Dimension 4 scoring.

If no matching skill is found for the detected stack, stop and return:
`ERROR: No coding-standards skill found under .github/skills/ for detected stack {stack}. Ensure the correct skill is present in the workspace.`

If the file does not exist, stop and return:
`ERROR: Plan file not found at .agent-workspace/{TICKET-KEY}/IMPL-PLAN-{TICKET-KEY}.md — ensure sub-plan-draft has run first.`

### Step 3: Score Each Rubric Dimension

Score each dimension independently on a scale of 1-5 using the criteria below.

---

#### Dimension 1: Instruction Adherence
*Does the plan follow the conventions defined in the coding-standards skill **for the detected stack**?*

> If the plan targets the wrong stack entirely (e.g. an ASP.NET MVC plan for a .NET MAUI project, or a MAUI plan for an MVC project), score **1** and record it as the primary issue.

| Score | Criteria |
|-------|----------|
| 5 | All naming conventions correct for the detected stack — **MAUI:** lowercase model filenames/properties, PascalCase view files and methods, `Update*` helper prefix, structure `Views/{Feature}/`, `Models/`, `Helpers/`, patterns (MVVM-lite code-behind, no DI container, `APICalls` static class, `BaseNotify`, `ObservableCollection`); **MVC:** PascalCase types/files/properties, `Controller` suffix, interface+implementation services/repositories, DTOs (never entities), structure `Controllers/`, `Services/`, `Repositories/`, `Models/{Feature}/`, `Views/{Feature}/`, DI via `AddScoped` in `Program.cs` |
| 4 | Minor deviation in one area that does not affect implementation correctness |
| 3 | 1-2 fixable convention violations (e.g. wrong casing on a property name, missing a required base type reference) |
| 2 | Several convention violations across multiple areas |
| 1 | Fundamental pattern misused **or wrong stack targeted** (e.g. DI container proposed for MAUI, controllers/`DbContext` proposed for MAUI, static `APICalls`/XAML proposed for MVC, wrong base class, incorrect file structure for the detected stack) |

---

#### Dimension 2: Codebase Accuracy
*Are all referenced files, namespaces, classes, and API patterns verified against the codebase summary?*

| Score | Criteria |
|-------|----------|
| 5 | Every file path, namespace, and class reference confirmed to exist in `CODEBASE-SUMMARY`; API endpoint URL patterns match the existing `APICalls.cs` OData style; namespace matches folder structure for all new files |
| 4 | All critical references verified; 1 minor unverified reference flagged in NOTES |
| 3 | Most references correct; 1-2 unverified paths present without being flagged |
| 2 | Several unverified or invented references |
| 1 | Multiple references to files or classes that do not exist in the codebase |

---

#### Dimension 3: AC Coverage
*Does every acceptance criterion from the ticket map to at least one concrete implementation step?*

| Score | Criteria |
|-------|----------|
| 5 | Every AC has an explicit entry in the AC MAPPING section and a corresponding step in IMPLEMENTATION ORDER; out-of-scope items are listed and not planned |
| 4 | All ACs covered; AC MAPPING present but 1 mapping reference is imprecise |
| 3 | Most ACs covered; 1 AC missing or only partially addressed |
| 2 | Multiple ACs unaddressed or out-of-scope items have been planned |
| 1 | AC MAPPING section absent or the majority of ACs have no corresponding steps |

---

#### Dimension 4: Completeness
*Are all required file categories present for the feature type described by the ticket, **for the detected stack**?*

| Score | Criteria |
|-------|----------|
| 5 | All expected categories present for the stack — **MAUI:** Model (`user{feature}.cs`), required Views (Add/All/Single as ACs require), APICalls endpoint constants, Update helper if list refresh needed, Converter if display transformation needed; **MVC:** Domain entity, `DbSet` + migration, DTO(s), repository (interface+impl), service (interface+impl), controller, required Razor views, DI registration in `Program.cs` |
| 4 | All required categories present; 1 optional category absent with a justification in NOTES |
| 3 | Core files present; 1 optional category missing without justification |
| 2 | A required category is present but incomplete (e.g. Model/entity defined but missing key properties) |
| 1 | A required category is entirely missing (e.g. no Model/entity, no APICalls entries / no repository or controller) |

---

#### Dimension 5: Dependency Ordering
*Is the IMPLEMENTATION ORDER correct, with no step depending on something defined later?*

| Score | Criteria |
|-------|----------|
| 5 | Model defined before used in ViewModels; APICalls constants defined before referenced; UI components depend on Model and API being available; all inter-step dependencies explicitly noted in brackets |
| 4 | Correct order throughout; dependency notes absent for 1-2 obvious dependencies |
| 3 | Mostly correct; 1-2 steps could be reordered without breaking the plan |
| 2 | A step references something defined later in the order |
| 1 | Significant ordering issues (e.g. ViewModel written before Model, API endpoint used before it is defined) |

---

### Step 4: Determine Pass or Fail

**PASS**: All 5 dimensions score >= 4
**FAIL**: Any dimension scores < 4

### Step 5: Return Structured Evaluation

```
EVALUATION
==========
TICKET: {KEY}
ITERATION: {N}
RESULT: PASS | FAIL

RUBRIC SCORES:
  Instruction Adherence:  {score}/5 -- {one-line justification}
  Codebase Accuracy:      {score}/5 -- {one-line justification}
  AC Coverage:            {score}/5 -- {one-line justification}
  Completeness:           {score}/5 -- {one-line justification}
  Dependency Ordering:    {score}/5 -- {one-line justification}

TOTAL: {sum}/25

ISSUES TO FIX (dimensions scoring < 4 only):
  [{Dimension Name}] {specific issue — cite the exact plan section and the violated convention}
    -> Suggested fix: {concrete action for sub-plan-draft to take}

APPROVED SECTIONS (dimensions scoring >= 4):
  {list — sub-plan-draft must not change these on the next iteration}
```

## Notes

- Read only — do NOT modify the plan file
- Be specific in issue descriptions: cite the exact plan section and the violated rule
- If RESULT is PASS, the calling agent (`software-engineer`) should proceed to the human approval gate without another draft iteration
- Score strictly — a 4 means "acceptable with minor notes", not "good enough to ignore"
