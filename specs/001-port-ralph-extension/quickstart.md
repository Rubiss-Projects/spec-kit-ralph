# Quickstart: Ralph Loop Extension

## Prerequisites

- [spec-kit](https://github.com/github/spec-kit) installed (`specify` CLI available)
- Project initialized with `specify init`
- GitHub Copilot CLI installed and authenticated (`copilot` binary in PATH)
- Git repository with a feature branch checked out
- Completed `tasks.md` in the current feature spec

## Install

```bash
# Clone the extension
git clone https://github.com/Rubiss-Projects/spec-kit-ralph

# Install as a dev extension
cd your-project
specify extension add --dev /path/to/spec-kit-ralph

# Verify installation
specify extension list
# Should show:
#  ✓ Ralph Loop (v1.0.0)
#    Autonomous implementation loop using AI agent CLI
#    Commands: 2 | Hooks: 1 | Status: Enabled
```

## Usage — Path 1: Agent Command

In a Copilot session:

```
/speckit.ralph.run
```

With options:

```
/speckit.ralph.run --max-iterations 5 --model gpt-5.1
```

The command validates prerequisites, sets up the agent profile, and launches the orchestrator script. Each iteration spawns a fresh Copilot process that completes one work unit.

## Usage — Path 2: Direct Script

### PowerShell (Windows)

```powershell
.specify/extensions/ralph/scripts/powershell/ralph-loop.ps1 `
  -FeatureName "001-my-feature" `
  -TasksPath "specs/001-my-feature/tasks.md" `
  -SpecDir "specs/001-my-feature" `
  -MaxIterations 10 `
  -Model "claude-sonnet-4.6"
```

### Bash (macOS/Linux)

```bash
.specify/extensions/ralph/scripts/bash/ralph-loop.sh \
  --feature-name "001-my-feature" \
  --tasks-path "specs/001-my-feature/tasks.md" \
  --spec-dir "specs/001-my-feature" \
  --max-iterations 10 \
  --model "claude-sonnet-4.6"
```

## Configuration

After installation, customize settings:

```bash
# Edit config (created from template during install)
$EDITOR .specify/extensions/ralph/ralph-config.yml
```

```yaml
model: "claude-sonnet-4.6"
max_iterations: 10
agent_cli: "copilot"
```

Environment variable overrides:

```bash
export SPECKIT_RALPH_MODEL="gpt-5.1"
export SPECKIT_RALPH_MAX_ITERATIONS="20"
```

Auth via environment (never in config):

```bash
export GH_TOKEN="your-token"
```

## What Happens During a Loop

1. Orchestrator validates prerequisites
2. For each iteration:
   - Spawns fresh `copilot --agent speckit.ralph` process
   - Agent reads `tasks.md` and `progress.md`
   - Agent identifies first incomplete work unit
   - Agent implements tasks, marks `[x]` in `tasks.md`
   - Agent commits completed work units
   - Agent appends progress entry to `progress.md`
3. Loop terminates when:
   - All tasks complete → exit 0
   - `<promise>COMPLETE</promise>` signal → exit 0
   - Max iterations reached → exit 1
   - 3 consecutive failures → exit 1
   - Ctrl+C → exit 130

## Resuming After Interruption

Simply re-run the command. The loop reads `tasks.md` checkbox state and `progress.md` to pick up where it left off:

```
/speckit.ralph.run
```

Already-completed tasks (`[x]`) are skipped. The progress log provides context from prior iterations.
