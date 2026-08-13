# Tasks: Accept Task Expansion With Completed Progress

**Input**: Design documents from `/specs/005-task-expansion-validation/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md
**Tests**: Required by FR-014, FR-015, SC-001, SC-002, and SC-006. Regression tasks appear before implementation tasks for each user story.
**Organization**: Tasks are grouped by user story so each behavior slice can be implemented and validated independently.

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish the working context and identify exact edit surfaces.

- [x] T001 Review task-expansion policy and validation matrix in specs/005-task-expansion-validation/contracts/task-expansion-policy.md and specs/005-task-expansion-validation/contracts/iteration-validation-contract.md
- [x] T002 Review existing Bash and PowerShell validation helpers in scripts/bash/ralph-loop.sh and scripts/powershell/ralph-loop.ps1
- [x] T003 [P] Review current Bash regression scaffold for coordinated iteration commits in tests/regression/bash/test-ralph-loop.sh
- [x] T004 [P] Review current PowerShell regression scaffold for transaction repositories in tests/regression/powershell/Test-RalphLoop.ps1

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Add shared task-identity primitives required before any story-specific behavior can be safely implemented.

**CRITICAL**: No user story work can begin until this phase is complete.

- [x] T005 Add Bash helper to extract unique incomplete task IDs from a task file in scripts/bash/ralph-loop.sh
- [x] T006 Add Bash helper to extract unique incomplete task IDs for a task file at a commit in scripts/bash/ralph-loop.sh
- [x] T007 Add Bash helper to count completed existing task IDs between two incomplete-ID snapshots in scripts/bash/ralph-loop.sh
- [x] T008 Update Bash regression helper extraction to include new task-ID helpers in tests/regression/bash/test-ralph-loop.sh
- [x] T009 Update PowerShell task-ID snapshot handling to treat duplicate incomplete IDs as a single progress identity in scripts/powershell/ralph-loop.ps1
- [x] T010 Add regression assertions for duplicate incomplete task IDs not being double-counted in tests/regression/bash/test-ralph-loop.sh and tests/regression/powershell/Test-RalphLoop.ps1

**Checkpoint**: Both orchestrators can derive completed existing task IDs from before/after task snapshots.

---

## Phase 3: User Story 1 - Completed progress remains valid when follow-up tasks are added (Priority: P1) MVP

**Goal**: Accept an iteration that completes existing tasks and adds new unchecked follow-up tasks without failing invalid work-unit history.

**Independent Test**: Complete at least one existing task, add new unchecked tasks in the same committed iteration, and confirm both execution paths accept the iteration as completed progress.

### Tests for User Story 1

- [x] T011 [P] [US1] Add Bash regression for advanced-HEAD task expansion where completed existing IDs increase while unchecked count also increases in tests/regression/bash/test-ralph-loop.sh
- [x] T012 [P] [US1] Add PowerShell regression for advanced-HEAD task expansion where completed existing IDs increase while unchecked count also increases in tests/regression/powershell/Test-RalphLoop.ps1
- [x] T013 [P] [US1] Add Bash regression for state-only task-expansion work unit that completes an existing planning task and adds follow-up tasks in tests/regression/bash/test-ralph-loop.sh
- [x] T014 [P] [US1] Add PowerShell regression for state-only task-expansion work unit that completes an existing planning task and adds follow-up tasks in tests/regression/powershell/Test-RalphLoop.ps1

### Implementation for User Story 1

- [x] T015 [US1] Update Bash advanced-HEAD validation to use completed existing task IDs instead of net incomplete count in scripts/bash/ralph-loop.sh
- [x] T016 [US1] Update Bash commit-level bookkeeping-only validation to accept coordinated state-only commits when existing task IDs complete even if unchecked count increases in scripts/bash/ralph-loop.sh
- [x] T017 [US1] Update PowerShell commit-level bookkeeping-only validation to compare completed existing task IDs at each commit boundary in scripts/powershell/ralph-loop.ps1
- [x] T018 [US1] Run Bash focused regression cases for task-expansion acceptance in tests/regression/bash/test-ralph-loop.sh
- [x] T019 [US1] Run PowerShell focused regression cases for task-expansion acceptance in tests/regression/powershell/Test-RalphLoop.ps1

**Checkpoint**: User Story 1 is independently complete when valid task expansion is accepted in both execution paths.

---

## Phase 4: User Story 2 - Users can see when task expansion increases the loop size (Priority: P2)

**Goal**: Report accepted task expansion clearly so users understand why remaining work may grow.

**Independent Test**: Run a valid expansion iteration and verify output reports completed progress, added unchecked tasks, and updated remaining work.

### Tests for User Story 2

- [x] T020 [P] [US2] Add Bash regression asserting task-expansion output reports added unchecked tasks and updated remaining count in tests/regression/bash/test-ralph-loop.sh
- [x] T021 [P] [US2] Add PowerShell regression asserting task-expansion output reports added unchecked tasks and updated remaining count in tests/regression/powershell/Test-RalphLoop.ps1
- [x] T022 [P] [US2] Add Bash regression asserting summary completed count is based on completed existing IDs rather than initial-minus-final unchecked count in tests/regression/bash/test-ralph-loop.sh
- [x] T023 [P] [US2] Add PowerShell regression asserting summary completed count is based on completed existing IDs rather than initial-minus-final unchecked count in tests/regression/powershell/Test-RalphLoop.ps1

### Implementation for User Story 2

- [x] T024 [US2] Add Bash per-iteration task-expansion reporting after accepted validation in scripts/bash/ralph-loop.sh
- [x] T025 [US2] Add PowerShell per-iteration task-expansion reporting after accepted validation in scripts/powershell/ralph-loop.ps1
- [x] T026 [US2] Update Bash loop summary completed-task accounting to use accepted completed existing task IDs in scripts/bash/ralph-loop.sh
- [x] T027 [US2] Update PowerShell loop summary completed-task accounting to use accepted completed existing task IDs in scripts/powershell/ralph-loop.ps1
- [x] T028 [US2] Update user-facing task expansion guidance in README.md
- [x] T029 [US2] Update iteration guidance for dynamic follow-up tasks in commands/iterate.md

**Checkpoint**: User Story 2 is independently complete when users can see accepted expansion and accurate completed/remaining counts.

---

## Phase 5: User Story 3 - No-work task changes are still rejected (Priority: P3)

**Goal**: Preserve guardrails so task additions or rewrites without completed existing work remain invalid.

**Independent Test**: Add, replace, or mutate tasks without completing a previously incomplete task and verify both execution paths reject the iteration.

### Tests for User Story 3

- [x] T030 [P] [US3] Add Bash regression rejecting add-only unchecked task changes with no completed existing task in tests/regression/bash/test-ralph-loop.sh
- [x] T031 [P] [US3] Add PowerShell regression rejecting add-only unchecked task changes with no completed existing task in tests/regression/powershell/Test-RalphLoop.ps1
- [x] T032 [P] [US3] Add Bash regression rejecting replacement of one incomplete task ID with another without completed progress in tests/regression/bash/test-ralph-loop.sh
- [x] T033 [P] [US3] Add PowerShell regression rejecting replacement of one incomplete task ID with another without completed progress in tests/regression/powershell/Test-RalphLoop.ps1
- [x] T034 [P] [US3] Add Bash regression rejecting failed-agent task-list mutation even when new tasks are added in tests/regression/bash/test-ralph-loop.sh
- [x] T035 [P] [US3] Add PowerShell regression rejecting failed-agent task-list mutation even when new tasks are added in tests/regression/powershell/Test-RalphLoop.ps1

### Implementation for User Story 3

- [x] T036 [US3] Ensure Bash failed/no-work validation still rejects task-state changes without completed existing task IDs in scripts/bash/ralph-loop.sh
- [x] T037 [US3] Ensure PowerShell failed/no-work validation still rejects task-state changes without completed existing task IDs in scripts/powershell/ralph-loop.ps1
- [x] T038 [US3] Align invalid task-churn diagnostics with existing diagnostic categories in scripts/bash/ralph-loop.sh and scripts/powershell/ralph-loop.ps1
- [x] T039 [US3] Run negative guardrail regressions for both execution paths in tests/regression/bash/test-ralph-loop.sh and tests/regression/powershell/Test-RalphLoop.ps1

**Checkpoint**: User Story 3 is independently complete when invalid task churn remains rejected across both execution paths.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final documentation, release notes, and end-to-end validation.

- [x] T040 [P] Update CHANGELOG.md with the task-expansion validation fix and user-visible reporting behavior
- [x] T041 [P] Verify quickstart scenarios remain aligned with implemented behavior in specs/005-task-expansion-validation/quickstart.md
- [x] T042 Run full Bash regression harness with bash tests/regression/bash/test-ralph-loop.sh
- [x] T043 Run full PowerShell regression harness with pwsh tests/regression/powershell/Test-RalphLoop.ps1
- [x] T044 Verify README.md and commands/iterate.md contain no contradictory task-expansion guidance
- [x] T045 Confirm all task-expansion requirements FR-001 through FR-015 are satisfied by tests, docs, or implementation in specs/005-task-expansion-validation/spec.md

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies; can start immediately.
- **Phase 2 Foundational**: Depends on Phase 1; blocks all user stories because task-ID snapshots are shared primitives.
- **Phase 3 / User Story 1**: Depends on Phase 2; delivers MVP acceptance of valid task expansion.
- **Phase 4 / User Story 2**: Depends on Phase 3 for accepted expansion classification.
- **Phase 5 / User Story 3**: Depends on Phase 2 and can run alongside Phase 4 after US1 classification is stable.
- **Phase 6 Polish**: Depends on desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: MVP. Must complete before user-visible reporting can rely on accepted expansion state.
- **US2 (P2)**: Depends on US1 classification; adds reporting and documentation.
- **US3 (P3)**: Depends on foundational task-ID primitives; can be implemented after US1 or in parallel with US2 once acceptance behavior is stable.

### Parallel Opportunities

- T003 and T004 can run in parallel.
- T011-T014 can run in parallel because they edit platform-specific test sections.
- T020-T023 can run in parallel because each targets a distinct platform or assertion scope.
- T030-T035 can run in parallel across Bash and PowerShell negative scenarios.
- T040 and T041 can run in parallel with final harness execution after implementation stabilizes.

---

## Parallel Example: User Story 1

```text
Task: "Add Bash regression for advanced-HEAD task expansion where completed existing IDs increase while unchecked count also increases in tests/regression/bash/test-ralph-loop.sh"
Task: "Add PowerShell regression for advanced-HEAD task expansion where completed existing IDs increase while unchecked count also increases in tests/regression/powershell/Test-RalphLoop.ps1"
Task: "Add Bash regression for state-only task-expansion work unit that completes an existing planning task and adds follow-up tasks in tests/regression/bash/test-ralph-loop.sh"
Task: "Add PowerShell regression for state-only task-expansion work unit that completes an existing planning task and adds follow-up tasks in tests/regression/powershell/Test-RalphLoop.ps1"
```

## Parallel Example: User Story 2

```text
Task: "Add Bash regression asserting task-expansion output reports added unchecked tasks and updated remaining count in tests/regression/bash/test-ralph-loop.sh"
Task: "Add PowerShell regression asserting task-expansion output reports added unchecked tasks and updated remaining count in tests/regression/powershell/Test-RalphLoop.ps1"
Task: "Add Bash regression asserting summary completed count is based on completed existing IDs rather than initial-minus-final unchecked count in tests/regression/bash/test-ralph-loop.sh"
Task: "Add PowerShell regression asserting summary completed count is based on completed existing IDs rather than initial-minus-final unchecked count in tests/regression/powershell/Test-RalphLoop.ps1"
```

## Parallel Example: User Story 3

```text
Task: "Add Bash regression rejecting add-only unchecked task changes with no completed existing task in tests/regression/bash/test-ralph-loop.sh"
Task: "Add PowerShell regression rejecting add-only unchecked task changes with no completed existing task in tests/regression/powershell/Test-RalphLoop.ps1"
Task: "Add Bash regression rejecting failed-agent task-list mutation even when new tasks are added in tests/regression/bash/test-ralph-loop.sh"
Task: "Add PowerShell regression rejecting failed-agent task-list mutation even when new tasks are added in tests/regression/powershell/Test-RalphLoop.ps1"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 setup.
2. Complete Phase 2 task-ID snapshot primitives.
3. Add failing US1 regressions for valid task expansion.
4. Implement US1 validation changes in both orchestrators.
5. Run focused Bash and PowerShell US1 regressions.

### Incremental Delivery

1. Deliver US1 to stop falsely failing valid expansion work units.
2. Deliver US2 to make expansion visible and summaries accurate.
3. Deliver US3 to prove no-work and failed task churn remain rejected.
4. Finish with README, iterate-command, changelog, quickstart, and full harness validation.

### Validation Gates

1. All tasks use strict checklist format with IDs and exact file paths.
2. Each user story has independent tests before implementation tasks.
3. Full Bash and PowerShell regression harnesses pass before completion.
4. Documentation states that `max_iterations` remains the boundary for expanded task lists.

## Notes

- `[P]` marks tasks that can run in parallel because they touch different files or independent assertion scopes.
- `[US1]`, `[US2]`, and `[US3]` labels map directly to the user stories in spec.md.
- The MVP is US1: accept real completed progress even when follow-up tasks increase remaining work.
