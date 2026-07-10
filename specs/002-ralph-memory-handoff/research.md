# Research: Durable Ralph Memory Handoff

## Decision 1: Split durable memory from iteration audit

**Decision**: Make `specs/{feature}/ralph-memory.md` the sole durable cross-iteration knowledge source. Keep `progress.md` append-only for chronological audit and optional recent context. New progress files no longer contain a mutable `Codebase Patterns` section; existing progress history is preserved without migration.

**Rationale**: Fresh agents need a compact current knowledge base, while users still need the complete execution trail. Keeping both concerns in one growing file recreates the context-bloat problem identified by Rubiss.

**Alternatives considered**: Expand `progress.md` with structured memory sections; duplicate patterns in both files; migrate historical progress entries into memory. All create two authorities, increase context, or risk altering audit history.

## Decision 2: Use one extension-owned template with deterministic rendering

**Decision**: Add `templates/ralph-memory.md` with `{{FEATURE_NAME}}` and `{{STARTED_AT}}` tokens. Both orchestrators resolve it from their common extension root, replace only those tokens, use a UTC ISO-8601 timestamp, and create a missing feature memory file without overwriting an existing path.

**Rationale**: One shipped template prevents Bash and PowerShell from inventing different Markdown. Deterministic tokens and timestamps make semantic parity testable without a new templating dependency.

**Alternatives considered**: Embed heredocs/here-strings in each script; register memory as extension configuration; place the template under project `.specify/templates/`. These either drift across platforms, misuse configuration, or fail when the extension runs from its installed root.

## Decision 3: Derive validation order from the canonical template and aggregate defects

**Decision**: Runtime helpers extract the canonical H2 sequence from the shared template and validate the target's title, non-empty matching `Feature:` metadata, parseable non-empty `Started:` metadata, exact unique ordered H2 headings, and absence of unresolved template tokens. Missing, duplicate, unexpected, or reordered H2 headings are all reported in one pass. Existing invalid files are never rewritten or partially normalized.

**Rationale**: Template-derived ordering minimizes duplicated structural knowledge. Aggregated diagnostics satisfy the clarified failure contract and reduce fix/retry cycles. Read-only invalid-file handling protects user-authored content and line endings.

**Alternatives considered**: Stop at the first error; automatically normalize malformed files; maintain independent heading lists with no parity test. These reduce diagnostics, risk data loss, or invite drift.

## Decision 4: Prepare and validate memory in the orchestrator before work selection

**Decision**: Add mirrored prepare-memory helpers and invoke them before the initial task decision and before every agent launch. Missing memory is initialized then validated. Invalid memory exits non-zero before any agent process. Already-complete legacy features that gain a new untracked memory file fail the clean completion gate and require an explicit user correction; Ralph does not auto-commit it.

**Rationale**: Orchestrator ownership guarantees all agent modes receive a valid file, including Copilot modes that rely on installed command copies. It also covers initial completion paths that never invoke the iterate command.

**Alternatives considered**: Let `commands/iterate.md` initialize memory; initialize only after tasks are selected; silently commit memory for complete legacy features. These leave bypasses or violate the no-recovery/no-bookkeeping contract.

## Decision 5: Treat a work-unit commit as a coordinated transaction

**Decision**: Reorder `commands/iterate.md`: implement and test; update `tasks.md`; compact/update `ralph-memory.md`; append `progress.md`; then stage and create one substantive work-unit commit. The audit entry uses `**Commit**: This work-unit commit`, a value knowable before commit, instead of a future hash. Partial or failed work creates no commit.

**Rationale**: The current command commits before updating progress, making clean completion impossible and encouraging a second bookkeeping commit. A future commit hash cannot appear inside that same commit without amendment.

**Alternatives considered**: Append the hash after commit; amend the work-unit commit; create a follow-up audit commit; omit state artifacts from the substantive commit. All conflict with the clarified rules.

## Decision 6: Persist failed-attempt knowledge without changing task state or HEAD

**Decision**: When an iteration learns a useful failed approach but completes no work unit, it updates memory, appends a failed-attempt audit entry using `**Commit**: No commit - no completed work unit`, leaves tasks unchanged, and exits without committing. Those working-tree records are consumed by the next fresh iteration and included with a later substantive commit.

**Rationale**: This preserves valuable failure knowledge across fresh contexts without falsely completing tasks or creating bookkeeping-only history.

**Alternatives considered**: Store failure only in process output; update memory but not audit; create a bookkeeping commit. These lose durable context, break audit completeness, or violate FR-013.

## Decision 7: Centralize all success paths behind a read-only completion gate

**Decision**: Initial task-zero, completion-signal, and post-iteration task-zero paths all call one mirrored completion check. Success requires: agent result is not a failure, zero incomplete tasks, valid memory, exactly `Feature complete; no handoff required.` under `Current Handoff`, and successful empty `git -C <repo> status --short --untracked-files=all`. Dirty paths and all other inconsistencies are reported; the loop exits non-zero immediately and launches no further iteration.

**Rationale**: Current scripts bypass repository validation in three separate success branches. One gate provides identical behavior and prevents signals from overriding real task or repository state.

**Alternatives considered**: Trust the completion token; check only task count; run a cleanup iteration; auto-amend or create recovery commits. These can report false success or mutate history invisibly.

## Decision 8: Detect commit-protocol violations without rewriting history

**Decision**: Snapshot task state and `HEAD` before an agent invocation. Afterward, read-only validation reports any new commit that contains only bookkeeping paths or omits the coordinated state required for a completed work unit. A violation fails the run but is never reset, amended, rebased, or repaired automatically.

**Rationale**: Agent instructions are the primary prevention mechanism, but postcondition checks make violations visible and keep success criteria auditable. Read-only detection honors the orchestrator's authority boundary.

**Alternatives considered**: Prompt-only enforcement; prevent the agent from using Git; automatically repair invalid commits. Prompt-only checks are weak, removing Git breaks Ralph's workflow, and repair violates the approved history rules.

## Decision 9: Amend the constitution as a breaking governance release

**Decision**: Amend Principles II, IV, and VI and bump the constitution from 1.0.0 to 2.0.0. Update the sync impact report and review active templates and guidance for propagation. Record the extension feature under CHANGELOG `Unreleased`; do not manually bump `extension.yml`, because the repository release workflow owns release version changes and the expected next feature release is 1.3.0.

**Rationale**: The old principles explicitly exclude the new memory source and promise success solely from task completion. Those semantics are incompatible, not merely additive. The manifest has no new command, hook, config, dependency, or schema field.

**Alternatives considered**: Constitution 1.1.0; time-boxed exception; manual extension version bump. These understate the governance break, contradict the accepted clarification, or bypass the established release process.

## Decision 10: Test behavior through mirrored helpers and temporary Git repositories

**Decision**: Extend both dependency-free regression suites with helper tests, full-script fake-agent scenarios, byte-preservation checks, Git history assertions, static command/documentation checks, and semantic cross-platform parity fixtures. Preserve the existing 79 Bash and 69 PowerShell tests.

**Rationale**: Helper extraction is fast but cannot prove agent non-invocation, exit codes, dirty-path diagnostics, commit contents, or unchanged history. Temporary repositories exercise those observable contracts without network access or real agent calls.

**Alternatives considered**: Manual-only validation; helper-only tests; adding a third-party test framework or Markdown parser. These provide weaker evidence or unnecessary dependencies.
