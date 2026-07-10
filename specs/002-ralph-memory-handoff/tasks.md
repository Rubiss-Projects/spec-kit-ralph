# Tasks: Durable Ralph Memory Handoff

**Input**: Design documents from `specs/002-ralph-memory-handoff/`

**Prerequisites**: [plan.md](plan.md), [spec.md](spec.md), [research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/), [quickstart.md](quickstart.md)

**Tests**: Required by SC-006, SC-009, SC-010, SC-011, the Script Gate, and the cross-platform parity contract. Test tasks appear before implementation tasks in each user-story phase.

**Organization**: Tasks are grouped by user story. Constitution amendment is the first blocking task; no product-code task may begin until it is complete.

**Delivery Constraint**: Work stays on `27-ralph-memory-handoff`. Every conventional commit created for this feature ends with `#27`; Ralph's downstream generic commit examples must not hard-code issue 27.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel after stated prerequisites because it touches different files
- **[Story]**: Maps the task to US1, US2, or US3
- Every task names the exact file or files it changes or validates

## Phase 1: Setup — Governance Gate

**Purpose**: Reconcile authoritative project governance before any product-code implementation.

- [x] T001 Amend Principles II, IV, and VI, bump the constitution to 2.0.0, and complete the sync impact propagation report in `.specify/memory/constitution.md`

**Checkpoint**: Constitution 2.0.0 authorizes `ralph-memory.md`, audit-only `progress.md`, coordinated persistence, and strict clean completion.

---

## Phase 2: Foundational — Shared Contract Assets

**Purpose**: Create the canonical template and reusable fixtures required by every user story.

**⚠️ CRITICAL**: This phase depends on T001 and blocks all user-story work.

- [x] T002 Create the UTF-8/LF canonical tokenized memory template defined by the schema contract in `templates/ralph-memory.md`
- [x] T003 [P] Add an active canonical memory fixture with nonterminal handoff content in `tests/regression/fixtures/ralph-memory-valid-active.md` after T002
- [x] T004 [P] Add a completed canonical memory fixture with the exact terminal marker in `tests/regression/fixtures/ralph-memory-valid-complete.md` after T002
- [x] T005 [P] Add one byte-stable malformed memory fixture containing multiple simultaneous structural defects in `tests/regression/fixtures/ralph-memory-malformed.md` after T002
- [x] T006 Document the memory fixtures, token normalization, and intended validation categories in `tests/regression/fixtures/README.md`

**Checkpoint**: The shared template and valid/invalid fixtures are ready for mirrored Bash and PowerShell tests.

---

## Phase 3: User Story 1 — Resume With Durable Context (Priority: P1) 🎯 MVP

**Goal**: Ensure every fresh iteration receives a valid canonical `ralph-memory.md` before selecting work, while `progress.md` remains optional audit context.

**Independent Test**: With incomplete tasks, verify a missing memory file is rendered from the shared template before fake-agent invocation; a valid existing file is preserved byte-for-byte; and a malformed file exits 1, reports every defect, remains unchanged, and never invokes the agent.

### Tests for User Story 1

> Write these tests first and confirm the new cases fail before implementation.

- [x] T007 [P] [US1] Add Bash helper and full-script tests for template rendering, valid-file preservation, aggregate malformed diagnostics, invalid-template failure, and pre-agent initialization in `tests/regression/bash/test-ralph-loop.sh`
- [x] T008 [P] [US1] Add equivalent PowerShell helper and full-script tests for rendering, preservation, aggregate diagnostics, invalid-template failure, and pre-agent initialization in `tests/regression/powershell/Test-RalphLoop.ps1`

### Implementation for User Story 1

- [x] T009 [P] [US1] Implement memory/template paths, create-new rendering, template-derived aggregate validation, repeated pre-agent preparation, and audit-only new progress initialization in `scripts/bash/ralph-loop.sh`
- [x] T010 [P] [US1] Implement the parity memory preparation and validation helpers with byte-preserving invalid-file behavior in `scripts/powershell/ralph-loop.ps1`
- [x] T011 [P] [US1] Make `ralph-memory.md` the first context source and demote `progress.md` to append-only audit/optional recent context in `commands/iterate.md`
- [x] T012 [US1] Add semantic parity assertions for canonical headings, metadata classes, validation result classes, and diagnostic categories across `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`
- [x] T013 [US1] Run the US1 independent scenario and syntax checks against `templates/ralph-memory.md`, `scripts/bash/ralph-loop.sh`, `scripts/powershell/ralph-loop.ps1`, `tests/regression/bash/test-ralph-loop.sh`, and `tests/regression/powershell/Test-RalphLoop.ps1`

**Checkpoint**: User Story 1 works independently—fresh contexts always begin with valid durable memory and never rely on the full audit log.

---

## Phase 4: User Story 2 — Preserve Knowledge and Audit History (Priority: P2)

**Goal**: Persist task state, compact durable memory, and append-only audit before one substantive work-unit commit, while failed/no-work iterations retain knowledge without changing tasks or `HEAD`.

