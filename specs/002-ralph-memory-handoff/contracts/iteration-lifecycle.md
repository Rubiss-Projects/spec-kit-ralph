# Contract: Ralph Iteration and Completion Lifecycle

## Participants

- **Orchestrator**: Bash or PowerShell process controlling fresh agent invocations and termination
- **Iteration agent**: One fresh configured agent CLI process working on at most one work unit
- **Task state**: `specs/{feature}/tasks.md`
- **Durable memory**: `specs/{feature}/ralph-memory.md`
- **Audit history**: `specs/{feature}/progress.md`
- **Git repository**: Source of substantive history and clean completion state

## Orchestrator Preflight

For every run:

1. Resolve repository, feature, tasks, spec directory, extension root, memory template, memory, and progress paths.
2. Initialize a missing memory file from the shared template without overwriting an existing file.
3. Validate memory according to [ralph-memory-schema.md](ralph-memory-schema.md).
4. On invalid memory, print every defect, exit 1, and do not invoke an agent.
5. Count incomplete tasks.
6. If no task remains, evaluate the full completion gate; do not return success from task count alone.
7. If tasks remain, launch a fresh iteration.

Memory preparation repeats before each fresh agent launch so a user or prior failed iteration cannot introduce an invalid handoff between iterations.

## Iteration Context Order

The iteration command reads context in this order:

1. `ralph-memory.md` — primary durable knowledge
2. `tasks.md` — authoritative task state and first incomplete work unit
3. `plan.md`, then optional data model, contracts, research, and other design artifacts
4. `progress.md` — optional recent audit context only

The agent selects at most one work unit and does not start a second.

## Completed Work-Unit Transaction

When the selected work unit is substantively complete:

1. Run applicable quality checks.
2. Mark only completed tasks in `tasks.md`.
3. Preserve and compact durable memory; update the current handoff.
4. If no tasks remain, replace handoff content with `Feature complete; no handoff required.`.
5. Append the progress record described below.
6. Stage substantive files plus `tasks.md`, `ralph-memory.md`, and `progress.md`.
7. Create one conventional work-unit commit.
8. Leave no post-commit bookkeeping change.

The delivery commits that implement issue #27 use branch prefix `27-` and subjects ending `#27`. This issue-specific repository convention does not impose `#27` on Ralph commits generated in downstream user projects.

## Failed, Partial, or No-Work Transaction

When no work unit completes:

- do not mark a task complete unless its substantive result passed validation;
- do not create a commit;
- when useful failure knowledge exists, update `ralph-memory.md` and append `progress.md`;
- leave those state changes uncommitted for the next fresh iteration;
- leave `HEAD` unchanged;
- let the next substantive work-unit commit include the retained records.

## Progress Record

Append before any work-unit commit:

```markdown
---
## Iteration [N] - [YYYY-MM-DD HH:MM]
**Work Unit**: [title or failed/partial description]
**Tasks Completed**:
- [x] [Task ID]: [description]
**Tasks Remaining in Work Unit**: [count or description]
**Commit**: [This work-unit commit | No commit - no completed work unit]
**Files Changed**:
- [repository-relative path]
**Learnings**:
- [concise audit note; durable detail is in ralph-memory.md]
---
```

The record never requires a future commit hash. Existing progress content is an immutable prefix and is not reorganized, including legacy `Codebase Patterns` content.

## Commit Postcondition Validation

The orchestrator snapshots `HEAD` and task state before invocation and inspects only the new history after that snapshot without mutation. Existing history is the trusted starting boundary for the process: human-authored spec or task refinements committed before the snapshot are not reclassified as Ralph-owned work-unit commits.

- A failed/no-work iteration must not advance `HEAD`.
- Each new work-unit commit includes the three active feature state artifacts and at least one substantive path outside them.
- A commit containing only `tasks.md`, `progress.md`, and/or `ralph-memory.md` is a bookkeeping-only violation.
- A violation is reported and prevents successful completion, but the orchestrator does not reset, amend, rebase, revert, or create a repair commit.

## Completion Gate

Every completion candidate—initial task-zero, standalone completion signal, or post-iteration task-zero—must satisfy all conditions:

| Condition | Required Result |
|---|---|
| Agent result | Successful, or absent for initial completion check |
| Incomplete tasks | Exactly zero |
| Memory structure | Valid |
| `Current Handoff` | Exactly one `Feature complete; no handoff required.` entry |
| Commit postconditions | For a post-iteration candidate, no invalid coordinated commit after the iteration's `HEAD` snapshot; an initial task-zero candidate validates current state without revalidating historical commit shape |
| Git status command | Exits zero |
| `git status --short --untracked-files=all` | Emits no lines |

A standalone completion signal cannot override a failed agent result, remaining task, invalid memory, stale handoff, invalid commit, Git error, or dirty path.

## Dirty or Inconsistent Completion

If all tasks are complete but any completion condition fails:

1. Print a clear non-success reason and every dirty porcelain line or validation defect.
2. Exit 1 immediately.
3. Start no reconciliation or cleanup iteration.
4. Perform no staging, commit, amend, reset, rebase, revert, checkout, stash, or hidden recovery action.
5. Require explicit user correction before rerunning.

Repository-wide status is intentional: unrelated tracked or untracked user changes also block success.

## Exit Contract

| Exit Code | State | Meaning |
|---|---|---|
| `0` | Completed | Every completion condition passed. |
| `1` | Failed / blocked / limit reached | Includes invalid memory, dirty completion, protocol inconsistency, Git error, circuit breaker, and iteration limit. |
| `130` | Interrupted | User interruption; existing on-disk state is preserved. |

## Platform Parity

Bash and PowerShell must produce the same result class and exit class for missing, valid, invalid, active, completed, dirty, failed-agent, and interrupted states. Text styling may differ, but diagnostic categories and reported paths must match.
