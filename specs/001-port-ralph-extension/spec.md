# Feature Specification: Port Ralph Loop to Spec-Kit Extension

**Feature Branch**: `001-port-ralph-extension`  
**Created**: 2026-03-06  
**Status**: Draft  
**Input**: User description: "Build a spec-kit extension that ports ralph loop support from the specify CLI core into a standalone extension package"

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Install Ralph Extension (Priority: P1)

As a spec-kit user, I want to install the ralph extension into my project with a single command so that I gain ralph loop capabilities without modifying my spec-kit installation.

**Why this priority**: Installation is the entry point for all other functionality. Without this, no other user story can be tested or delivered.

**Independent Test**: Can be fully tested by running `specify extension add --dev /path/to/spec-kit-ralph` on a fresh spec-kit project and verifying that the extension appears in `specify extension list` with all commands registered.

**Acceptance Scenarios**:

1. **Given** a spec-kit project initialized with `specify init`, **When** I run `specify extension add --dev /path/to/spec-kit-ralph`, **Then** the extension is registered, its commands are available, and `specify extension list` shows "spec-kit-ralph" as enabled with version, command count, and hook count
2. **Given** the extension is installed, **When** I inspect `.specify/extensions/ralph/`, **Then** the extension configuration file exists with default settings
3. **Given** the extension is installed, **When** I run `specify extension list`, **Then** the output shows the ralph extension with its `speckit.ralph.run` and `speckit.ralph.iterate` commands listed
4. **Given** a spec-kit project running a version below the extension's `requires.speckit_version`, **When** I attempt to install the extension, **Then** the installation fails with a clear compatibility error message

---

### User Story 2 - Run Ralph Loop via Extension Command (Priority: P1)

As a developer with completed spec, plan, and tasks phases, I want to run a single command that autonomously implements my feature by iterating through tasks in a controlled loop, so that I can leverage AI-driven implementation while maintaining clean context boundaries.

**Why this priority**: This is the core value proposition — the ralph loop orchestration. It is equally critical to installation since together they form the minimum viable product.

**Independent Test**: Can be fully tested by installing the extension on a project with a completed `tasks.md`, running the ralph loop via either the agent command (`/speckit.ralph.run`) or directly via the orchestrator script (`ralph-loop.ps1` / `ralph-loop.sh`), and observing that the agent iterates through tasks, updates checkboxes, writes progress entries, and terminates correctly.

**Acceptance Scenarios**:

1. **Given** a project with completed spec.md, plan.md, and tasks.md, **When** I run the ralph loop command, **Then** the system validates prerequisites (agent CLI installed, tasks.md exists, git repo present, feature branch active) and begins the loop
2. **Given** a running ralph loop iteration, **When** the agent completes a work unit, **Then** the system spawns a fresh agent process for the next iteration with no inherited in-memory state
3. **Given** a running ralph loop, **When** the agent outputs `<promise>COMPLETE</promise>` after all tasks are verified complete, **Then** the loop terminates with exit code 0 and a success summary
4. **Given** a running ralph loop, **When** the configured maximum iteration count is reached with tasks remaining, **Then** the loop terminates with a non-zero exit code and a summary of completed vs. remaining tasks
5. **Given** a running ralph loop, **When** the user presses Ctrl+C, **Then** the loop terminates gracefully, preserves all progress written to disk, and exits with code 130

---

### User Story 3 - Progress Tracking and Cross-Iteration Learning (Priority: P2)

As a developer, I want the ralph loop to maintain a progress log across iterations so that each fresh agent context can learn from previous iterations without relying on in-memory state.

**Why this priority**: Progress persistence is what makes the ralph loop resumable and debuggable. Without it, context isolation (Principle II) would cause repeated mistakes across iterations.

**Independent Test**: Can be tested by running 2-3 iterations and verifying that `progress.md` contains chronological entries with timestamps, tasks completed, files changed, and learnings; and that the codebase patterns section is populated.

**Acceptance Scenarios**:

1. **Given** a ralph loop iteration completes a work unit, **When** the iteration ends, **Then** the system appends a progress entry to `specs/{feature}/progress.md` with: timestamp, work unit attempted, tasks completed, files changed, and learnings discovered
2. **Given** a new ralph loop iteration starts, **When** the agent prompt is constructed, **Then** it includes instructions to read the progress file for codebase patterns and prior context
3. **Given** multiple iterations have run, **When** I inspect `progress.md`, **Then** I see a chronological log with a `## Codebase Patterns` section at the top that accumulates discovered conventions
4. **Given** a previously interrupted ralph loop, **When** I restart it, **Then** it reads `tasks.md` checkbox state and `progress.md` to pick up where it left off without re-doing completed work

---

### User Story 4 - Agent Command for Single Iteration (Priority: P2)

As an AI agent invoked by the ralph loop orchestrator, I need a command definition (`speckit.ralph.iterate`) that instructs me to complete exactly one work unit from tasks.md with proper commits and progress tracking, so that the orchestrator can call me repeatedly with fresh context.

**Why this priority**: The iteration command is the agent-facing counterpart to the orchestrator. Without it, the loop has no instructions to give the agent for each iteration.

