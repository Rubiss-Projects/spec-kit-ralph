# Contract: Configuration Schema

**Config File**: `ralph-config.yml`
**Template File**: `ralph-config.template.yml` (reference/reset copy)
**Installed Location**: `.specify/extensions/ralph/ralph-config.yml`
**Local Override**: `.specify/extensions/ralph/ralph-config.local.yml` (gitignored)

## Schema

```yaml
# Ralph Extension Configuration
# ⚠️ DO NOT store authentication tokens or secrets in this file!
# Use environment variables instead: GH_TOKEN or GITHUB_TOKEN
#
# Copy this file to ralph-config.yml and customize.

# AI model for agent iterations
# Override: --model flag, or SPECKIT_RALPH_MODEL env var
model: "claude-sonnet-4.6"

# Maximum loop iterations before stopping
# Override: --max-iterations flag, or SPECKIT_RALPH_MAX_ITERATIONS env var
max_iterations: 10

# Path to agent CLI binary
# Default searches PATH for 'copilot'
# Override: SPECKIT_RALPH_AGENT_CLI env var
agent_cli: "copilot"
```

## Field Specifications

| Field | Type | Default | Constraints | Env Override |
|-------|------|---------|-------------|--------------|
| `model` | string | `"claude-sonnet-4.6"` | Non-empty | `SPECKIT_RALPH_MODEL` |
| `max_iterations` | integer | `10` | > 0 | `SPECKIT_RALPH_MAX_ITERATIONS` |
| `agent_cli` | string | `"copilot"` | Non-empty, valid path or command name | `SPECKIT_RALPH_AGENT_CLI` |

## Loading Precedence

Priority (lowest → highest):

1. **Extension defaults** (`extension.yml` → `defaults` section)
2. **Project config** (`.specify/extensions/ralph/ralph-config.yml`)
3. **Local overrides** (`.specify/extensions/ralph/ralph-config.local.yml`)
4. **Environment variables** (`SPECKIT_RALPH_*`)
5. **CLI parameters** (script flags like `-MaxIterations`, `--model`)

## Security Rules

- **MUST NOT** contain: tokens, PATs, passwords, API keys, secrets
- **Auth mechanism**: Environment variables only (`GH_TOKEN`, `GITHUB_TOKEN`)
- **Template warning**: First comment block MUST warn against storing tokens
- **Local overrides file**: Gitignored by default (for local path customization)

## Loading Implementation

### PowerShell (in ralph-loop.ps1)

```powershell
# Load config with defaults
$configPath = Join-Path $RepoRoot ".specify/extensions/ralph/ralph-config.yml"
if (Test-Path $configPath) {
    # Parse YAML and apply as defaults (script params override)
}

# Environment variable overrides
if ($env:SPECKIT_RALPH_MODEL) { $Model = $env:SPECKIT_RALPH_MODEL }
if ($env:SPECKIT_RALPH_MAX_ITERATIONS) { $MaxIterations = [int]$env:SPECKIT_RALPH_MAX_ITERATIONS }
if ($env:SPECKIT_RALPH_AGENT_CLI) { $AgentCli = $env:SPECKIT_RALPH_AGENT_CLI }
```

### Bash (in ralph-loop.sh)

```bash
# Load config with defaults
config_path="$REPO_ROOT/.specify/extensions/ralph/ralph-config.yml"
if [[ -f "$config_path" ]]; then
    # Parse YAML and apply as defaults (script args override)
fi

# Environment variable overrides
MODEL="${SPECKIT_RALPH_MODEL:-$MODEL}"
MAX_ITERATIONS="${SPECKIT_RALPH_MAX_ITERATIONS:-$MAX_ITERATIONS}"
AGENT_CLI="${SPECKIT_RALPH_AGENT_CLI:-$AGENT_CLI}"
```
