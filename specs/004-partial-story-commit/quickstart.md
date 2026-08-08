# Quickstart: Validating the Partial-Story Commit Fix

**Feature**: 004-partial-story-commit | **Date**: 2026-08-08

This guide proves the fix end-to-end: a multi-task user story spans several
Ralph iterations without failing the loop, completed state is never stranded,
and the command + orchestrator agree. See [contracts/](./contracts/) and
[data-model.md](./data-model.md) for the authoritative rules.

## Prerequisites

- `git`, `bash` (3.2+), and PowerShell (5.1+/7+) available.
- Repository checked out on branch `004-partial-story-commit`.
- No implementation code needs to be pasted here — run the existing harnesses.

## 1. Regression harnesses (primary gate)

Run both platform harnesses; they must pass, including the new
partial-completion cases (SC-006).

```sh
# Bash
bash tests/regression/bash/test-ralph-loop.sh
```

```powershell
# PowerShell
pwsh tests/regression/powershell/Test-RalphLoop.ps1
```

**Expected**: all cases pass, including:

- partial-story iteration that commits a validated subset → **accepted**
  (advanced HEAD, reduced incomplete count);
- partial-story state with unchanged HEAD + reduced count → **rejected** with
  `coordinated-commit-invalid`;
- a story completed across two coordinated commits → loop does **not** report
  `FAILED`.

## 2. Manual reproduction of the original bug (should now pass)

Recreate the issue scenario: a user story with three tasks, completing only the
first in one iteration.

```markdown
## User Story 1
- [ ] T001 Move watch implementation
- [ ] T002 Split update command
- [ ] T003 Split cancel command
```

Run one iteration that validates and completes only `T001`.

**Expected outcome (post-fix)**:

- `tasks.md` shows `- [x] T001` with T002/T003 still `- [ ]`.
- Exactly one coordinated commit exists containing the substantive change plus
  `tasks.md`, `progress.md`, and `ralph-memory.md`.
- `git status --short` is clean — no completed-task state left uncommitted.
- The loop continues to a next iteration instead of terminating; status is not
  `FAILED`.
- The next iteration selects `T002` (next incomplete task in the same story),
  not `T001`.

## 3. Policy-consistency review (SC-005)

Confirm the three surfaces state one policy with zero contradictions:

- `commands/iterate.md` — work unit = phase / story / validated task group;
  validated partial subsets are committed each iteration, never left
  uncommitted.
- The generated `speckit-ralph-iterate` skill — produced from the command, so it
  inherits the same wording (no separate edit in this repo).
- `scripts/bash/ralph-loop.sh` + `scripts/powershell/ralph-loop.ps1` — accept a
  coordinated partial-story commit; reject reduced-count-with-unchanged-HEAD.

Cross-check against [contracts/orchestrator-commit-validation.md](./contracts/orchestrator-commit-validation.md)
decision table.

## 4. Guardrails still hold (negative checks)

- An iteration that fails validation leaves `tasks.md` unchanged and creates no
  commit (FR-005).
- No commit contains only `tasks.md` / `progress.md` / `ralph-memory.md` without
  a completed task (FR-006).
- No iteration begins a second user story (FR-008).

## Success

All of the above pass ⇒ spec Success Criteria SC-001…SC-006 are satisfied.
