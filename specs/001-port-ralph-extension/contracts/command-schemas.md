# Contract: Command Schemas

## speckit.ralph.run

**File**: `commands/run.md`
**Purpose**: Thin launcher — validates prerequisites, resolves configuration, delegates to orchestrator script
**Invoked by**: User via `/speckit.ralph.run` in agent session

### Frontmatter

```yaml
---
description: "Run the ralph autonomous implementation loop"
---
```

### Required Behavior (agent instructions)

1. **Parse `$ARGUMENTS` as launcher arguments only**:
   - `--max-iterations N` / `-n N` (default: from config or 10)
   - `--model MODEL` / `-m MODEL` (default: from config or `claude-sonnet-4.6`)
   - `--agent-cli CLI` (default: from config or `copilot`)
   - `--verbose` / `-v` (default: false)
   - Ignore free-form text such as `Implement US1` after warning that Ralph selects work from `tasks.md`
   - Stop with a clear error for unknown flags or malformed flag values
   - MUST NOT implement tasks, edit project files, mark checkboxes, create commits, or run `speckit.ralph.iterate` inline

2. **Validate prerequisites** (all MUST pass):
   | Check | Method | Failure Action |
   |-------|--------|----------------|
   | Copilot CLI installed | `which copilot` or check config `agent_cli` | Print error with install URL, stop |
   | `tasks.md` exists | Find in `specs/{feature}/tasks.md` | Print error, suggest `/speckit.tasks`, stop |
   | Git repository | `git rev-parse --git-dir` | Print error, stop |
   | Feature branch active | `git branch --show-current` | Print error, stop |

3. **Load config**:
   - Read `.specify/extensions/ralph/ralph-config.yml` if exists
   - Apply env overrides (`SPECKIT_RALPH_*`)
   - CLI arguments override all

4. **Launch orchestrator**:
   - Detect platform: PowerShell on Windows, Bash on Unix
   - Locate script under `.specify/extensions/ralph/scripts/`
   - Execute with arguments:
     ```
     # PowerShell
     powershell -ExecutionPolicy Bypass -File {script} -FeatureName {name} -TasksPath {path} -SpecDir {dir} -MaxIterations {n} -Model {model} -AgentCli {agent_cli} [-DetailedOutput]

     # Bash
     bash {script} --feature-name {name} --tasks-path {path} --spec-dir {dir} --max-iterations {n} --model {model} --agent-cli {agent_cli} [--verbose]
     ```

### Exit Behavior

The command exits after the orchestrator is launched. It does not wait for the loop outcome.

| Outcome | Meaning |
|---------|---------|
| Command completes normally | Orchestrator was launched successfully |
| Command fails during validation | Prerequisite check, argument parsing, or launch setup failed |

The orchestrator script reports loop completion, iteration limit, consecutive failures, and Ctrl+C interruption in the visible terminal it owns.

---

## speckit.ralph.iterate

**File**: `commands/iterate.md`
**Purpose**: Define single-iteration agent behavior — complete one work unit from tasks.md
**Invoked by**: Orchestrator via `copilot --agent speckit.ralph.iterate -p "Iteration N"` or equivalent configured agent CLI path

### Frontmatter

```yaml
---
description: "Execute a single ralph loop iteration - complete one work unit from tasks.md"
scripts:
  sh: ../../scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
  ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
---
```

Note: The `../../scripts/` paths are relative to the extension's `commands/` directory. After registration, they resolve to `.specify/scripts/` (core spec-kit scripts).

### Required Behavior (agent instructions)

1. **Setup**: Run prerequisites script, parse feature directory and available docs
2. **Read context**: `progress.md` (patterns), `tasks.md` (task list), `plan.md` (architecture), optionally `data-model.md`, `contracts/`, `research.md`
3. **Identify scope**: Find FIRST incomplete work unit (phase/story/task group). Work ONLY within that scope
4. **Implement tasks**: Complete in dependency order, TDD when appropriate, mark `[x]` in tasks.md
5. **Commit on completion**: If all tasks in work unit complete → `git add -A && git commit -m "feat({feature}): {work unit}"`
6. **Update progress**: Append iteration entry to `progress.md` with format below

### Progress Entry Format

```markdown
---
## Iteration [N] - [YYYY-MM-DD HH:MM]
**Work Unit**: [title]
**Tasks Completed**:
- [x] Task ID: description
**Tasks Remaining in Work Unit**: [count] or "None - work unit complete"
**Commit**: [hash] or "No commit - partial progress"
**Files Changed**:
- path/to/file.ext (created/modified/deleted)
**Learnings**:
- patterns discovered
---
```

### Completion Signal

When ALL tasks in tasks.md are complete (no `- [ ]` remaining), output exactly:

```
<promise>COMPLETE</promise>
```

### Scope Constraint (NON-NEGOTIABLE)

- AT MOST one work unit per invocation
- DO NOT start a second work unit even if time remains
- Partial progress is acceptable — next iteration continues
