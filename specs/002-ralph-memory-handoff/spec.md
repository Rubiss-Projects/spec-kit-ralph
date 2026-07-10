# Feature Specification: Durable Ralph Memory Handoff

**Feature Branch**: `27-ralph-memory-handoff`

**Created**: 2026-07-10

**Status**: Draft

**Input**: GitHub issue [#27](https://github.com/Rubiss-Projects/spec-kit-ralph/issues/27), including all comments, with Rubiss's response treated as the leading design direction and the later issue-owner musts treated as binding scope.

## Clarifications

### Session 2026-07-10

- Q: How should this feature reconcile the constitution's current durable-memory requirements with the new `ralph-memory.md` split? → A: Include a constitution amendment in this feature, with the required version increment and propagation review.
- Q: What should Ralph do when all tasks are complete but `git status --short` is dirty? → A: Stop immediately with a non-zero result, report the dirty paths, and require an explicit correction before rerunning.
- Q: How should Ralph handle an existing `ralph-memory.md` that does not match the canonical structure? → A: Stop with a non-zero result, preserve the file unchanged, and report every missing or invalid canonical section.
- Q: How should failed-attempt knowledge persist when an iteration completes no work unit? → A: Update `ralph-memory.md`, append `progress.md`, leave both uncommitted for a later substantive work-unit commit, and leave `tasks.md` unchanged.
- Q: What should `Current Handoff` contain after successful feature completion? → A: Replace its content with the single entry `Feature complete; no handoff required.` before the final substantive commit.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Resume With Durable Context (Priority: P1)

As a Ralph user, I want each fresh iteration to load a compact record of durable implementation knowledge before choosing work so that the agent continues from earlier discoveries without consuming the full iteration history.

**Why this priority**: Fresh-context execution is Ralph's defining behavior. A dependable, bounded memory bridge is therefore the core user value of this feature.

**Independent Test**: Start a fresh iteration for a feature that has durable decisions, gotchas, reusable commands, rejected approaches, and a current handoff. Verify that the iteration consumes those facts before selecting a work unit while remaining independent of the full audit history.

**Acceptance Scenarios**:

1. **Given** a feature with an existing `ralph-memory.md`, **When** a fresh Ralph iteration begins, **Then** it reads that memory before selecting or implementing a work unit.
2. **Given** a feature with no `ralph-memory.md`, **When** Ralph prepares the next iteration, **Then** it initializes the missing file from the shared canonical template before work selection.
3. **Given** a long `progress.md` and a concise `ralph-memory.md`, **When** a fresh iteration prepares its context, **Then** durable knowledge comes from `ralph-memory.md` and the audit history is only optional recent context.
4. **Given** an existing `ralph-memory.md` with missing or invalid canonical sections, **When** a fresh iteration prepares its context, **Then** Ralph stops with a non-zero result before work selection, leaves the file unchanged, and identifies every invalid section.

---

### User Story 2 - Preserve Knowledge and Audit History (Priority: P2)

As a maintainer, I want durable discoveries and chronological iteration history kept in separate artifacts so that future agents receive actionable knowledge without losing an auditable record of what happened.

**Why this priority**: The split prevents context bloat while preserving traceability and avoiding repeated mistakes across isolated iterations.

**Independent Test**: Complete one work unit containing a decision, a failed approach, and a reusable command. Verify that durable findings and the current handoff are reflected in `ralph-memory.md`, the chronological result is appended to `progress.md`, task state is current, and all three artifacts are updated before the work-unit commit.

**Acceptance Scenarios**:

1. **Given** an iteration discovers a reusable repository convention, **When** the work unit is completed, **Then** the convention is recorded under the canonical durable-memory section and the iteration outcome is separately appended to the audit history.
2. **Given** an attempted approach fails and no work unit completes, **When** the iteration ends, **Then** the rejected approach is recorded in `ralph-memory.md`, the attempt is appended to `progress.md`, `tasks.md` remains unchanged, and no commit is created.
3. **Given** existing durable memory, **When** a later iteration updates it, **Then** relevant existing entries are preserved, superseded entries are revised or removed, and the current handoff reflects only what the next iteration needs.
4. **Given** an iteration changes only bookkeeping artifacts and produces no completed work unit, **When** commit eligibility is evaluated, **Then** Ralph does not create a bookkeeping-only commit.

---

### User Story 3 - Complete Transparently and Consistently (Priority: P3)

As a project owner, I want Ralph to apply the same memory and completion contract on every supported platform and to finish only with a clean working tree so that completion is trustworthy and does not hide repository mutations.

**Why this priority**: Cross-platform parity and transparent completion protect user trust after the core handoff behavior is established.

**Independent Test**: Exercise the same missing-memory, existing-memory, completed-work-unit, and completion cases through each supported orchestration path. Verify equivalent outcomes, a clean working tree on success, and no silent history rewrites or hidden recovery commits.

**Acceptance Scenarios**:

1. **Given** equivalent feature state on any supported platform, **When** Ralph initializes or updates memory, **Then** the resulting structure and lifecycle behavior are equivalent.
2. **Given** all planned tasks are complete but the working tree has uncommitted changes, **When** Ralph validates completion, **Then** it stops immediately with a non-zero result, reports the dirty paths, and does not start another iteration.
3. **Given** completion validation detects inconsistent bookkeeping or repository state, **When** Ralph responds, **Then** it reports the problem without amending commits, rewriting history, or creating a hidden recovery commit.
4. **Given** a user reads the project documentation, **When** they look for iteration history or durable cross-iteration knowledge, **Then** they can identify `progress.md` as the audit trail and `ralph-memory.md` as the memory bridge.
5. **Given** the final substantive work unit completes all tasks, **When** durable memory is finalized before its commit, **Then** `Current Handoff` contains only `Feature complete; no handoff required.` and no stale next-work instructions.

### Edge Cases

- A feature predates this capability and has `progress.md` and `tasks.md` but no `ralph-memory.md`.
- Memory initialization is attempted more than once; existing user-authored memory must not be overwritten.
- An existing memory file has the canonical sections but contains outdated or duplicate entries.
- An iteration makes no new durable discovery; canonical sections remain valid without fabricated content.
- An iteration fails before completing a work unit; applicable failure knowledge and audit history remain as uncommitted working-tree changes for the next iteration, while task state remains unchanged.
- All tasks are marked complete while `ralph-memory.md`, `progress.md`, or `tasks.md` still has uncommitted changes.
- The working tree contains unrelated user changes when completion is evaluated.
- Platform-specific orchestration reaches the same logical state through different execution paths.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Ralph MUST keep `progress.md` as the append-only chronological audit and history of iterations.
- **FR-002**: Ralph MUST use `ralph-memory.md` as the primary compact, durable memory bridge between fresh iterations.
- **FR-003**: The durable memory MUST use one canonical structure containing feature identity, start information, `Codebase Patterns`, `Decisions`, `Gotchas`, `Reusable Commands`, `Do Not Repeat`, and `Current Handoff`.
- **FR-004**: The canonical durable-memory structure MUST come from one shared template in the project's `templates/` directory whenever a feature memory file is initialized.
- **FR-005**: Every supported orchestration path MUST initialize a missing `ralph-memory.md` from that shared source alongside the feature's existing state artifacts.
- **FR-006**: Memory initialization MUST preserve an existing `ralph-memory.md` and MUST NOT replace user-authored durable knowledge; an existing file with any missing or invalid canonical section MUST remain unchanged and cause a non-zero result before work selection that reports every invalid section.
- **FR-007**: Each fresh iteration MUST read `ralph-memory.md` before selecting a work unit.
- **FR-008**: Ralph MUST treat `progress.md` only as audit history and optional recent context, never as the primary durable-memory source; per-iteration learnings MUST remain concise and direct durable discoveries into `ralph-memory.md`.
- **FR-009**: Iterations MUST preserve still-valid durable entries and record non-obvious decisions, gotchas, reusable commands, failed approaches, and next-iteration handoff information before committing a completed work unit.
- **FR-010**: Durable memory MUST remain compact by updating or removing superseded information, avoiding chronological iteration logs, and limiting `Current Handoff` to information needed by the next fresh iteration or the single required completion marker when no work remains.
- **FR-011**: All memory update paths MUST preserve the canonical section names and meanings so repeated iterations cannot introduce incompatible structures.
- **FR-012**: Before committing a completed work unit, Ralph MUST update `tasks.md`, append the applicable audit entry to `progress.md`, and update `ralph-memory.md` with applicable durable knowledge and current handoff state.
- **FR-013**: Ralph MUST NOT create commits whose only purpose is to record changes to `progress.md` or `ralph-memory.md` without a completed work unit.
- **FR-014**: Ralph MUST require a clean result from `git status --short` before reporting successful completion; when all tasks are complete but the result is dirty, Ralph MUST stop immediately with a non-zero result, report the dirty paths, and require explicit correction before rerunning without starting another iteration.
- **FR-015**: Completion validation MUST report inconsistent task, memory, audit, or working-tree state and MUST NOT silently rewrite history, amend commits, or create hidden recovery commits.
- **FR-016**: Equivalent missing-memory, preservation, update-order, no-bookkeeping-commit, and clean-completion behaviors MUST be verifiable on every supported orchestration path.
- **FR-017**: User documentation MUST explain the artifact split, when durable memory is read and updated, how missing memory is initialized, and why audit history is not the primary context source.
- **FR-018**: Delivery work for this feature MUST use branch names beginning with `27-` and conventional commit messages ending with `#27`.
- **FR-019**: This feature MUST amend the project constitution so Principles II and IV recognize `ralph-memory.md` as the durable cross-iteration memory source and `progress.md` as the append-only audit history, including the required version increment and propagation review.
- **FR-020**: Ralph MUST validate an existing `ralph-memory.md` against the canonical section contract before using it, without rewriting, normalizing, or partially updating an invalid file.
- **FR-021**: When an iteration discovers useful failure knowledge but completes no work unit, Ralph MUST update `ralph-memory.md`, append the failed attempt to `progress.md`, leave `tasks.md` unchanged, create no commit, and retain those uncommitted records for inclusion in a later substantive work-unit commit.
- **FR-022**: Before committing the final substantive work unit, Ralph MUST replace all `Current Handoff` content with the single entry `Feature complete; no handoff required.`.

### Key Entities

- **Ralph Memory**: The compact durable knowledge carried between fresh iterations. It has fixed semantic sections, retains still-valid discoveries, removes superseded information, and exposes one current handoff that becomes an explicit completion marker when no work remains.
- **Progress Record**: The append-only chronological audit of an iteration, including the work attempted or completed and concise iteration-specific learnings.
- **Task State**: The authoritative completion state for planned work units, updated before the related completed-work commit.
- **Completed Work Unit**: A meaningful implementation increment that may be committed together with its task, audit, and memory updates; bookkeeping changes alone do not qualify.
- **Completion Validation**: The observable evaluation of task and repository state that permits success only when no uncommitted changes remain and does not mutate history.

### Scope Boundaries

- This feature strengthens the file-based handoff protocol; it does not replace Ralph's fresh-process orchestration model.
- This feature does not make `progress.md` a second durable-memory source or migrate the full historical log into `ralph-memory.md`.
- This feature does not authorize automatic commit amendment, history rewriting, hidden recovery commits, or commits containing bookkeeping alone.
- This feature does not change how task completion is represented or expand an iteration beyond one work unit.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of tested fresh iterations, durable memory is available and read before a work unit is selected, including when the memory file was initially absent.
- **SC-002**: Across all supported orchestration paths, the missing-memory and existing-memory test cases produce the same canonical section set and preservation behavior.
- **SC-003**: In 100% of tested completed work units, task state, audit history, and applicable durable memory are current before the work-unit commit; zero bookkeeping-only commits are produced.
- **SC-004**: In 100% of tested successful completions, `git status --short` is empty; every all-tasks-complete dirty-state case stops immediately with a non-zero result, reports all dirty paths, starts no further iteration, and changes no existing commit.
- **SC-005**: Durable memory contains no chronological iteration entries; every active `Current Handoff` contains only information relevant to the next work unit, and every completed handoff contains only the required completion marker.
- **SC-006**: Regression coverage exercises initialization, preservation, coordinated updates, and completion validation on 100% of supported orchestration paths without regressing the append-only progress behavior.
- **SC-007**: In a documentation review, at least 4 of 5 representative users correctly identify the source for durable knowledge, the source for audit history, and the clean-working-tree completion rule on their first attempt.
- **SC-008**: Before implementation begins, the constitution and every artifact identified by its propagation review consistently describe `ralph-memory.md` as durable memory and `progress.md` as audit history, with no conflicting guidance remaining.
- **SC-009**: In 100% of malformed-memory tests, Ralph stops before work selection, returns a non-zero result, reports every missing or invalid canonical section, and leaves the existing file byte-for-byte unchanged.
- **SC-010**: In 100% of failed-attempt tests with useful new knowledge and no completed work unit, memory and audit changes remain available and uncommitted, task state is unchanged, no commit is created, and the records are included with the next substantive work-unit commit.
- **SC-011**: In 100% of successful final-work-unit tests, committed durable memory contains exactly `Feature complete; no handoff required.` under `Current Handoff` and contains no stale next-work instruction.

## Assumptions

- Rubiss's comment defines the leading direction: durable knowledge belongs in a separate bounded `ralph-memory.md`, while `progress.md` remains the audit trail.
- The later issue-owner comment's listed musts are binding refinements consistent with Rubiss's direction.
- Existing features may be upgraded lazily when Ralph first encounters a missing memory file; no bulk migration is required.
- A durable-memory update may add no new lasting knowledge, but `Current Handoff` must still represent the next iteration's needs or the required completion marker before a completed-work commit.
- The constitution amendment and its propagation review are part of this feature and must be completed before implementation begins.
- Existing task tracking, iteration limits, agent selection, and completion signaling remain unchanged unless needed to enforce the requirements above.
- The branch and commit convention is issue-specific: `27` is the only numeric identifier used for this feature's branch prefix and conventional commit suffix, independent of the sequential spec directory number.
