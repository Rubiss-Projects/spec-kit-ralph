---
description: "Execute a single Ralph loop iteration - complete one work unit from tasks.md with proper commits and progress tracking"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Scope Constraint

**CRITICAL**: Complete AT MOST ONE user story in this iteration.

- If you cannot complete an entire user story, complete and commit as many of its tasks as you can validate this iteration
- Partial progress is committed as a coordinated work unit each iteration; the remaining tasks in the same story are handled in subsequent iterations
- A completed task may add follow-up tasks to `tasks.md`; this is valid only when at least one previously-open task is also marked `[x]` in the same coordinated commit
- DO NOT start a second user story even if you have time remaining
- This prevents context rot and keeps changes reviewable

## Outline

1. **Setup**: Run the prerequisite check script from repo root and parse FEATURE_DIR and AVAILABLE_DOCS list. All paths must be absolute. For single quotes in args like "I'm Groot", use escape syntax appropriate to your shell.

   ```bash
   .specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
   ```

   ```powershell
   .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
   ```

2. **Read context first**:
   - Read `FEATURE_DIR/ralph-memory.md` FIRST -- it is the primary durable source for codebase patterns, decisions, gotchas, reusable commands, failed approaches, and the current handoff
   - Read `FEATURE_DIR/tasks.md` -- understand task structure and identify next incomplete user story
   - Read `FEATURE_DIR/plan.md` for tech stack, architecture, and file structure
   - **IF EXISTS**: Read `FEATURE_DIR/data-model.md` for entities and relationships
   - **IF EXISTS**: Read `FEATURE_DIR/contracts/` for API specifications
   - **IF EXISTS**: Read `FEATURE_DIR/research.md` for technical decisions and constraints
   - **IF EXISTS**: Read only the recent relevant entries in `FEATURE_DIR/progress.md` for optional audit context; never use it as the primary memory bridge

3. **Identify scope**:
   - Find the FIRST user story section with incomplete tasks (`- [ ]`)
   - Work ONLY on tasks within that single user story
   - Example: If "US-001: Initialize Ralph Command" has incomplete tasks, work only on US-001

4. **Implement and validate tasks**:
   - Complete tasks in dependency order (non-[P] before parallel [P] where noted)
   - Follow TDD when appropriate: write tests first, then implementation
   - Run quality checks after each task (typecheck, lint, test as appropriate)
   - Do not change task state until the corresponding substantive result passes its quality checks

5. **Persist the iteration outcome before any commit**:

   The work unit for this iteration is the validated subset of tasks you actually
   completed — a single task, a task group, or the whole user story. Whenever
   that subset is non-empty, it MUST be committed in this same iteration; never
   mark a task complete and leave that change uncommitted for a later iteration.

   - When you have substantively completed and validated at least one task in the selected user story (a partial subset is a valid work unit; you need not finish the entire story):
     1. Mark exactly the validated tasks by changing `[ ]` to `[x]` in `tasks.md`; leave tasks you did not validate as `[ ]`
     2. Preserve and compact durable discoveries in `ralph-memory.md`; replace `Current Handoff` with only the information needed by the next iteration (for a partial story, point it at the next incomplete task in the same story)
     3. If no task remains anywhere in `tasks.md`, replace the handoff content with exactly `- Feature complete; no handoff required.`
     4. Append the Progress Report below with `**Commit**: This work-unit commit`
     5. Stage substantive files together with `tasks.md`, `ralph-memory.md`, and `progress.md`
   - When the selected work unit fails or produces no validated work:
     - Do not create a commit
     - Leave `HEAD` unchanged
     - Leave `tasks.md` byte-for-byte unchanged — do not mark any task `[x]`
     - Preserve useful failure knowledge in `ralph-memory.md` and append the Progress Report with `**Commit**: No commit - no completed work unit`
     - Leave those memory/audit changes uncommitted so the next substantive work-unit commit includes them

