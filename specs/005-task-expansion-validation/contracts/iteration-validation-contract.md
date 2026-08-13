# Contract: Iteration Validation With Task Expansion

## Snapshot Inputs

For each iteration, Ralph captures before and after task snapshots:

| Snapshot Field | Required Meaning |
|----------------|------------------|
| `head` | Current Git `HEAD` |
| `task_state` | Full task-file state for detecting any task mutation |
| `incomplete_ids` | Unique IDs of unchecked tasks |
| `incomplete_count` | Count of unchecked tasks |
| `agent_exit` | Agent process result |

## Derived Sets

| Derived Set | Rule |
|-------------|------|
| `completed_existing_ids` | `before.incomplete_ids - after.incomplete_ids` |
| `added_unchecked_ids` | `after.incomplete_ids - before.incomplete_ids` |
| `task_expanded` | `added_unchecked_ids` is non-empty |
| `made_progress` | `completed_existing_ids` is non-empty |

Duplicate IDs are counted once for progress classification.

## Classification Matrix

| Agent result | HEAD | Task state | Completed existing IDs | Added unchecked IDs | Classification |
|--------------|------|------------|------------------------|---------------------|----------------|
| success | advanced | changed | none | any | invalid failed/no-work HEAD advance |
| success | advanced | changed | one or more | none | completed progress |
| success | advanced | changed | one or more | one or more | completed progress with expansion |
| success | unchanged | changed | one or more | any | invalid completed state not committed |
| success | unchanged | changed | none | any | invalid failed/no-work task-state change |
| success | unchanged | unchanged | none | none | no-work/no progress |
| failure | advanced | any | any | any | invalid failed/no-work HEAD advance |
| failure | unchanged | changed | any | any | invalid failed/no-work task-state change |
| failure | unchanged | unchanged | any | any | failed attempt with no task mutation |

## Commit-Level State-Only Rule

A commit that changes only coordinated state artifacts is accepted only when the
task snapshot at that commit completes at least one task ID that was incomplete
at the previous inspected commit boundary. Net unchecked-task count reduction is
not required when newly added unchecked tasks offset the completed IDs.

If no previously incomplete ID was completed at that commit boundary, the commit
remains a bookkeeping-only violation.

## Summary Count Rule

Tasks completed in run summaries are based on the count of unique previously
incomplete task IDs completed during accepted iterations, not on
`initial_incomplete_count - final_incomplete_count`.

Remaining tasks are always the current unchecked-task count after the final
iteration or completion gate.

## Diagnostic Stability

Existing diagnostic categories remain stable:

- `failed-iteration-advanced-head`
- `failed-iteration-task-state`
- `coordinated-commit-invalid`
- `bookkeeping-only`

Task expansion may add explanatory reporting, but it must not replace these
categories for invalid states.