**Independent Test**: Complete a fixture work unit and verify source changes plus `tasks.md`, `ralph-memory.md`, and `progress.md` are in one commit with no residual bookkeeping dirt; then verify a failed attempt changes only memory/audit, creates no commit, and those records join the next substantive commit.

### Tests for User Story 2

> Write these tests first and confirm the new cases fail before implementation.

- [ ] T014 [P] [US2] Add Bash static and temporary-Git-repository tests for persistence-before-commit ordering, failed-attempt retention, later substantive inclusion, and bookkeeping-only commit detection in `tests/regression/bash/test-ralph-loop.sh`
- [ ] T015 [P] [US2] Add equivalent PowerShell transaction, failed-attempt, follow-up commit, and bookkeeping-only detection tests in `tests/regression/powershell/Test-RalphLoop.ps1`

### Implementation for User Story 2

- [ ] T016 [P] [US2] Reorder the completed-work transaction, replace future commit hashes with knowable audit dispositions, define failed/no-work persistence, and remove the partial-commit contradiction in `commands/iterate.md`
- [ ] T017 [P] [US2] Add pre-iteration task/HEAD snapshots and read-only coordinated-commit/bookkeeping violation reporting in `scripts/bash/ralph-loop.sh`
- [ ] T018 [P] [US2] Add parity task/HEAD snapshots and read-only coordinated-commit/bookkeeping violation reporting in `scripts/powershell/ralph-loop.ps1`
- [ ] T019 [US2] Run the US2 completed-work, failed-attempt, follow-up-commit, and no-bookkeeping independent scenarios in `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`

**Checkpoint**: User Story 2 works independently with canonical fixtures—durable knowledge and audit history are separated, coordinated, and committed only with substantive work.

---

## Phase 5: User Story 3 — Complete Transparently and Consistently (Priority: P3)

**Goal**: Apply one strict, read-only completion contract on both platforms and clearly document the memory/audit split and failure behavior.

**Independent Test**: Exercise initial and post-agent completion on both platforms. Clean task-zero state with exact terminal handoff exits 0; dirty, stale-handoff, invalid-memory, failed-agent, or signal-with-remaining-task states exit 1 immediately, report all relevant paths/defects, start no next iteration, and leave history unchanged.

### Tests for User Story 3

> Write these tests first and confirm the new cases fail before implementation.

- [ ] T020 [P] [US3] Add Bash completion-gate tests for initial/post-agent clean success, dirty-path aggregation, stale handoff, failed-agent token, remaining-task token, no-next-iteration behavior, and unchanged history in `tests/regression/bash/test-ralph-loop.sh`
- [ ] T021 [P] [US3] Add equivalent PowerShell completion-gate and history-preservation tests in `tests/regression/powershell/Test-RalphLoop.ps1`

### Implementation for User Story 3

- [ ] T022 [P] [US3] Require the exact terminal `Current Handoff` before the final substantive commit and prohibit premature completion signaling in `commands/iterate.md`
- [ ] T023 [P] [US3] Centralize initial, signal, and post-iteration success behind task, memory, commit, handoff, and `git status --short --untracked-files=all` validation in `scripts/bash/ralph-loop.sh`
- [ ] T024 [P] [US3] Implement the parity centralized completion gate, aggregate dirty diagnostics, and immediate non-zero termination in `scripts/powershell/ralph-loop.ps1`
- [ ] T025 [US3] Add final cross-platform result/exit/diagnostic parity assertions while preserving existing completion-signal regressions in `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`
- [ ] T026 [P] [US3] Document initialization, malformed-memory failure, memory-first context, failed-attempt persistence, audit-only progress, and strict completion in `README.md`
- [ ] T027 [P] [US3] Record the durable memory handoff and clean-completion behavior under `Unreleased` without editing released sections in `CHANGELOG.md`
- [ ] T028 [P] [US3] Align launcher preflight and orchestrator exit descriptions with memory validation and dirty completion in `commands/run.md`
- [ ] T029 [US3] Run the US3 clean/dirty/inconsistent completion scenarios and documentation assertions in `tests/regression/bash/test-ralph-loop.sh`, `tests/regression/powershell/Test-RalphLoop.ps1`, `README.md`, and `commands/run.md`

**Checkpoint**: All three user stories are independently verifiable and both supported orchestration paths enforce the same transparent completion contract.

---

## Phase 6: Polish & Cross-Cutting Validation

**Purpose**: Close compatibility, packaging, propagation, and end-to-end quality gates.

