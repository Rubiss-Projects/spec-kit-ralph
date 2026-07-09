# Research: Port Ralph Loop to Spec-Kit Extension

## R1: Extension Structure & File Layout

**Decision**: Extension-native flat structure at repo root

**Rationale**: The [Extension Development Guide](https://github.com/github/spec-kit/blob/main/extensions/EXTENSION-DEVELOPMENT-GUIDE.md) specifies extensions as self-contained directories with `extension.yml` at root. Since this is a dedicated extension repo (not embedded in a larger project), the repo root IS the extension root. This aligns with the distribution pattern: `git clone` + `specify extension add --dev ./spec-kit-ralph`.

**Alternatives Considered**:
- Nested `src/` structure: Rejected — no Python/compiled code exists; this is scripts + markdown commands
- Monorepo with extension as subdirectory: Rejected — single-purpose repo, unnecessary nesting

**Source Reference**: Extension Development Guide § Distribution → Option 1: GitHub Repository

---

## R2: Script Porting Strategy

**Decision**: Port `ralph-loop.ps1` and `ralph-loop.sh` with minimal modifications

**Rationale**: The existing scripts (368 LOC PowerShell, 350 LOC Bash) in `C:\Users\Rubis\Projects\spec-kit` are mature and tested. They are already mostly self-contained — the `common.ps1` import is guarded with `if (Test-Path)` and only used for optional path helpers. Key changes needed:

1. **Remove `common.ps1`/`common.sh` dependency**: These are spec-kit core scripts. The extension scripts must be fully self-contained. The only usage is optional — inline what's needed or skip.
2. **Config file loading**: Add loading of `ralph-config.yml` from `.specify/extensions/ralph/` for defaults (model, max iterations, agent CLI path). Script parameters still override config values.
3. **Agent CLI path**: Read from config's `agent_cli` field instead of hardcoding `copilot`. Default to `copilot` if not configured.
4. **Agent name**: The scripts reference the registered iteration command/agent name `speckit.ralph.iterate`.

**Alternatives Considered**:
- Rewrite scripts from scratch: Rejected — existing scripts are proven and handle all edge cases (Ctrl+C, consecutive failures, completion detection)
- Add abstraction layer for agent CLIs: Rejected — spec clarification Q3 confirms Copilot-only at v1.0; premature abstraction

**Source Files**:
- `C:\Users\Rubis\Projects\spec-kit\scripts\powershell\ralph-loop.ps1` (368 lines)
- `C:\Users\Rubis\Projects\spec-kit\scripts\bash\ralph-loop.sh` (350 lines)

---

## R3: Command Registration Strategy

**Decision**: The extension provides behavior through registered command files. `commands/run.md` is the launcher and `commands/iterate.md` is the agent-facing iteration behavior.

**Rationale**: The current implementation generates the agent/command surface from extension command files, so a separate bundled `agents/speckit.ralph.agent.md` file is no longer required. Keeping the behavior in command files avoids drift between launcher instructions, Copilot invocation, and Codex stdin invocation.

The `run.md` command must not perform implementation work. It validates prerequisites, resolves configuration, and launches the orchestrator. The orchestrator then invokes the registered `speckit.ralph.iterate` behavior for each fresh context.

**Alternatives Considered**:
- Keep a separate bundled agent profile: Rejected — creates duplicate behavior and stale file references
- Require manual copy: Rejected — violates SC-001 (install + run with two commands, no additional manual config)
- Post-install hook: Rejected — unnecessary for the command-file registration path

**Key Detail**: Free-form text passed to `speckit.ralph.run` is not implementation scope. The launcher warns and ignores it because work selection happens inside `speckit.ralph.iterate` from `tasks.md`.

---

## R4: Command Pipeline Architecture

**Decision**: Two-command architecture with clear separation of concerns

### `speckit.ralph.run` (thin launcher)
- **Role**: User-facing entry point invoked via `/speckit.ralph.run` in an agent session
- **Behavior**: 
  1. Validate prerequisites (copilot CLI, tasks.md, git repo, feature branch)
  2. Resolve configuration and launcher arguments
  3. Detect platform (PowerShell or Bash)
  4. Locate orchestrator script in extension directory
  5. Launch script with configured parameters
- **Does NOT**: Contain loop logic, manage iterations, track progress, or implement task work inline

### `speckit.ralph.iterate` (single iteration)  
- **Role**: Agent-facing command invoked BY the orchestrator script for each iteration
- **Behavior**: Read tasks.md → identify first incomplete work unit → implement it → update tasks.md checkboxes → append to progress.md → commit if work unit complete
- **Invoked by**: `copilot --agent speckit.ralph.iterate -p "Iteration N"` from the orchestrator script

### Pipeline Flow
```
User ──→ /speckit.ralph.run ──→ validate ──→ ralph-loop.ps1/sh
                                                    │
                                              ┌─────┴─────┐
                                              │  Loop N×   │
                                              │            │
                                              │  copilot   │
                                              │  --agent   │
                                              │  speckit.  │
                                              │  ralph     │
                                              │     │      │
                                              │  iterate   │
                                              │  command   │
                                              │     │      │
                                              │  tasks.md  │
                                              │ progress.md│
                                              └────────────┘
```

**Rationale**: This matches the spec clarification Q4 (thin launcher) and Q2 (dual invocation paths). Users can also bypass the agent entirely and run scripts directly from terminal.

**Alternatives Considered**:
- Single command with embedded loop: Rejected — violates Q4 decision; can't run directly from terminal
- Three commands (run, iterate, status): Rejected — status can be read from progress.md; third command adds complexity without value

---

## R5: Config System Design

**Decision**: YAML config template with environment variable overrides

**Config File**: `ralph-config.template.yml` → installed as `.specify/extensions/ralph/ralph-config.yml`

**Schema**:
```yaml
# Ralph Extension Configuration
# DO NOT store authentication tokens here!
# Use environment variables: GH_TOKEN or GITHUB_TOKEN

# AI model for agent iterations
model: "claude-sonnet-4.6"

# Maximum loop iterations before stopping
max_iterations: 10

# Path to agent CLI binary (default: searches PATH for 'copilot')
agent_cli: "copilot"
```

**Loading Precedence** (per Extension Dev Guide § Config Loading):
1. Extension defaults (`extension.yml` → `defaults`)
2. Project config (`.specify/extensions/ralph/ralph-config.yml`)
3. Local overrides (`.specify/extensions/ralph/ralph-config.local.yml` — gitignored)
4. Environment variables (`SPECKIT_RALPH_MODEL`, `SPECKIT_RALPH_MAX_ITERATIONS`, `SPECKIT_RALPH_AGENT_CLI`)
5. Script parameters (highest priority — CLI flags always win)

**Rationale**: Follows the extension config pattern from the dev guide. The warning against storing tokens satisfies FR-015. Environment variables for auth satisfy spec clarification Q1.

---

## R6: Porting the Iterate Command

**Decision**: Adapt `templates/commands/ralph.md` from spec-kit core into `commands/iterate.md`

**Key Changes**:
1. **Script reference**: The frontmatter `scripts` field uses relative paths from extension root. After registration, these resolve to core spec-kit scripts:
   ```yaml
   scripts:
     sh: ../../scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
     ps: ../../scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
   ```
   These paths become `.specify/scripts/bash/check-prerequisites.sh` and `.specify/scripts/powershell/check-prerequisites.ps1` after registration (core spec-kit scripts).

2. **Registered command reference**: The orchestrator invokes `speckit.ralph.iterate` through the configured agent CLI.

3. **Content**: The iterate command body from `templates/commands/ralph.md` (121 lines) is mature and comprehensive. Port with minimal changes:
   - Update header description to reference extension context
   - Keep all scope constraints, outline steps, progress format, stop conditions, quality gates, and error handling

**Source File**: `C:\Users\Rubis\Projects\spec-kit\templates\commands\ralph.md`

---

## R7: Porting Iteration Command Behavior

**Decision**: Superseded by the registered command-file approach. Keep iteration behavior in `commands/iterate.md`.

**Source**: `C:\Users\Rubis\Projects\spec-kit\templates\commands\ralph.md`

**Changes Needed**:
1. **Script reference in step 1**: The iterate command references `.specify/scripts/powershell/check-prerequisites.ps1`. This is a core spec-kit script that exists in any initialized project. Keep unchanged.
2. **Work unit scope**: The iterate command constrains work to one user story per invocation. Keep unchanged.
3. **Launcher boundary**: Keep `commands/run.md` limited to launch orchestration so user text like `Implement US1` cannot override it.

**Rationale**: The iteration command is the critical behavior surface. Duplicating it in a separate agent profile increases the chance of divergent instructions.

---

## R8: Testing Strategy

**Decision**: Manual integration testing with verification checklist

**Test Plan**:
1. **Manifest validation**: `specify extension add --dev` validates schema automatically
2. **Command registration**: `specify extension list` shows commands
3. **Dry run**: Install on a project with completed tasks.md, run one iteration
4. **Full loop**: Run 3-5 iterations on a small task set
5. **Cross-platform**: Test PowerShell on Windows, Bash on macOS/Linux
6. **Interruption**: Test Ctrl+C during active iteration
7. **Config**: Test with custom model, max iterations, agent CLI path
8. **Resume**: Interrupt and restart to verify pickup from checkpoint

**Rationale**: This is a script+command extension with no compilable code. Unit testing is limited value; integration testing is the primary validation mechanism. The spec-kit `ExtensionManifest` class provides schema validation.

**Future**: If the extension grows, add automated tests using the Python ExtensionManifest API (see Extension API Reference § Testing).