**Independent Test**: Can be tested by manually invoking the agent with the `speckit.ralph.iterate` command on a project with incomplete tasks and verifying: at most one work unit is completed, tasks.md checkboxes are updated, a commit is created for completed stories, and progress.md is appended.

**Acceptance Scenarios**:

1. **Given** a project with incomplete tasks in tasks.md, **When** the `speckit.ralph.iterate` command is invoked, **Then** the agent identifies the first incomplete work unit (phase, user story, or task group) and works only within that scope
2. **Given** the agent completes all tasks in a work unit, **When** the work unit is done, **Then** the agent creates a git commit with a conventional commit message and marks all tasks as `[x]` in tasks.md
3. **Given** the agent cannot complete the entire work unit, **When** partial progress is made, **Then** the agent marks completed tasks `[x]` but does not commit, leaving the rest for the next iteration
4. **Given** all tasks in tasks.md are complete, **When** the agent verifies this, **Then** it outputs exactly `<promise>COMPLETE</promise>` to signal loop termination

---

### User Story 5 - Configurable Iteration Limits and Model Selection (Priority: P3)

As a developer, I want to control the maximum number of iterations and the AI model used so that I can manage resource usage and experiment with different models.

**Why this priority**: Configurability is important for power users but not essential to the core loop. Default values (10 iterations, default model) are sufficient for initial use.

**Independent Test**: Can be tested by running the ralph loop with explicit `--max-iterations 3` and `--model` flags and verifying the loop respects both settings.

**Acceptance Scenarios**:

1. **Given** I run the ralph command with `--max-iterations 3`, **When** 3 iterations complete, **Then** the loop terminates even if tasks remain incomplete
2. **Given** I run the ralph command without specifying a limit, **When** the loop runs, **Then** it uses the default limit of 10 iterations
3. **Given** I run the ralph command with `--model gpt-5.1`, **When** the agent CLI is invoked, **Then** it uses the specified model for all iterations
4. **Given** I run the ralph command with `--list-models`, **When** the command executes, **Then** it displays available models and exits without starting the loop

---

### User Story 6 - Extension Hook Integration (Priority: P3)

As a spec-kit user, I want the ralph extension to optionally hook into the `after_tasks` lifecycle event so that I am prompted to start the ralph loop immediately after generating tasks.

**Why this priority**: Hook integration improves workflow continuity but is not required for core functionality. Users can always invoke the ralph command manually.

**Independent Test**: Can be tested by running `/speckit.tasks` on a project with the extension installed and verifying the user is prompted to run the ralph loop.

**Acceptance Scenarios**:

1. **Given** the ralph extension is installed with the `after_tasks` hook enabled, **When** `/speckit.tasks` completes, **Then** the user is prompted: "Run ralph loop to implement tasks?"
2. **Given** the user responds yes to the hook prompt, **When** the hook executes, **Then** the `speckit.ralph.run` command is invoked with default settings
3. **Given** the user responds no to the hook prompt, **When** the hook is declined, **Then** no action is taken and control returns to the user

---

### Edge Cases

- What happens when tasks.md does not exist or is empty? → Display error message guiding user to run `/speckit.tasks` first
- What happens when the agent CLI is not installed? → Display error with installation instructions for the configured agent
- What happens when an iteration fails (agent crashes or times out)? → Log the failure, increment iteration count, attempt next iteration
- What happens when 3 consecutive iterations fail? → Terminate the loop with an error summary rather than waste resources
- What happens when the user interrupts the loop (Ctrl+C)? → Gracefully stop, preserve progress file, report current status with exit code 130
- What happens when git is in a dirty state with uncommitted changes? → Warn user but allow continuation; agent commits its own changes
- What happens when the extension is installed alongside other spec-kit extensions? → Must not conflict; commands are namespaced under `speckit.ralph.*`
- What happens when the user runs the ralph loop on a branch that does not match any specs directory? → Fall back to the most recent (highest-numbered) spec directory
- What happens when progress.md already exists from a prior run? → Append to it; never overwrite existing entries

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Extension MUST provide a valid `extension.yml` manifest conforming to spec-kit extension schema version 1.0
- **FR-002**: Extension MUST provide a `speckit.ralph.run` command that acts as a thin launcher: it validates prerequisites, resolves the correct platform script (`ralph-loop.ps1` on Windows/PowerShell, `ralph-loop.sh` on Unix/Bash), and delegates all orchestration logic (iteration management, termination handling, progress tracking) to that script. The command file itself MUST NOT contain loop logic. Users MUST be able to invoke the loop via either: (a) the agent command `/speckit.ralph.run` inside an agent session, or (b) directly running the orchestrator script from the terminal. README MUST document both invocation paths
- **FR-003**: Extension MUST provide a `speckit.ralph.iterate` command file that instructs the agent to complete one work unit per invocation with proper scope constraints
- **FR-004**: Extension MUST include both PowerShell (`ralph-loop.ps1`) and Bash (`ralph-loop.sh`) orchestrator scripts for cross-platform support
- **FR-005**: Each loop iteration MUST spawn a fresh agent CLI process; no in-memory state may carry over between iterations
- **FR-006**: Task completion MUST be tracked via `tasks.md` checkbox state (`[ ]` → `[x]`); no separate tracking file is permitted
- **FR-007**: Iteration history MUST be appended to `specs/{feature}/progress.md` after each iteration with timestamp, work unit, tasks completed, files changed, and learnings
- **FR-008**: The loop MUST terminate when: (a) the agent outputs `<promise>COMPLETE</promise>`, (b) all tasks.md checkboxes are `[x]`, or (c) the maximum iteration count is reached
- **FR-009**: The loop MUST terminate after 3 consecutive iteration failures with a clear error summary
- **FR-010**: The loop MUST handle Ctrl+C gracefully, preserving all progress and exiting with code 130
- **FR-011**: The orchestrator MUST accept configurable parameters: maximum iterations (default 10), AI model, and verbose output flag
- **FR-012**: The extension MUST provide an `after_tasks` hook that optionally prompts the user to start the ralph loop after task generation
- **FR-013**: Every termination path MUST produce a summary block reporting iterations run, tasks completed, tasks remaining, and final status
- **FR-014**: The extension config MUST include an `agent_cli` field for the agent binary path. At v1.0, orchestrator scripts target GitHub Copilot CLI flag conventions only; adding support for other agents (Claude, Gemini, etc.) is deferred to future releases as additional script codepaths. The architecture MUST NOT preclude this future extension
- **FR-015**: Extension MUST include a configuration template with settings for default model, max iterations, and agent CLI path. The configuration MUST NOT store authentication credentials (tokens, PATs); auth is exclusively via environment variables (`GH_TOKEN` / `GITHUB_TOKEN`). The config template MUST include a comment warning against storing tokens

