# Contract: Orchestrator Commit Validation

**Surface**: `validate_iteration_commit_history` in `scripts/bash/ralph-loop.sh`
and its PowerShell twin in `scripts/powershell/ralph-loop.ps1`.

**Inputs**: pre-iteration `HEAD` + task-state snapshot, `before_incomplete`,
`after_incomplete`, `agent_exit`, paths to `tasks.md` / `progress.md` /
`ralph-memory.md`, feature name, branch.

**Output**: exit 0 (accepted) or non-zero with one line per diagnostic on stderr.

This contract pins the behavior that MUST hold after the fix. The Bash and
PowerShell implementations MUST produce identical decisions and diagnostics
(FR-011). Only comments/messages may change; the decision table below is
authoritative.

## Decision table (authoritative)

| # | HEAD | Incomplete count | Other | Result |
|---|------|------------------|-------|--------|
| 1 | unchanged | `after == before` | task_state unchanged | **accept** (no-work) |
| 2 | unchanged | `after < before` | — | **reject** `coordinated-commit-invalid: completed task state was not included in a new work-unit commit` |
| 3 | unchanged | `after == before` | task_state changed | **reject** `failed-iteration-task-state` |
| 4 | advanced | `after < before`, `agent_exit==0` | each commit valid (see C-commit) | **accept** (completed progress, possibly partial story) |
| 5 | advanced | `after >= before` OR `agent_exit!=0` | — | **reject** `failed-iteration-advanced-head` |

### C-commit — per-commit checks on advanced HEAD (all must hold)

For every commit in `before_head..after_head`:

- **Coordinated artifacts**: includes `tasks.md` AND `progress.md` AND
  `ralph-memory.md`; else `coordinated-commit-invalid: commit <id> must include
  tasks.md, progress.md, and ralph-memory.md`.
- **Not bookkeeping-only**: touches a substantive path OR reduces that commit's
  incomplete count; else `bookkeeping-only: commit <id> …`.
- **Subject policy** (only when a commit policy is configured): subject passes
  `validate_commit_subject`; else the subject diagnostic.

## Invariant under the fix

A user story MAY be completed across multiple iterations, each contributing one
commit that satisfies row 4 + C-commit. The validator MUST NOT require a story
to be fully complete within a single iteration, and MUST continue to reject row
2 (the reported-bug state) so option 1 is enforced rather than reintroducing the
uncommitted-partial contradiction.

## Parity requirement

`Test-RalphLoop.ps1` and `test-ralph-loop.sh` MUST both assert rows 2 and 4 (the
"unchanged HEAD" reject and the "advanced HEAD" partial accept) plus a two-commit
multi-iteration story completion.

## Acceptance (maps to spec)

| Clause | Spec requirement |
|--------|------------------|
| Rows 1,4 accept | FR-001, FR-002, FR-004 |
| Row 2 reject | FR-003, FR-006, FR-009 (enforces commit, no stranded state) |
| Rows 3,5 reject | FR-005 |
| C-commit | FR-003, FR-006 |
| Parity requirement | FR-011, FR-012, SC-006 |
