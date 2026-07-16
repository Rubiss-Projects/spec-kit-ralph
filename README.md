# Ralph Loop

Autonomous implementation loop for [spec-kit](https://github.com/github/spec-kit). Ralph repeatedly spawns a fresh AI agent that resumes from compact durable memory, implements the next work unit, and loops until every task is committed and the repository is clean.

## Prerequisites

| Requirement | Why |
|---|---|
| [spec-kit](https://github.com/github/spec-kit) (`specify` CLI) >= 0.8.5 | Extension host — provides project structure, task management, and integration metadata used for skills-mode dispatch |
| [GitHub Copilot CLI](https://docs.github.com/en/copilot), [OpenAI Codex CLI](https://developers.openai.com/codex/cli), or [Claude Code](https://docs.claude.com/en/docs/claude-code) | Agent CLI used to execute each iteration (`copilot` is the default) |
| [Git](https://git-scm.com/) | Version control — Ralph commits completed work units automatically |

Your project must be initialized with `specify init` and have a feature branch checked out with a completed `tasks.md`.

## Installation

```bash
specify extension add ralph
```
Or install from repository directly
```bash
specify extension add ralph --from https://github.com/Rubiss-Projects/spec-kit-ralph/archive/refs/tags/v1.2.1.zip
```

Verify the installation:

```bash
specify extension list
# ✓ Ralph Loop (v1.2.1)
#   Autonomous implementation loop using AI agent CLI
#   Commands: 2 | Hooks: 1 | Status: Enabled
```

The installed extension includes `.specify/extensions/ralph/ralph-config.yml` for project defaults and registers the iterate command for your active agent. No post-install config copy step is required.

## Usage

### Path 1 — Agent Command

Run inside an agent session that supports spec-kit extension commands:

```
/speckit.ralph.run
```

With options:

```
/speckit.ralph.run --max-iterations 5 --model gpt-5.1
```

The command validates prerequisites, detects the current feature context, and delegates to the platform-appropriate orchestrator script.

Only launcher flags are accepted here. Free-form text such as `Implement US1` is ignored by the launcher because Ralph selects the next incomplete work unit from `tasks.md` inside the orchestrated iteration.

### Path 2 — Direct Script Invocation

Run the orchestrator scripts directly from your terminal for debugging or CI use.

**PowerShell (Windows):**

```powershell
.specify/extensions/ralph/scripts/powershell/ralph-loop.ps1 `
  -FeatureName "001-my-feature" `
  -TasksPath "specs/001-my-feature/tasks.md" `
  -SpecDir "specs/001-my-feature" `
  -MaxIterations 10 `
  -Model "claude-sonnet-4.6" `
  -AgentCli "copilot"
```

**Bash (macOS / Linux):**

```bash
.specify/extensions/ralph/scripts/bash/ralph-loop.sh \
  --feature-name "001-my-feature" \
  --tasks-path "specs/001-my-feature/tasks.md" \
  --spec-dir "specs/001-my-feature" \
  --max-iterations 10 \
  --model "claude-sonnet-4.6" \
  --agent-cli "copilot"
```

## Configuration

Edit `.specify/extensions/ralph/ralph-config.yml` to customize defaults:

```yaml
# AI model for agent iterations
model: "claude-sonnet-4.6"

# Maximum loop iterations before stopping
max_iterations: 10

# Path or name of the agent CLI binary
# Supported: copilot, codex, claude
agent_cli: "copilot"

# Commit subject policy (optional — omit this block to preserve today's behavior)
commit:
  style: "legacy"      # legacy | conventional
  scope: "ralph"       # optional; used only for conventional style; default: ralph
  issue: "auto"        # optional; auto-links commits to inferred GitHub issue number
```

The installed extension contains only the active `ralph-config.yml`, which is also the manifest's canonical configuration source.

### Commit Style

Ralph generates work-unit commit subjects in the format `feat(<feature-name>): <work-unit title>` by default. The optional `commit` block lets you change this behavior without affecting projects that have no `commit` configuration.

**Legacy (default)** — preserves the existing format exactly:

```yaml
commit:
  style: legacy
```

Result: `feat(<feature-name>): <work-unit title>`

**Conventional** — uses a short, configurable scope:

```yaml
commit:
  style: conventional
  scope: myteam
```

Result: `feat(myteam): <commit summary>`

Omit `scope` to use the default scope `ralph`:

```yaml
commit:
  style: conventional
```

Result: `feat(ralph): <commit summary>`

**Issue auto-linking** — appends `#<issue>` when the branch name starts with a numeric prefix (e.g. `069-some-feature` → `#69`). Works with both `legacy` and `conventional` styles. If no numeric prefix is found, the commit is created without a suffix.

```yaml
commit:
  style: conventional
  issue: auto
```

Result (on branch `069-some-feature`): `feat(ralph): <commit summary> #69`

Setting an unsupported `commit.style` value causes Ralph to stop with a clear configuration error before creating any commit.

When a `commit` block is configured, Ralph also validates the subject of each new agent-created work-unit commit before accepting completion. The validator checks the configured prefix, required issue suffix, and obvious planning labels in conventional payloads, but it does not require an exact deterministic summary. A subject-only defect is reported back to the next iteration so the agent can repair it, for example by amending the latest commit.

### Agent CLI Support

Ralph supports CLI-specific invocation codepaths selected by `agent_cli`.

| `agent_cli` | Invocation shape | Notes |
|---|---|---|
| `copilot` | `copilot --agent speckit.ralph.iterate -p ... --model ... --yolo -s` or `copilot -p "/speckit-ralph-iterate ..." --model ... --yolo -s` | Default path. Resolves the registered command/skill name from `.specify/integration.json`: dot separator uses `--agent speckit.ralph.iterate`; dash/skills mode invokes `/speckit-ralph-iterate` in the prompt. Spec Kit integration options such as `--skills` are not passed as Copilot runtime flags. |
| `codex` | `codex exec --json --model ... --sandbox danger-full-access --cd ... -` | Uses Codex non-interactive mode and passes the existing `speckit.ralph.iterate` command text via stdin. |
| `claude` | `claude -p ... --model ... --dangerously-skip-permissions` | Uses Claude Code print/non-interactive mode. Passes the existing `speckit.ralph.iterate` command text in the prompt (Claude Code has no registered agent to select). `--dangerously-skip-permissions` runs unattended (equivalent to `--permission-mode bypassPermissions`). |

To use Codex:

```yaml
model: "gpt-5.3-codex"
max_iterations: 10
agent_cli: "codex"
```

Install and authenticate the Codex CLI first. Ralph does not store Codex API keys or ChatGPT credentials in its config.

To use Claude Code:

```yaml
model: "claude-sonnet-4-6"
max_iterations: 10
agent_cli: "claude"
```

Install and authenticate Claude Code (`claude`) first. Ralph passes `--dangerously-skip-permissions` so iterations run unattended — only use this in a trusted working directory. Ralph does not store Anthropic API keys or credentials in its config.

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
export SPECKIT_RALPH_MODEL="gpt-5.3-codex"
export SPECKIT_RALPH_MAX_ITERATIONS="20"
export SPECKIT_RALPH_AGENT_CLI="codex"
```

> **Note:** Never store authentication tokens in the config file. Use `GH_TOKEN` or `GITHUB_TOKEN` environment variables for authentication.

## How the Loop Works

```
┌─────────────────────────────────────────┐
│           ralph-loop starts             │
│  prepare + validate ralph-memory.md      │
└──────────────────┬──────────────────────┘
                   ▼
          ┌────────────────────┐
          │ Any tasks left?    │──No──▶ strict completion gate
          └─────────┬──────────┘
                    │ Yes
                    ▼
  ┌───────────────────────────────┐
  │ Spawn fresh agent process     │
  │ memory first, tasks second    │
  └──────────────┬────────────────┘
                 ▼
  ┌───────────────────────────────┐
  │ Implement and validate ONE    │
  │ work unit                     │
  └──────────────┬────────────────┘
                 ▼
  ┌───────────────────────────────┐
  │ Persist tasks + memory +      │
  │ audit, then substantive commit│
  └──────────────┬────────────────┘
                 ▼
       validate history and loop
```

### Iteration Cycle

1. The orchestrator creates a missing `ralph-memory.md` from the installed canonical template, or validates the existing file without rewriting it. A malformed file reports all structural defects, remains byte-for-byte unchanged, and blocks agent invocation.
2. Each **fresh** agent reads `ralph-memory.md` first, then `tasks.md` and design artifacts. Recent `progress.md` entries are optional audit context, not durable memory.
3. The agent implements and validates one work unit. Durable patterns, decisions, gotchas, commands, failed approaches, and the next handoff are compacted in memory.
4. For completed work, the agent updates tasks and memory, appends progress, then creates one substantive commit containing implementation, `tasks.md`, `ralph-memory.md`, and `progress.md`. The audit uses `This work-unit commit`; it never requires a future hash or a bookkeeping amend.
5. Failed or no-work attempts leave tasks and `HEAD` unchanged. Useful memory and audit updates remain uncommitted and join the next substantive commit.
6. The orchestrator validates only commits created after it snapshots `HEAD` for the current iteration. Earlier human-authored spec or task refinements form the trusted starting boundary, so a clean branch can be rerun without rewriting history.

### Termination Conditions

| Condition | Exit Code | Meaning |
|---|---|---|
| Zero tasks, valid terminal handoff, required current state files, clean repository | `0` | Completion contract passed; historical commits from before this run are not reclassified as Ralph work-unit commits |
| Zero tasks but stale handoff, invalid memory, invalid commit, Git error, or any dirty path | `1` | Blocked immediately; all relevant diagnostics are printed and no agent is launched |
| Completion signal with remaining tasks or a failed agent | `1` | Inconsistent protocol; the signal cannot force success |
| Max iterations reached | `1` | Safety limit — increase `max_iterations` if needed |
| 3 consecutive failures | `1` | Circuit breaker — agent is stuck |
| Ctrl+C | `130` | User interrupted the loop |

The terminal `Current Handoff` must contain only `- Feature complete; no handoff required.`. Completion also requires `git status --short --untracked-files=all` to succeed with no output. Ralph reports dirty paths and stops; it does not stage, amend, reset, stash, or launch a cleanup iteration.

## Resuming After Interruption

Ralph is designed to be interrupted and resumed safely. `tasks.md` records authoritative task state, `ralph-memory.md` carries compact durable context and the next handoff, and committed files carry implementation state. `progress.md` is append-only chronological audit history.

To resume, simply re-run the command:

```
/speckit.ralph.run
```

Or re-run the script directly. The orchestrator validates memory before selection, reads the current checkbox state, and skips completed tasks. A failed attempt's uncommitted memory/audit record is preserved for the next substantive work-unit commit.

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
├── templates/
│   └── ralph-memory.md             # Canonical durable-memory template
├── ralph-config.yml               # Installed project defaults
├── README.md
├── CHANGELOG.md
└── LICENSE                        # MIT
```

## License

[MIT](LICENSE) © Rubiss
