# Phase 1 Data Model: Reconcile Partial User-Story Progress With Commit Validation

**Feature**: 004-partial-story-commit | **Date**: 2026-08-08

This feature manipulates behavioral/state concepts, not persisted database
records. The "entities" below are the conceptual objects the policy and the
orchestrator reason about. They are defined by on-disk artifacts and Git state.

## Entity: Iteration Snapshot

Represents the observable state captured before and after one iteration; the
orchestrator diffs the two to classify the outcome.

| Field | Meaning | Source |
|-------|---------|--------|
| `head` | Current Git `HEAD` commit id | `git rev-parse HEAD` |
| `task_state` | Full checkbox state of `tasks.md` | `tasks.md` contents |
| `incomplete_count` | Number of `- [ ]` tasks remaining | derived from `tasks.md` |
| `agent_exit` | Exit status of the iteration's agent process | orchestrator |

**Derived transition** (before → after): `(head_changed, count_delta,
task_state_changed, agent_exit)` selects the Iteration Outcome below.

## Entity: Work Unit

The amount of validated progress an iteration may complete and commit together.

- **Definition (post-fix, canonical across command + skill + orchestrator)**:
  one phase, one user story, **or one validated task group** within a single
  user story.
- **Invariant**: a Work Unit never spans two user stories (FR-008).
- **Invariant**: a Work Unit that changes task completion MUST be committed in
  the same iteration that completes it (no deferral) (FR-003).

## Entity: Coordinated Record Set

The file group that must move together in one accepted commit.

- **Members**: substantive implementation path(s) **and** `tasks.md` **and**
  `progress.md` **and** `ralph-memory.md`.
- **Validity rule**: a commit is valid only if it contains all three coordinated
  artifacts AND is not bookkeeping-only (it either touches a substantive path or
  reduces that commit's incomplete count). (FR-003, FR-006)

## Entity: Iteration Outcome

Classification that drives loop continuation, what gets recorded, and the
reported status. Derived from the Iteration Snapshot transition.

| Outcome | Precondition | Task state | Commit | Loop action | Reported status |
|---------|--------------|-----------|--------|-------------|-----------------|
| Completed progress (full or partial) | validated subset done, `agent_exit==0` | reduced `incomplete_count` | one coordinated commit; `HEAD` advances | continue (or complete if none remain) | success / progress |
| No-work | nothing validated | unchanged | none; `HEAD` unchanged | continue or terminate on limits | no-work (not FAILED) |
| Failure | work attempted but not validated / `agent_exit!=0` | unchanged | none | retry/terminate per Principle VI | FAILED |

**Illegal states the orchestrator rejects** (unchanged from today, kept as
guardrails):

| Illegal state | Diagnostic |
|---------------|-----------|
| `HEAD` unchanged AND `incomplete_count` reduced | `coordinated-commit-invalid: completed task state was not included in a new work-unit commit` |
| `HEAD` unchanged AND `task_state` changed without count reduction | `failed-iteration-task-state` |
| `HEAD` advanced AND (`agent_exit!=0` OR count not reduced) | `failed-iteration-advanced-head` |
| Commit missing any coordinated artifact | `coordinated-commit-invalid: commit <id> must include tasks.md, progress.md, and ralph-memory.md` |
| Commit is bookkeeping-only (no substantive path, count not reduced) | `bookkeeping-only: commit <id> …` |

## State Transitions (per user story across iterations)

```text
story: [ ][ ][ ]  --iter A: complete T1, coordinated commit-->  [x][ ][ ]   (Completed partial)
                  --iter B: complete T2, coordinated commit-->  [x][x][ ]   (Completed partial)
                  --iter C: complete T3, coordinated commit-->  [x][x][x]   (Story done)
```

Each arrow advances `HEAD` by exactly one coordinated commit that reduces
`incomplete_count`. No arrow leaves completed-task state uncommitted. The "no
second user story per iteration" invariant holds on every arrow.

## Validation Rules Cross-Reference

- FR-001/FR-002/FR-007 → the multi-iteration transition sequence above.
- FR-003/FR-006 → Coordinated Record Set validity rule.
- FR-004 → Iteration Outcome table (partial completion → success, not FAILED).
- FR-005 → Failure row leaves task state unchanged.
- FR-009/FR-010/FR-011 → Illegal-states table enforced identically by both
  orchestrator scripts and described identically by command + generated skill.
