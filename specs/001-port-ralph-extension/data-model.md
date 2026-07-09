# Data Model: Port Ralph Loop to Spec-Kit Extension

## Entity Relationship Overview

```
ExtensionManifest ──provides──→ Command (run, iterate)
       │                            │
       ├──provides──→ Hook          │
       │              (after_tasks) │
       ├──provides──→ Config        │
       │              Template      │
       │                            │
       └──requires──→ speckit       │
                      (>=0.8.5)     │
                                    │
RalphSession ──────────────────invokes──→ Iteration ──uses──→ AgentProfile
       │                                      │
       ├── tracks ──→ ProgressLog             │
       │              (progress.md)           │
       ├── carries ─→ RalphMemory             │
       │              (ralph-memory.md)       │
       ├── reads  ──→ TaskFile                │
       │              (tasks.md)         marks complete
       │                                      │
       └── uses   ──→ ExtensionConfig         │
                      (ralph-config.yml)      ▼
                                          TaskFile
                                          (tasks.md)
```

---

## Entities

### 1. Extension Manifest

**File**: `extension.yml`
**Purpose**: Declares the extension identity, commands, hooks, config, and compatibility requirements per spec-kit schema v1.0.

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | string | yes | Always `"1.0"` |
| `extension.id` | string | yes | `"ralph"` — pattern: `^[a-z0-9-]+$` |
| `extension.name` | string | yes | `"Ralph Loop"` |
| `extension.version` | string | yes | Semantic version (e.g., `"1.0.0"`) |
| `extension.description` | string | yes | `"Autonomous implementation loop using AI agent CLI"` |
| `extension.author` | string | yes | Extension author |
| `extension.repository` | string | yes | GitHub repo URL |
| `extension.license` | string | yes | `"MIT"` |
| `requires.speckit_version` | string | yes | `">=0.8.5"` |
| `requires.tools[0]` | object | yes | `{name: "copilot", required: true}` |
| `provides.commands` | array | yes | Two commands: `speckit.ralph.run`, `speckit.ralph.iterate` |
| `provides.config` | array | yes | One config: `ralph-config.yml` |
| `hooks.after_tasks` | object | no | Optional prompt to run ralph after task generation |
| `tags` | array | no | `["implementation", "automation", "loop", "copilot"]` |
| `defaults` | object | no | Default config values |

**Validation Rules**:
- `extension.id` matches `^[a-z0-9-]+$`
- `extension.version` is semantic version `X.Y.Z`
- All command names match `^speckit\.[a-z0-9-]+\.[a-z0-9-]+$`
- All command `file` paths resolve to existing files
- `requires.speckit_version` is valid version specifier

---

### 2. Ralph Session

**Concept**: A single execution of the ralph loop from start to termination. Not persisted as a file — exists as runtime state within the orchestrator script.

| Field | Type | Description |
|-------|------|-------------|
| `feature_name` | string | Feature directory name (e.g., `"001-port-ralph-extension"`) |
| `tasks_path` | path | Absolute path to `tasks.md` |
| `spec_dir` | path | Absolute path to feature spec directory |
| `max_iterations` | int | Maximum iterations (default: 10) |
| `model` | string | AI model name (default: `"claude-sonnet-4.6"`) |
| `iteration_count` | int | Number of iterations executed (mutable, starts at 0) |
| `consecutive_failures` | int | Consecutive failed iterations (mutable, resets on success) |
| `initial_task_count` | int | Incomplete tasks at session start |
| `final_status` | enum | One of: `completed`, `interrupted`, `iteration-limit-reached`, `failed` |
| `exit_code` | int | 0 (completed), 1 (limit/failure), 130 (interrupted) |

**State Transitions**:
```
RUNNING ──all tasks done──→ COMPLETED (exit 0)
   │
   ├──agent <promise>COMPLETE──→ COMPLETED (exit 0)
   │
   ├──max iterations──→ ITERATION_LIMIT_REACHED (exit 1)
   │
   ├──3 consecutive failures──→ FAILED (exit 1)
   │
   └──Ctrl+C──→ INTERRUPTED (exit 130)
```

---

### 3. Iteration

**Concept**: One invocation of the agent CLI within a session. Runtime state tracked by the orchestrator script; outcomes recorded in `progress.md` and durable discoveries maintained in `ralph-memory.md` by the agent.

| Field | Type | Description |
|-------|------|-------------|
| `number` | int | 1-indexed iteration number |
| `status` | enum | `running`, `success`, `failure` |
| `work_unit` | string | Title of the work unit attempted (phase/story/task group) |
| `exit_code` | int | Agent CLI exit code (0 = success) |
| `completion_signal` | bool | Whether agent output contained `<promise>COMPLETE</promise>` |
| `tasks_completed` | list | Task IDs marked `[x]` during this iteration |
| `files_changed` | list | File paths created/modified/deleted |
| `learnings` | list | Concise iteration-specific notes |

**Invariants**:
- At most one work unit per iteration (scope constraint)
- Commit only when all tasks in work unit are complete
- Progress entry appended after every iteration (success or failure)
- Durable implementation discoveries updated in `ralph-memory.md` before exit

