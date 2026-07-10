<!--
  ============================================================================
  SYNC IMPACT REPORT
  ============================================================================
  Version change: 1.0.0 → 2.0.0

  Modified principles:
    - II. Context Isolation — ralph-memory.md is now the primary durable
      handoff; progress.md is audit-only optional context
    - IV. Progress Persistence — coordinated task/memory/audit persistence,
      failed-attempt retention, and no bookkeeping-only commits
    - VI. Graceful Termination — clean working tree, canonical terminal
      handoff, and read-only failure validation are required for success

  Added sections: None

  Removed sections: None (initial version)

  Propagation review:
    ✅ .specify/templates/plan-template.md - Constitution Check remains compatible
    ✅ .specify/templates/spec-template.md - no durable-state guidance to change
    ✅ .specify/templates/tasks-template.md - phase/task structure remains compatible
    ⚠ commands/iterate.md - update in T011, T016, and T022
    ⚠ commands/run.md - update in T028
    ⚠ scripts/bash/ralph-loop.sh - update in T009, T017, and T023
    ⚠ scripts/powershell/ralph-loop.ps1 - update in T010, T018, and T024
    ⚠ README.md - update in T026

  Follow-up TODOs: Complete the active-guidance propagation tasks above and
  close the review in T033. Historical specs/001 artifacts remain unchanged.
  ============================================================================
-->

# Spec Kit Ralph Extension Constitution

## Core Principles

### I. Extension-First Architecture

All functionality MUST be packaged as a valid spec-kit extension
following the extension manifest schema (`extension.yml`). The
extension MUST NOT modify or monkey-patch spec-kit core internals.

- Commands MUST follow the `speckit.ralph.{command}` naming pattern
  as defined by the extension API (`^speckit\.[a-z0-9-]+\.[a-z0-9-]+$`).
- The extension manifest MUST declare all provided commands, hooks,
  configuration templates, and dependency requirements.
- Scripts (PowerShell and Bash) MUST be self-contained within the
  extension directory and referenced via the manifest or command
  frontmatter.
- Configuration MUST use the extension config system
  (`.specify/extensions/ralph/`) rather than ad-hoc file locations.

**Rationale**: Spec-kit extensions are the sanctioned integration
point. Bypassing the extension API creates fragile coupling to core
internals that breaks on upstream updates and prevents catalog
distribution.

### II. Context Isolation (NON-NEGOTIABLE)

Each ralph loop iteration MUST spawn a completely fresh agent
context. No iteration may inherit in-memory state from a previous
iteration.

- The orchestrator script MUST invoke the agent CLI as a new
  process per iteration, never reuse a running session.
- Inter-iteration knowledge transfer MUST occur exclusively through
  on-disk artifacts: `ralph-memory.md` as the primary durable knowledge
  source, `tasks.md` checkbox state, committed source files, and
  `progress.md` only as optional recent audit context.
- The orchestrator MUST initialize a missing `ralph-memory.md` from the
  extension's canonical shared template and validate it without mutation
  before any fresh iteration selects work.
- Each iteration MUST read `ralph-memory.md` before `tasks.md` and other
  design artifacts. It MUST NOT treat the chronological progress log as
  the primary memory bridge.
- A single iteration MUST complete at most one work unit (one
  phase, one user story, or one task group) to prevent context
  degradation.
- The agent prompt for each iteration MUST instruct the agent to
  read disk-persisted context rather than assume prior knowledge.

**Rationale**: Context isolation is the defining property of the
ralph loop methodology. Without it, agent context windows fill with
stale or conflicting information, causing implementation quality to
degrade over successive iterations.

### III. Spec-Kit Compatibility

The extension MUST maintain backward compatibility with the spec-kit
extension API and MUST NOT require users to modify their spec-kit
installation.

- The `requires.speckit_version` field MUST specify the minimum
  supported spec-kit version using semantic version specifiers.
- All commands, hooks, and config schemas MUST conform to the
  extension API reference (schema version 1.0).
- The extension MUST work with projects initialized by any
  supported `specify init` invocation without additional setup
  beyond `specify extension add`.
- Breaking changes to the extension's own API MUST follow semantic
  versioning: MAJOR for incompatible changes, MINOR for additive
  features, PATCH for fixes.

**Rationale**: Users adopt extensions expecting drop-in
functionality. Breaking the spec-kit contract or requiring manual
patching undermines trust and blocks catalog distribution.

### IV. Progress Persistence

All iteration state MUST be persisted to disk. Durable knowledge,
task completion, and chronological audit have separate authoritative
artifacts; no state that would be lost on process termination is
acceptable.

- Task completion MUST be tracked via `tasks.md` checkbox state
  (`[ ]` → `[x]`). No separate tracking database or file is
  permitted for task status.
- Iteration history MUST be appended to
  `specs/{feature}/progress.md` after each iteration with:
  timestamp, work unit attempted, tasks completed, files changed,
  and learnings discovered.
- Durable codebase patterns, decisions, gotchas, reusable commands,
  failed approaches, and the current handoff MUST be maintained in
  `specs/{feature}/ralph-memory.md` using the canonical section contract.
