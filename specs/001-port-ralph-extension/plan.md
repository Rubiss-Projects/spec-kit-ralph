# Implementation Plan: Port Ralph Loop to Spec-Kit Extension

**Branch**: `001-port-ralph-extension` | **Date**: 2026-03-06 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `specs/001-port-ralph-extension/spec.md`

## Summary

Port the ralph loop autonomous implementation system from spec-kit core into a standalone spec-kit extension. The extension packages orchestrator scripts (PowerShell + Bash), agent command files, and a config template into the `extension.yml` manifest format. The `speckit.ralph.run` command acts as a thin launcher delegating to platform scripts; `speckit.ralph.iterate` defines single-iteration agent behavior. No Python code — all orchestration via scripts, all agent behavior via markdown commands.

## Technical Context

**Language/Version**: Markdown (command files), PowerShell 5.1+/7+ (Windows orchestrator), Bash 4+ (Unix orchestrator), YAML (manifest + config)
**Primary Dependencies**: spec-kit extension system (schema v1.0), GitHub Copilot CLI (`copilot` binary)
**Storage**: File-based — `tasks.md` (checkbox state), `progress.md` (iteration log), YAML config
**Testing**: Manual via `specify extension add --dev`; automated manifest validation via `specify_cli.extensions.ExtensionManifest`
**Target Platform**: Windows (PowerShell), macOS/Linux (Bash) — both must produce identical behavior
**Project Type**: spec-kit extension
**Performance Goals**: <2s between iterations (SC-003)
**Constraints**: No Python runtime required for end users; context isolation per iteration (NON-NEGOTIABLE); self-contained within extension directory
**Scale/Scope**: 2 commands, 2 orchestrator scripts, 1 config template, 1 hook

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| # | Principle | Status | Notes |
|---|-----------|--------|-------|
| I | Extension-First Architecture | PASS | Entire project IS an extension with `extension.yml` manifest; commands follow `speckit.ralph.*` pattern; config in `.specify/extensions/ralph/` |
| II | Context Isolation (NON-NEGOTIABLE) | PASS | Scripts spawn fresh `copilot` process per iteration; no state inheritance; inter-iteration transfer via `progress.md` and `tasks.md` only |
| III | Spec-Kit Compatibility | PASS | Schema version 1.0; `requires.speckit_version: ">=0.1.0"`; installs via `specify extension add --dev` |
| IV | Progress Persistence | PASS | `tasks.md` checkboxes for completion; `progress.md` append-only log; `<promise>COMPLETE</promise>` only after verified completion |
| V | Agent Agnosticism | PASS (with caveat) | Config has `agent_cli` field; v1.0 targets Copilot-only per spec clarification Q3; architecture does not preclude future agents |
| VI | Graceful Termination | PASS | All 4 termination paths handled: completion (exit 0), iteration limit (exit 1), Ctrl+C (exit 130), consecutive failures (exit 1 with summary) |

**Extension Compliance Gates**:

| Gate | Status | Notes |
|------|--------|-------|
| Manifest Gate | PASS | `extension.yml` conforms to schema 1.0; all commands resolve to files |
| Script Gate | PASS | Both `ralph-loop.ps1` and `ralph-loop.sh` included with identical behavior |
| Integration Gate | PENDING | Will verify during implementation via `specify extension add --dev` |
| Documentation Gate | PENDING | README, command descriptions, config template to be created |
| Compatibility Gate | PENDING | Will verify no conflicts with other extensions |

## Project Structure

### Documentation (this feature)

```text
specs/001-port-ralph-extension/
├── plan.md              # This file
├── research.md          # Phase 0: porting decisions and unknowns resolved
├── data-model.md        # Phase 1: entities and relationships
├── quickstart.md        # Phase 1: getting started guide
├── contracts/           # Phase 1: command and config schemas
│   ├── extension-manifest.md
│   ├── command-schemas.md
│   └── config-schema.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
spec-kit-ralph/                          # Extension root (= repo root)
├── extension.yml                        # Extension manifest (schema v1.0)
├── commands/
│   ├── run.md                           # speckit.ralph.run — thin launcher
│   └── iterate.md                       # speckit.ralph.iterate — single iteration
├── scripts/
│   ├── powershell/
│   │   └── ralph-loop.ps1               # PowerShell orchestrator (ported from core)
│   └── bash/
│       └── ralph-loop.sh                # Bash orchestrator (ported from core)
├── ralph-config.template.yml            # Config template (model, iterations, agent_cli)
├── README.md                            # Extension documentation (install, usage, both paths)
├── LICENSE                              # MIT
└── CHANGELOG.md                         # Version history
```

**Structure Decision**: Extension-native flat structure per the [Extension Development Guide](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md). No `src/`, `tests/`, or nested project layout — this is a script+command extension, not a library. Agent behavior is supplied through registered extension command files, with `run.md` acting only as a launcher and `iterate.md` defining one iteration of work.

## Complexity Tracking

No constitution violations. Table not required.