---

### 4. Progress Log

**File**: `specs/{feature}/progress.md`
**Purpose**: Append-only markdown audit log of iteration history. Created by the orchestrator on first run and appended by the agent during iteration.

**Structure**:
```markdown
# Ralph Progress Log

Feature: {feature_name}
Started: {timestamp}

---

## Iteration 1 - {YYYY-MM-DD HH:MM}
**Work Unit**: {title}
**Tasks Completed**:
- [x] T001: description
**Tasks Remaining in Work Unit**: N or "None - work unit complete"
**Commit**: {hash} or "No commit - partial progress"
**Files Changed**:
- path/to/file.ext (created/modified/deleted)
**Learnings**:
- concise iteration-specific notes; durable discoveries added to ralph-memory.md

---

## Iteration 2 - {YYYY-MM-DD HH:MM}
...
```

**Rules**:
- NEVER overwrite existing entries
- Each iteration section separated by `---`
- Created by `Initialize-ProgressFile` / `initialize_progress_file` in orchestrator if first run

---

### 5. Ralph Memory

**File**: `specs/{feature}/ralph-memory.md`
**Purpose**: Compact durable memory bridge read by each fresh agent context before selecting work. Created by the orchestrator on first run and updated by the agent before exit.

**Structure**:
```markdown
# Ralph Memory

Feature: {feature_name}
Started: {timestamp}

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

**Rules**:
- NEVER overwrite existing memory
- Preserve the fixed section headings
- Promote reusable findings into `## Codebase Patterns`
- Record failed approaches in `## Do Not Repeat`
- Keep `## Current Handoff` concise and current
- Created by `Initialize-MemoryFile` / `initialize_memory_file` in orchestrator if first run

---

### 6. Extension Configuration

**Template File**: `ralph-config.template.yml`
**Installed Location**: `.specify/extensions/ralph/ralph-config.yml`

| Field | Type | Default | Description |
|-------|------|---------|-------------|
| `model` | string | `"claude-sonnet-4.6"` | AI model for iterations |
| `max_iterations` | int | `10` | Default max loop iterations |
| `agent_cli` | string | `"copilot"` | Path to agent CLI binary |

**Validation Rules**:
- `model`: Non-empty string
- `max_iterations`: Integer > 0
- `agent_cli`: String (path or binary name)

**Loading Precedence** (lowest → highest):
1. Extension defaults in `extension.yml`
2. Project config (`ralph-config.yml`)
3. Local overrides (`ralph-config.local.yml` — gitignored)
4. Environment variables (`SPECKIT_RALPH_*`)
5. Script CLI parameters (always win)

**Security Constraint**: Config MUST NOT store tokens. Auth exclusively via `GH_TOKEN` / `GITHUB_TOKEN` environment variables. Template includes warning comment.

---

### 7. Registered Iteration Command

**File (extension source)**: `commands/iterate.md`
**Runtime usage**: Invoked by the orchestrator through the configured agent CLI, e.g. `copilot --agent speckit.ralph.iterate`.

**Purpose**: Agent-facing command definition that constrains behavior during each iteration.

| Section | Purpose |
|---------|---------|
| Scope Constraint | AT MOST one work unit per invocation |
| User Input | `$ARGUMENTS` (iteration prompt from orchestrator) |
| Outline (11 steps) | Prerequisites → memory/context → scope → implement → commit → memory/progress |
| Progress Report Format | Standardized markdown template for progress.md entries |
| Stop Conditions | `<promise>COMPLETE</promise>` when all tasks done |
| Quality Gates | Tests must pass, no broken commits |
| Error Handling | Table of condition → expected behavior |

**Relationship to Commands**: `speckit.ralph.run` launches the loop. Each loop iteration invokes `speckit.ralph.iterate` through the configured agent CLI, so the launcher never performs implementation work inline.

---

### 8. Task File

**File**: `specs/{feature}/tasks.md`
**Purpose**: Source of truth for task completion. Not created by the extension — created by `/speckit.tasks`.

| Pattern | Meaning |
|---------|---------|
| `- [ ] T001: description` | Incomplete task |
| `- [x] T001: description` | Completed task |

**Invariants**:
- Checkbox state is the ONLY completion tracking mechanism (FR-006)
- Only the agent (during iteration) modifies checkboxes
- Orchestrator reads checkbox state to detect all-complete condition

---

### 9. Command Files

#### `commands/run.md` (speckit.ralph.run)

| Section | Content |
|---------|---------|
| Frontmatter `description` | Thin launcher for ralph loop orchestration |
| User input | Launcher flags only; free-form implementation text is warned and ignored |
| Body | Prerequisites validation → configuration resolution → platform detection → script launch |

#### `commands/iterate.md` (speckit.ralph.iterate)

| Section | Content |
|---------|---------|
| Frontmatter `description` | Execute single ralph loop iteration |
| Frontmatter `scripts` | References to core check-prerequisites scripts |
| Body | Scope constraint → context loading → work unit identification → implementation → progress tracking → completion signal |
