#!/usr/bin/env bash
#
# ralph-loop.sh - Ralph loop orchestrator for autonomous implementation
#
# Executes GitHub Copilot CLI in a controlled loop, processing tasks from tasks.md.
# Each iteration spawns a fresh agent context with the speckit.ralph profile.
#
# The loop terminates when:
# - Agent outputs <promise>COMPLETE</promise>
# - Max iterations reached
# - All tasks in tasks.md are complete
# - 3 consecutive failures (circuit breaker)
# - User interrupts with Ctrl+C
#
# Configuration precedence (highest wins):
#   CLI arguments > Environment variables > Local config > Project config > Defaults
#
# Usage:
#   ./ralph-loop.sh --feature-name "001-feature" --tasks-path "specs/001-feature/tasks.md" \
#                   --spec-dir "specs/001-feature" --max-iterations 10 \
#                   --model "claude-sonnet-4.6" --agent-cli "copilot"

set -euo pipefail

#region Configuration

FEATURE_NAME=""
TASKS_PATH=""
SPEC_DIR=""
MAX_ITERATIONS=10
MODEL="claude-sonnet-4.6"
AGENT_CLI="copilot"
VERBOSE=false
WORKING_DIRECTORY=""

# Track which args were explicitly set via CLI
FEATURE_NAME_EXPLICIT=false
TASKS_PATH_EXPLICIT=false
SPEC_DIR_EXPLICIT=false
MAX_ITERATIONS_EXPLICIT=false
MODEL_EXPLICIT=false
AGENT_CLI_EXPLICIT=false
WORKING_DIRECTORY_EXPLICIT=false

#endregion

#region Parse Arguments

while [[ $# -gt 0 ]]; do
    case $1 in
        --feature-name)
            FEATURE_NAME="$2"
            FEATURE_NAME_EXPLICIT=true
            shift 2
            ;;
        --tasks-path)
            TASKS_PATH="$2"
            TASKS_PATH_EXPLICIT=true
            shift 2
            ;;
        --spec-dir)
            SPEC_DIR="$2"
            SPEC_DIR_EXPLICIT=true
            shift 2
            ;;
        --max-iterations)
            MAX_ITERATIONS="$2"
            MAX_ITERATIONS_EXPLICIT=true
            shift 2
            ;;
        --model)
            MODEL="$2"
            MODEL_EXPLICIT=true
            shift 2
            ;;
        --agent-cli)
            AGENT_CLI="$2"
            AGENT_CLI_EXPLICIT=true
            shift 2
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --working-directory)
            WORKING_DIRECTORY="$2"
            WORKING_DIRECTORY_EXPLICIT=true
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FEATURE_NAME" || -z "$TASKS_PATH" || -z "$SPEC_DIR" ]]; then
    echo "Error: Missing required arguments" >&2
    echo "Usage: $0 --feature-name NAME --tasks-path PATH --spec-dir DIR [--max-iterations N] [--model MODEL] [--agent-cli CLI] [--verbose]" >&2
    exit 1
fi

#endregion

#region Resolve Paths

REPO_ROOT="$(pwd)"
TASKS_PATH="$(realpath "$TASKS_PATH")"
SPEC_DIR="$(realpath "$SPEC_DIR")"
PROGRESS_PATH="$SPEC_DIR/progress.md"

# Paths for spec files
SPEC_PATH="$SPEC_DIR/spec.md"
PLAN_PATH="$SPEC_DIR/plan.md"

# Use working directory if not specified
if [[ -z "$WORKING_DIRECTORY" ]]; then
    WORKING_DIRECTORY="$REPO_ROOT"
fi

#endregion

#region Config Loading

load_ralph_config() {
    local repo_root=$1
    local config_path="$repo_root/.specify/extensions/ralph/ralph-config.yml"
    local local_config_path="$repo_root/.specify/extensions/ralph/ralph-config.local.yml"

    for cfg in "$config_path" "$local_config_path"; do
        if [[ -f "$cfg" ]]; then
            while IFS= read -r line; do
                line=$(echo "$line" | sed 's/^[[:space:]]*//' | sed 's/[[:space:]]*$//')
                [[ -z "$line" || "$line" == \#* ]] && continue
                key=$(echo "$line" | sed 's/:.*//' | tr -d ' ')
                value=$(echo "$line" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
                case "$key" in
                    model) CONFIG_MODEL="$value" ;;
                    max_iterations) CONFIG_MAX_ITERATIONS="$value" ;;
                    agent_cli) CONFIG_AGENT_CLI="$value" ;;
                esac
            done < "$cfg"
        fi
    done
}

# Load config from YAML files
load_ralph_config "$REPO_ROOT"

