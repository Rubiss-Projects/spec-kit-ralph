# Quickstart: Validate Configurable Ralph Commit Style

## Prerequisites

- Git available in `PATH`
- Bash 3.2 or newer for Unix regression validation
- PowerShell (`pwsh`) for Windows/parity validation
- Repository checkout on `003-ralph-commit-style`
- No real agent credentials required; regression scenarios can use temporary repositories and fake agent executables

## 1. Review the public configuration and contract artifacts

Confirm the feature documents the public config surface and generated subject rules:

```bash
test -f ralph-config.yml
test -f specs/003-ralph-commit-style/contracts/commit-config-schema.md
test -f specs/003-ralph-commit-style/contracts/work-unit-commit-format.md
```

Review the config contract and examples before implementation validation.

## 2. Run syntax and regression validation

```bash
bash -n scripts/bash/ralph-loop.sh
bash -n tests/regression/bash/test-ralph-loop.sh
bash tests/regression/bash/test-ralph-loop.sh
pwsh -NoLogo -NoProfile -Command '$errors=$null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "scripts/powershell/ralph-loop.ps1"), [ref]$null, [ref]$errors) > $null; [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "tests/regression/powershell/Test-RalphLoop.ps1"), [ref]$null, [ref]$errors) > $null; if ($errors.Count) { $errors | ForEach-Object { Write-Error $_ }; exit 1 }'
pwsh -NoLogo -NoProfile -File tests/regression/powershell/Test-RalphLoop.ps1
git diff --check
```

All commands must exit 0.

## 3. Validate the required commit-style scenarios

The two regression suites must exercise equivalent temporary-Git-repository scenarios:

| Scenario | Expected Outcome |
|---|---|
| No `commit` config | Ralph generates the legacy subject `feat(<feature-name>): <work-unit title>` exactly. |
| `commit.style: legacy` | Ralph generates the same legacy subject as the no-config case. |
| `commit.style: conventional` with explicit scope | Ralph generates a conventional subject using the configured scope and a concise summary of the completed change. |
| `commit.style: conventional` without scope | Ralph generates a conventional subject using the default scope `ralph` and a concise summary of the completed change. |
| Conventional work-unit title contains `US-`, `Phase`, or task-range labels | Ralph omits those planning labels from the conventional commit subject payload. |
| `commit.issue: auto` with numeric branch prefix | Ralph appends the matching `#<issue>` suffix. |
| `commit.issue: auto` without numeric branch prefix | Ralph creates the commit successfully with no issue suffix. |
| `commit.issue: auto` with legacy style | Ralph still appends the inferred issue suffix. |
| Unsupported explicit `commit.style` | Ralph exits non-zero with a clear configuration error and creates no commit. |
| Flattened config shape (`commit.style: conventional` as a top-level key instead of under `commit:`) | Ralph exits non-zero with a clear configuration error and creates no commit. |
| Equivalent Bash and PowerShell inputs | Both orchestration paths generate the same effective subject and error behavior. |

## 4. Verify documentation and template propagation

```bash
grep -n 'commit:' ralph-config.yml README.md
grep -n 'legacy' README.md specs/003-ralph-commit-style/contracts/*.md
grep -n 'conventional' README.md specs/003-ralph-commit-style/contracts/*.md
grep -n 'issue: auto' README.md specs/003-ralph-commit-style/contracts/*.md
```

Confirm:

- the configuration example shows the new `commit` block (commented out as an example);
- README explains the exact legacy default behavior (`feat(<feature-name>): <work-unit title>`), conventional scope configuration including the default scope `ralph`, the cleaner conventional commit-summary behavior, and issue auto-linking;
- the examples use a nested `commit:` block rather than flattened keys;
- the documented examples match the public contract artifacts.

## 5. Verify installed-extension compatibility

From a disposable Spec Kit project, install this checkout as a development extension:

```bash
specify extension add --dev /absolute/path/to/spec-kit-ralph
specify extension list
```

Then confirm the installed project config includes the documented commit settings and that Ralph still runs with no commit configuration present.

## Completion Evidence

Validation is complete when both regression suites pass, no-config behavior remains unchanged, conventional/issue-auto scenarios match the documented contract, conventional subjects use cleaner change summaries rather than raw planning titles, invalid-style and malformed-shape cases fail cleanly before commit creation, and installed-extension documentation remains consistent with the implementation.
