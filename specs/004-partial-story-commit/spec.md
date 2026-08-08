# Feature Specification: Reconcile Partial User-Story Progress With Commit Validation

**Feature Branch**: `004-partial-story-commit`

**Created**: 2026-08-08

**Status**: Draft

**Input**: User description: "https://github.com/Rubiss-Projects/spec-kit-ralph/issues/50"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A multi-task story spans several iterations without failing the loop (Priority: P1)

A user runs the Ralph loop against a feature whose user story contains several
substantial tasks. One iteration validates and completes a subset of those
tasks (for example, one of three). The user expects the loop to record that
progress and continue, not terminate with a failure.

**Why this priority**: This is the reported defect. Today a successful,
validated iteration ends the loop with `Status: FAILED`, which blocks the
primary autonomous-loop use case for any story larger than a single task.

**Independent Test**: Create a user story with three tasks, run the loop, allow
one iteration to complete only the first task, and confirm the loop continues to
the next iteration instead of terminating with a validation failure.

**Acceptance Scenarios**:

1. **Given** a user story with three incomplete tasks, **When** an iteration
   validates and completes exactly one of them, **Then** the loop records the
   progress and proceeds to another iteration rather than terminating with a
   commit-validation failure.
2. **Given** a partially completed user story from a prior iteration, **When**
   the next iteration begins, **Then** it selects the next incomplete task in
   the same story and does not re-select an already-completed task.
3. **Given** an iteration that completes a subset of a story, **When** the loop
   reports its status, **Then** the reported status reflects success/progress,
   not `FAILED`.

---

### User Story 2 - Completed task state is never stranded in an uncommitted worktree (Priority: P1)

A user relies on the loop to keep completed work, task checkboxes, and audit
records consistent and durable. When an iteration marks a task complete, the
user expects that completion and its associated implementation and bookkeeping
to be captured together, so nothing valuable is left in a dirty worktree that a
later failure or interruption could lose.

**Why this priority**: The reported behavior leaves validated implementation and
completed-task state uncommitted. Stranded state undermines resumability and
auditability, which are core promises of the loop.

**Independent Test**: Run an iteration that completes a validated subset of a
story and confirm that, at the end of the iteration, there is no completed-task
state left uncommitted in the worktree and the recorded history is internally
consistent.

**Acceptance Scenarios**:

1. **Given** an iteration that completes a validated task subset, **When** the
   iteration ends, **Then** the completed-task state, the substantive
   implementation changes, and the audit/memory records are captured together
   rather than split or left uncommitted.
2. **Given** an iteration that completes no validated work, **When** the
   iteration ends, **Then** no task is marked complete and no commit is created
   solely for bookkeeping.
3. **Given** an iteration whose work failed validation, **When** the iteration
   ends, **Then** no task is marked complete and the task list is unchanged.

---

### User Story 3 - Instructions and orchestrator enforce one consistent policy (Priority: P2)

A contributor reading the iterate command, the generated skill, and the
orchestrator expects all three to describe and enforce the same rule for how
partial progress is recorded and committed. Today they contradict each other,
which produces the failure and confuses anyone reasoning about the system.

**Why this priority**: Even after the immediate defect is fixed, divergent
documentation and enforcement will re-introduce the conflict. A single stated
policy is required for durable correctness and maintainability.

**Independent Test**: Review the iterate command, the generated skill, and the
orchestrator behavior and confirm they describe the same definition of a work
unit and the same commit expectation for partial story progress, with no
contradictory instruction.

**Acceptance Scenarios**:

1. **Given** the iterate command and the generated skill, **When** they are
   compared, **Then** they state the same policy for marking and committing a
   validated partial subset of a story.
2. **Given** the orchestrator's acceptance rule, **When** it is compared to the
   stated iterate policy, **Then** the state the orchestrator accepts is exactly
   the state the iterate policy tells the agent to produce.
3. **Given** the same policy expressed for both supported script platforms,
   **When** their behavior is compared, **Then** they enforce the policy
   equivalently.

---

### Edge Cases

- What happens when an iteration completes the **final** task of a story,
  finishing the whole story in one iteration? The completion, implementation,
  and bookkeeping must still be captured together as one coordinated unit.
- What happens when an iteration attempts work but validation fails? No task may
  be marked complete and the task list must remain unchanged, so the loop must
  not interpret it as a committable work unit.
- What happens when a single iteration would complete tasks spanning **two**
  different user stories? The existing rule that one iteration must not start a
  second user story must be preserved.
- How does the loop behave when it reaches the maximum iteration count with a
  story still partially complete? It must terminate with a clear summary of
  completed versus remaining tasks, not a spurious validation failure.
