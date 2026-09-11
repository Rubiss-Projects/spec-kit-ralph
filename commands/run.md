---
description: "Run the ralph autonomous implementation loop"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** treat the user input as launcher arguments only.

Recognized launcher arguments are:

- `--max-iterations N` or `-n N`
- `--model MODEL` or `-m MODEL`
- `--agent-cli CLI`
- `--verbose` or `-v`

Free-form requests such as "Implement US1", "do the next story", or "fix the tasks" are **not** instructions for this command to execute work directly. If free-form text is present:

1. Print a short warning that the text is ignored by `speckit.ralph.run` because Ralph selects work from `tasks.md`.
2. Continue launching the Ralph orchestrator with the resolved configuration.

This command **MUST NOT** implement tasks, edit project files, mark checkboxes, create commits, or run `/speckit.ralph.iterate` inline. Its only job is prerequisite validation, configuration resolution, and launching the orchestrator script.

## Purpose

This command is a **thin launcher** for the ralph loop orchestrator. It validates prerequisites, resolves configuration, and launches the platform-appropriate orchestrator script in a **visible terminal** for the user to monitor. It verifies startup during a bounded launch check, then exits without waiting for the loop to complete. Opening a terminal alone is not a successful launch.

## Outline

1. **Parse launcher arguments only** from `$ARGUMENTS`:
   - `--max-iterations N` or `-n N` (default: from config or 10)
   - `--model MODEL` or `-m MODEL` (default: from config or `claude-sonnet-4.6`)
   - `--agent-cli CLI` (default: from config or `copilot`; supported: `copilot`, `codex`, `claude`, `opencode`)
     - For `copilot`, resolve the registered Spec Kit command/skill name from `.specify/integration.json`. Dot separator uses `--agent speckit.ralph.iterate`; dash/skills mode invokes `/speckit-ralph-iterate` in the prompt. Spec Kit integration options such as `--skills` are not passed as Copilot runtime flags.
   - `--verbose` or `-v` (default: false)
   - Ignore non-flag free-form text after printing the warning described above
   - Stop with a clear error for unknown flags or malformed flag values

2. **Validate prerequisites** (all MUST pass before proceeding):

   | Check | Method | On Failure |
   |-------|--------|------------|
   | Agent CLI installed | Resolve configured `agent_cli` (`copilot`, `codex`, `claude`, or `opencode`) with `which` or `Get-Command` | Print error with install instructions, STOP |
   | `tasks.md` exists | Search `specs/*/tasks.md` for current feature | Print error, suggest running `/speckit.tasks`, STOP |
   | Git repository | Run `git rev-parse --git-dir` | Print error: "Not a git repository", STOP |
   | Feature branch | Run `git branch --show-current`, verify not `main`/`master` | Print warning but continue |

3. **Detect feature context**:
   - Run the prerequisite check script:

     ```bash
     .specify/scripts/bash/check-prerequisites.sh --json --require-tasks --include-tasks
     ```

     ```powershell
     .specify/scripts/powershell/check-prerequisites.ps1 -Json -RequireTasks -IncludeTasks
     ```

   - Parse FEATURE_DIR, feature name, and spec directory from output

4. **Load configuration**:
   - Read `.specify/extensions/ralph/ralph-config.yml` if it exists
   - Apply environment variable overrides (`SPECKIT_RALPH_MODEL`, `SPECKIT_RALPH_MAX_ITERATIONS`, `SPECKIT_RALPH_AGENT_CLI`)
   - CLI arguments from step 1 override everything

5. **Select a visible terminal and dispatch the orchestrator**:
   - A **visible terminal** is a user-accessible, interactive terminal window, tab, pane, or in-app terminal canvas that displays the orchestrator's live output and lets the user interrupt it with Ctrl+C. A hidden/background process, tool-output transcript, unopened PTY, or idle shell prompt is insufficient.
   - Prefer an **in-app terminal canvas** when the host provides one with command execution and readable output. Open or focus the canvas, then explicitly dispatch the full command with its arguments and working directory. If the API only types text, send Enter to execute it. If the open call already executes the command, do not dispatch it a second time. Retain the terminal/session handle for step 6.
   - If no suitable in-app terminal is available, use an installed native terminal on the machine where the repository and agent CLI reside:

     | Platform | Native terminal fallback | Required dispatch |
     |----------|--------------------------|-------------------|
     | macOS | Terminal.app, or iTerm when available | Open a session and execute the Bash command in it, such as through Terminal's `do script` automation; opening the app alone is insufficient. |
     | Windows | Windows Terminal, then a visible PowerShell console | Start a tab/window running `pwsh` or `powershell` with the PowerShell command; retain the console after an early exit so errors remain visible. Do not use a hidden window. |
     | Linux | An installed graphical terminal such as `gnome-terminal`, `konsole`, or `xterm` | Supply the Bash command using the terminal's execute option and preserve output after exit. A graphical desktop/display must be available. |

   - Set the child shell's working directory to the repository root. Pass the resolved feature, task path, spec directory, model, iteration limit, agent CLI, and verbose setting to the script below. Preserve the configured environment. Use argument arrays where available; otherwise quote each value for every shell/automation layer it crosses. Paths with spaces must remain single arguments.
   - Before dispatch, ensure startup output will be readable in step 6. For native terminals without a readable session API, arrange to tee the child's output to a fresh, launch-specific temporary log **outside the repository**, while still displaying output live in the visible terminal. Preserve the orchestrator's exit status. Do not use a prior run's log or create tracked project files for launch verification.
   - If a terminal cannot be opened or cannot execute commands, try the next available fallback **only if no orchestrator command has been dispatched**. If no supported visible terminal with verifiable output is available (including headless/SSH environments without an in-app terminal), STOP with the error in step 6.
   - **Do NOT wait** for the script to finish. The bounded startup check in step 6 is required before exiting; it is not loop monitoring.
   - Do NOT perform any task implementation in the current agent session.
   - The launched orchestrator resolves the installed `templates/ralph-memory.md`, creates or validates the feature's `ralph-memory.md` before task selection, and blocks malformed memory without invoking an agent
   - Execute with resolved parameters:

     **PowerShell**:
     ```powershell
     & ".specify/extensions/ralph/scripts/powershell/ralph-loop.ps1" -FeatureName "{feature}" -TasksPath "{tasks_path}" -SpecDir "{spec_dir}" -MaxIterations {n} -Model "{model}" -AgentCli "{agent_cli}" [-DetailedOutput]
     ```

     **Bash**:
     ```bash
     bash ".specify/extensions/ralph/scripts/bash/ralph-loop.sh" --feature-name "{feature}" --tasks-path "{tasks_path}" --spec-dir "{spec_dir}" --max-iterations {n} --model "{model}" --agent-cli "{agent_cli}" [--verbose]
     ```