### Key Entities

- **Extension Manifest**: The `extension.yml` file declaring the extension's identity, commands, hooks, configuration, and compatibility requirements
- **Ralph Session**: A single execution of the ralph loop from start to termination; characterized by iteration count, start/end time, and final status (completed, interrupted, failed, iteration-limit-reached)
- **Iteration**: One invocation of the agent CLI within a session; has a number, work unit attempted, outcome (success/failure), and duration
- **Progress Log**: Append-only markdown file (`progress.md`) tracking all iterations with a codebase patterns section for cross-iteration learning
- **Iteration Command**: The `speckit.ralph.iterate` command definition that constrains agent behavior to one work unit per invocation
- **Extension Configuration**: User-customizable settings (default model, max iterations, agent CLI binary) stored in the extension config directory

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Users can install the extension and run the ralph loop with two commands (`specify extension add` + `specify ralph`) and no additional manual configuration
- **SC-002**: A feature with 5–10 tasks can be implemented autonomously in under 30 minutes of wall-clock time
- **SC-003**: Each iteration starts within 2 seconds of the previous iteration completing
- **SC-004**: Progress file accurately reflects all completed work and is verifiable by user inspection after every iteration
- **SC-005**: The loop terminates correctly in 100% of cases where all tasks are complete (no false negatives on completion detection)
- **SC-006**: User interruption (Ctrl+C) preserves all progress made up to that point in 100% of cases
- **SC-007**: Users can resume a partially completed ralph loop by re-running the command; it picks up from where it left off without re-doing completed work
- **SC-008**: The extension installs and operates correctly alongside other spec-kit extensions without command conflicts or side effects
- **SC-009**: Both PowerShell and Bash orchestrator scripts produce identical loop behavior (same termination conditions, same progress format, same exit codes)

## Clarifications

### Session 2026-03-06

- Q: Should the extension config exclude authentication credentials, relying on environment variables for agent CLI auth? → A: Yes — config stores only non-sensitive settings (model, iterations, CLI path); auth exclusively via environment variables with a warning comment in the config template
- Q: How should users start the ralph loop — agent command only, direct script, or both? → A: Both — users can invoke via agent command (`/speckit.ralph.run`) or run orchestrator scripts directly from terminal; README documents both paths
- Q: What level of agent CLI abstraction at v1.0 — Copilot-only, thin flag abstraction, or full agent profiles? → A: Copilot-only with a config `agent_cli` field for the binary path; Copilot flag patterns hardcoded in scripts; new agents added as future codepaths
- Q: Should the `.run` command contain full orchestration logic or be a thin launcher invoking platform scripts? → A: Thin launcher — the command file validates prerequisites and delegates to `ralph-loop.ps1`/`.sh`; all loop logic lives in scripts for direct invocation parity and easier debugging

## Assumptions

- Users have already completed the specify, plan, and tasks phases before running the ralph loop
- The target project is initialized with `specify init` and has a `.specify/` directory structure
- An AI agent CLI (initially GitHub Copilot CLI) is installed and authenticated on the user's machine. v1.0 supports Copilot CLI only; other agents are a future extension point
- Tasks in `tasks.md` are appropriately sized for single-context completion per the ralph methodology
- Git is available and the project is a git repository (for commit tracking between iterations)
- The spec-kit CLI (`specify`) supports the extension system (`specify extension add`, `specify extension list`)
- The extension will be distributed via GitHub releases and optionally listed in the community catalog