6. **Create one substantive commit only after coordinated persistence**:
   - Before creating the commit, resolve the effective commit policy from `.specify/extensions/ralph/ralph-config.yml` (or `.local.yml` override):
     - If the `commit` block is **absent**, use legacy format (default).
     - If `commit.style` is present but unsupported, **stop immediately** with a clear configuration error — do not create a commit.
     - If `commit.style` is `legacy` (or absent), use: `feat(<feature-name>): <work-unit title>` — preserve the work-unit title exactly as the commit subject payload.
     - If `commit.style` is `conventional`, use: `feat(<scope>): <commit summary>` where `<scope>` defaults to `ralph` when `commit.scope` is not set, and `<commit summary>` is a concise description of the completed change. The work-unit title is preserved separately in the progress/audit log but **must not** appear verbatim as the conventional commit subject payload. Planning labels such as `US-`, `US1`, `Phase`, and task ranges must be omitted from `<commit summary>`.
     - If `commit.issue: auto` is set, infer an issue number from a leading numeric branch prefix (e.g. `069-...` → `#69`) and append ` #<N>` when inference succeeds; omit the suffix silently when no numeric prefix exists.
   - When you have completed and marked (`[x]`) the validated work unit for this iteration — whether that is a single task, a task group, or the whole story — create exactly one commit using the resolved subject:

     ```sh
     git add -A
     git commit -m "<resolved commit subject>"
     ```

   - Legacy example (no config): `git commit -m "feat(001-ralph-loop-implement): US-001 Initialize Ralph Command"`
   - Legacy with issue: `git commit -m "feat(069-ctx-list-filter): US-001 Initialize Ralph Command #69"`
   - Conventional example: `git commit -m "feat(ralph): initialize ralph command"`
   - Conventional with issue: `git commit -m "feat(myapp): add context list filter flag #42"`
   - A completed review or analysis task may commit only `tasks.md`, `ralph-memory.md`, and `progress.md` when those coordinated records are the task's intended result
   - A completed planning or task-expansion work unit may add new unchecked follow-up tasks; make the expansion clear in `progress.md` and `ralph-memory.md`, and remember that remaining tasks may increase while still being bounded by `max_iterations`
   - Never create a state-only commit when no task was completed; retained failure or no-work records must wait for the next completed work unit
   - Never amend or create a follow-up bookkeeping commit to insert a commit hash into the audit log
   - If the orchestrator feeds back only `commit-subject-invalid` defects for the just-created work-unit commit, repair the subject in the current normal iteration; do not treat this as permission for broader cleanup, reset, rebase, hidden recovery commits, or unrelated history edits
   - After committing, leave no bookkeeping change outside the commit

## Progress Report Format

APPEND to FEATURE_DIR/progress.md:

```markdown
---
## Iteration [N] - [YYYY-MM-DD HH:MM]
**Work Unit**: [US-XXX title or failed/partial description]
**Tasks Completed**:
- [x] Task ID: description
**Tasks Remaining in Work Unit**: [count or description]
**Commit**: [This work-unit commit | No commit - no completed work unit]
**Files Changed**:
- path/to/file.ext
**Learnings**:
- [concise audit note; put durable detail in ralph-memory.md]
---
```

Append the new record after every existing byte in `progress.md`. Do not reorganize or rewrite historical entries, including legacy `Codebase Patterns` content.

## Stop Conditions

Output the completion signal only after the final substantive work-unit transaction has
passed every quality check and all of these statements are true:

- Every task in `tasks.md` is complete (`[x]`)
- `ralph-memory.md` is structurally valid
- `Current Handoff` contains exactly one entry and no other content: `- Feature complete; no handoff required.`
- The final coordinated commit includes the completed work plus `tasks.md`, `ralph-memory.md`, and `progress.md`; for review or analysis work, the coordinated records may be the complete intended result
- `git status --short --untracked-files=all` succeeds and emits no lines

Then output the following as the final line of your response, alone on its own line with
no other text or backticks around it:

```text
<promise>COMPLETE</promise>
```

This signals the ralph loop orchestrator to terminate successfully. The orchestrator only
recognizes the token when it stands alone on a line.

If any completion condition fails—including remaining tasks, a failed quality check, an
invalid or stale handoff, an incomplete commit, or a dirty path—end your response normally
and DO NOT write the token anywhere in your response. Do not mention the token in prose.
The orchestrator independently validates the same conditions and will reject a premature
signal rather than allowing it to override a failed iteration or inconsistent state.

## Quality Gates

- ALL changes must pass quality checks before marking tasks complete
- DO NOT commit broken code
- Follow existing code patterns and decisions from `ralph-memory.md`
- Reference plan.md for architecture decisions
- Run tests if they exist before committing

## Code Style

Follow the patterns established in the codebase:

- Check existing files for naming conventions
- Match indentation and formatting styles
- Use the same import/module patterns
- Follow any linting rules configured in the project

## Error Handling

| Condition | Expected Behavior |
| --------- | ----------------- |
| User story unclear | Ask for clarification in progress entry, mark tasks as blocked |
| Tests fail | Report failure, do not mark task complete, no commit |
| Story partially done (at least one task validated) | Mark only the validated tasks `[x]` and commit them as one coordinated work unit this iteration; remaining tasks continue next iteration |
| Validated task expansion | Mark the completed existing task(s) `[x]`, add the new unchecked follow-up tasks, commit the coordinated state, and continue within the configured iteration limit |
| No task could be validated this iteration | Persist useful memory/audit context, leave `tasks.md` and `HEAD` unchanged, and make no commit |
| All tasks done | Persist the terminal handoff, create the coordinated final work-unit commit, verify the clean completion gate, then output the completion signal |
| Dependencies missing | Note in progress file, skip to next available task |
