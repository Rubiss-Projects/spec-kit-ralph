# Implementation Plan: Reconcile Partial User-Story Progress With Commit Validation

**Branch**: `004-partial-story-commit` | **Date**: 2026-08-08 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/004-partial-story-commit/spec.md`

**Note**: This template is filled in by the `/speckit-plan` command; its definition describes the execution workflow.

## Summary

Ralph's iterate instructions and its Bash/PowerShell orchestrator disagree on
what a "work unit" is. `commands/iterate.md` commits only when an **entire user
story** is complete, and explicitly tells the agent that a validated partial
result "may mark only its completed tasks" and "leave those state changes
uncommitted." The orchestrator (`validate_iteration_commit_history` in
`scripts/bash/ralph-loop.sh` and its PowerShell twin) rejects exactly that
state: when `HEAD` is unchanged but the incomplete-task count dropped, it emits
`coordinated-commit-invalid`. A validated iteration therefore terminates the
loop with `Status: FAILED`.

Technical approach: adopt the issue's recommended **option 1** — treat the
validated task (or task subset) completed in an iteration as the committed work
unit. The orchestrator **already** enforces option 1 (it accepts a coordinated
commit that reduces the incomplete count and advances `HEAD`, and it rightly
rejects a reduced count with an unchanged `HEAD`). The reconciliation is
therefore primarily a **documentation/behavioral** fix in `commands/iterate.md`
(and its downstream-generated skill, which is produced from that command),
plus tightened orchestrator comments/messages, new regression coverage on both
platforms, and updated user docs. The constitution already permits a "task
group" as a work unit (Principle II), so **no constitution amendment is
required**.

## Technical Context

**Language/Version**: Bash (macOS `bash` 3.2+ compatible, as used across
existing `scripts/bash/*.sh`) and PowerShell (5.1+/7+, as used across
`scripts/powershell/*.ps1`); command specs authored in Markdown.

**Primary Dependencies**: `git` CLI (history/task-state inspection); the
spec-kit extension API (`extension.yml` schema 1.0). No third-party runtime
libraries.

**Storage**: On-disk artifacts only — `tasks.md` (checkbox state), `progress.md`
(audit log), `ralph-memory.md` (durable memory). No database.

**Testing**: Existing custom regression harnesses
`tests/regression/bash/test-ralph-loop.sh` and
`tests/regression/powershell/Test-RalphLoop.ps1`.

**Target Platform**: Cross-platform developer/CI environments running the Ralph
loop under either shell.

**Project Type**: Spec-kit extension — orchestration scripts + Markdown command
definitions (not an application). Single-project layout.

**Performance Goals**: N/A — correctness feature. Commit-history validation
remains O(commits-per-iteration) and read-only; no measurable perf change.

**Constraints**: Bash/PowerShell behavioral parity (Constitution Script Gate);
read-only validation (no cleanup/amend/rewrite — Principle VI); no
bookkeeping-only commits (Principle IV); one work unit per iteration
(Principle II); the iterate command and generated skill must stay synchronized.

**Scale/Scope**: Small, surgical change. Edits concentrated in one command spec,
two orchestrator scripts (comments/messages, minimal logic), two regression
harnesses, README, and CHANGELOG.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluated against `.specify/memory/constitution.md` v2.1.0:

- **I. Extension-First Architecture** — PASS. Changes stay within the extension
  layout (`commands/`, `scripts/`, `tests/`); no spec-kit core modification.
- **II. Context Isolation** — PASS / reinforced. The fix defines the work unit as
  a validated task group, explicitly allowed by "one phase, one user story, or
  one task group." The "no second user story per iteration" rule is preserved
  (FR-008).
- **III. Spec-Kit Compatibility** — PASS. No API/schema change; command frontmatter
  and manifest untouched in shape.
- **IV. Progress Persistence** — PASS / central to the fix. Every accepted unit
  bundles `tasks.md` + `ralph-memory.md` + `progress.md` with substantive work in
  one coordinated commit (FR-003); bookkeeping-only commits remain forbidden
  (FR-006).
- **V. Agent Agnosticism** — PASS. No agent-specific coupling introduced.
- **VI. Graceful Termination** — PASS / reinforced. Removing the contradiction
  stops spurious `FAILED` termination of valid iterations (FR-004) without
  introducing cleanup/amend/recovery behavior.

**Gate result: PASS. No violations; Complexity Tracking not required.**

Compliance gates (Extension Compliance section): Manifest Gate unaffected;
**Script Gate** requires Bash+PowerShell parity (addressed via FR-011 + parity
tests); Integration Gate unaffected; **Documentation Gate** requires README/
command-description updates (in scope); Compatibility Gate unaffected.

## Project Structure

### Documentation (this feature)

```text
specs/004-partial-story-commit/
├── plan.md              # This file (/speckit-plan command output)
├── spec.md              # Feature specification
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
│   ├── iterate-partial-progress-policy.md
│   └── orchestrator-commit-validation.md
├── checklists/
│   └── requirements.md  # Spec quality checklist (/speckit-specify)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created here)
```

### Source Code (repository root)

```text
commands/
└── iterate.md                         # Work-unit + partial-progress policy (primary edit)

scripts/
├── bash/
│   └── ralph-loop.sh                  # validate_iteration_commit_history (comments/messages, tests target)
└── powershell/
    └── ralph-loop.ps1                 # PowerShell parity of the above

tests/
└── regression/
    ├── bash/
    │   └── test-ralph-loop.sh         # Add partial-completion cases
    └── powershell/
        └── Test-RalphLoop.ps1         # Add parity partial-completion cases

README.md                              # User-facing partial-progress guidance
CHANGELOG.md                           # Unreleased entry
```

**Structure Decision**: Single-project spec-kit extension layout. The behavioral
contract lives in `commands/iterate.md`; enforcement lives in the two
`scripts/*/ralph-loop.sh|ps1` orchestrators; verification lives in the two
`tests/regression/*` harnesses. The generated skill referenced in the issue
(`.agents/skills/speckit-ralph-iterate/SKILL.md`) is produced downstream from
`commands/iterate.md` on extension install, so editing the command keeps command
and skill synchronized without a separate source file in this repo.

## Complexity Tracking

> No Constitution Check violations. Section intentionally left empty.
