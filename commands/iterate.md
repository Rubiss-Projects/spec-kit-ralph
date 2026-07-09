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

- If you cannot complete an entire user story, complete as many tasks as you can
- Partial progress is fine -- uncompleted tasks will be handled in subsequent iterations
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
   - Read `FEATURE_DIR/ralph-memory.md` if it exists -- this is Ralph's compact cross-iteration memory bridge
   - Read `FEATURE_DIR/progress.md` if it exists -- use it only as the append-only audit trail and recent history
   - Read `FEATURE_DIR/tasks.md` -- understand task structure and identify next incomplete user story
   - Read `FEATURE_DIR/plan.md` for tech stack, architecture, and file structure
   - **IF EXISTS**: Read `FEATURE_DIR/data-model.md` for entities and relationships
   - **IF EXISTS**: Read `FEATURE_DIR/contracts/` for API specifications
   - **IF EXISTS**: Read `FEATURE_DIR/research.md` for technical decisions and constraints

3. **Identify scope**:
   - Find the FIRST user story section with incomplete tasks (`- [ ]`)
   - Work ONLY on tasks within that single user story
   - Example: If "US-001: Initialize Ralph Command" has incomplete tasks, work only on US-001

4. **Implement tasks**:
   - Complete tasks in dependency order (non-[P] before parallel [P] where noted)
   - Follow TDD when appropriate: write tests first, then implementation
   - Run quality checks after each task (typecheck, lint, test as appropriate)
   - Mark each completed task by changing `[ ]` to `[x]` in tasks.md

5. **Update memory and progress**:
   - Create or update `FEATURE_DIR/ralph-memory.md`
   - Preserve all existing memory sections and useful entries; update sections in place rather than rewriting unrelated history
   - Add durable discoveries to the relevant memory sections before ending the iteration
   - Record failed approaches in `## Do Not Repeat`
   - Promote reusable repo patterns into `## Codebase Patterns`
   - Add known-good commands and required environment variables to `## Reusable Commands`
   - Keep `## Current Handoff` short and current for the next fresh agent context
   - Create or append to `FEATURE_DIR/progress.md`
   - Use the Progress Report Format below for the append-only audit entry

6. **Commit on user story completion**:
   - When ALL tasks in the current user story are complete (`[x]`), create a commit:

     ```sh
     git add -A
     git commit -m "feat(<feature-name>): <user story title>"
     ```

   - Example: `git commit -m "feat(001-ralph-loop-implement): US-001 Initialize Ralph Command"`
   - If only partial progress, NO commit -- let the next iteration continue

## Ralph Memory Format

PRESERVE and UPDATE FEATURE_DIR/ralph-memory.md:

```markdown
# Ralph Memory

Feature: [feature name]
Started: [initial timestamp]

## Codebase Patterns

- Durable repo conventions and APIs discovered across iterations.

## Decisions

- Decision, rationale, and affected files.

## Gotchas

- Unexpected behavior, environment quirks, failing commands, generated-file rules.

## Reusable Commands

- Known-good test/lint/build commands and required environment variables.

## Do Not Repeat

- Failed approaches or paths already ruled out.

## Current Handoff

- Short notes the next fresh agent must know before continuing.
```

## Progress Report Format

APPEND to FEATURE_DIR/progress.md:

```markdown
---
## Iteration [N] - [Current Date/Time]
**User Story**: [US-XXX title or "Partial progress on US-XXX"]
**Tasks Completed**: 
- [x] Task ID: description
- [x] Task ID: description
**Tasks Remaining in Story**: [count] or "None - story complete"
**Commit**: [commit hash if story completed, or "No commit - partial progress"]
**Files Changed**: 
- path/to/file.ext
**Learnings**:
- [concise iteration-specific notes; durable discoveries were added to ralph-memory.md]
---
```

## Stop Conditions

**If ALL tasks in tasks.md are complete** (`[x]`), output the following as the final
line of your response, alone on its own line with no other text or backticks around it:

```text
<promise>COMPLETE</promise>
```

This signals the ralph loop orchestrator to terminate successfully. The orchestrator only
recognizes the token when it stands alone on a line.

**If tasks remain**, end your response normally and DO NOT write the token anywhere in your
response — not even to say you are omitting it. Mentioning `<promise>COMPLETE</promise>` in
prose while tasks remain would falsely terminate the loop. The next iteration will continue.

## Quality Gates

- ALL changes must pass quality checks before marking tasks complete
- DO NOT commit broken code
- DO NOT create bookkeeping-only commits for `progress.md` or `ralph-memory.md`
- Successful completion must leave `git status --short` clean
- Follow existing code patterns (check `## Codebase Patterns` in ralph-memory.md)
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
| Tests fail | Report failure in progress entry, record command/context in ralph-memory.md, do not mark task complete, no commit |
| Cannot complete story | Report partial progress, update Current Handoff in ralph-memory.md, commit only if all completed tasks form coherent unit |
| All tasks done | Commit final story, verify clean worktree, output `<promise>COMPLETE</promise>` |
| Dependencies missing | Note in progress file, add durable setup detail to ralph-memory.md, skip to next available task |