6. **Verify startup, then confirm and exit**:
   - Inspect output produced **after this dispatch**, using the terminal/session handle or the fresh temporary log from step 5. Allow a bounded startup check of **at most 30 seconds**; stop checking as soon as there is positive evidence or a startup error.
   - Startup evidence must come from the orchestrator: its `Ralph Loop - {feature}` header with an iteration line for the selected feature. A run that finishes before the first iteration may instead produce a `Ralph Loop Summary`; inspect that summary and report the observed immediate outcome. A summary reporting failure is not a successful launch. Do not wait for an agent/model response as startup evidence.
   - A terminal ID, process ID, successful window-open return code, echoed command text, or idle shell prompt does **not** prove that the orchestrator started. Do not print a success summary based on these alone.
   - On verified startup, print the feature name, model, max iterations, agent CLI, and terminal location. State that **startup was verified**, tell the user to monitor that terminal, then exit. Do not continue polling or watch the loop's outcome.
   - On a visible prerequisite/script error, report **launch failed** with that error and the terminal location. If no usable terminal exists, report **launch failed: no supported visible terminal with command dispatch and readable output is available**. Include the fully resolved direct invocation from step 5 and tell the user to run it from the repository root in their own terminal.
   - On timeout or unreadable output after dispatch, report **launch unverified: no orchestrator startup evidence was observed within the launch check**. Identify the terminal and explain that the process may still be running. Do not relaunch automatically; tell the user to inspect that terminal and stop any existing run before using the supplied direct invocation. This avoids starting duplicate Ralph loops.

## Exit Behavior

This command exits after the bounded startup verification. It does **not** monitor subsequent iterations or claim that implementation completed. If the script already terminated during verification, report the observed immediate outcome.

| Outcome | Meaning |
|---------|---------|
| Command completes normally | Orchestrator startup was verified from fresh output — user should monitor the identified terminal |
| Command fails during validation | A prerequisite check failed — see error message for details |
| Command fails during terminal setup | No supported visible terminal can dispatch the command and provide startup evidence — use the supplied direct invocation |
| Command reports launch failed | The dispatched script reported a startup error — inspect the terminal error |
| Command reports launch unverified | Dispatch occurred but startup could not be confirmed within 30 seconds — inspect the terminal before retrying |
| Script already finished during verification | Report the observed summary/exit result; do not describe the loop as still running |

The orchestrator script itself has its own exit codes. Exit `0` means the full completion gate passed: no tasks remain, memory has the exact terminal handoff, coordinated commit history is valid, and `git status --short --untracked-files=all` is empty. Exit `1` includes malformed memory, inconsistent completion signals, dirty completion (with every porcelain path reported), protocol violations, iteration limits, and other failures. Exit `130` means interrupted. The orchestrator does not launch a cleanup iteration or mutate Git to repair a blocked completion. Narrow exception: before completion is accepted, a subject-only `commit-subject-invalid` defect from explicitly configured commit policy may be fed into the next normal iteration so the agent can repair its own just-created work-unit commit subject. The user sees this result in the launched terminal.

## Notes

- This command validates, configures, dispatches, verifies startup, and exits; only the bounded launch check is allowed before handing monitoring to the user
- The orchestrator script handles ALL loop logic: iteration management, termination, progress tracking
- The script runs in a **visible terminal** so the user can watch progress in real time
- This command uses whatever model is active in the current session since it only does lightweight setup work
- Users can also run the scripts directly from terminal for debugging:

  ```bash
  bash .specify/extensions/ralph/scripts/bash/ralph-loop.sh --feature-name "001-feature" --tasks-path "specs/001-feature/tasks.md" --spec-dir "specs/001-feature"
  ```

  ```powershell
  & ".specify/extensions/ralph/scripts/powershell/ralph-loop.ps1" -FeatureName "001-feature" -TasksPath "specs/001-feature/tasks.md" -SpecDir "specs/001-feature"
  ```
