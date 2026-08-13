# Phase 1 Data Model: Accept Task Expansion With Completed Progress

**Feature**: 005-task-expansion-validation | **Date**: 2026-08-13

This feature defines behavioral state derived from `tasks.md` and Git history.
It does not introduce a database or new persisted state file.

## Entity: Task Identity

Represents a stable task identifier in the active task list.

| Field | Meaning | Source |
|-------|---------|--------|
| `id` | Task identifier such as `T048` | Checkbox line in `tasks.md` |
| `status` | Incomplete or complete | Checkbox marker in `tasks.md` |
| `description` | Human-readable task text | Checkbox line in `tasks.md` |

**Validation rules**:

- A task is considered completed progress only if its `id` existed in the
  pre-iteration incomplete set and does not exist in the post-iteration
  incomplete set.
- Duplicate or reused IDs must not be double-counted as multiple completed
  tasks.
- Task text changes alone do not count as completed progress.

## Entity: Iteration Task Snapshot

Represents the task state captured before or after an iteration.

| Field | Meaning |
|-------|---------|
| `task_state` | Full task-file byte/content snapshot used to detect any task-list change |
| `incomplete_ids` | Unique task IDs currently unchecked |
| `incomplete_count` | Count of currently unchecked tasks |

**Derived values**:

- `completed_existing_ids`: IDs present in `before.incomplete_ids` and absent
  from `after.incomplete_ids`.
- `added_unchecked_ids`: IDs present in `after.incomplete_ids` and absent from
  `before.incomplete_ids`.
- `task_expanded`: true when `added_unchecked_ids` is non-empty.
- `valid_completed_progress`: true when `completed_existing_ids` is non-empty
  and the agent result is successful.

## Entity: Task Expansion

Represents the addition of unchecked follow-up tasks during an iteration.

| Field | Meaning |
|-------|---------|
| `added_unchecked_ids` | New unchecked task IDs introduced by the iteration |
| `added_count` | Number of new unique unchecked task IDs |
| `source_iteration` | The iteration that produced the expansion |
| `paired_completed_ids` | Existing tasks completed in the same accepted iteration |

**Validation rules**:

- Task expansion is valid only when `paired_completed_ids` is non-empty.
- Task expansion does not by itself imply feature completion or failure.
- Newly added unchecked tasks become part of Remaining Work immediately.

## Entity: Iteration Outcome

Classification of the iteration after comparing snapshots and result status.

| Outcome | Required state | Loop behavior |
|---------|----------------|---------------|
| Completed progress | Agent succeeded and `completed_existing_ids` is non-empty | Accept iteration; continue or complete based on remaining work |
| Completed progress with expansion | Completed progress plus `added_unchecked_ids` is non-empty | Accept iteration; report expansion; continue if tasks remain |
| No-work | Agent succeeded but no existing incomplete task was completed | Reject task-list changes; do not treat as work-unit progress |
| Failure | Agent failed or no-work failure threshold reached | Task state must remain unchanged; existing failure handling applies |

## Entity: Remaining Work

The set of unchecked tasks after validation.

| Field | Meaning |
|-------|---------|
| `remaining_ids` | All unchecked task IDs after the iteration |
| `remaining_count` | Total unchecked tasks after the iteration |
| `includes_expansion` | Whether remaining work contains tasks added by the last accepted iteration |

**State transition example**:

```text
Before: checked=43, unchecked={T044..T057}
After:  checked=48, unchecked={T049..T057,T058..T069}

completed_existing_ids={T044,T045,T046,T047,T048}
added_unchecked_ids={T058..T069}
remaining_count=21
outcome=Completed progress with expansion
```

## Validation Rules Cross-Reference

- FR-001, FR-009 → Task Identity and Iteration Task Snapshot.
- FR-002, FR-003, FR-004 → Iteration Outcome and Remaining Work.
- FR-005, FR-006 → Task Expansion reporting and iteration limit.
- FR-007, FR-008, FR-010, FR-011 → no-work, failure, duplicate-ID, and
  bookkeeping guardrails.
- FR-012, FR-014, FR-015 → parity and regression coverage.
