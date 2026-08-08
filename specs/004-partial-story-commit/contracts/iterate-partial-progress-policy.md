# Contract: Iterate Partial-Progress Policy

**Surface**: `commands/iterate.md` (and the downstream-generated
`speckit-ralph-iterate` skill produced from it).

**Consumers**: The iteration agent; must match the orchestrator contract exactly.

This contract defines the behavior the iterate instructions MUST specify. It is
verified by human review (policy wording) and, indirectly, by the orchestrator
regression tests that reject any deviation.

## C1 — Work-unit definition

The instructions MUST define the committable work unit as **one phase, one user
story, or one validated task group within a single user story**. They MUST NOT
require an entire user story to be complete before committing.

## C2 — Validated partial completion is committed, not deferred

When an iteration completes and validates a subset of a story's tasks, the
instructions MUST direct the agent to, in one coordinated commit:

1. Mark only the validated tasks `[x]` in `tasks.md`.
2. Compact `ralph-memory.md` and set `Current Handoff` to the next step (or the
   terminal handoff line when no task remains anywhere).
3. Append a `progress.md` record with `**Commit**: This work-unit commit`.
4. Stage substantive changes together with `tasks.md`, `ralph-memory.md`, and
   `progress.md`, then create exactly one commit using the resolved commit
   subject policy.

The instructions MUST NOT tell the agent to mark tasks complete while leaving
those changes uncommitted for a later commit.

## C3 — No-work and failure paths

When the iteration validates nothing (no-work) or fails:

- Do not create a commit; leave `HEAD` unchanged.
- Leave `tasks.md` byte-for-byte unchanged (no task marked `[x]`).
- Record failure knowledge in `ralph-memory.md` / `progress.md` with `**Commit**:
  No commit - no completed work unit`.

## C4 — Preserved invariants

- At most one user story per iteration; never start a second story (unchanged).
- Never create a bookkeeping-only commit when no task was completed (unchanged).
- No amend / reset / rebase / hidden recovery commit (unchanged; Principle VI).
- The `commit-subject-invalid` narrow self-repair allowance is unchanged.

## Acceptance (maps to spec)

| Contract clause | Spec requirement |
|-----------------|------------------|
| C1 | FR-001, FR-002 |
| C2 | FR-003, FR-004 |
| C3 | FR-005, FR-006 |
| C4 | FR-008; Principles II, IV, VI |