# Apply config defaults where CLI args were not explicitly provided
[[ -n "${CONFIG_MODEL:-}" ]] && [[ "$MODEL_EXPLICIT" != "true" ]] && MODEL="$CONFIG_MODEL"
[[ -n "${CONFIG_MAX_ITERATIONS:-}" ]] && [[ "$MAX_ITERATIONS_EXPLICIT" != "true" ]] && MAX_ITERATIONS="$CONFIG_MAX_ITERATIONS"
[[ -n "${CONFIG_AGENT_CLI:-}" ]] && [[ "$AGENT_CLI_EXPLICIT" != "true" ]] && AGENT_CLI="$CONFIG_AGENT_CLI"

# Environment variable overrides (higher priority than config, lower than CLI args)
[[ -n "${SPECKIT_RALPH_MODEL:-}" ]] && [[ "$MODEL_EXPLICIT" != "true" ]] && MODEL="$SPECKIT_RALPH_MODEL"
[[ -n "${SPECKIT_RALPH_MAX_ITERATIONS:-}" ]] && [[ "$MAX_ITERATIONS_EXPLICIT" != "true" ]] && MAX_ITERATIONS="$SPECKIT_RALPH_MAX_ITERATIONS"
[[ -n "${SPECKIT_RALPH_AGENT_CLI:-}" ]] && [[ "$AGENT_CLI_EXPLICIT" != "true" ]] && AGENT_CLI="$SPECKIT_RALPH_AGENT_CLI"

#endregion

#region Helper Functions

print_header() {
    local iteration=$1
    local max=$2
    local border
    border=$(printf '=%.0s' {1..60})

    echo ""
    echo -e "\033[36m$border\033[0m"
    echo -e "\033[36m  Ralph Loop - $FEATURE_NAME\033[0m"
    echo -e "\033[37m  Iteration $iteration of $max\033[0m"
    echo -e "\033[36m$border\033[0m"
    echo ""
}

print_status() {
    local iteration=$1
    local status=$2
    local message=$3
    local timestamp
    timestamp=$(date +"%H:%M:%S")

    local icon color
    case "$status" in
        running)  icon="o"; color="\033[36m" ;;
        success)  icon="*"; color="\033[32m" ;;
        failure)  icon="x"; color="\033[31m" ;;
        skipped)  icon="-"; color="\033[33m" ;;
        *)        icon="o"; color="\033[37m" ;;
    esac

    echo -ne "\033[90m[$timestamp] \033[0m"
    echo -ne "${color}${icon}\033[0m"
    echo -ne " \033[37mIteration $iteration\033[0m"
    if [[ -n "$message" ]]; then
        echo -e " \033[90m- $message\033[0m"
    else
        echo ""
    fi
}

get_incomplete_task_count() {
    local path="$1"
    if [[ ! -f "$path" ]]; then
        printf "0"
        return 0
    fi
    local count
    count=$(grep -c '^- \[ \]' "$path" 2>/dev/null) || true
    echo "${count:-0}"
}

initialize_progress_file() {
    local path=$1
    local feature=$2

    if [[ ! -f "$path" ]]; then
        local timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        cat > "$path" << EOF
# Ralph Progress Log

Feature: $feature
Started: $timestamp

## Codebase Patterns

[Patterns discovered during implementation - updated by agent]

---

EOF
        echo -e "\033[90mCreated progress log: $path\033[0m"
    fi
}

