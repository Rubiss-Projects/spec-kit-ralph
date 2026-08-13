# Feature Specification: Accept Task Expansion With Completed Progress

**Feature Branch**: `005-task-expansion-validation`

**Created**: 2026-08-13

**Status**: Draft

**Input**: GitHub issue [#49](https://github.com/Rubiss-Projects/spec-kit-ralph/issues/49) - "Ralph fails valid work-unit when task count grows after completing a task that generates follow-up tasks"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Completed progress remains valid when follow-up tasks are added (Priority: P1)

As a Ralph user running a Spec Kit feature, I want an iteration that completes
existing tasks and adds follow-up tasks to be accepted as real progress so that
the loop does not fail a valid work unit solely because the remaining task count
increased.

**Why this priority**: This is the reported defect. Ralph currently fails a
successful iteration when completed task progress is offset by newly added
unchecked tasks, even though the work was committed and the task expansion was
the intended output of one completed task.

**Independent Test**: Start with a task list containing incomplete tasks,
complete at least one existing task during an iteration, add new unchecked
follow-up tasks in the same iteration, and verify that Ralph accepts the
iteration and continues instead of reporting invalid work-unit history.

**Acceptance Scenarios**:

1. **Given** a task list with existing incomplete tasks, **When** an iteration
   marks one or more of those existing tasks complete and adds new unchecked
   follow-up tasks, **Then** Ralph accepts the iteration as completed progress
   rather than failed or no-work.
2. **Given** an accepted task-expansion iteration, **When** Ralph reports the
   loop summary, **Then** the completed-task count reflects the tasks that were
   checked off and the remaining-task count includes the newly added tasks.
3. **Given** an accepted task-expansion iteration, **When** the next iteration
   begins, **Then** Ralph can select from the newly added unchecked tasks.

---

### User Story 2 - Users can see when task expansion increases the loop size (Priority: P2)

As a Ralph user, I want Ralph to clearly report when an accepted iteration added
new tasks so that I understand why the loop may need more iterations than
initially expected.

**Why this priority**: Task expansion is useful in agentic workflows, but it can
surprise users if the loop appears to move the finish line without explanation.
Visible reporting keeps the behavior compatible with Spec Kit while preserving
user control.

**Independent Test**: Run an iteration that completes existing tasks and adds
new unchecked tasks, then verify that the output clearly reports the expansion
and the updated remaining-work count.

**Acceptance Scenarios**:

1. **Given** an iteration that adds unchecked tasks, **When** Ralph summarizes
   the iteration, **Then** the summary states that new tasks were added.
2. **Given** new unchecked tasks were added, **When** Ralph displays remaining
   work, **Then** the count includes those tasks and does not imply that the
   completed progress was lost.
3. **Given** the remaining task count increased after a valid iteration,
   **When** Ralph continues, **Then** users can tell that the increase came from
   task expansion rather than failed progress.

---

### User Story 3 - No-work task changes are still rejected (Priority: P3)

As a maintainer, I want Ralph to distinguish valid task expansion from arbitrary
task-list churn so that agents cannot advance the loop by only adding or
rewriting tasks without completing existing work.

**Why this priority**: Accepting task expansion must not weaken Ralph's
guardrails. The system still needs a clear threshold between real progress and
bookkeeping-only or no-work iterations.

**Independent Test**: Run iterations that only add tasks, only replace tasks, or
change tasks after a failed attempt, and verify that Ralph rejects those cases
unless at least one previously incomplete task was completed.

**Acceptance Scenarios**:

1. **Given** an iteration adds new unchecked tasks but completes no previously
   incomplete task, **When** Ralph validates the iteration, **Then** it rejects
   the iteration as no-work or invalid task-state change.
2. **Given** an iteration replaces one incomplete task with another without
   completing an existing task, **When** Ralph validates the iteration, **Then**
   it rejects the change as not completed progress.
3. **Given** an agent exits unsuccessfully after changing the task list, **When**
   Ralph validates the iteration, **Then** Ralph rejects the task-list change
   regardless of whether tasks were added.

---

### Edge Cases

- What happens when an iteration completes existing tasks and adds more new
  tasks than it completed? The iteration must remain valid if at least one
  previously incomplete task was completed.
- What happens when an iteration completes the last original task but adds new
  follow-up tasks? The feature is not complete; Ralph continues until no
  unchecked tasks remain or the iteration limit is reached.
- What happens when the configured maximum iteration count is reached after
  task expansion? Ralph terminates with the normal iteration-limit result and a
  clear remaining-task summary.
- What happens when new task IDs overlap or duplicate existing task IDs? Ralph
  must not double-count completed progress and must report the task list in a
  way that avoids ambiguous progress accounting.
- What happens when only task text changes but no previously incomplete task is
  checked off? Ralph must not treat that as completed progress.
- What happens when an accepted task-expansion iteration has no substantive
  work outside coordinated state records? Ralph may accept it only when the
  completed task itself was a planning, review, or task-expansion work unit.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Ralph MUST treat an iteration as completed progress when at least
  one task that was incomplete before the iteration is complete after the
  iteration, even if the total number of unchecked tasks increases.
- **FR-002**: Ralph MUST NOT classify an iteration as failed or no-work solely
  because new unchecked tasks were added by the completed work unit.
- **FR-003**: Ralph MUST continue the loop after a valid task-expansion
  iteration when unchecked tasks remain.
- **FR-004**: Ralph MUST include newly added unchecked tasks in remaining-work
  reporting and subsequent task selection.
- **FR-005**: Ralph MUST report that task expansion occurred when an accepted
  iteration adds one or more unchecked tasks.
- **FR-006**: Ralph MUST preserve the configured maximum iteration count as the
  clear boundary for how long an expanded task list may continue running.
- **FR-007**: Ralph MUST reject task-list changes that add, replace, or rewrite
  unchecked tasks without completing at least one previously incomplete task.
- **FR-008**: Ralph MUST reject task-list changes made by failed or no-work
  iterations, regardless of whether those changes add new tasks.
- **FR-009**: Ralph MUST distinguish completed task identity from net unchecked
  task count when deciding whether progress occurred.
- **FR-010**: Ralph MUST avoid double-counting progress when task IDs are
  duplicated, reused, or ambiguous.
- **FR-011**: Ralph MUST preserve existing guardrails for coordinated records,
  bookkeeping-only commits, clean completion, and failed/no-work attempts.
- **FR-012**: Ralph MUST behave equivalently across all supported execution
  paths for task-expansion validation and reporting.
- **FR-013**: User-facing documentation MUST explain that task expansion is
  allowed when existing tasks are completed, that it may increase remaining
  iterations, and that `max_iterations` remains the controlling limit.
- **FR-014**: Regression coverage MUST include a valid iteration where checked
  task count increases while unchecked task count also increases.
- **FR-015**: Regression coverage MUST include invalid iterations where tasks
  are added or rewritten without completing previously incomplete tasks.

### Key Entities

- **Task Identity**: The stable task identifier used to determine whether a
  task that was incomplete before an iteration became complete after it.
- **Task Expansion**: The addition of one or more new unchecked tasks to the
  active task list during an iteration.
- **Completed Progress**: An iteration outcome where at least one previously
  incomplete task is completed and accepted as part of the work unit.
- **Remaining Work**: The set of unchecked tasks after an iteration, including
  tasks that existed before the iteration and tasks added during valid task
  expansion.
- **Iteration Limit**: The configured maximum number of iterations Ralph may run
  before stopping with remaining work still present.

### Scope Boundaries

- This feature changes how Ralph classifies task-list growth during iteration
  validation; it does not require a separate planning or converge mode.
- This feature allows task expansion only when the same iteration completes
  existing work; it does not permit arbitrary task churn.
- This feature does not change the requirement that feature completion means no
  unchecked tasks remain and completion gates pass.
- This feature does not remove or raise the configured maximum iteration limit.
- This feature does not require users to predeclare which tasks may add
  follow-up tasks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In 100% of tested task-expansion iterations where at least one
  previously incomplete task is completed, Ralph accepts the iteration as
  progress even when the remaining unchecked-task count increases.
- **SC-002**: In 100% of tested iterations that add or rewrite tasks without
  completing a previously incomplete task, Ralph rejects the iteration as
  no-work or invalid task-state change.
- **SC-003**: In 100% of accepted task-expansion iterations, the user-facing
  summary reports both completed progress and the updated remaining-task count.
- **SC-004**: In 100% of accepted task-expansion runs, newly added unchecked
  tasks are eligible for selection in later iterations.
- **SC-005**: In 100% of runs that reach the configured iteration limit after
  task expansion, Ralph stops with the normal iteration-limit result rather
  than a spurious work-unit validation failure.
- **SC-006**: Equivalent task-expansion scenarios produce the same observable
  results across all supported execution paths.
- **SC-007**: User-facing documentation allows 4 of 5 representative users to
  correctly predict that task expansion can increase remaining iterations while
  still being bounded by `max_iterations`.

## Assumptions

- Spec Kit-compatible task files may legitimately contain tasks whose accepted
  output is additional tasks or refined implementation slices.
- Ralph should remain compatible with Spec Kit workflows that refine `tasks.md`
  during convergence or implementation, provided real progress is made.
- The clearest progress threshold is completion of at least one previously
  incomplete task, not reduction of net unchecked-task count.
- The clearest safety threshold is the configured maximum iteration count,
  paired with explicit reporting when task expansion occurs.
- Existing users expect failed or no-work iterations to leave task state
  unchanged; that expectation remains unchanged.
