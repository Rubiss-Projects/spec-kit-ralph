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
- `printf '%d'` treats `069` as octal — use `$((10#${BASH_REMATCH[1]}))` to force base-10 when stripping leading zeros from branch prefix numbers
- PowerShell `Read-RalphConfig` uses `$inCommitBlock` state variable tracked within each config file; the `$inCommitBlock` variable must be declared inside the `ForEach-Object` outer scope to persist across iterations (use a script-level variable or pass via `[ref]`; inner ScriptBlock scope creates issues — use `$script:` prefix or inline the state in the outer `foreach` loop)

## Reusable Commands

- Run bash regression tests: `bash tests/regression/bash/test-ralph-loop.sh`
- Check bash syntax: `bash -n scripts/bash/ralph-loop.sh`
- Validate PowerShell syntax: `pwsh -NoProfile -NonInteractive -Command "[System.Management.Automation.Language.Parser]::ParseFile(...)"`

## Do Not Repeat

- (none yet)

## Current Handoff

- Phase 4 (US2, T012-T017) is complete. Next is Phase 5 (T018-T023): add Bash and PowerShell regression scenarios for US3 issue auto-linking (numeric-prefix inference, no-prefix fallback, legacy+issue-auto), implement conditional issue-suffix appending in both orchestrators (already scaffolded in `build_commit_subject`/`Build-RalphCommitSubject`), align public config and issue-linking contracts, and run the US3 parity scenarios.