invoke_copilot_iteration() {
    local model=$1
    local iteration=$2
    local work_dir=$3

    # Simple prompt - the speckit.ralph agent already knows to complete one work unit
    local prompt="Iteration $iteration - Complete one work unit from tasks.md"

    # Only show debug info when verbose
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: Prompt = $prompt\033[0m" >&2
        echo -e "\033[35mDEBUG: WorkDir = $work_dir\033[0m" >&2
        echo -e "\033[35mDEBUG: AgentCLI = $AGENT_CLI\033[0m" >&2
    fi

    # Change to working directory if specified
    local original_dir
    original_dir=$(pwd)
    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        cd "$work_dir"
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "\033[35mDEBUG: Changed to $work_dir\033[0m" >&2
        fi
    fi

    # Always stream copilot output in real-time so user can see what the agent is doing
    echo "" >&2
    echo -e "\033[36m--- Copilot Agent Output ---\033[0m" >&2

    local exit_code=0
    local output_lines=()

    # Stream output line by line - use speckit.ralph.iterate agent
    while IFS= read -r line; do
        echo "$line" >&2
        output_lines+=("$line")
    done < <("$AGENT_CLI" --agent speckit.ralph.iterate -p "$prompt" --model "$model" --yolo -s 2>&1) || exit_code=$?

    echo -e "\033[36m--- End Agent Output ---\033[0m" >&2
    echo "" >&2

    # Restore original directory
    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        cd "$original_dir"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: $AGENT_CLI exit code = $exit_code\033[0m" >&2
    fi

    # Join output lines for return
    local output
    output=$(printf '%s\n' "${output_lines[@]}")

    # Return output via stdout, exit code via return
    echo "$output"
    return $exit_code
}

test_completion_signal() {
    local output=$1
    echo "$output" | grep -q '<promise>COMPLETE</promise>'
}

print_summary() {
    local iterations_run=$1
    local status_label=$2
    local status_color=$3

    local border
    border=$(printf '=%.0s' {1..60})

    local final_tasks
    final_tasks=$(get_incomplete_task_count "$TASKS_PATH")
    local tasks_completed=$((INITIAL_TASKS - final_tasks))

    echo ""
    echo -e "\033[36m$border\033[0m"
    echo -e "\033[36m  Ralph Loop Summary\033[0m"
    echo -e "\033[36m$border\033[0m"
    echo -e "  \033[37mIterations run: $iterations_run\033[0m"
    echo -e "  \033[37mTasks completed: $tasks_completed\033[0m"
    echo -e "  \033[37mTasks remaining: $final_tasks\033[0m"
    echo -ne "  \033[37mStatus: \033[0m"
    echo -e "${status_color}${status_label}\033[0m"
}

#endregion

#region Signal Handling

INTERRUPTED=false

cleanup() {
    INTERRUPTED=true
    echo ""
    echo -e "\033[33mInterrupted by user\033[0m"
}

trap cleanup SIGINT SIGTERM

#endregion

#region Main Loop

# Initialize progress file
initialize_progress_file "$PROGRESS_PATH" "$FEATURE_NAME"

# Check initial task count
INITIAL_TASKS=$(get_incomplete_task_count "$TASKS_PATH")
if [[ "$INITIAL_TASKS" -eq 0 ]]; then
    echo -e "\033[32mAll tasks are already complete!\033[0m"
    echo "<promise>COMPLETE</promise>"
    exit 0
fi

echo -e "\033[37mFound $INITIAL_TASKS incomplete task(s)\033[0m"

# Iteration tracking
iteration=1
consecutive_failures=0
max_consecutive_failures=3
completed=false
circuit_breaker=false

while [[ $iteration -le $MAX_ITERATIONS && "$completed" == "false" && "$INTERRUPTED" == "false" && "$circuit_breaker" == "false" ]]; do
    print_header "$iteration" "$MAX_ITERATIONS"
    print_status "$iteration" "running" "Starting iteration"

    # Invoke Copilot CLI with speckit.ralph.iterate agent
    set +e
    output=$(invoke_copilot_iteration \
        "$MODEL" \
        "$iteration" \
        "$WORKING_DIRECTORY")
    exit_code=$?
    set -e

    # Check for completion signal
    if test_completion_signal "$output"; then
        print_status "$iteration" "success" "COMPLETE signal received"
        completed=true
        break
    fi

    # Check exit code
    if [[ $exit_code -ne 0 ]]; then
        ((consecutive_failures++))
        print_status "$iteration" "failure" "Exit code $exit_code (failure $consecutive_failures/$max_consecutive_failures)"

        if [[ $consecutive_failures -ge $max_consecutive_failures ]]; then
            echo -e "\033[31mToo many consecutive failures. Stopping loop.\033[0m"
            circuit_breaker=true
            break
        fi
    else
        consecutive_failures=0
        print_status "$iteration" "success" "Iteration completed"
    fi

    # Check remaining tasks
    remaining_tasks=$(get_incomplete_task_count "$TASKS_PATH")
    if [[ "$remaining_tasks" -eq 0 ]]; then
        echo -e "\033[32mAll tasks complete!\033[0m"
        completed=true
        break
    fi

    echo -e "\033[90m$remaining_tasks task(s) remaining\033[0m"

    ((iteration++))
done

#endregion

#region Summary

iterations_run=$((iteration > MAX_ITERATIONS ? MAX_ITERATIONS : iteration))
if [[ "$completed" == "true" ]]; then
    # Completed via signal or all tasks done
    iterations_run=$iteration
fi

if [[ "$completed" == "true" ]]; then
    print_summary "$iterations_run" "COMPLETED" "\033[32m"
    exit 0
elif [[ "$INTERRUPTED" == "true" ]]; then
    print_summary "$((iteration - 1))" "INTERRUPTED" "\033[33m"
    exit 130
elif [[ "$circuit_breaker" == "true" ]]; then
    print_summary "$iteration" "FAILED" "\033[31m"
    exit 1
else
    print_summary "$((iteration - 1))" "ITERATION LIMIT REACHED" "\033[33m"
    exit 1
fi

#endregion
