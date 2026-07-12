# Ralph Progress Log

Feature: 003-ralph-commit-style
Started: 2026-07-12 15:58:14

---

## Iteration 1 - 2026-07-12 15:58
**Work Unit**: Phase 1 — Setup: Shared Commit Policy Assets (T001-T003)
**Tasks Completed**:
- [x] T001: Create `tests/regression/fixtures/ralph-config-legacy.yml`
- [x] T002: Create `tests/regression/fixtures/ralph-config-conventional.yml`
- [x] T003: Create `tests/regression/fixtures/ralph-config-invalid.yml` and update `tests/regression/fixtures/README.md`
**Tasks Remaining in Work Unit**: 0
**Commit**: This work-unit commit
**Files Changed**:
- tests/regression/fixtures/ralph-config-legacy.yml
- tests/regression/fixtures/ralph-config-conventional.yml
- tests/regression/fixtures/ralph-config-invalid.yml
- tests/regression/fixtures/README.md
- specs/003-ralph-commit-style/tasks.md
- specs/003-ralph-commit-style/ralph-memory.md
- specs/003-ralph-commit-style/progress.md
**Learnings**:
- Existing config loader is top-level key/value only; Phase 2 needs nested `commit:` block handling
- All 165 existing regression tests pass unchanged
---

## Iteration 2 - 2026-07-12 16:00
**Work Unit**: Phase 2 — Foundational: Shared Commit Policy Plumbing (T004-T006)
**Tasks Completed**:
- [x] T004: Implement commit policy helpers in `scripts/bash/ralph-loop.sh`
- [x] T005: Implement parity commit policy helpers in `scripts/powershell/ralph-loop.ps1`
- [x] T006: Update policy-aware commit instructions in `commands/iterate.md`
**Tasks Remaining in Work Unit**: 0
**Commit**: This work-unit commit
**Files Changed**:
- scripts/bash/ralph-loop.sh
- scripts/powershell/ralph-loop.ps1
- commands/iterate.md
- tests/regression/bash/test-ralph-loop.sh
- specs/003-ralph-commit-style/tasks.md
- specs/003-ralph-commit-style/ralph-memory.md
- specs/003-ralph-commit-style/progress.md
**Learnings**:
- `load_ralph_config` extended with `in_commit_block` tracking to parse nested `commit.style/scope/issue` keys
- `printf '%d'` treats leading-zero strings as octal; use `$((10#N))` to force base-10 branch prefix extraction
- PowerShell `$inCommitBlock` must be declared before the `ForEach-Object` pipeline to persist across lines
- All 165 existing bash regression tests pass unchanged
---

## Iteration 3 - 2026-07-12 16:08
**Work Unit**: Phase 3 — User Story 1: Keep Existing Commit Behavior by Default (T007-T011)
**Tasks Completed**:
- [x] T007: Add Bash regression scenarios for no-config and explicit legacy commit behavior
- [x] T008: Add PowerShell parity regression scenarios for no-config and explicit legacy commit behavior
- [x] T009: Wire resolved legacy-default commit policy into `build_iteration_prompt` in `scripts/bash/ralph-loop.sh`
- [x] T010: Wire resolved legacy-default commit policy into `New-IterationPrompt` in `scripts/powershell/ralph-loop.ps1`; update `Invoke-ClaudeIteration` and `Invoke-CodexIteration` callers
- [x] T011: All 173 bash and 228 PowerShell regression tests pass
**Tasks Remaining in Work Unit**: 0
**Commit**: This work-unit commit
**Files Changed**:
- tests/regression/bash/test-ralph-loop.sh
- tests/regression/powershell/Test-RalphLoop.ps1
- scripts/bash/ralph-loop.sh
- scripts/powershell/ralph-loop.ps1
- specs/003-ralph-commit-style/tasks.md
- specs/003-ralph-commit-style/ralph-memory.md
- specs/003-ralph-commit-style/progress.md
**Learnings**:
- `build_iteration_prompt` (bash) and `New-IterationPrompt` (PS) now append a `## Resolved Commit Policy` section when `COMMIT_POLICY_STYLE` / `CommitPolicy` is set, so agents receive the pre-resolved format without re-reading config
- `New-IterationPrompt` gained an optional `[hashtable]$CommitPolicy = $null` parameter; callers `Invoke-ClaudeIteration` and `Invoke-CodexIteration` now pass `$commitPolicy` (script-level variable)
- TDD flow: T007/T008 tests for `build_iteration_prompt`/`New-IterationPrompt` policy injection failed before T009/T010 implementation, then passed after
---