- [ ] T030 Verify `templates/ralph-memory.md` remains package-included and no manifest schema/dependency change is required, updating `.extensionignore` or `extension.yml` only if the compatibility check fails
- [ ] T031 [P] Reconcile the validation guide with final commands, diagnostics, and fixture names in `specs/002-ralph-memory-handoff/quickstart.md`
- [ ] T032 Execute development-extension installation and installed-root template resolution from `specs/002-ralph-memory-handoff/quickstart.md` against `templates/ralph-memory.md`, `scripts/bash/ralph-loop.sh`, and `scripts/powershell/ralph-loop.ps1`
- [ ] T033 [P] Run the active-guidance propagation review across `.specify/memory/constitution.md`, `commands/iterate.md`, `commands/run.md`, and `README.md`, confirming `specs/001-port-ralph-extension/` remains unchanged
- [ ] T034 Run `bash -n`, both complete regression suites, `git diff --check`, and the full acceptance matrix documented in `specs/002-ralph-memory-handoff/quickstart.md`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 — Governance Gate**: No dependency; T001 must complete before all product-code work.
- **Phase 2 — Foundational Assets**: Depends on T001; blocks every user story.
- **Phase 3 — US1**: Depends on Phase 2.
- **Phase 4 — US2**: Depends on Phase 2 and integrates after US1 because it extends the memory lifecycle and the same command/script files.
- **Phase 5 — US3**: Depends on US1 and US2 because completion validates their memory and transaction postconditions.
- **Phase 6 — Polish**: Depends on all selected user stories.

### User Story Dependency Graph

```text
Governance (T001)
  └─> Shared Template & Fixtures (T002-T006)
        └─> US1 Durable Context (T007-T013)
              └─> US2 Coordinated Persistence (T014-T019)
                    └─> US3 Strict Completion (T020-T029)
                          └─> Polish & Validation (T030-T034)
```

### User Story Independence

- **US1 (P1)**: Independently testable after Phase 2 using missing, valid, and malformed memory fixtures.
- **US2 (P2)**: Independently testable with a pre-created valid memory fixture and temporary Git repository; integration order follows US1 because files overlap.
- **US3 (P3)**: Independently testable with complete/active memory fixtures and fake agent results; integration requires US1 validation and US2 commit postconditions.

### Within Each User Story

- Write the Bash and PowerShell tests first and confirm new cases fail.
- Implement mirrored platform behavior in parallel where files do not overlap.
- Update shared Markdown commands after tests define the observable contract.
- Run the independent checkpoint before starting the next story.
- Create at most one substantive work-unit commit per completed story, with a conventional subject ending in `#27`.

### Requirement Coverage

| Requirement Set | Covered By |
|---|---|
| FR-019 constitution amendment and propagation | T001, T033 |
| FR-002–FR-007, FR-010–FR-011, FR-016, FR-020 durable memory initialization/validation/parity | T002–T013 |
| FR-001, FR-008–FR-013, FR-015, FR-021 audit split and coordinated/failed persistence | T014–T019 |
| FR-014–FR-017, FR-022 strict completion and user documentation | T020–T029 |
| FR-004 packaging plus all success criteria and compatibility gates | T030–T034 |

## Parallel Opportunities

### Foundational

After T002, T003, T004, and T005 can run together because they create separate fixture files.

### User Story 1

```text
Parallel tests:          T007 (Bash) + T008 (PowerShell)
Parallel implementation: T009 (Bash) + T010 (PowerShell) + T011 (iterate command)
Join:                    T012, then T013
```

### User Story 2

```text
Parallel tests:          T014 (Bash) + T015 (PowerShell)
Parallel implementation: T016 (iterate command) + T017 (Bash) + T018 (PowerShell)
Join:                    T019
```

### User Story 3

```text
Parallel tests:          T020 (Bash) + T021 (PowerShell)
Parallel implementation: T022 (iterate command) + T023 (Bash) + T024 (PowerShell)
Parallel documentation:  T026 (README) + T027 (CHANGELOG) + T028 (run command)
Join:                    T025, then T029
```

### Polish

```text
Parallel gate checks:    T030 (packaging) + T031 (quickstart) + T033 (propagation)
Installed validation:    T032 after T030 and T031
Final join:              T034 after T032 and T033
```

## Implementation Strategy

### MVP First — User Story 1

1. Complete T001 so the constitution authorizes the new model.
2. Complete T002-T006 to establish the canonical shared contract assets.
3. Complete T007-T013 using test-first Bash/PowerShell development.
4. Stop and run the US1 independent test: missing memory initializes before work, valid memory is preserved, and malformed memory blocks selection without mutation.

### Incremental Delivery

1. **Governance + Foundation**: Constitution 2.0.0, template, and fixtures.
2. **US1 MVP**: Durable memory is available and read before every fresh iteration.
3. **US2**: Memory, task state, and audit become one coordinated substantive transaction; failures retain knowledge without commits.
4. **US3**: Every completion path becomes strict, read-only, cross-platform, and documented.
5. **Polish**: Package/install verification, propagation audit, and full quickstart matrix.

### Commit Strategy

- Do not create task-by-task bookkeeping commits.
- Commit only completed substantive work units with their `tasks.md`, `progress.md`, and `ralph-memory.md` updates when those runtime artifacts exist.
- Use conventional commit messages whose subject ends with `#27` on this feature branch.
- Never amend, auto-recover, or hide a failed completion state.

## Notes

- `[P]` means parallel only after its stated prerequisite and only when no listed file overlaps.
- `commands/iterate.md` is intentionally updated in separate story tasks; execute those tasks sequentially across stories.
- The release workflow owns extension version bumps; do not manually change `extension.yml` solely to set the expected 1.3.0 release.
- Do not rewrite historical design artifacts under `specs/001-port-ralph-extension/`.
- Preserve all existing Bash and PowerShell regression cases while adding the new matrix.