- What happens on resume when a prior partial story left recorded progress? The
  next iteration must continue with the next incomplete task and must not
  double-count or re-select completed tasks.
- How does the loop handle an iteration that changes only bookkeeping records
  with no completed task? It must not accept that as a valid work-unit commit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The system MUST allow a single user story that contains multiple
  substantial tasks to be completed across multiple iterations without
  terminating the loop.
- **FR-002**: The system MUST treat a validated task or validated subset of
  tasks completed during an iteration as a legitimate unit of progress that the
  loop accepts and continues from.
- **FR-003**: When an iteration completes a validated task subset, the system
  MUST keep the completed-task state, the substantive implementation changes,
  and the audit and memory records coordinated together, with no completed-task
  state left uncommitted at the end of the iteration.
- **FR-004**: The system MUST NOT report a successful, validated iteration as a
  failure, and MUST NOT terminate the loop, solely because a story remains
  partially complete.
- **FR-005**: The system MUST NOT mark any task complete when the iteration's
  work failed or was not validated, and MUST leave the task list unchanged in
  that case.
- **FR-006**: The system MUST NOT accept a commit that contains only bookkeeping
  records (task list, progress log, memory) with no completed task as a valid
  work-unit commit.
- **FR-007**: On the iteration following partial story progress, the system MUST
  select the next incomplete task within the same story and MUST NOT re-select a
  task already marked complete.
- **FR-008**: The system MUST preserve the constraint that a single iteration
  does not begin work on a second user story.
- **FR-009**: The iterate command instructions, the generated skill, and the
  orchestrator MUST describe and enforce one consistent policy for recording and
  committing partial user-story progress, such that the state the instructions
  tell the agent to produce is exactly the state the orchestrator accepts.
- **FR-010**: The orchestrator's acceptance rules MUST cover both the case where
  a partial completion advances the recorded history and the case where it does
  not, without misclassifying a valid iteration as invalid.
- **FR-011**: The policy and its enforcement MUST behave equivalently across both
  supported orchestrator script platforms.
- **FR-012**: Automated regression coverage MUST exercise partial-completion
  scenarios, including both an unchanged and an advanced recorded history, to
  prevent regression of this behavior.

### Key Entities *(include if feature involves data)*

- **Work Unit**: The amount of validated progress an iteration is allowed to
  complete and record together. Its definition must be identical across the
  instructions, the generated skill, and the orchestrator.
- **Task List State**: The per-task completion record for a feature, whose
  incomplete-task count is used to determine whether an iteration made progress.
- **Coordinated Record Set**: The grouping of substantive implementation changes
  together with task, progress, and memory records that represents one accepted
  unit of progress.
- **Iteration Outcome**: The classification of an iteration as completed
  progress, partial-but-valid progress, no-work, or failure, which drives
  whether the loop continues, what it records, and the reported status.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user story containing at least three substantial tasks completes
  fully across multiple iterations with a 0% rate of spurious loop-termination
  failures attributable to partial-story progress.
- **SC-002**: 100% of iterations that complete a validated task subset are
  reported as success/progress rather than failure.
- **SC-003**: After any iteration that marks a task complete, 0 completed-task
  changes remain stranded as uncommitted worktree state.
- **SC-004**: 100% of iterations whose work failed validation leave the task
  list unchanged and mark no task complete.
- **SC-005**: A reviewer comparing the iterate command, the generated skill, and
  the orchestrator finds 0 contradictions in the stated and enforced
  partial-progress policy.
- **SC-006**: Automated regression coverage includes at least one passing
  partial-completion case with unchanged recorded history and one with advanced
  recorded history, on each supported platform.

## Assumptions

- The recommended reconciliation direction is to treat the validated task subset
  completed in an iteration as the committed work unit (option 1 in the issue),
  producing one coordinated record per iteration; the alternative of keeping
  partial progress uncommitted is acceptable only if the loop can reliably resume
  it without re-selecting completed tasks.
- "Validated" means the iteration's own success checks (for example, the
  feature's tests) passed for the completed task subset; the loop does not
  redefine what validation means beyond the existing checks.
- Both currently supported orchestrator script platforms (the two shipped script
  variants) must reach behavioral parity; no third platform is in scope.
- The change is scoped to reconciling partial-progress recording and commit
  validation; it does not redesign the broader loop, memory format, or
  completion-gate semantics beyond what is required to remove the contradiction.
- Existing governance rules (one work unit per iteration, no bookkeeping-only
  commits, no cleanup/recovery iterations) remain in force and constrain the
  chosen reconciliation.
