# Ralph Loop

Autonomous implementation loop for [spec-kit](https://github.com/github/spec-kit). Ralph repeatedly spawns a fresh AI agent that reads your `tasks.md`, implements the next work unit, commits the result, and loops until every task is done.

## Prerequisites

| Requirement | Why |
|---|---|
| [spec-kit](https://github.com/github/spec-kit) (`specify` CLI) | Extension host — provides project structure and task management |
| [GitHub Copilot CLI](https://docs.github.com/en/copilot) (`copilot` binary in PATH) | Default agent CLI used to execute each iteration |
| [Git](https://git-scm.com/) | Version control — Ralph commits completed work units automatically |

Your project must be initialized with `specify init` and have a feature branch checked out with a completed `tasks.md`.

## Installation

```bash
specify extension add ralph
```
Or install from repository directly
```bash
specify extension add ralph --from https://github.com/Rubiss-Projects/spec-kit-ralph/archive/refs/tags/v1.0.2.zip
```

Verify the installation:

```bash
specify extension list
# ✓ Ralph Loop (v1.0.2)
#   Autonomous implementation loop using AI agent CLI
#   Commands: 2 | Hooks: 1 | Status: Enabled
```

The installer copies a config template to `.specify/extensions/ralph/ralph-config.yml` and the iterate command to `.github/agents/speckit.ralph.iterate.agent.md`.

## Usage

### Path 1 — Agent Command

Run inside a Copilot chat session:

```
/speckit.ralph.run
```

With options:

```
/speckit.ralph.run --max-iterations 5 --model gpt-5.1
```

The command validates prerequisites, detects the current feature context, and delegates to the platform-appropriate orchestrator script.

### Path 2 — Direct Script Invocation

Run the orchestrator scripts directly from your terminal for debugging or CI use.

**PowerShell (Windows):**

```powershell
.specify/extensions/ralph/scripts/powershell/ralph-loop.ps1 `
  -FeatureName "001-my-feature" `
  -TasksPath "specs/001-my-feature/tasks.md" `
  -SpecDir "specs/001-my-feature" `
  -MaxIterations 10 `
  -Model "claude-sonnet-4.6"
```

**Bash (macOS / Linux):**

```bash
.specify/extensions/ralph/scripts/bash/ralph-loop.sh \
  --feature-name "001-my-feature" \
  --tasks-path "specs/001-my-feature/tasks.md" \
  --spec-dir "specs/001-my-feature" \
  --max-iterations 10 \
  --model "claude-sonnet-4.6"
```

## Configuration

Edit `.specify/extensions/ralph/ralph-config.yml` to customize defaults:

```yaml
# AI model for agent iterations
model: "claude-sonnet-4.6"

# Maximum loop iterations before stopping
max_iterations: 10

# Path or name of the agent CLI binary
agent_cli: "copilot"
```

### Configuration Precedence

Settings are resolved from lowest to highest priority:

| Priority | Source | Example |
|---|---|---|
| 1 (lowest) | Extension defaults | Hardcoded in `extension.yml` |
| 2 | Project config | `.specify/extensions/ralph/ralph-config.yml` |
| 3 | Local overrides | `.specify/extensions/ralph/ralph-config.local.yml` (gitignored) |
| 4 | Environment variables | `SPECKIT_RALPH_MODEL` |
| 5 (highest) | CLI parameters | `--model`, `--max-iterations` |

### Environment Variables

| Variable | Description | Default |
|---|---|---|
| `SPECKIT_RALPH_MODEL` | AI model to use | `claude-sonnet-4.6` |
| `SPECKIT_RALPH_MAX_ITERATIONS` | Maximum iterations before stopping | `10` |
| `SPECKIT_RALPH_AGENT_CLI` | Agent CLI binary name or path | `copilot` |

```bash
export SPECKIT_RALPH_MODEL="gpt-5.1"
export SPECKIT_RALPH_MAX_ITERATIONS="20"
export SPECKIT_RALPH_AGENT_CLI="copilot"
```

> **Note:** Never store authentication tokens in the config file. Use `GH_TOKEN` or `GITHUB_TOKEN` environment variables for authentication.

## How the Loop Works

```
┌─────────────────────────────────────────┐
│           ralph-loop starts             │
│  validate prerequisites, load config    │
└──────────────────┬──────────────────────┘
                   ▼
          ┌────────────────┐
          │ Any tasks left?│──No──▶ exit 0 (COMPLETED)
          └───────┬────────┘
                  │ Yes
                  ▼
  ┌───────────────────────────────┐
  │  Spawn fresh agent process    │
  │  copilot --agent speckit.ralph│
  └──────────────┬────────────────┘
                 ▼
  ┌───────────────────────────────┐
  │  Agent reads tasks.md +       │
  │  progress.md, implements      │
  │  ONE work unit, commits       │
  └──────────────┬────────────────┘
                 ▼
       ┌──────────────────┐
       │ Check termination│
       │   conditions     │
       └────────┬─────────┘
                ▼
        back to "Any tasks left?"
```

### Iteration Cycle

1. The orchestrator spawns a **fresh** `copilot --agent speckit.ralph` process each iteration.
2. The agent reads `tasks.md` to find the first incomplete work unit (phase, user story, or task group).
3. It implements tasks within that single work unit, marks them `[x]` in `tasks.md`, and commits on completion.
4. It appends an iteration entry to `progress.md` with files changed and lessons learned.
5. Control returns to the orchestrator, which checks termination conditions and loops.

### Termination Conditions

| Condition | Exit Code | Meaning |
|---|---|---|
| All tasks in `tasks.md` marked `[x]` | `0` | Success — nothing left to do |
| Agent outputs `<promise>COMPLETE</promise>` | `0` | Agent confirmed all work is done |
| Max iterations reached | `1` | Safety limit — increase `max_iterations` if needed |
| 3 consecutive failures | `1` | Circuit breaker — agent is stuck |
| Ctrl+C | `130` | User interrupted the loop |

## Resuming After Interruption

Ralph is designed to be interrupted and resumed safely. Each iteration is self-contained: tasks are marked `[x]` in `tasks.md` and progress is logged in `progress.md` as work completes.

To resume, simply re-run the command:

```
/speckit.ralph.run
```

Or re-run the script directly. The orchestrator reads the current checkbox state in `tasks.md` and skips completed tasks. The `progress.md` log gives the agent context from prior iterations.

## Extension Structure

```
spec-kit-ralph/
├── extension.yml                  # Extension manifest (schema v1.0)
├── commands/
│   ├── run.md                     # speckit.ralph.run — thin launcher
│   └── iterate.md                 # speckit.ralph.iterate — single iteration
├── scripts/
│   ├── powershell/
│   │   └── ralph-loop.ps1         # PowerShell orchestrator
│   └── bash/
│       └── ralph-loop.sh          # Bash orchestrator
├── agents/
│   └── speckit.ralph.agent.md     # Copilot agent profile
├── ralph-config.template.yml      # Config template
├── README.md
├── CHANGELOG.md
└── LICENSE                        # MIT
```

## License

[MIT](LICENSE) © Rubiss
