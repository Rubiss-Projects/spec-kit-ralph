# Tasks: Port Ralph Loop to Spec-Kit Extension

**Input**: Design documents from `/specs/001-port-ralph-extension/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not requested — manual integration testing per research R8.

**Organization**: Tasks are grouped by user story to enable independent implementation and testing. US3, US5, and US6 are cross-cutting concerns satisfied by artifacts in other phases (see Dependencies section).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US4)
- Include exact file paths in descriptions

## Path Conventions

- **Extension-native flat structure**: Extension root = repository root (no `src/` or nested layout)
- Scripts at `scripts/powershell/` and `scripts/bash/`
- Commands at `commands/`
- Config template at repository root

---

## Phase 1: Setup

**Purpose**: Create directory structure and boilerplate files

- [x] T001 Create directory structure: `commands/`, `scripts/powershell/`, `scripts/bash/`, `agents/` per plan.md project structure
- [x] T002 [P] Create MIT license file at LICENSE
- [x] T003 [P] Create initial changelog at CHANGELOG.md with v1.0.0 Unreleased section

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Create the extension manifest and config template that define the contract for all subsequent work

**⚠️ CRITICAL**: All user story phases reference manifest commands and config fields. These must exist first.

- [x] T004 Create extension.yml manifest per specs/001-port-ralph-extension/contracts/extension-manifest.md at extension.yml (schema v1.0, 2 commands, 1 hook, 1 config, defaults section)
- [x] T005 [P] Create ralph-config.template.yml per specs/001-port-ralph-extension/contracts/config-schema.md at ralph-config.template.yml (model: claude-sonnet-4.6, max_iterations: 10, agent_cli: copilot — NO authentication tokens)

**Checkpoint**: Manifest and config template exist. Extension structure is defined.

---

## Phase 3: US1 - Install Ralph Extension (Priority: P1) 🎯 MVP

**Goal**: Make the extension installable via `specify extension add --dev /path/to/spec-kit-ralph` with all manifest references valid

**Independent Test**: Run `specify extension add --dev .` on a fresh spec-kit project → extension appears in `specify extension list` with 2 commands, config file exists at `.specify/extensions/ralph/ralph-config.yml`

### Implementation for User Story 1

US1 is satisfied when the extension.yml (T004) is valid AND all files it references exist. The manifest references:
- `commands/run.md` → Created in Phase 4 (US2, T009)
- `commands/iterate.md` → Created in Phase 5 (US4, T010)
- `ralph-config.template.yml` → Created in Phase 2 (T005)

No standalone implementation tasks — US1 is the integration checkpoint verified after all referenced files exist.

**Checkpoint**: Extension is installable. Verified in Phase 6 (Polish, T012).

---

## Phase 4: US2 - Run Ralph Loop (Priority: P1) 🎯 MVP

**Goal**: Port the orchestrator scripts and create the run command so the ralph loop can execute end-to-end

**Independent Test**: Install extension, create a project with completed tasks.md, run `ralph-loop.ps1` (or `.sh`) directly → agent iterates through tasks, spawns fresh process per iteration, updates checkboxes, writes progress, terminates on completion or limit

### Implementation for User Story 2

- [x] T006 [US2] Port ralph-loop.ps1 from source repo to scripts/powershell/ralph-loop.ps1 — adapt per research R2: remove common.ps1 dependency (inline any needed helpers), add config loading from .specify/extensions/ralph/ralph-config.yml with env var overrides (SPECKIT_RALPH_MODEL, SPECKIT_RALPH_MAX_ITERATIONS, SPECKIT_RALPH_AGENT_CLI), read agent_cli from config instead of hardcoded copilot path. MUST preserve from source: 3-consecutive-failure circuit breaker (FR-009), Ctrl+C/SIGINT trap with exit 130 (FR-010), summary block on ALL 4 termination paths — completion/limit/failure/interrupt (FR-013), and all 3 termination-condition checks (FR-008). Source: C:\Users\Rubis\Projects\spec-kit\scripts\powershell\ralph-loop.ps1
- [x] T007 [P] [US2] Port ralph-loop.sh from source repo to scripts/bash/ralph-loop.sh — adapt per research R2: same changes as PowerShell (remove common.sh dependency, add YAML config loading, env var overrides, agent_cli from config). MUST preserve from source: 3-consecutive-failure circuit breaker (FR-009), Ctrl+C/SIGINT trap with exit 130 (FR-010), summary block on ALL 4 termination paths (FR-013), and all 3 termination-condition checks (FR-008). Source: C:\Users\Rubis\Projects\spec-kit\scripts\bash\ralph-loop.sh
- [x] T008 [P] [US2] Port iteration behavior from source command material into commands/iterate.md — keep all outline steps, scope constraint, progress format, completion signal, and reference to .specify/scripts/powershell/check-prerequisites.ps1 (core spec-kit script). Source: C:\Users\Rubis\Projects\spec-kit\templates\commands\ralph.md
- [x] T009 [US2] Create commands/run.md thin launcher per specs/001-port-ralph-extension/contracts/command-schemas.md at commands/run.md — implement: prerequisite validation (copilot CLI, tasks.md, git repo, feature branch), launcher-only argument parsing, platform detection (PowerShell vs Bash), and delegation to ralph-loop.ps1 or ralph-loop.sh with configured parameters (model, max_iterations, spec_dir). Extension path resolution: after `specify extension add`, the extension files are symlinked/copied into `.specify/extensions/ralph/`

**Checkpoint**: Ralph loop runs end-to-end via direct script invocation. US2 acceptance scenarios 1-5 satisfied.

---

## Phase 5: US4 - Agent Iteration Command (Priority: P2)

**Goal**: Create the iterate command that instructs the agent on single-iteration behavior — scope constraint, task identification, progress logging, commit protocol

**Independent Test**: Manually invoke `copilot --agent speckit.ralph.iterate` on a project with incomplete tasks → agent completes one work unit, updates tasks.md checkboxes, appends progress entry, creates conventional commit

### Implementation for User Story 4

- [x] T010 [US4] Create commands/iterate.md per specs/001-port-ralph-extension/contracts/command-schemas.md at commands/iterate.md — port from source repo templates/commands/ralph.md (adapt per research R6: update frontmatter script references to use ../../scripts/bash/check-prerequisites.sh and ../../scripts/powershell/check-prerequisites.ps1 with --json --require-tasks --include-tasks flags, keep scope constraint, outline steps, progress format, stop conditions, quality gates, error handling). Source: C:\Users\Rubis\Projects\spec-kit\templates\commands\ralph.md

**Checkpoint**: Iterate command defined. US4 acceptance scenarios 1-4 satisfied. US3 (Progress Tracking and Memory) also satisfied — progress.md format and ralph-memory.md handoff sections are specified in iterate command instructions and initialized by scripts from templates/ralph-memory-template.md.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Documentation and integration validation

- [x] T011 Create README.md at README.md documenting: extension overview, prerequisites (spec-kit, copilot CLI, git), installation via specify extension add, both usage paths (agent command /speckit.ralph.run AND direct script invocation), configuration options (model, max_iterations, agent_cli), environment variables, how the loop works (iteration cycle, termination conditions), resume after interruption
- [x] T012 [P] Run quickstart.md validation: verify `specify extension add --dev .` succeeds on a spec-kit project, `specify extension list` shows ralph extension with 2 commands, config file created at .specify/extensions/ralph/ralph-config.yml, iterate.md frontmatter script paths (../../scripts/bash/check-prerequisites.sh, ../../scripts/powershell/check-prerequisites.ps1) resolve correctly after registration — confirms US1 acceptance scenarios 1-3

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — can start immediately
- **Foundational (Phase 2)**: Depends on Setup (directories must exist first)
- **US1 (Phase 3)**: No standalone tasks — integration checkpoint verified in Polish (T012)
- **US2 (Phase 4)**: Depends on Foundational (manifest defines command paths)
- **US4 (Phase 5)**: Depends on Foundational (manifest defines command paths); independent of US2
- **Polish (Phase 6)**: Depends on all previous phases completing

### User Story Dependencies

- **US1 (Install)**: Satisfied when extension.yml (T004) + config template (T005) + all referenced command files (T009, T010) exist. Verified by T012.
- **US2 (Run Loop)**: Core implementation. Scripts (T006, T007) + iterate command behavior (T008) + run command (T009). Independent of US4.
- **US3 (Progress Tracking and Memory)**: Cross-cutting — satisfied by scripts' Initialize-ProgressFile and Initialize-MemoryFile functions (T006/T007), templates/ralph-memory-template.md, and iterate command's progress report and memory handoff format (T010). No standalone tasks.
- **US4 (Iterate Command)**: Single command file (T010). Independent of US2 scripts (can be written and tested separately).
- **US5 (Config)**: Cross-cutting — satisfied by config template (T005) + script config loading (T006/T007) + env var overrides. No standalone tasks.
- **US6 (Hooks)**: Cross-cutting — satisfied by `hooks.after_tasks` section in extension.yml (T004). No standalone tasks.

### Within Each User Story

- Scripts before commands (commands reference scripts)
- Iterate command behavior before run command (orchestrator invokes `speckit.ralph.iterate`)
- Core implementation before polish

### Parallel Opportunities

- **Phase 1**: T002 and T003 can run in parallel (independent files)
- **Phase 2**: T004 and T005 can run in parallel (independent files)
- **Phase 4**: T007 and T008 can run in parallel with each other (different files), but T009 should follow T006/T007/T008 (run.md references scripts and agent)
- **Phase 6**: T011 and T012 can run in parallel

---

## Parallel Example: User Story 2 (Phase 4)

```text
# Sequential first (PowerShell script sets the porting pattern):
Task T006: "Port ralph-loop.ps1 to scripts/powershell/ralph-loop.ps1"

