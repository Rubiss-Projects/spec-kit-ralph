# Quickstart: Validate Durable Ralph Memory Handoff

## Prerequisites

- Git available in `PATH`
- Bash 3.2 or newer for the Unix regression path
- PowerShell (`pwsh`) for the Windows/parity regression path
- Repository checkout on `27-ralph-memory-handoff`
- No real agent credentials are required; regression scenarios use temporary repositories and fake agent executables

## 1. Confirm the design and canonical template

After implementation, verify the shared template exists and exposes the contract headings in order:

```bash
test -f templates/ralph-memory.md
grep -E '^#|^Feature:|^Started:' templates/ralph-memory.md
grep '^## ' templates/ralph-memory.md
```

Expected H2 sequence:

```text
## Codebase Patterns
## Decisions
## Gotchas
## Reusable Commands
## Do Not Repeat
## Current Handoff
```

See [Ralph Memory Schema](contracts/ralph-memory-schema.md) for metadata, invalid-file, and terminal-handoff rules.

## 2. Run syntax and regression validation

```bash
bash -n scripts/bash/ralph-loop.sh
bash -n tests/regression/bash/test-ralph-loop.sh
bash tests/regression/bash/test-ralph-loop.sh
pwsh -NoLogo -NoProfile -Command '$errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "scripts/powershell/ralph-loop.ps1"), [ref]$null, [ref]$errors) > $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "tests/regression/powershell/Test-RalphLoop.ps1"), [ref]$null, [ref]$errors) > $null; if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }'
pwsh -NoLogo -NoProfile -File tests/regression/powershell/Test-RalphLoop.ps1
git diff --check
```

All commands must exit 0. The regression summaries must report no failures and must retain all pre-feature tests.

## 3. Verify required lifecycle scenarios

The two regression suites must exercise equivalent temporary-Git-repository scenarios:

| Scenario | Expected Outcome |
|---|---|
| Missing memory with incomplete tasks | Canonical file exists before fake agent invocation. |
| Valid existing memory | File remains byte-for-byte unchanged during preparation. |
| Malformed memory with multiple defects | Exit 1; all defects reported; no agent invocation; bytes unchanged. |
| Completed substantive work unit | Source, tasks, memory, and appended progress are in one commit. |
| Failed/no-work iteration | Memory/progress remain uncommitted; tasks and `HEAD` unchanged. |
| Later substantive work after failure | Prior uncommitted failure records join the substantive commit. |
| Initially complete and fully canonical, clean state | Exit 0 without agent invocation. |
| Initially or newly complete but dirty | Exit 1 immediately; all dirty paths reported; no next iteration. |
| Completion token with remaining tasks or failed agent | Exit 1 as inconsistent; token does not force success. |
| Final work unit | `Current Handoff` contains only the exact completion marker. |
| Bookkeeping-only commit | Report protocol violation without rewriting history. |

The normative sequencing and exit behavior are in [Iteration Lifecycle](contracts/iteration-lifecycle.md).

Canonical regression inputs are:

- `tests/regression/fixtures/ralph-memory-valid-active.md` for valid nonterminal state;
- `tests/regression/fixtures/ralph-memory-valid-complete.md` for the exact terminal handoff;
- `tests/regression/fixtures/ralph-memory-malformed.md` for simultaneous structural defects and byte-preservation checks.

Memory diagnostics use the stable categories `template-unavailable`, `title-invalid`, `feature-invalid`, `started-invalid`, `section-missing`, `section-duplicate`, `section-unexpected`, `section-order`, `token-unresolved`, and `handoff-invalid`. Completion diagnostics additionally distinguish an invalid agent result, remaining tasks, coordinated-commit violations, bookkeeping-only commits, and each `dirty-path` porcelain line.

## 4. Verify cross-platform parity

Compare the Bash and PowerShell test summaries for the scenario classes above. Newly initialized timestamps may differ, but both paths must agree on:

- canonical metadata labels and heading order;
- valid/invalid classification and aggregate diagnostic categories;
- task and commit transitions;
- clean/dirty completion result and exit class;
- exact preservation of invalid file bytes.

## 5. Verify governance and documentation propagation

```bash
grep -n 'Version.*2.0.0' .specify/memory/constitution.md
grep -n 'ralph-memory.md' .specify/memory/constitution.md commands/iterate.md README.md
grep -n 'progress.md' .specify/memory/constitution.md commands/iterate.md README.md
grep -n 'Feature complete; no handoff required.' commands/iterate.md tests/regression/bash/test-ralph-loop.sh tests/regression/powershell/Test-RalphLoop.ps1
```

Review the matches and confirm:

- Constitution Principles II, IV, and VI describe the new memory/audit/completion contract.
- No active guidance identifies `progress.md` as the primary durable-memory source.
- README explains lazy initialization, malformed-memory failure, failed-attempt persistence, and clean completion.
- CHANGELOG `[Unreleased]` records the behavior change.
- Historical `specs/001-port-ralph-extension/**` files remain unchanged.

## 6. Verify extension packaging

From a disposable Spec Kit project, install this checkout as a development extension:

```bash
specify extension add --dev /absolute/path/to/spec-kit-ralph
specify extension list
```

Confirm the installed extension contains `templates/ralph-memory.md`, both scripts, and both commands. Run a regression fixture or disposable feature through the installed script path and confirm memory initialization resolves from the installed extension root.

## Completion Evidence

Validation is complete when syntax checks, both regression suites, propagation review, and development-extension packaging all pass; dirty or malformed scenarios must fail only in their expected controlled way and must leave Git history unchanged.
