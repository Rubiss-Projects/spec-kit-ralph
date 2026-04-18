---
description: "Run the ralph autonomous implementation loop"
---

## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Purpose

This command is a **thin launcher** for the ralph loop orchestrator. It validates prerequisites, resolves configuration, and launches the platform-appropriate orchestrator script in a **visible terminal** for the user to monitor. Once the script is launched, this command's job is done — it exits immediately and does not wait for the script to complete.

## Outline

1. **Parse arguments** from `$ARGUMENTS`:
   - `--max-iterations N` or `-n N` (default: from config or 10)
   - `--model MODEL` or `-m MODEL` (default: from config or `claude-sonnet-4.6`)
   - `--verbose` or `-v` (default: false)

2. **Validate prerequisites** (all MUST pass before proceeding):

   | Check | Method | On Failure |
   |-------|--------|------------|
   | Agent CLI installed | Run `which gh` or `Get-Command gh` | Print error with install instructions, STOP |
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
   - Apply environment variable overrides (`SPECKIT_RALPH_MODEL`, `SPECKIT_RALPH_MAX_ITERATIONS`)
   - CLI arguments from step 1 override everything

5. **Launch orchestrator script in a visible terminal**:
   - Detect platform and run the appropriate script in a **visible, non-hidden terminal** so the user can monitor progress directly
   - **Do NOT wait** for the script to finish — launch it and exit immediately
   - Execute with resolved parameters:

     **PowerShell**:
     ```powershell
     & ".specify/extensions/ralph/scripts/powershell/ralph-loop.ps1" -FeatureName "{feature}" -TasksPath "{tasks_path}" -SpecDir "{spec_dir}" -MaxIterations {n} -Model "{model}" [-DetailedOutput]
     ```

     **Bash**:
     ```bash
     bash ".specify/extensions/ralph/scripts/bash/ralph-loop.sh" --feature-name "{feature}" --tasks-path "{tasks_path}" --spec-dir "{spec_dir}" --max-iterations {n} --model "{model}" [--verbose]
     ```

6. **Confirm launch and exit**:
   - Print a summary of what was launched (feature name, model, max iterations)
   - Tell the user to monitor the terminal for progress
   - Exit — do not poll, wait, or watch the script

## Exit Behavior

This command exits as soon as the orchestrator script is launched. It does **not** monitor the script or report its outcome.

| Outcome | Meaning |
|---------|---------|
| Command completes normally | Orchestrator was launched successfully — user should monitor the terminal |
| Command fails during validation | A prerequisite check failed — see error message for details |

The orchestrator script itself has its own exit codes (0 = all tasks complete, 1 = limit/failure, 130 = interrupted). The user will see these directly in the terminal where the script is running.

## Notes

- This command is a **fire-and-forget launcher** — it validates, configures, launches, and exits
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
