# Implementation Plan: Accept Task Expansion With Completed Progress

**Branch**: `005-task-expansion-validation` | **Date**: 2026-08-13 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/005-task-expansion-validation/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command; its definition describes the execution workflow.

## Summary

Ralph currently treats a successful iteration as failed/no-work when the net
unchecked-task count does not decrease. That rejects a valid Spec Kit-compatible
case: an iteration completes one or more previously incomplete tasks and, as
the accepted output of that work unit, adds new unchecked follow-up tasks.

Technical approach: classify progress by **completed task identity** rather
than by net unchecked-task count. An iteration is valid progress when at least
one task that was incomplete before the iteration is checked after the
iteration, even if new unchecked tasks were added. Bash needs first-class
incomplete/completed task ID snapshots; PowerShell already has iteration-level
ID snapshots but still needs the same checked-existing-ID rule in commit-level
bookkeeping checks and user-facing summaries. Both execution paths must report
accepted task expansion clearly while preserving all existing failed/no-work,
coordinated-commit, bookkeeping-only, clean-completion, and iteration-limit
guardrails.

## Technical Context

**Language/Version**: Bash 3.2+ compatible shell scripts; Windows PowerShell 5.1 and PowerShell 7+; Markdown command and documentation artifacts.

**Primary Dependencies**: Git CLI; standard shell utilities already used by the project; PowerShell/.NET file and process APIs; Spec Kit extension API via `extension.yml`.

**Storage**: Git-tracked feature files: `tasks.md` for checkbox task state, `progress.md` for append-only audit, and `ralph-memory.md` for durable memory. No additional state store.

**Testing**: Existing dependency-free regression harnesses: `tests/regression/bash/test-ralph-loop.sh` and `tests/regression/powershell/Test-RalphLoop.ps1`.

**Target Platform**: macOS/Linux through Bash and Windows through PowerShell, including local developer runs and CI-style validation.

**Project Type**: Spec Kit extension composed of Markdown command contracts, cross-platform orchestration scripts, and regression tests.

**Performance Goals**: Correctness-first feature. Iteration validation remains bounded by the number of tasks in the active `tasks.md` and the number of commits created in the current iteration.

**Constraints**: Preserve fresh agent process isolation, disk-persisted task state, read-only validation, no hidden repair commits, no arbitrary task churn, no bookkeeping-only commits, and cross-platform parity.

**Scale/Scope**: Small validation/reporting change across two orchestrators, two regression harnesses, command/user documentation, and feature design artifacts.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluated against `.specify/memory/constitution.md` v2.1.0:

- **I. Extension-First Architecture** — PASS. Changes remain inside the extension source tree (`commands/`, `scripts/`, `tests/`, `README.md`, `CHANGELOG.md`, and feature specs). No Spec Kit core changes.
- **II. Context Isolation** — PASS. The plan keeps one fresh agent process per iteration and preserves the one work-unit-per-iteration rule. Task expansion is accepted only when the same isolated iteration completes existing work.
- **III. Spec-Kit Compatibility** — PASS / reinforced. The feature improves compatibility with Spec Kit task workflows that legitimately refine or expand `tasks.md`.
- **IV. Progress Persistence** — PASS. Task status remains authoritative in `tasks.md`, durable context remains in `ralph-memory.md`, audit remains in `progress.md`, and accepted work continues to be captured in coordinated commits.
- **V. Agent Agnosticism** — PASS. The progress rule is based on on-disk task state and Git history, not on a specific agent CLI.
- **VI. Graceful Termination** — PASS. `max_iterations`, failure circuit breaking, dirty completion, and no-repair behavior are preserved. The feature removes a spurious invalid-work-unit failure without adding cleanup or recovery behavior.

**Gate result: PASS. No violations; Complexity Tracking not required.**

Extension compliance gates: Manifest Gate unaffected; Script Gate requires mirrored Bash/PowerShell behavior and tests; Documentation Gate applies because users must understand accepted task expansion and iteration-limit implications; Integration and Compatibility Gates remain unchanged.

## Project Structure

### Documentation (this feature)

```text
specs/005-task-expansion-validation/
├── plan.md
├── spec.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── task-expansion-policy.md
│   └── iteration-validation-contract.md
├── checklists/
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
commands/
└── iterate.md                         # User-facing iteration/task-expansion policy wording

scripts/
├── bash/
│   └── ralph-loop.sh                  # ID-based task progress validation and summary reporting
└── powershell/
    └── ralph-loop.ps1                 # PowerShell parity for validation and reporting

tests/
└── regression/
    ├── bash/
    │   └── test-ralph-loop.sh         # Valid expansion + invalid churn cases
    └── powershell/
        └── Test-RalphLoop.ps1         # Mirrored parity cases

README.md                              # Explain accepted expansion and max_iterations boundary
CHANGELOG.md                           # Unreleased entry
AGENTS.md                              # Plan reference for active feature
```

**Structure Decision**: Keep the existing single-project Spec Kit extension layout. The core behavior is enforced in the two orchestrators, explained in `commands/iterate.md` and README, and verified in the existing platform-specific regression harnesses.

## Complexity Tracking

> No Constitution Check violations. Section intentionally left empty.

## Phase 0: Research Complete

Research output: [research.md](./research.md)

Key decisions:

- Progress is detected by previously incomplete task IDs that are now checked, not net unchecked-task count.
- Task expansion is accepted only when existing incomplete tasks were completed.
- `max_iterations` remains the loop-size boundary; task expansion adds visibility, not new control semantics.
- Bash and PowerShell must share the same conceptual snapshot fields and diagnostic categories.

## Phase 1: Design Complete

Design outputs:

- [data-model.md](./data-model.md)
- [contracts/task-expansion-policy.md](./contracts/task-expansion-policy.md)
- [contracts/iteration-validation-contract.md](./contracts/iteration-validation-contract.md)
- [quickstart.md](./quickstart.md)

## Post-Design Constitution Check

Re-evaluated after Phase 1:

- **I. Extension-First Architecture** — PASS. Contracts and quickstart target extension-local files only.
- **II. Context Isolation** — PASS. The data model keeps state transfer on disk and does not introduce shared in-memory iteration state.
- **III. Spec-Kit Compatibility** — PASS. The contracts explicitly accept Spec Kit-compatible task expansion while preserving Ralph's stricter no-work guardrails.
- **IV. Progress Persistence** — PASS. Accepted task expansion still requires coordinated state persistence; failed/no-work attempts still leave task state unchanged.
- **V. Agent Agnosticism** — PASS. All decisions are file/history based.
- **VI. Graceful Termination** — PASS. Iteration limit and failure handling remain unchanged, and spurious invalid-work-unit termination is removed only for genuine completed progress.

**Post-design gate result: PASS. No unresolved clarifications.**
