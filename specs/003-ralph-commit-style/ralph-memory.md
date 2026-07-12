# Ralph Memory

Feature: 003-ralph-commit-style
Started: 2026-07-12T13:58:14Z

## Codebase Patterns

- Config fixtures live in `tests/regression/fixtures/` as `ralph-config-<name>.yml`
- Existing `load_ralph_config()` in `scripts/bash/ralph-loop.sh` uses a simple `key: value` line parser; new `commit.*` sub-keys will need nested parsing (strip leading whitespace, handle `commit.style` etc.)
- Bash regression harness at `tests/regression/bash/test-ralph-loop.sh` extracts functions via `sed -n '/^fn_name()/,/^}/p'` — new commit policy functions must follow the same top-level function declaration style
- PowerShell harness at `tests/regression/powershell/Test-RalphLoop.ps1` follows equivalent patterns; both suites must stay in parity

## Decisions

- Legacy format: `feat(<feature-name>): <work-unit title>` — preserved unchanged when no `commit` block is present
- Conventional format: `feat(<scope>): <work-unit title>` with default scope `ralph`
- Issue suffix: ` #<N>` appended when `issue: auto` and branch starts with numeric prefix (e.g. `069-...` → `#69`)
- Unsupported `commit.style` is a preflight error; no commit is created

## Gotchas

- The existing `load_ralph_config` only handles top-level keys; nested YAML (`commit:\n  style: ...`) needs special handling — strip leading whitespace and track whether we are inside the `commit:` block
- Do NOT introduce a YAML parser dependency; keep line-based parsing

## Reusable Commands

- Run bash regression tests: `bash tests/regression/bash/test-ralph-loop.sh`
- Check bash syntax: `bash -n scripts/bash/ralph-loop.sh`

## Do Not Repeat

- (none yet)

## Current Handoff

- Phase 1 fixtures are complete (T001-T003). Next is Phase 2 (T004-T006): implement commit policy parsing helpers in `scripts/bash/ralph-loop.sh` and `scripts/powershell/ralph-loop.ps1`, and update `commands/iterate.md` with policy-aware commit instructions.
