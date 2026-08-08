# Phase 0 Research: Reconcile Partial User-Story Progress With Commit Validation

**Feature**: 004-partial-story-commit | **Date**: 2026-08-08

This feature has no external technology unknowns (no new languages, frameworks,
or dependencies). The "research" here resolves the **design decision** that the
spec left open and confirms the exact behavior of the existing orchestrator so
the fix does not over-reach.

## Decision 1: Reconciliation direction — commit each validated subset (option 1)

- **Decision**: Adopt issue option 1. A validated task or task subset completed
  during an iteration **is** the work unit and is committed in one coordinated
  commit (substantive changes + `tasks.md` + `progress.md` + `ralph-memory.md`).
  The loop then continues with the next incomplete task of the same story in a
  later iteration. Drop the current instruction that a partial result may mark
  tasks complete but "leave those state changes uncommitted."
- **Rationale**:
  - The orchestrator already implements option 1 (see Decision 2), so aligning
    the instructions is the smallest change that removes the contradiction.
  - It never strands validated work in a dirty worktree (spec SC-003, FR-003),
    preserving resumability/auditability (Constitution IV).
  - Constitution II already sanctions a "task group" as a legal work unit, so no
    governance amendment is needed.
- **Alternatives considered**:
  - *Option 2 — keep partial progress uncommitted and teach the orchestrator to
    accept a reduced incomplete count with unchanged `HEAD`.* Rejected: it
    permanently legalizes a dirty worktree carrying completed-task state across
    process boundaries, weakening the durable-state guarantee, and it requires
    deeper orchestrator changes plus a resume mechanism that avoids re-selecting
    completed tasks. Higher risk, worse invariants.
  - *Require the whole story per iteration (status quo).* Rejected: this is the
    defect — large stories cannot span iterations.

## Decision 2: Exact current orchestrator behavior (confirmed by reading source)

- **Decision**: Treat the orchestrator's existing acceptance rules as the
  reference contract; make only comment/message clarifications, not a logic
  rewrite.
- **Findings** (`validate_iteration_commit_history`,
  `scripts/bash/ralph-loop.sh` ~L795–913; PowerShell twin
  `scripts/powershell/ralph-loop.ps1` ~L785–933):
  - **Unchanged `HEAD` + reduced incomplete count** → `coordinated-commit-invalid`
    ("completed task state was not included in a new work-unit commit"). Under
    option 1 this is genuinely invalid (the agent should have committed), so the
    rule is **kept**.
  - **Unchanged `HEAD` + changed task state without count reduction** →
    `failed-iteration-task-state`. Kept.
  - **Advanced `HEAD`**: each new commit is inspected and must (a) include all
    three coordinated artifacts, (b) be non-bookkeeping-only — either touch a
    substantive path or reduce that commit's incomplete count, and (c) satisfy
    the configured commit-subject policy. A **partial-story** coordinated commit
    passes: the validator never requires the story to be fully complete.
  - **Advanced `HEAD` with `agent_exit != 0` or non-decreasing count** →
    `failed-iteration-advanced-head`. Kept.
- **Rationale**: The validator is already per-commit and story-agnostic, so a
  story that spans multiple iterations (one coordinated commit each) is already
  accepted. The bug is confined to the instructions telling the agent to produce
  a state the validator rejects.
- **Alternatives considered**: Rewriting the validator to key off "story
  complete" — rejected as unnecessary and higher-risk.

## Decision 3: Where the "generated skill" is edited

- **Decision**: Edit `commands/iterate.md` only; do not hand-edit any
  `.agents/skills/speckit-ralph-iterate/SKILL.md` in this repo.
- **Rationale**: This repository is the extension **source**. `extension.yml`
  registers `speckit.ralph.iterate` → `commands/iterate.md`. The generated skill
  the issue references is produced downstream when the extension is installed
  into a project, from the command file. Keeping the single source correct keeps
  command and generated skill synchronized (issue acceptance criterion).
- **Alternatives considered**: Maintaining a duplicate skill file in-repo —
  rejected (no such source file exists; would drift).

## Decision 4: Regression coverage strategy

- **Decision**: Extend the existing harnesses with fixtures that exercise, on
  **both** platforms:
  1. Partial-story iteration that **commits** a validated subset (advanced
     `HEAD`, reduced count) → **accepted**; next iteration selects the next
     incomplete task.
  2. Partial-story state with **unchanged `HEAD`** + reduced count →
     **rejected** with `coordinated-commit-invalid` (guards the policy).
  3. A multi-task story completed across **two** coordinated commits → loop does
     not spuriously fail.
- **Rationale**: Directly maps to spec SC-001, SC-002, SC-006 and the issue's
  "unchanged and advanced `HEAD`" requirement; reuses proven harness scaffolding
  for parity.
- **Alternatives considered**: A new bespoke test file — rejected; the existing
  harnesses already model iteration snapshots and are the parity anchor.

## Open Questions

None. All spec assumptions are confirmed against source; no `NEEDS
CLARIFICATION` remains.
