# Contract: Task Expansion Policy

## Purpose

Define when Ralph accepts task-list growth during an iteration and how that
growth is communicated to users.

## Valid Task Expansion

An iteration has valid task expansion when all conditions are true:

1. The agent result is successful.
2. At least one task ID that was incomplete before the iteration is complete
   after the iteration.
3. One or more unchecked task IDs exist after the iteration that did not exist
   before the iteration.
4. The iteration satisfies normal coordinated state and commit postconditions.

Valid task expansion is completed progress. It is not failed/no-work solely
because the total unchecked-task count increased.

## Invalid Task Expansion

An iteration is not valid task expansion when any condition is true:

- no previously incomplete task was completed;
- the agent result failed;
- `tasks.md` changed during a failed or no-work iteration;
- the task list rewrote, replaced, or added tasks without completed existing
  work;
- coordinated state artifacts or commit postconditions are invalid.

These cases continue to use the existing failure or no-work diagnostics.

## Reporting Requirements

When valid task expansion occurs, Ralph reports:

- the number or IDs of tasks completed by the iteration;
- that new unchecked tasks were added;
- the updated remaining-task count;
- normal loop status: continuing, completed, failed, or iteration limit reached.

The report must make clear that a remaining-task count increase came from
accepted expansion, not lost progress.

## Iteration Limit

Task expansion does not alter `max_iterations`. If expansion creates more work
than the remaining allowed iterations can finish, Ralph stops with the normal
iteration-limit result and reports remaining tasks.

## Documentation Requirements

User-facing documentation explains:

- task expansion is allowed when existing tasks are completed;
- task expansion may increase the number of iterations needed;
- `max_iterations` remains the user's boundary for loop growth;
- adding or rewriting tasks without completing existing work remains invalid.
