# Data Model: Durable Ralph Memory Handoff

## Ralph Memory

Represents the compact durable knowledge read by each fresh iteration before work selection.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `path` | filesystem path | yes | Exactly `specs/{feature}/ralph-memory.md` for the active feature. |
| `title` | string | yes | Exactly `Ralph Memory`. |
| `feature` | string | yes | Non-empty and equal to the active feature identity supplied to the orchestrator. |
| `started_at` | timestamp | yes | Non-empty UTC ISO-8601 value rendered when the file is first created; never refreshed on later runs. |
| `codebase_patterns` | ordered Markdown entries | yes | Durable repository conventions and reusable APIs; no chronological iteration history. |
| `decisions` | ordered Markdown entries | yes | Current decisions with rationale and affected scope. |
| `gotchas` | ordered Markdown entries | yes | Unexpected behavior, environment constraints, and generated-file rules. |
| `reusable_commands` | ordered Markdown entries | yes | Known-good commands and required environment details. |
| `do_not_repeat` | ordered Markdown entries | yes | Failed approaches and why they were rejected. |
| `current_handoff` | ordered Markdown entries | yes | Only next-iteration information while active; exactly the terminal marker when complete. |
| `source_bytes` | byte sequence | derived | Used only to prove an invalid or existing file was not rewritten. |

### Validation Rules

- The H1, metadata labels, and six H2 sections follow [ralph-memory-schema.md](contracts/ralph-memory-schema.md).
- Required H2 sections occur exactly once and in canonical order; unknown H2 sections are invalid.
- Empty durable-knowledge sections are valid and must not be filled with fabricated discoveries.
- After an iteration with work remaining, `current_handoff` contains only actionable information for the next work unit.
- At completion, `current_handoff` contains only `Feature complete; no handoff required.`.
- Existing invalid content is diagnostic input only and is never normalized or partially updated.

### Lifecycle

| From | Event | To | Side Effects |
|---|---|---|---|
| Missing | Prepare feature memory | Active | Render shared template once, then validate. |
| Active | Durable discovery or supersession | Active | Preserve valid entries, update/remove obsolete entries, replace current handoff. |
| Active | Final substantive work unit completed | Complete | Replace handoff with the exact terminal marker before commit. |
| Active / Complete | Validation fails | Invalid | Report all defects; preserve bytes; do not select work. |
| Invalid | User explicitly corrects file | Active / Complete | A later run revalidates; Ralph performs no automatic transition. |

## Progress Record

Represents the append-only chronological audit of one iteration.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `iteration` | positive integer | yes | Monotonic within the current loop run. |
| `timestamp` | timestamp | yes | Date/time of the audited iteration. |
| `work_unit` | string | yes | Selected unit or explicit failed/partial unit. |
| `tasks_completed` | list | yes | May be empty on failed/no-work iterations. |
| `tasks_remaining` | count or description | yes | Reflects state after the iteration. |
| `commit_disposition` | enum | yes | `This work-unit commit` or `No commit - no completed work unit`. Never a future hash. |
| `files_changed` | path list | yes | Intended/observed changes, including state artifacts when applicable. |
| `learnings` | concise list | yes | Iteration-local summary; durable details are directed to Ralph Memory. |

### Validation Rules

- New entries append after all existing bytes; historical entries and legacy pattern sections are not rewritten.
- Progress is never the primary durable context source.
- A completed work-unit entry is created before and included in the corresponding substantive commit.
- A failed/no-work entry remains uncommitted until a later substantive work-unit commit.

## Task State

Represents authoritative planned-work completion in `tasks.md`.

| Field | Type | Required | Rules |
|---|---|---|---|
| `task_id` | string | yes | Existing task identifier. |
| `description` | string | yes | Existing task text. |
| `completed` | boolean | yes | Stored only through `[ ]` to `[x]` checkbox transition. |
| `work_unit` | string | yes | User story or task group selected for the iteration. |

Task state changes only for validated completed work. A failed/no-work iteration leaves the complete file byte-equivalent.

## Work-Unit Commit

Represents one substantive Git commit created after coordinated persistence.

### Fields

| Field | Type | Required | Rules |
|---|---|---|---|
| `before_head` | commit identity | yes | Snapshot before agent invocation. |
| `after_head` | commit identity | conditional | Present only when a completed work unit was committed. |
| `completed_tasks` | task transition set | yes | At least one task transitions to complete. |
| `state_artifacts` | path set | yes | Includes active feature `tasks.md`, `progress.md`, and `ralph-memory.md`. |
| `substantive_paths` | path set | yes | At least one path outside the three bookkeeping artifacts. |
| `message` | string | yes | Conventional commit for the work unit; issue `#27` suffix applies to this extension feature's delivery commits only. |

### Validation Rules

- Persistence occurs before staging and committing.
- No new commit may contain only bookkeeping artifacts.
- A detected violation is reported without modifying `HEAD`, the index, commits, or reflog.
- Failed/no-work and partial iterations do not advance `HEAD`.

## Completion Candidate

Represents an attempted successful termination from initial state, a completion signal, or post-iteration task inspection.

### Fields

| Field | Type | Required | Passing Value |
|---|---|---|---|
| `agent_result` | result class | conditional | Successful or absent for initial check. |
| `incomplete_task_count` | integer | yes | `0`. |
| `memory_validation` | validation result | yes | Valid. |
| `handoff_state` | string | yes | Exact terminal marker only. |
| `git_status_exit` | integer | yes | `0`. |
| `dirty_paths` | porcelain line list | yes | Empty. |
| `commit_contract` | validation result | yes | No detected bookkeeping-only or incomplete coordinated commit. |

### State Transitions

| From | Condition | To | Result |
|---|---|---|---|
| Preparing | Memory invalid | BlockedInvalidMemory | Exit 1; no agent invocation. |
| Preparing | Memory valid and tasks remain | Ready | Agent iteration may start. |
| Ready | Agent fails with useful knowledge | Ready / Failed | Persist memory/audit uncommitted; task state and HEAD unchanged. |
| Ready | Work unit completes, tasks remain | Ready | Coordinated substantive commit; next fresh iteration. |
| Ready / Preparing | Completion candidate passes every field | Completed | Exit 0. |
| Ready / Preparing | Tasks complete but candidate fails | BlockedCompletion | Exit 1 immediately; report every applicable defect; no next iteration. |
| Any | User interruption | Interrupted | Exit 130 with persisted on-disk state unchanged by orchestrator. |

## Relationships

- One active feature has exactly one Task State file, one Progress Log, and zero-or-one Ralph Memory before preparation; it has exactly one valid Ralph Memory before work selection.
- Each fresh iteration reads Ralph Memory first, then Task State and design artifacts, and may consult Progress only for recent audit context.
- A completed Work-Unit Commit atomically contains Task State, Ralph Memory, the appended Progress Record, and substantive implementation changes.
- Completion Candidate references all four entities but performs read-only validation.