- Before committing a completed work unit, the agent MUST update
  `tasks.md`, compact/update `ralph-memory.md`, and append `progress.md`,
  then include those state changes with substantive implementation work
  in the same commit.
- A failed or no-work iteration MAY update memory and append progress,
  but MUST leave tasks and `HEAD` unchanged. Ralph MUST NOT create a
  commit containing only `tasks.md`, `progress.md`, or `ralph-memory.md`.

**Rationale**: Separate, coordinated state preserves resumability and
auditability without forcing every fresh context to consume an
unbounded historical log or allowing bookkeeping-only history.

### V. Agent Agnosticism

The loop orchestration layer MUST decouple from any specific AI
agent CLI to enable future multi-agent support.

- The orchestrator MUST accept the agent CLI command as a
  configurable parameter rather than hardcoding a specific binary.
- Agent-specific invocation flags (e.g., `--agent`, `--model`,
  `--allow-all-tools`) MUST be configurable, not embedded in
  business logic.
- The completion detection mechanism (`<promise>COMPLETE</promise>`)
  MUST be agent-agnostic—it is detected in stdout regardless of
  which agent produced it.
- Initial release MAY support only GitHub Copilot CLI, but the
  architecture MUST NOT preclude adding Claude, Gemini, or other
  CLI-based agents without major refactoring.

**Rationale**: The AI tooling landscape evolves rapidly. Tight
coupling to one agent CLI creates vendor lock-in and limits adoption
by teams using different tools.

### VI. Graceful Termination

The ralph loop MUST handle all termination paths cleanly, preserving
progress and providing actionable status information.

- **Completion**: The completion signal or zero remaining tasks creates
  a completion candidate; neither is sufficient by itself. Exit code 0
  requires a successful agent result (when applicable), all tasks
  complete, valid canonical memory, `Current Handoff` containing only
  `Feature complete; no handoff required.`, valid commit postconditions,
  and an empty successful `git status --short` result.
- **Inconsistent or dirty completion**: The loop MUST exit non-zero
  immediately, report every applicable validation defect and dirty path,
  and MUST NOT launch a cleanup iteration, amend a commit, rewrite
  history, or create a hidden recovery commit.
- **Iteration limit**: When `MaxIterations` is reached with tasks
  remaining, the loop MUST exit with a non-zero code and a summary
  of completed vs. remaining tasks.
- **User interruption** (Ctrl+C): The loop MUST catch the signal,
  preserve all progress written to disk, and exit with code 130.
- **Consecutive failures**: After 3 consecutive iteration failures
  (non-zero exit from agent CLI), the loop MUST terminate with an
  error summary rather than waste resources.
- Every termination path MUST produce a summary block reporting:
  iterations run, tasks completed, tasks remaining, and final
  status.

**Rationale**: Autonomous loops that fail silently or lose progress
erode user trust. Predictable termination behavior enables
integration into CI/CD pipelines and unattended workflows.

## Extension Compliance

All changes MUST satisfy these gates before merge:

1. **Manifest Gate**: `extension.yml` MUST validate against the
   spec-kit extension schema (version 1.0). All commands MUST
   resolve to existing command files.
2. **Script Gate**: Both PowerShell (`*.ps1`) and Bash (`*.sh`)
   variants of orchestrator scripts MUST exist and produce
   identical behavior for cross-platform support.
3. **Integration Gate**: The extension MUST install cleanly via
   `specify extension add --dev` and all provided commands MUST
   execute without error on a sample project with completed
   `tasks.md`.
4. **Documentation Gate**: README, command descriptions, and
   configuration templates MUST be updated for any user-facing
   change.
5. **Compatibility Gate**: The extension MUST not break when
   installed alongside other spec-kit extensions.

## Development Workflow

The Spec-Driven Development workflow governs all changes:

1. **Specification Phase**: Requirements captured in spec documents
   with acceptance criteria and user stories.
2. **Planning Phase**: Constitution Check validates alignment with
   the six core principles before design proceeds.
3. **Task Phase**: Work items link to spec requirements, organized
   by user story for independent implementation.
4. **Implementation Phase**: Test-first development where applicable;
   ralph loop self-hosting is encouraged (use the extension to build
   the extension).
5. **Review Phase**: PRs verified against specification, constitution
   compliance, and cross-platform script parity.

## Governance

This constitution is the authoritative source for project standards:

- **Supremacy**: Constitution principles supersede conflicting
  practices, preferences, or inherited defaults from the parent
  spec-kit project.
- **Amendments**: Changes require documented rationale, version
  increment (semantic versioning), and propagation check across
  templates.
- **Compliance**: All pull requests MUST verify adherence to
  applicable principles. Reviewers MUST reference specific
  principle numbers (I–VI) when flagging violations.
- **Exceptions**: Deviations MUST be documented with justification
  and a time-boxed resolution plan in the PR description.
- **Review Cadence**: Constitution is reviewed when the spec-kit
  extension API changes or when a new major version is released.

**Version**: 2.0.0 | **Ratified**: 2026-03-06 | **Last Amended**: 2026-07-10
