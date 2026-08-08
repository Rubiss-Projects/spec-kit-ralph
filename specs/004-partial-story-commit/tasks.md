---
description: "Task list for feature 004-partial-story-commit"
---

# Tasks: Reconcile Partial User-Story Progress With Commit Validation

**Input**: Design documents from `/specs/004-partial-story-commit/`

**Prerequisites**: plan.md (required), spec.md (required), research.md, data-model.md, contracts/

**Tests**: INCLUDED — the spec explicitly requires regression coverage
(FR-012, SC-006) and issue #50 lists orchestrator test coverage plus PowerShell
parity as acceptance criteria.

**Organization**: Tasks are grouped by user story so each story can be
implemented and verified independently.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3)
- Exact file paths are included in each task

## Path Conventions

Spec-kit extension (single-project) layout at repository root:

- Command spec: `commands/iterate.md`
- Orchestrators: `scripts/bash/ralph-loop.sh`, `scripts/powershell/ralph-loop.ps1`
- Regression harnesses: `tests/regression/bash/test-ralph-loop.sh`,
  `tests/regression/powershell/Test-RalphLoop.ps1`
- Docs: `README.md`, `CHANGELOG.md`
- The downstream-generated `speckit-ralph-iterate` skill is produced from
  `commands/iterate.md` on install; it is not edited directly in this repo.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Establish a known-good baseline before changing behavior.

- [ ] T001 Run both regression harnesses to record the current baseline:
  `bash tests/regression/bash/test-ralph-loop.sh` and
  `pwsh tests/regression/powershell/Test-RalphLoop.ps1`; note any pre-existing
  failures so post-change results can be compared.
- [ ] T002 [P] Confirm the edit anchors still match source: the partial/failed
  branch of step 5 and the commit trigger in step 6 of `commands/iterate.md`,
  and `validate_iteration_commit_history` in `scripts/bash/ralph-loop.sh`
  (~L795–913) plus its twin in `scripts/powershell/ralph-loop.ps1` (~L785–933).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Fix the single shared source of the contradiction that every user
story depends on.

**⚠️ CRITICAL**: No user-story work can begin until this phase is complete.

