# Implementation Plan: Durable Ralph Memory Handoff

**Branch**: `27-ralph-memory-handoff` | **Date**: 2026-07-10 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-ralph-memory-handoff/spec.md`

## Summary

Introduce `ralph-memory.md` as Ralph's compact durable knowledge bridge while retaining `progress.md` as an append-only audit trail. Both orchestrators will initialize memory from one extension-owned Markdown template, validate existing memory without mutation, and refuse work selection when the canonical contract is invalid. The iteration command will read memory first and persist tasks, memory, and audit state before a substantive work-unit commit. Every completion path will independently verify task state, the terminal handoff, commit protocol, and an empty `git status --short`; validation remains read-only and never amends, rewrites, or creates recovery commits.

## Technical Context

**Language/Version**: Bash 3.2+; Windows PowerShell 5.1 and PowerShell 7+; Markdown; YAML 1.2-compatible manifest/configuration

**Primary Dependencies**: Git CLI; standard Bash utilities (`grep`, `sed`, `awk`, `mktemp`, `realpath`); PowerShell/.NET file and process APIs; existing Spec Kit prerequisite scripts and configured agent CLI

**Storage**: Git-tracked files in `specs/{feature}/` (`tasks.md`, `progress.md`, `ralph-memory.md`) plus one extension-owned template at `templates/ralph-memory.md`

**Testing**: Existing dependency-free Bash regression harness and PowerShell assertion harness; subprocess scenarios in temporary Git repositories; cross-platform semantic parity checks; `bash -n` and PowerShell parser validation

**Target Platform**: macOS/Linux through Bash and Windows through PowerShell, with equivalent lifecycle, validation categories, exit classes, and user diagnostics

**Project Type**: Spec Kit extension composed of Markdown agent commands, cross-platform CLI orchestration scripts, file contracts, and regression tests

**Performance Goals**: Memory preparation performs a single bounded local template/file scan before agent launch; completion adds one read-only Git status inspection and no extra agent iteration

**Constraints**: No new runtime or third-party parser; preserve invalid/existing files byte-for-byte; report all validation defects; never auto-normalize memory; never create bookkeeping-only, amend, recovery, or history-rewrite commits; exact final handoff marker; repository-wide clean-tree requirement; Bash/PowerShell parity; delivery branch begins `27-` and feature commit subjects end with `#27`

**Scale/Scope**: Two orchestrators, two regression suites, one iteration command, one shared template, two public file/lifecycle contracts, README and changelog updates, and a breaking constitution amendment from 1.0.0 to 2.0.0

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-checked after Phase 1 design.*

### Pre-Research Gate

| Principle / Gate | Status | Planning Evidence |
|---|---|---|
| I. Extension-First Architecture | PASS | The memory template, command changes, helpers, and tests remain inside the extension; no Spec Kit core modification is proposed. |
| II. Context Isolation | AUTHORIZED AMENDMENT | The existing text omits `ralph-memory.md`. Clarification Q1 and FR-019 authorize a breaking amendment that preserves fresh-process isolation while changing the disk handoff source. |
| III. Spec-Kit Compatibility | PASS | The design adds no command, hook, configuration key, schema dependency, or core requirement. The new template is packaged because `templates/` is not excluded. |
| IV. Progress Persistence | AUTHORIZED AMENDMENT | The existing text assigns durable patterns to `progress.md`. The approved split moves durable knowledge to memory while retaining append-only audit and task persistence. |
| V. Agent Agnosticism | PASS | Memory and completion behavior is enforced through shared file/process contracts and does not depend on Copilot, Codex, or Claude-specific semantics. |
| VI. Graceful Termination | AUTHORIZED AMENDMENT | The existing unconditional all-tasks-complete success rule conflicts with the approved clean-tree and terminal-handoff gates; the amendment will make success conditional and validation read-only. |
| Manifest Gate | PASS | No manifest schema change is needed; release versioning remains owned by the existing release workflow. |
| Script Gate | PASS | Every runtime behavior is designed for both Bash and PowerShell with mirrored regression coverage. |
| Integration Gate | PENDING | Validate installed/source-tree template resolution and direct script execution during implementation. |
| Documentation Gate | PENDING | README, changelog, command contract, and constitution propagation are implementation deliverables. |
| Compatibility Gate | PENDING | Regression suites must prove existing agent dispatch, configuration, progress append behavior, and completion-signal parsing remain intact. |

**Gate Result**: PASS for planning. The conflicts are not waived exceptions; they are an explicitly approved constitution transition. The constitution amendment to 2.0.0 and its propagation review are a prerequisite to product-code implementation.

### Post-Design Re-evaluation

| Principle / Gate | Status | Design Evidence |
|---|---|---|
| I. Extension-First Architecture | PASS | [ralph-memory-schema.md](contracts/ralph-memory-schema.md) locates the canonical template under the extension root. |
| II. Context Isolation | PASS AFTER AMENDMENT | [iteration-lifecycle.md](contracts/iteration-lifecycle.md) requires a fresh process and memory-first disk context before selection. |
| III. Spec-Kit Compatibility | PASS | The plan uses existing scripts, command registration, Git, and file storage only. |
| IV. Progress Persistence | PASS AFTER AMENDMENT | The data model separates durable memory, append-only audit, task state, and substantive commits with explicit transitions. |
| V. Agent Agnosticism | PASS | Lifecycle rules apply before and after any configured agent CLI invocation. |
| VI. Graceful Termination | PASS AFTER AMENDMENT | A single read-only completion gate covers initial, signal, and post-iteration candidates and returns non-zero on invalid or dirty state. |
| Script Gate | PASS BY DESIGN | Contract cases have Bash and PowerShell equivalents and semantic parity criteria. |
| Integration / Documentation / Compatibility Gates | PENDING IMPLEMENTATION | [quickstart.md](quickstart.md) defines the runnable evidence required to close these gates. |

No unjustified constitution violation remains in the design.

## Project Structure

### Documentation (this feature)

```text
specs/002-ralph-memory-handoff/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── iteration-lifecycle.md
│   └── ralph-memory-schema.md
└── tasks.md                     # Created by /speckit-tasks, not this command
```

### Source Code (repository root)

```text
spec-kit-ralph/
├── .specify/memory/constitution.md       # Amend Principles II, IV, VI; version 2.0.0
├── commands/
│   ├── iterate.md                        # Memory-first and persistence-before-commit contract
│   └── run.md                            # Review launcher/preflight wording for compatibility
├── scripts/
│   ├── bash/ralph-loop.sh                # Bash memory and completion helpers
│   └── powershell/ralph-loop.ps1         # PowerShell parity implementation
├── templates/
│   └── ralph-memory.md                   # Single canonical runtime template
├── tests/regression/
│   ├── bash/test-ralph-loop.sh
│   ├── powershell/Test-RalphLoop.ps1
│   └── fixtures/                         # Canonical and malformed memory/task fixtures
├── README.md                             # Memory/audit split and completion behavior
├── CHANGELOG.md                          # Unreleased feature record
├── extension.yml                         # Compatibility review; release workflow owns version bump
└── .extensionignore                      # Verify templates remain package-included
```

**Structure Decision**: Extend the existing flat Spec Kit extension layout. Runtime initialization and completion validation live in mirrored script helpers; agent-owned knowledge and commit sequencing live in `commands/iterate.md`; the template is the only initialization source; contract documents define the shared behavior used by both platforms. Historical `specs/001-port-ralph-extension/**` artifacts remain unchanged.

## Complexity Tracking

No constitution exception or additional subsystem is required. The breaking constitution version records the approved governance change rather than waiving it.
