# Implementation Plan: Configurable Ralph Commit Style

**Branch**: `003-ralph-commit-style` | **Date**: 2026-07-12 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-ralph-commit-style/spec.md`

## Summary

Add an optional Ralph commit policy that preserves the legacy work-unit commit subject `feat(<feature-name>): <work-unit title>` by default, supports an opt-in conventional format with configurable scope and default scope `ralph`, generates a cleaner conventional commit summary from the actual completed change instead of reusing the raw planning title, and appends an inferred GitHub issue reference when requested. The commit policy is valid only when expressed as a nested `commit:` block in `.specify/extensions/ralph/ralph-config.yml`; flattened keys are invalid. The design resolves commit policy consistently before agent execution, separates work-unit audit titles from Git commit summaries, updates the public iterate/config contracts, and validates the behavior through mirrored Bash and PowerShell regression coverage plus documentation updates.

## Technical Context

**Language/Version**: Bash 3.2+; Windows PowerShell 5.1 and PowerShell 7+; Markdown; YAML 1.2-compatible configuration

**Primary Dependencies**: Git CLI; standard Bash utilities (`grep`, `sed`, `awk`, `mktemp`, `realpath`); PowerShell/.NET file and process APIs; existing Spec Kit integration metadata and command registration

**Storage**: Git-tracked extension source files plus project-level Ralph configuration at `.specify/extensions/ralph/ralph-config.yml`

**Testing**: Existing dependency-free Bash regression harness, PowerShell assertion harness, parser validation, and temporary-Git-repository scenarios

**Target Platform**: macOS/Linux via Bash and Windows via PowerShell, with equivalent work-unit commit behavior across supported agent CLIs

**Project Type**: Spec Kit extension composed of Markdown command contracts, cross-platform orchestration scripts, configuration templates, and regression tests

**Performance Goals**: Commit policy resolution adds only bounded local config and branch-name parsing before a completed work-unit commit; no extra agent iteration or network dependency is introduced

**Constraints**: Preserve current behavior exactly when commit config is absent; reject unsupported `commit.style` values clearly and reject flattened commit-policy keys outside the nested `commit:` block; support `issue: auto` without failing when no issue prefix exists; keep legacy subjects exact while making conventional subjects read like concise Git history entries rather than raw planning titles; avoid adding a YAML parser dependency; maintain Bash/PowerShell parity; keep the change extension-local and documentation-complete

**Scale/Scope**: One public config surface, one public iterate-command contract, two orchestration scripts, two regression suites, one config template, README guidance, and example/fixture updates for exact legacy subjects plus normalized conventional commit-summary outputs

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

### Pre-Research Gate

| Principle / Gate | Status | Planning Evidence |
|---|---|---|
| I. Extension-First Architecture | PASS | All changes stay within the extension's commands, scripts, config template, tests, and docs; no Spec Kit core modification is needed. |
| II. Context Isolation | PASS | The feature changes commit-subject policy only; it does not alter Ralph's fresh-process iteration model or memory contract beyond separating audit titles from commit summaries. |
| III. Spec-Kit Compatibility | PASS | The config remains optional and backward-compatible; no new command, hook, schema, or installation requirement is introduced. |
| IV. Progress Persistence | PASS | Commit subject generation is separated from progress tracking so audit titles remain durable even when conventional commit summaries differ. |
| V. Agent Agnosticism | PASS | Commit policy is defined through extension config and shared orchestration behavior rather than a single agent-specific implementation. |
| VI. Graceful Termination | PASS | Unsupported config becomes an explicit, non-success validation outcome instead of a silent fallback. |
| Manifest Gate | PASS | Existing command/config registration remains sufficient; only referenced files and docs change. |
| Script Gate | PENDING | Bash and PowerShell must resolve and validate commit policy identically. |
| Integration Gate | PENDING | Validation must cover the installed extension path and active project config behavior. |
| Documentation Gate | PENDING | README and config template must document the new commit options and examples. |
| Compatibility Gate | PENDING | Regression validation must show existing projects without commit config remain unchanged. |

**Gate Result**: PASS for planning after Constitution v2.1.0 amendment. Principle VI now allows only the narrow pre-acceptance retry for subject-only `commit-subject-invalid` defects from explicitly configured commit policy; all broader cleanup/recovery remains forbidden.

### Post-Design Re-evaluation

| Principle / Gate | Status | Design Evidence |
|---|---|---|
| I. Extension-First Architecture | PASS | The design is captured in [commit-config-schema.md](contracts/commit-config-schema.md) and [work-unit-commit-format.md](contracts/work-unit-commit-format.md), both extension-local artifacts. |
| II. Context Isolation | PASS | The resolved commit policy is an on-disk/config-derived input to each fresh iteration and does not depend on reused in-memory state. |
| III. Spec-Kit Compatibility | PASS | [research.md](research.md) keeps the config optional and avoids any core/runtime dependency expansion. |
| IV. Progress Persistence | PASS | [work-unit-commit-format.md](contracts/work-unit-commit-format.md) changes commit-subject construction while keeping the coordinated persistence contract and progress log structure intact. |
| V. Agent Agnosticism | PASS | The plan resolves policy in mirrored orchestrators and exposes one shared contract to Copilot, Codex, and Claude paths. |
| VI. Graceful Termination | PASS | Invalid present config is a deterministic preflight failure with no silent fallback and no history mutation. |
| Script Gate | PASS BY DESIGN | The same config-resolution, issue-inference, and validation scenarios are planned for both scripts and both regression suites. |
| Integration / Documentation / Compatibility Gates | PENDING IMPLEMENTATION | [quickstart.md](quickstart.md) defines the validation evidence required to close them. |

No constitution violation remains after the v2.1.0 narrow retry amendment.

## Project Structure

### Documentation (this feature)

```text
specs/003-ralph-commit-style/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── commit-config-schema.md
│   └── work-unit-commit-format.md
└── tasks.md                     # Created by /speckit-tasks, not this command
```

### Source Code (repository root)

```text
spec-kit-ralph/
├── commands/
│   └── iterate.md                      # Public agent contract for work-unit commits
├── scripts/
│   ├── bash/
│   │   └── ralph-loop.sh               # Bash config resolution and preflight validation
│   └── powershell/
│       └── ralph-loop.ps1              # PowerShell parity implementation
├── tests/
│   └── regression/
│       ├── bash/test-ralph-loop.sh     # Bash regression scenarios
│       ├── powershell/Test-RalphLoop.ps1
│       └── fixtures/                   # Config and branch/commit fixtures
├── ralph-config.yml                    # Canonical installed config source
├── README.md                           # User-facing config and commit examples
└── extension.yml                       # Compatibility review only; no schema change expected
```

**Structure Decision**: Extend the existing flat extension layout. Commit policy resolution and validation live in the mirrored orchestrator scripts; agent-facing commit instructions stay in `commands/iterate.md`; the project-visible configuration surface remains the canonical `ralph-config.yml`; regression coverage and fixtures stay in the existing cross-platform suites.

## Complexity Tracking

No extra subsystem is required. The narrow subject-only retry is authorized by Constitution v2.1.0.
