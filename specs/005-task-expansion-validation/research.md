# Phase 0 Research: Accept Task Expansion With Completed Progress

**Feature**: 005-task-expansion-validation | **Date**: 2026-08-13

This feature has no external technology unknowns. Research resolves the policy
choice from issue #49 and maps it onto the current Ralph lifecycle.

## Decision 1: Progress threshold is completed task identity

- **Decision**: Ralph will classify an iteration as completed progress when at
  least one task that was incomplete before the iteration is no longer
  incomplete after the iteration, even if new unchecked tasks were added.
- **Rationale**:
  - It directly captures the user-visible fact that work was completed.
  - It matches Spec Kit-compatible workflows where a completed task may refine
    or expand `tasks.md`.
  - It avoids the reported false negative where completing 5 existing tasks and
    adding 12 follow-up tasks looks like no progress under a net-count rule.
- **Alternatives considered**:
  - *Keep net unchecked-task reduction as the threshold.* Rejected because it
    fails valid task-expansion work units.
  - *Allow any task-list change when `HEAD` advances.* Rejected because it would
    accept arbitrary task churn with no completed work.
  - *Require users to predeclare expansion tasks.* Rejected for this feature
    because the spec prefers compatibility with ordinary Spec Kit task output
    and avoids adding configuration ceremony.

## Decision 2: Task expansion is visible, not separately configured

- **Decision**: Accepted task expansion will be reported in iteration and/or
  summary output, but it will not require a new configuration flag.
- **Rationale**:
  - Users need to understand why remaining work may grow.
  - The existing `max_iterations` setting already provides the clear upper
    bound for loop growth.
  - A new opt-in setting would make a Spec Kit-compatible task shape fail by
    default, preserving the compatibility problem.
- **Alternatives considered**:
  - *Add a dedicated `allow_task_expansion` configuration.* Rejected as
    unnecessary for the reported defect and a likely source of surprising
    failures.
  - *Silently accept expansion.* Rejected because users need visibility when the
    task list grows.

## Decision 3: Failed/no-work task changes remain invalid

- **Decision**: Any failed or no-work iteration that changes `tasks.md` remains
  invalid. Adding unchecked tasks without completing a previously incomplete
  task is still no-work/task-state churn.
- **Rationale**:
  - Preserves Constitution IV: task completion is authoritative in `tasks.md`,
    and failed/no-work iterations must leave task state unchanged.
  - Prevents an agent from extending the task list indefinitely without making
    progress.
  - Keeps existing bookkeeping-only and coordinated-commit guardrails intact.
- **Alternatives considered**:
  - *Permit planning-only task additions during implementation.* Rejected for
    this feature because it needs a separate planning/converge policy and would
    weaken the immediate work-unit invariant.

## Decision 4: Cross-platform validation shape

- **Decision**: Both execution paths will reason about:
  - incomplete task IDs before an iteration;
  - incomplete task IDs after an iteration;
  - completed IDs as the set difference from before to after;
  - newly added unchecked IDs as IDs present after but absent before;
  - task expansion as added unchecked tasks plus at least one completed existing
    task.
- **Rationale**:
  - PowerShell already captures incomplete IDs at the iteration level, so the
    concept is proven in one path.
  - Bash currently relies on counts and needs an equivalent ID snapshot.
  - Commit-level state-only validation also needs identity-based progress so a
    review/planning/task-expansion work unit can be accepted even when net
    unchecked count increases.
- **Alternatives considered**:
  - *Patch only the top-level advanced-HEAD check.* Rejected because
    bookkeeping-only validation and summary reporting would remain count-based.
  - *Use task line text rather than task IDs.* Rejected because task descriptions
    can be edited while task identity should remain stable.

## Open Questions

None. No `NEEDS CLARIFICATION` remains.