# Then parallel (follow same pattern, independent files):
Task T007: "Port ralph-loop.sh to scripts/bash/ralph-loop.sh"
Task T008: "Port iteration behavior to commands/iterate.md"

# Then sequential (depends on scripts + iteration behavior):
Task T009: "Create commands/run.md thin launcher"
```

---

## Implementation Strategy

### MVP First (US1 + US2 — P1)

1. Complete Phase 1: Setup → directories + boilerplate exist
2. Complete Phase 2: Foundational → manifest + config template define the contract
3. Complete Phase 4: US2 → scripts + run command deliver loop execution
4. **STOP and VALIDATE**: Run `specify extension add --dev .` (verifies US1), then run ralph loop on a test project (verifies US2)
5. At this point, the extension is functional for direct script invocation

### Incremental Delivery

1. Setup + Foundational → Extension structure defined
2. US2 (scripts + run.md + agent) → Loop runs end-to-end (MVP!)
3. US4 (iterate.md) → Agent command available for Copilot integration
4. Polish (README + validation) → Extension ready for distribution
5. Each phase adds value without breaking previous work

### Cross-Cutting Story Resolution

US3 (Progress), US5 (Config), and US6 (Hooks) have no standalone phases because they are architectural cross-cuts:
- US3 emerges from scripts (T006/T007) + iterate command (T010)
- US5 emerges from config template (T005) + script config loading (T006/T007)
- US6 emerges from manifest hooks section (T004)

All cross-cutting stories are fully satisfied by the completion of Phase 5 (US4).

### Deferred Scope

- **`--list-models` flag** (US5 acceptance scenario 4): Not present in source scripts being ported. Deferred to a future release. The spec acceptance scenario remains as a target but is not covered by v1.0 tasks.

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story for traceability
- Source files to port are in `C:\Users\Rubis\Projects\spec-kit` (branch `001-ralph-loop-implement`)
- No Python code — all files are Markdown, YAML, PowerShell, and Bash
- Commit after each task or logical group
- Stop at any checkpoint to validate story independently