- [ ] T003 In `commands/iterate.md` step 5 ("Persist the iteration outcome
  before any commit"), rewrite the "When the selected work unit fails, produces
  no work, or remains partial" branch: remove the instruction that a validated
  partial result may mark completed tasks while leaving those changes
  uncommitted (current lines ~61–66). Replace with policy option 1 — a validated
  task or task subset is marked `[x]` AND committed in one coordinated commit in
  the same iteration; only failed/no-work attempts leave `tasks.md` unchanged and
  create no commit. Keep the coordinated-commit staging (tasks.md +
  ralph-memory.md + progress.md + substantive changes). See
  `contracts/iterate-partial-progress-policy.md`.
- [ ] T004 In `commands/iterate.md` step 6, change the commit trigger from "When
  ALL tasks in the selected user story are complete" to "When the validated work
  unit (a task, task group, or completed story) is complete", so a mid-story
  validated subset commits each iteration. Preserve the one-story-per-iteration
  Scope Constraint (lines ~13–21) and the `commit-subject-invalid` self-repair
  allowance.

**Checkpoint**: The canonical partial-progress policy now lives in
`commands/iterate.md`; the generated skill inherits it. User-story verification
can begin.

---

## Phase 3: User Story 1 - Multi-task story spans iterations without failing (Priority: P1) 🎯 MVP

**Goal**: A user story with several tasks completes across multiple iterations;
each iteration that finishes a validated subset is accepted and the loop
continues.

**Independent Test**: Run the bash harness case where an iteration advances HEAD
with one coordinated commit that reduces the incomplete count → validation exits
0; a two-commit sequence completes a two-task story without a FAILED result.

- [ ] T005 [P] [US1] Add a regression case in
  `tests/regression/bash/test-ralph-loop.sh` that builds a temp repo, performs a
  partial-story coordinated commit (substantive file + tasks.md + progress.md +
  ralph-memory.md) reducing the incomplete count by one, and asserts
  `validate_iteration_commit_history` exits 0 (advanced HEAD, partial story
  accepted).
- [ ] T006 [P] [US1] Add a regression case in
  `tests/regression/bash/test-ralph-loop.sh` that applies two sequential
  coordinated commits completing a two-task story across two iterations and
  asserts both pass and no `coordinated-commit-invalid`/`FAILED` diagnostic is
  emitted.
- [ ] T007 [US1] Mirror T005 and T006 as parity cases in
  `tests/regression/powershell/Test-RalphLoop.ps1` (advanced-HEAD partial accept
  + two-commit story completion), asserting identical decisions/diagnostics.

**Checkpoint**: US1 verified — the reported bug scenario now passes on both
platforms.

---

## Phase 4: User Story 2 - Completed state never stranded uncommitted (Priority: P1)

**Goal**: Marking tasks complete without committing is rejected, and failed work
never mutates the task list — so no validated completion is left in a dirty
worktree.

**Independent Test**: Bash harness case where HEAD is unchanged but the
incomplete count dropped → validation exits non-zero with
`coordinated-commit-invalid`; a failed iteration that changed `tasks.md` →
`failed-iteration-task-state`.

- [ ] T008 [US2] In `scripts/bash/ralph-loop.sh`, tighten the comment on the
  unchanged-HEAD + reduced-count branch (~L840–842) to state that option 1
  requires the completion to be committed in the same iteration; keep the
  existing `coordinated-commit-invalid` rejection logic unchanged.
- [ ] T009 [US2] Apply the parity comment tightening in
  `scripts/powershell/ralph-loop.ps1` (~L808–812); keep the rejection logic
  unchanged.
- [ ] T010 [P] [US2] Add a regression case in
  `tests/regression/bash/test-ralph-loop.sh`: unchanged HEAD + reduced incomplete
  count → exit 1 containing
  `coordinated-commit-invalid: completed task state was not included in a new
  work-unit commit`.
- [ ] T011 [P] [US2] Add a regression case in
  `tests/regression/bash/test-ralph-loop.sh`: a failed/no-work iteration that
  changed `tasks.md` without reducing the count → exit 1 containing
  `failed-iteration-task-state`.
- [ ] T012 [US2] Mirror T010 and T011 as parity cases in
  `tests/regression/powershell/Test-RalphLoop.ps1`.

**Checkpoint**: US2 verified — guardrails against stranded/uncommitted
completion hold identically on both platforms.

---

## Phase 5: User Story 3 - One consistent policy across command, skill, and orchestrator (Priority: P2)

**Goal**: The iterate command, the generated skill, and both orchestrators
describe and enforce the same work-unit definition, with no contradictions.

**Independent Test**: A review pass finds the same work-unit wording in
`commands/iterate.md` and both orchestrator scripts, and the docs describe
committing validated subsets each iteration.

- [ ] T013 [P] [US3] Align the work-unit wording in `scripts/bash/ralph-loop.sh`
  comments/messages so "work unit" explicitly includes a validated task group
  (matching `commands/iterate.md` and Constitution Principle II); no logic
  change.
- [ ] T014 [P] [US3] Apply the same wording alignment in
  `scripts/powershell/ralph-loop.ps1`; keep it byte-for-byte equivalent in intent
  to the bash version.
- [ ] T015 [P] [US3] Self-consistency sweep of `commands/iterate.md`: verify the
  Scope Constraint (lines ~13–21), steps 5–6, the Progress Report `**Commit**`
  values, and Stop Conditions contain no residual "entire user story"-only or
  "leave uncommitted" wording that contradicts T003/T004.
- [ ] T016 [P] [US3] Update `README.md` iteration/commit guidance to state that a
  validated task subset is committed as a coordinated work unit each iteration
  and that a story may span multiple iterations.
- [ ] T017 [P] [US3] Add an Unreleased entry to `CHANGELOG.md` describing the
  reconciliation and referencing issue #50.

**Checkpoint**: US3 verified — a single, consistent policy is stated and enforced
everywhere.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Final validation across all stories.

- [ ] T018 Run both regression harnesses and confirm all cases (including the new
  T005–T012 cases) pass on both platforms (quickstart.md §1).
- [ ] T019 [P] Walk the quickstart.md §2 manual reproduction (three-task story,
  complete only T001) and confirm the post-fix expected outcomes, including a
  clean `git status --short` and next-iteration selection of T002.
- [ ] T020 Final cross-surface consistency check per SC-005: diff the policy
  statements in `commands/iterate.md`, both orchestrators, and `README.md` for
  zero contradictions; confirm the generated-skill note in plan.md still holds.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately.
- **Foundational (Phase 2, T003–T004)**: Depends on Setup — **BLOCKS all user
  stories** (the policy edit is the shared source).
- **User Stories (Phases 3–5)**: All depend on Foundational completion.
  - US1 and US2 are both P1 and independently verifiable after Phase 2.
  - US3 (P2) depends on Phase 2 and is cleanest after US1/US2 land, but its doc
    and wording tasks can proceed in parallel once T003/T004 are done.
- **Polish (Phase 6)**: Depends on all user stories being complete.

### User Story Dependencies

- **US1 (P1)**: After Phase 2. No dependency on US2/US3.
- **US2 (P1)**: After Phase 2. Independent of US1 (touches orchestrator comments +
  distinct test cases).
- **US3 (P2)**: After Phase 2. Reconciles wording/docs; independent test surface.

### Within Each User Story

- Orchestrator comment tasks (T008/T009, T013/T014) before or alongside their
  test tasks; bash and PowerShell edits must stay in parity.
- New test cases are added to the existing harnesses and run at each checkpoint.

### Parallel Opportunities

- T002 (Setup) is [P].
- Within US1: T005 and T006 are [P] (same file, distinct cases — sequence if edit
  conflicts arise); T007 is separate-file parity.
- Within US2: T010 and T011 are [P]; T012 is separate-file parity.
- Within US3: T013, T014, T015, T016, T017 are all [P] (distinct files/sections).
- Polish: T019 is [P].

---

## Parallel Example: User Story 3

```bash
# Once Phase 2 (T003–T004) is complete, US3 doc/wording tasks can run together:
Task: "Align work-unit wording in scripts/bash/ralph-loop.sh"          # T013
Task: "Align work-unit wording in scripts/powershell/ralph-loop.ps1"   # T014
Task: "Self-consistency sweep of commands/iterate.md"                   # T015
Task: "Update README.md iteration/commit guidance"                     # T016
Task: "Add CHANGELOG.md Unreleased entry for #50"                      # T017
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup (baseline green).
2. Phase 2: Foundational — rewrite the `commands/iterate.md` partial-progress
   policy (T003–T004). **This alone removes the reported failure.**
3. Phase 3: US1 — add and pass the multi-iteration regression cases.
4. **STOP and VALIDATE**: The issue #50 reproduction now passes.

### Incremental Delivery

1. Setup + Foundational → contradiction removed.
2. US1 → multi-iteration story spanning verified (MVP).
3. US2 → stranded-state guardrails verified.
4. US3 → policy wording/docs reconciled across all surfaces.
5. Polish → full cross-platform regression + quickstart validation.

---

## Notes

- [P] tasks = different files or clearly separable sections, no ordering
  dependency.
- Bash and PowerShell changes MUST remain in behavioral parity (Constitution
  Script Gate; FR-011).
- No cleanup/amend/rebase/recovery logic may be introduced (Principle VI).
- The generated skill is not edited directly; correctness flows from
  `commands/iterate.md`.
- Commit after each coordinated task group; run the relevant harness at each
  checkpoint.
