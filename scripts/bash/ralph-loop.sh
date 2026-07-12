#!/usr/bin/env bash
#
# ralph-loop.sh - Ralph loop orchestrator for autonomous implementation
#
# Executes an AI agent CLI in a controlled loop, processing tasks from tasks.md.
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXTENSION_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
ITERATE_COMMAND_PATH="$EXTENSION_ROOT/commands/iterate.md"

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
            printf 'Unknown option: %s\n' "$1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$FEATURE_NAME" || -z "$TASKS_PATH" || -z "$SPEC_DIR" ]]; then
    printf '%s\n' "Error: Missing required arguments" >&2
    printf 'Usage: %s --feature-name NAME --tasks-path PATH --spec-dir DIR [--max-iterations N] [--model MODEL] [--agent-cli CLI] [--verbose]\n' "$0" >&2
    exit 1
fi

#endregion

#region Resolve Paths

REPO_ROOT="$(pwd -P)"
TASKS_PATH="$(realpath "$TASKS_PATH")"
SPEC_DIR="$(realpath "$SPEC_DIR")"
PROGRESS_PATH="$SPEC_DIR/progress.md"
MEMORY_PATH="$SPEC_DIR/ralph-memory.md"
MEMORY_TEMPLATE_PATH="$EXTENSION_ROOT/templates/ralph-memory.md"

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
    local cfg in_commit_block raw_line line trimmed key value

    for cfg in "$config_path" "$local_config_path"; do
        if [[ -f "$cfg" ]]; then
            in_commit_block=false
            while IFS= read -r raw_line; do
                # Strip trailing whitespace/CRLF only; preserve leading whitespace to detect nesting
                line=$(printf '%s\n' "$raw_line" | sed 's/[[:space:]]*$//')
                [[ -z "$line" || "$line" == \#* ]] && continue
                if [[ "$line" == [[:space:]]* ]]; then
                    # Indented line — process only when inside the commit: block
                    if [[ "$in_commit_block" == "true" ]]; then
                        trimmed=$(printf '%s\n' "$line" | sed 's/^[[:space:]]*//')
                        key=$(printf '%s\n' "$trimmed" | sed 's/:.*//' | tr -d ' ')
                        value=$(printf '%s\n' "$trimmed" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
                        case "$key" in
                            style) CONFIG_COMMIT_STYLE="$value" ;;
                            scope) CONFIG_COMMIT_SCOPE="$value" ;;
                            issue) CONFIG_COMMIT_ISSUE="$value" ;;
                        esac
                    fi
                else
                    # Top-level key — exit any active nested block first
                    in_commit_block=false
                    key=$(printf '%s\n' "$line" | sed 's/:.*//' | tr -d ' ')
                    value=$(printf '%s\n' "$line" | sed 's/^[^:]*:[[:space:]]*//' | sed 's/^"//' | sed 's/"$//')
                    case "$key" in
                        model) CONFIG_MODEL="$value" ;;
                        max_iterations) CONFIG_MAX_ITERATIONS="$value" ;;
                        agent_cli) CONFIG_AGENT_CLI="$value" ;;
                        commit) in_commit_block=true ;;
                        commit.*) CONFIG_COMMIT_FLATTENED=true ;;
                    esac
                fi
            done < "$cfg"
        fi
    done
}

resolve_commit_policy() {
    local raw_style="${CONFIG_COMMIT_STYLE:-}"

    if [[ "${CONFIG_COMMIT_FLATTENED:-false}" == "true" ]]; then
        printf 'commit-policy-invalid: commit policy keys must be nested under a commit: block, not as top-level dot-separated keys\n' >&2
        return 1
    fi

    if [[ -z "$raw_style" ]]; then
        COMMIT_POLICY_STYLE="legacy"
    elif [[ "$raw_style" == "legacy" || "$raw_style" == "conventional" ]]; then
        COMMIT_POLICY_STYLE="$raw_style"
    else
        printf 'commit-policy-invalid: unsupported commit.style value: %s\n' "$raw_style" >&2
        return 1
    fi

    COMMIT_POLICY_SCOPE="${CONFIG_COMMIT_SCOPE:-ralph}"
    COMMIT_POLICY_ISSUE="${CONFIG_COMMIT_ISSUE:-}"
    return 0
}

infer_issue_number() {
    local branch="$1"
    if [[ "$branch" =~ ^([0-9]+)[-_] ]]; then
        printf '%d\n' "$((10#${BASH_REMATCH[1]}))"
    fi
}

build_commit_subject() {
    local feature_name="$1"
    local work_unit_title="$2"
    local branch="$3"
    local commit_summary="${4:-}"
    local issue_suffix=""

    if [[ "${COMMIT_POLICY_ISSUE:-}" == "auto" ]]; then
        local issue_num
        issue_num=$(infer_issue_number "$branch")
        if [[ -n "$issue_num" ]]; then
            issue_suffix=" #$issue_num"
        fi
    fi

    if [[ "${COMMIT_POLICY_STYLE:-legacy}" == "conventional" ]]; then
        local scope="${COMMIT_POLICY_SCOPE:-ralph}"
        local payload="${commit_summary:-$work_unit_title}"
        printf '%s\n' "feat($scope): $payload$issue_suffix"
    else
        printf '%s\n' "feat($feature_name): $work_unit_title$issue_suffix"
    fi
}

# Commit policy config variables (populated by load_ralph_config)
CONFIG_COMMIT_STYLE=""
CONFIG_COMMIT_SCOPE=""
CONFIG_COMMIT_ISSUE=""
CONFIG_COMMIT_FLATTENED=false

# Resolved commit policy variables (populated by resolve_commit_policy)
COMMIT_POLICY_STYLE=""
COMMIT_POLICY_SCOPE=""
COMMIT_POLICY_ISSUE=""

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
        printf '%s\n' "0"
        return 0
    fi
    local count
    count=$(grep -c '^- \[ \]' "$path" 2>/dev/null) || true
    printf '%s\n' "${count:-0}"
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

---

EOF
        echo -e "\033[90mCreated progress log: $path\033[0m"
    fi
}

extract_ralph_memory_lines() {
    local path=$1
    local kind=$2

    awk -v kind="$kind" '
        { sub(/\r$/, "", $0) }
        /^```/ || /^~~~/ { fenced = !fenced; next }
        fenced { next }
        kind == "h1" && /^# / { print; next }
        kind == "h2" && /^## / { print; next }
        kind == "feature" && /^Feature:/ { print; next }
        kind == "started" && /^Started:/ { print; next }
    ' "$path"
}

is_valid_utc_timestamp() {
    local value=$1
    local normalized

    [[ "$value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || return 1

    normalized=$(date -u -d "$value" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || true
    if [[ "$normalized" == "$value" ]]; then
        return 0
    fi

    normalized=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$value" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null) || true
    [[ "$normalized" == "$value" ]]
}

load_ralph_memory_schema() {
    local template_path=$1
    local expected_sections="## Codebase Patterns
## Decisions
## Gotchas
## Reusable Commands
## Do Not Repeat
## Current Handoff"
    local actual_sections
    local title_count
    local feature_token_count
    local started_token_count
    local unresolved_tokens

    if [[ ! -f "$template_path" || ! -r "$template_path" ]]; then
        printf 'template-unavailable: shared memory template is missing or unreadable: %s\n' "$template_path" >&2
        return 1
    fi

    title_count=$(extract_ralph_memory_lines "$template_path" "h1" | grep -c '^# Ralph Memory$') || true
    feature_token_count=$(grep -c '^Feature: {{FEATURE_NAME}}$' "$template_path" 2>/dev/null) || true
    started_token_count=$(grep -c '^Started: {{STARTED_AT}}$' "$template_path" 2>/dev/null) || true
    actual_sections=$(extract_ralph_memory_lines "$template_path" "h2")
    unresolved_tokens=$(grep -Eo '\{\{[^}]+\}\}' "$template_path" 2>/dev/null | grep -Ev '^\{\{(FEATURE_NAME|STARTED_AT)\}\}$') || true

    if [[ "$title_count" -ne 1 ]] ||
       [[ $(extract_ralph_memory_lines "$template_path" "h1" | wc -l | tr -d ' ') -ne 1 ]] ||
       [[ "$feature_token_count" -ne 1 ]] ||
       [[ "$started_token_count" -ne 1 ]] ||
       [[ "$actual_sections" != "$expected_sections" ]] ||
       [[ -n "$unresolved_tokens" ]] ||
       LC_ALL=C grep -q $'\r' "$template_path"; then
        printf 'template-unavailable: shared memory template is structurally invalid: %s\n' "$template_path" >&2
        return 1
    fi

    # Once the canonical template passes its own contract, use its structure as
    # the schema for feature-instance validation.
    RALPH_MEMORY_TITLE=$(extract_ralph_memory_lines "$template_path" "h1")
    RALPH_MEMORY_SECTIONS=()
    while IFS= read -r section; do
        RALPH_MEMORY_SECTIONS+=("$section")
    done < <(extract_ralph_memory_lines "$template_path" "h2")

    return 0
}

validate_ralph_memory_template() {
    local template_path=$1
    load_ralph_memory_schema "$template_path"
}

get_current_handoff_content() {
    local memory_path=$1

    awk '
        { sub(/\r$/, "", $0) }
        /^```/ || /^~~~/ {
            if (in_handoff) { print }
            fenced = !fenced
            next
        }
        !fenced && /^## Current Handoff$/ { in_handoff = 1; next }
        in_handoff { print }
    ' "$memory_path" | sed '/^[[:space:]]*$/d'
}

validate_ralph_memory_file() {
    local template_path=$1
    local memory_path=$2
    local feature=$3
    local completion_required=${4:-false}
    local defects=()
    local title_count
    local all_h1_count
    local feature_count
    local feature_value
    local started_count
    local started_value
    local actual_sections
    local expected_sections=""
    local section
    local section_count
    local known

    load_ralph_memory_schema "$template_path" || return 1

    if [[ ! -f "$memory_path" || ! -r "$memory_path" ]]; then
        printf 'template-unavailable: feature memory is missing or unreadable: %s\n' "$memory_path" >&2
        return 1
    fi

    title_count=$(extract_ralph_memory_lines "$memory_path" "h1" | grep -Fxc "$RALPH_MEMORY_TITLE") || true
    all_h1_count=$(extract_ralph_memory_lines "$memory_path" "h1" | wc -l | tr -d ' ')
    if [[ "$title_count" -ne 1 || "$all_h1_count" -ne 1 ]]; then
        defects+=("title-invalid: expected exactly one '# Ralph Memory' title")
    fi

    feature_count=$(extract_ralph_memory_lines "$memory_path" "feature" | wc -l | tr -d ' ')
    feature_value=$(extract_ralph_memory_lines "$memory_path" "feature" | sed 's/^Feature:[[:space:]]*//')
    if [[ "$feature_count" -ne 1 || -z "$feature_value" || "$feature_value" != "$feature" ]]; then
        defects+=("feature-invalid: expected exactly one non-empty Feature field matching '$feature'")
    fi

    started_count=$(extract_ralph_memory_lines "$memory_path" "started" | wc -l | tr -d ' ')
    started_value=$(extract_ralph_memory_lines "$memory_path" "started" | sed 's/^Started:[[:space:]]*//')
    if [[ "$started_count" -ne 1 ]] || ! is_valid_utc_timestamp "$started_value"; then
        defects+=("started-invalid: expected exactly one UTC Started timestamp")
    fi

    # Keep defect categories stable: all missing-section diagnostics precede
    # every duplicate-section diagnostic.
    for section in "${RALPH_MEMORY_SECTIONS[@]}"; do
        section_count=$(extract_ralph_memory_lines "$memory_path" "h2" | grep -Fxc "$section") || true
        if [[ "$section_count" -eq 0 ]]; then
            defects+=("section-missing: $section")
        fi
        if [[ -z "$expected_sections" ]]; then
            expected_sections="$section"
        else
            expected_sections="$expected_sections
$section"
        fi
    done

    for section in "${RALPH_MEMORY_SECTIONS[@]}"; do
        section_count=$(extract_ralph_memory_lines "$memory_path" "h2" | grep -Fxc "$section") || true
        if [[ "$section_count" -gt 1 ]]; then
            defects+=("section-duplicate: $section")
        fi
    done

    while IFS= read -r section; do
        [[ -z "$section" ]] && continue
        known=false
        local expected
        for expected in "${RALPH_MEMORY_SECTIONS[@]}"; do
            if [[ "$section" == "$expected" ]]; then
                known=true
                break
            fi
        done
        if [[ "$known" == "false" ]]; then
            defects+=("section-unexpected: $section")
        fi
    done < <(extract_ralph_memory_lines "$memory_path" "h2")

    actual_sections=$(extract_ralph_memory_lines "$memory_path" "h2")
    if [[ "$actual_sections" != "$expected_sections" ]]; then
        defects+=("section-order: H2 headings do not match canonical template order")
    fi

    if grep -Eq '\{\{[^}]+\}\}' "$memory_path" 2>/dev/null; then
        defects+=("token-unresolved: feature memory contains an unresolved template token")
    fi

    if [[ "$completion_required" == "true" ]] &&
       [[ $(get_current_handoff_content "$memory_path") != '- Feature complete; no handoff required.' ]]; then
        defects+=("handoff-invalid: Current Handoff must contain only '- Feature complete; no handoff required.'")
    fi

    if [[ ${#defects[@]} -gt 0 ]]; then
        printf '%s\n' "${defects[@]}" >&2
        return 1
    fi

    return 0
}

render_ralph_memory() {
    local template_path=$1
    local output_path=$2
    local feature=$3
    local started_at=$4
    local line

    : > "$output_path" || return 1
    while IFS= read -r line || [[ -n "$line" ]]; do
        line=${line//'{{FEATURE_NAME}}'/$feature}
        line=${line//'{{STARTED_AT}}'/$started_at}
        printf '%s\n' "$line" >> "$output_path" || return 1
    done < "$template_path"
}

prepare_ralph_memory() {
    local template_path=$1
    local memory_path=$2
    local feature=$3
    local started_at
    local temporary_path

    validate_ralph_memory_template "$template_path" || return 1

    if [[ ! -e "$memory_path" ]]; then
        started_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        temporary_path=$(mktemp "${memory_path}.tmp.XXXXXX") || {
            printf 'template-unavailable: cannot create memory render target: %s\n' "$memory_path" >&2
            return 1
        }

        if ! render_ralph_memory "$template_path" "$temporary_path" "$feature" "$started_at"; then
            rm -f "$temporary_path"
            printf 'template-unavailable: cannot render shared memory template: %s\n' "$template_path" >&2
            return 1
        fi

        # A hard-link publish is atomic and create-new: if another process won
        # the race, ln fails without replacing the existing feature memory.
        if ! ln "$temporary_path" "$memory_path" 2>/dev/null && [[ ! -e "$memory_path" ]]; then
            rm -f "$temporary_path"
            printf 'template-unavailable: cannot publish feature memory: %s\n' "$memory_path" >&2
            return 1
        fi
        rm -f "$temporary_path"
    fi

    validate_ralph_memory_file "$template_path" "$memory_path" "$feature"
}

get_git_head_snapshot() {
    local repo_root=$1
    local head

    head=$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null) || return 0
    printf '%s\n' "$head"
}

get_task_state_snapshot() {
    local tasks_path=$1

    if [[ ! -f "$tasks_path" ]]; then
        printf '%s\n' "missing"
        return 0
    fi

    cksum < "$tasks_path" | awk '{ printf "%s:%s\n", $1, $2 }'
}

validate_iteration_commit_history() {
    local repo_root=$1
    local before_head=$2
    local before_task_state=$3
    local before_incomplete=$4
    local after_incomplete=$5
    local agent_exit=$6
    local tasks_path=$7
    local progress_path=$8
    local memory_path=$9
    local after_head
    local after_task_state
    local tasks_relative
    local progress_relative
    local memory_relative
    local commits
    local commit
    local paths
    local path
    local has_tasks
    local has_progress
    local has_memory
    local has_substantive
    local violations=()

    after_head=$(get_git_head_snapshot "$repo_root")
    after_task_state=$(get_task_state_snapshot "$tasks_path")

    # Preserve compatibility with callers outside a Git worktree. The strict
    # repository preflight belongs to the centralized completion gate; when a
    # HEAD exists, all checks below are mandatory and read-only.
    if [[ -z "$before_head" || -z "$after_head" ]]; then
        return 0
    fi

    tasks_relative=${tasks_path#"$repo_root"/}
    progress_relative=${progress_path#"$repo_root"/}
    memory_relative=${memory_path#"$repo_root"/}

    if [[ "$before_head" == "$after_head" ]]; then
        if [[ "$after_incomplete" -lt "$before_incomplete" ]]; then
            violations+=("coordinated-commit-invalid: completed task state was not included in a new work-unit commit")
        elif [[ "$after_task_state" != "$before_task_state" ]]; then
            violations+=("failed-iteration-task-state: failed or no-work iteration changed tasks.md")
        fi
    else
        if [[ "$agent_exit" -ne 0 || "$after_incomplete" -ge "$before_incomplete" ]]; then
            violations+=("failed-iteration-advanced-head: failed or no-work iteration advanced HEAD")
        fi

        commits=$(git -C "$repo_root" rev-list --reverse "$before_head..$after_head" 2>/dev/null) || {
            violations+=("coordinated-commit-invalid: new history cannot be inspected from the pre-iteration HEAD")
            commits=""
        }

        while IFS= read -r commit; do
            [[ -z "$commit" ]] && continue
            paths=$(git -C "$repo_root" diff-tree --root --no-commit-id --name-only -r "$commit" 2>/dev/null) || {
                violations+=("coordinated-commit-invalid: cannot inspect commit $commit")
                continue
            }
            has_tasks=false
            has_progress=false
            has_memory=false
            has_substantive=false

            while IFS= read -r path; do
                [[ -z "$path" ]] && continue
                case "$path" in
                    "$tasks_relative") has_tasks=true ;;
                    "$progress_relative") has_progress=true ;;
                    "$memory_relative") has_memory=true ;;
                    *) has_substantive=true ;;
                esac
            done <<< "$paths"

            if [[ "$has_substantive" == "false" ]]; then
                violations+=("bookkeeping-only: commit $commit contains no substantive path")
            fi
            if [[ "$has_tasks" == "false" || "$has_progress" == "false" || "$has_memory" == "false" ]]; then
                violations+=("coordinated-commit-invalid: commit $commit must include tasks.md, progress.md, and ralph-memory.md")
            fi
        done <<< "$commits"
    fi

    if [[ ${#violations[@]} -gt 0 ]]; then
        printf '%s\n' "${violations[@]}" >&2
        return 1
    fi

    return 0
}

validate_initial_state_postconditions() {
    local repo_root=$1
    local tasks_path=$2
    local progress_path=$3
    local memory_path=$4
    local path
    local relative_path
    local defects=()

    # Existing commits predate this Ralph process and may legitimately be
    # human-authored spec/task refinements. Coordinated commit shape is only
    # enforceable for commits created after an iteration snapshots HEAD.
    if [[ ! -f "$tasks_path" ]]; then
        defects+=("state-artifact-missing: required tasks file not found: $tasks_path")
    fi
    if [[ ! -f "$progress_path" ]]; then
        defects+=("state-artifact-missing: required progress file not found: $progress_path")
    fi
    if [[ ! -f "$memory_path" ]]; then
        defects+=("state-artifact-missing: required memory file not found: $memory_path")
    fi
    for path in "$tasks_path" "$progress_path" "$memory_path"; do
        [[ ! -f "$path" ]] && continue
        relative_path=${path#"$repo_root"/}
        if ! git -C "$repo_root" ls-files --error-unmatch -- "$relative_path" >/dev/null 2>&1; then
            defects+=("state-artifact-untracked: required feature state file is not Git-tracked: $relative_path")
        fi
    done
    if [[ ${#defects[@]} -gt 0 ]]; then
        printf '%s\n' "${defects[@]}" >&2
        return 1
    fi
    return 0
}

validate_completion_gate() {
    local agent_result=$1
    local commit_postconditions=$2
    local repo_root=$3
    local tasks_path=$4
    local template_path=$5
    local memory_path=$6
    local feature=$7
    local state_postconditions=${8:-0}
    local incomplete
    local memory_output
    local status_output
    local status_exit
    local line
    local defects=()

    if [[ "$agent_result" != "absent" && "$agent_result" -ne 0 ]]; then
        defects+=("agent-result-invalid: completion requires a successful agent result")
    fi

    incomplete=$(get_incomplete_task_count "$tasks_path")
    if [[ "$incomplete" -ne 0 ]]; then
        defects+=("tasks-incomplete: $incomplete task(s) remain")
    fi

    if ! memory_output=$(validate_ralph_memory_file "$template_path" "$memory_path" "$feature" true 2>&1); then
        while IFS= read -r line; do
            [[ -n "$line" ]] && defects+=("$line")
        done <<< "$memory_output"
    fi

    if [[ "$commit_postconditions" -ne 0 ]]; then
        defects+=("commit-postcondition-invalid: iteration history failed coordinated commit validation")
    fi
    if [[ "$state_postconditions" -ne 0 ]]; then
        defects+=("state-postcondition-invalid: current feature state failed validation")
    fi

    if status_output=$(git -C "$repo_root" status --short --untracked-files=all 2>&1); then
        status_exit=0
    else
        status_exit=$?
    fi
    if [[ "$status_exit" -ne 0 ]]; then
        defects+=("git-status-invalid: git status failed: $status_output")
    elif [[ -n "$status_output" ]]; then
        while IFS= read -r line; do
            defects+=("dirty-path: $line")
        done <<< "$status_output"
    fi

    if [[ ${#defects[@]} -gt 0 ]]; then
        printf '%s\n' "${defects[@]}" >&2
        return 1
    fi

    return 0
}

get_agent_cli_kind() {
    local cli=$1
    local cli_name
    cli=${cli//\\//}
    cli_name=$(basename "$cli")
    # tr (not ${var,,}) so this works on bash 3.2, the default on macOS
    cli_name=$(printf '%s' "$cli_name" | tr '[:upper:]' '[:lower:]')
    cli_name=${cli_name%.exe}
    cli_name=${cli_name%.cmd}
    cli_name=${cli_name%.bat}

    case "$cli_name" in
        copilot) echo "copilot" ;;
        codex) echo "codex" ;;
        claude) echo "claude" ;;
        *) echo "unsupported" ;;
    esac
}

get_specify_integration_field() {
    local repo_root=$1
    local field=$2
    local integration_path="$repo_root/.specify/integration.json"

    [[ -f "$integration_path" ]] || return 0

    sed -nE "/\"$field\"[[:space:]]*:/ { s/.*\"$field\"[[:space:]]*:[[:space:]]*\"([^\"]*)\".*/\1/p; q; }" "$integration_path"
}

get_specify_integration_invoke_separator() {
    local repo_root=$1
    local integration
    local separator
    local raw_options

    integration=$(get_specify_integration_field "$repo_root" "integration")
    separator=$(get_specify_integration_field "$repo_root" "invoke_separator")
    raw_options=$(get_specify_integration_field "$repo_root" "raw_options")

    if [[ -n "$integration" && "$integration" != "copilot" ]]; then
        printf "."
        return 0
    fi

    if [[ $raw_options =~ (^|[[:space:]])--skills($|[[:space:]]) ]]; then
        printf "-"
        return 0
    fi

    separator=${separator:-.}
    if [[ "$separator" != "." && "$separator" != "-" ]]; then
        separator="."
    fi
    printf "%s" "$separator"
}

build_integration_command_name() {
    local command_name=$1
    local separator=${2:-.}
    local parts=()
    local result
    local part

    IFS='.' read -r -a parts <<< "$command_name"
    result="${parts[0]}"
    for part in "${parts[@]:1}"; do
        result+="${separator}${part}"
    done

    printf "%s" "$result"
}

is_copilot_skills_mode() {
    local invoke_separator=$1
    [[ "$invoke_separator" == "-" ]]
}

build_copilot_iteration_prompt() {
    local agent_name=$1
    local invoke_separator=$2
    local prompt=$3

    if is_copilot_skills_mode "$invoke_separator"; then
        printf "/%s %s" "$agent_name" "$prompt"
        return 0
    fi

    printf "%s" "$prompt"
}

build_iteration_prompt() {
    local iteration=$1
    local command_text=""

    if [[ -f "$ITERATE_COMMAND_PATH" ]]; then
        command_text=$(cat "$ITERATE_COMMAND_PATH")
    else
        command_text="Complete at most one work unit from tasks.md. Mark completed tasks, update progress.md, commit only when the current user story is complete, and output <promise>COMPLETE</promise> when all tasks are done."
    fi

    cat << EOF
You are running Ralph iteration $iteration.

Follow the speckit.ralph.iterate command below exactly for this single iteration.

$command_text
EOF

    if [[ -n "${COMMIT_POLICY_STYLE:-}" ]]; then
        cat << EOF
## Resolved Commit Policy

The Ralph orchestrator has pre-validated the commit configuration. Use this format when creating the work-unit commit:
- Style: ${COMMIT_POLICY_STYLE}
- Scope: ${COMMIT_POLICY_SCOPE:-ralph}
- Issue: ${COMMIT_POLICY_ISSUE:-disabled}
EOF
    fi
}

invoke_copilot_iteration() {
    local model=$1
    local iteration=$2
    local work_dir=$3

    # Simple prompt - the speckit.ralph agent already knows to complete one work unit
    local base_prompt="Iteration $iteration - Complete one work unit from tasks.md"
    local prompt
    local invoke_separator
    local agent_name

    invoke_separator=$(get_specify_integration_invoke_separator "$work_dir")
    agent_name=$(build_integration_command_name "speckit.ralph.iterate" "$invoke_separator")
    prompt=$(build_copilot_iteration_prompt "$agent_name" "$invoke_separator" "$base_prompt")

    # Only show debug info when verbose
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: Prompt = $prompt\033[0m" >&2
        echo -e "\033[35mDEBUG: WorkDir = $work_dir\033[0m" >&2
        echo -e "\033[35mDEBUG: AgentCLI = $AGENT_CLI\033[0m" >&2
        echo -e "\033[35mDEBUG: AgentName = $agent_name\033[0m" >&2
        echo -e "\033[35mDEBUG: InvokeSeparator = $invoke_separator\033[0m" >&2
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
    local output_file
    output_file="$(mktemp "${TMPDIR:-/tmp}/ralph-copilot-output.XXXXXX")"

    set +e
    if is_copilot_skills_mode "$invoke_separator"; then
        "$AGENT_CLI" -p "$prompt" --model "$model" --yolo -s 2>&1 | while IFS= read -r line; do
            printf '%s\n' "$line" >&2
            printf '%s\n' "$line" >> "$output_file"
        done
        exit_code=${PIPESTATUS[0]}
    else
        "$AGENT_CLI" --agent "$agent_name" -p "$prompt" --model "$model" --yolo -s 2>&1 | while IFS= read -r line; do
            printf '%s\n' "$line" >&2
            printf '%s\n' "$line" >> "$output_file"
        done
        exit_code=${PIPESTATUS[0]}
    fi
    set -e

    echo -e "\033[36m--- End Agent Output ---\033[0m" >&2
    echo "" >&2

    # Restore original directory
    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        cd "$original_dir"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: $AGENT_CLI exit code = $exit_code\033[0m" >&2
    fi

    local output
    output=$(cat "$output_file")
    rm -f "$output_file"

    # Return output via stdout, exit code via return
    printf '%s\n' "$output"
    return $exit_code
}

is_agent_resolution_failure() {
    local output=$1
    printf '%s' "$output" | grep -Eiq 'No such agent|No such skill|Unknown agent|Unknown skill|agent .*not found|skill .*not found|error: unknown option'
}

invoke_claude_iteration() {
    local model=$1
    local iteration=$2
    local work_dir=$3

    # Claude Code has no registered speckit.ralph.iterate agent (that's a Copilot mechanism),
    # so inline the iterate command text into the prompt, the same way the codex path does.
    local prompt
    prompt=$(build_iteration_prompt "$iteration")

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: Prompt = Ralph iteration $iteration using $ITERATE_COMMAND_PATH\033[0m" >&2
        echo -e "\033[35mDEBUG: WorkDir = $work_dir\033[0m" >&2
        echo -e "\033[35mDEBUG: AgentCLI = $AGENT_CLI\033[0m" >&2
    fi

    local original_dir
    original_dir=$(pwd)
    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        cd "$work_dir"
        if [[ "$VERBOSE" == "true" ]]; then
            echo -e "\033[35mDEBUG: Changed to $work_dir\033[0m" >&2
        fi
    fi

    echo "" >&2
    echo -e "\033[36m--- Claude Agent Output ---\033[0m" >&2

    local exit_code=0
    local output_file
    output_file=$(mktemp)

    # Claude Code uses --dangerously-skip-permissions for unattended execution (vs copilot's --yolo -s).
    # Pipe through a loop and read PIPESTATUS so the agent exit code survives the redirection.
    set +e
    "$AGENT_CLI" -p "$prompt" --model "$model" --dangerously-skip-permissions 2>&1 | while IFS= read -r line; do
        printf '%s\n' "$line" >&2
        printf '%s\n' "$line" >> "$output_file"
    done
    exit_code=${PIPESTATUS[0]}
    set -e

    echo -e "\033[36m--- End Agent Output ---\033[0m" >&2
    echo "" >&2

    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        cd "$original_dir"
    fi

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: $AGENT_CLI exit code = $exit_code\033[0m" >&2
    fi

    local output
    output=$(cat "$output_file")
    rm -f "$output_file"

    printf '%s\n' "$output"
    return $exit_code
}

invoke_codex_iteration() {
    local model=$1
    local iteration=$2
    local work_dir=$3

    local prompt
    prompt=$(build_iteration_prompt "$iteration")

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: Prompt = Ralph iteration $iteration using $ITERATE_COMMAND_PATH\033[0m" >&2
        echo -e "\033[35mDEBUG: WorkDir = $work_dir\033[0m" >&2
        echo -e "\033[35mDEBUG: AgentCLI = $AGENT_CLI\033[0m" >&2
    fi

    echo "" >&2
    echo -e "\033[36m--- Codex Agent Output ---\033[0m" >&2

    local exit_code=0
    local output_file
    output_file=$(mktemp)
    local codex_args=(exec --json --model "$model" --sandbox danger-full-access)

    if [[ -n "$work_dir" && -d "$work_dir" ]]; then
        codex_args+=(--cd "$work_dir")
    fi

    set +e
    printf '%s' "$prompt" | "$AGENT_CLI" "${codex_args[@]}" - 2>&1 | while IFS= read -r line; do
        printf '%s\n' "$line" >&2
        printf '%s\n' "$line" >> "$output_file"
    done
    local pipeline_status=("${PIPESTATUS[@]}")
    exit_code=${pipeline_status[1]}
    set -e

    echo -e "\033[36m--- End Agent Output ---\033[0m" >&2
    echo "" >&2

    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "\033[35mDEBUG: $AGENT_CLI exit code = $exit_code\033[0m" >&2
    fi

    local output
    output=$(cat "$output_file")
    rm -f "$output_file"

    printf '%s\n' "$output"
    return $exit_code
}

invoke_agent_iteration() {
    local model=$1
    local iteration=$2
    local work_dir=$3
    local agent_kind
    agent_kind=$(get_agent_cli_kind "$AGENT_CLI")

    case "$agent_kind" in
        copilot)
            invoke_copilot_iteration "$model" "$iteration" "$work_dir"
            ;;
        codex)
            invoke_codex_iteration "$model" "$iteration" "$work_dir"
            ;;
        claude)
            invoke_claude_iteration "$model" "$iteration" "$work_dir"
            ;;
        *)
            printf 'Unsupported agent CLI: %s\n' "$AGENT_CLI" >&2
            printf '%s\n' "Supported agent CLIs: copilot, codex, claude" >&2
            return 2
            ;;
    esac
}

test_completion_signal() {
    local output=$1
    # Only honor the signal when it stands alone on a line (ignoring surrounding
    # whitespace/backticks). Agents often mention the token in prose — e.g.
    # "stopping here; no <promise>COMPLETE</promise>" — which must NOT complete the loop.
    printf '%s\n' "$output" | grep -Eq '^[[:space:]`]*<promise>COMPLETE</promise>[[:space:]`]*$'
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

# Prepare durable context before any task selection or agent invocation.
if ! prepare_ralph_memory "$MEMORY_TEMPLATE_PATH" "$MEMORY_PATH" "$FEATURE_NAME"; then
    exit 1
fi

# Validate commit policy before any agent invocation.
if ! resolve_commit_policy; then
    exit 1
fi

# Check initial task count
INITIAL_TASKS=$(get_incomplete_task_count "$TASKS_PATH")
if [[ "$INITIAL_TASKS" -eq 0 ]]; then
    initial_state_postconditions=0
    if ! validate_initial_state_postconditions "$REPO_ROOT" "$TASKS_PATH" "$PROGRESS_PATH" "$MEMORY_PATH"; then
        initial_state_postconditions=1
    fi
    if validate_completion_gate "absent" 0 "$REPO_ROOT" "$TASKS_PATH" "$MEMORY_TEMPLATE_PATH" "$MEMORY_PATH" "$FEATURE_NAME" "$initial_state_postconditions"; then
        echo -e "\033[32mAll tasks are already complete!\033[0m"
        echo "<promise>COMPLETE</promise>"
        exit 0
    fi
    exit 1
fi

# Initialize the audit log only when work remains. Completion validation is
# read-only and must not create a missing progress file while reporting an
# inconsistent task-zero repository.
initialize_progress_file "$PROGRESS_PATH" "$FEATURE_NAME"

echo -e "\033[37mFound $INITIAL_TASKS incomplete task(s)\033[0m"

# Iteration tracking
iteration=1
consecutive_failures=0
max_consecutive_failures=3
completed=false
circuit_breaker=false
fatal_failure=false

while [[ $iteration -le $MAX_ITERATIONS && "$completed" == "false" && "$INTERRUPTED" == "false" && "$circuit_breaker" == "false" && "$fatal_failure" == "false" ]]; do
    print_header "$iteration" "$MAX_ITERATIONS"
    print_status "$iteration" "running" "Starting iteration"

    # Revalidate before every fresh context. A failed or external iteration may
    # have left memory malformed since the preceding preparation.
    if ! prepare_ralph_memory "$MEMORY_TEMPLATE_PATH" "$MEMORY_PATH" "$FEATURE_NAME"; then
        fatal_failure=true
        break
    fi

    # Snapshot authoritative state immediately before the fresh agent context.
    iteration_head_before=$(get_git_head_snapshot "$REPO_ROOT")
    iteration_task_state_before=$(get_task_state_snapshot "$TASKS_PATH")
    iteration_tasks_before=$(get_incomplete_task_count "$TASKS_PATH")

    # Invoke configured agent CLI with speckit.ralph.iterate behavior
    set +e
    output=$(invoke_agent_iteration \
        "$MODEL" \
        "$iteration" \
        "$WORKING_DIRECTORY")
    exit_code=$?
    set -e

    iteration_tasks_after=$(get_incomplete_task_count "$TASKS_PATH")
    commit_postconditions=0
    if ! validate_iteration_commit_history \
        "$REPO_ROOT" \
        "$iteration_head_before" \
        "$iteration_task_state_before" \
        "$iteration_tasks_before" \
        "$iteration_tasks_after" \
        "$exit_code" \
        "$TASKS_PATH" \
        "$PROGRESS_PATH" \
        "$MEMORY_PATH"; then
        commit_postconditions=1
    fi

    completion_signaled=false
    if test_completion_signal "$output"; then
        completion_signaled=true
    fi

    # Every completion candidate uses the same strict, read-only gate. A bad
    # signal or inconsistent task-zero state fails immediately without a
    # reconciliation iteration or repository mutation.
    if [[ "$completion_signaled" == "true" || "$iteration_tasks_after" -eq 0 ]]; then
        if validate_completion_gate "$exit_code" "$commit_postconditions" "$REPO_ROOT" "$TASKS_PATH" "$MEMORY_TEMPLATE_PATH" "$MEMORY_PATH" "$FEATURE_NAME"; then
            print_status "$iteration" "success" "Completion gate passed"
            completed=true
        else
            print_status "$iteration" "failure" "Completion gate failed"
            fatal_failure=true
        fi
        break
    fi

    if [[ "$commit_postconditions" -ne 0 ]]; then
        print_status "$iteration" "failure" "Invalid work-unit commit history"
        fatal_failure=true
        break
    fi

    if [[ $exit_code -ne 0 ]] && is_agent_resolution_failure "$output"; then
        print_status "$iteration" "failure" "Agent command unavailable"
        echo -e "\033[31mResolved agent command is unavailable. Stopping loop before consuming more iterations.\033[0m"
        fatal_failure=true
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
    remaining_tasks=$iteration_tasks_after
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
elif [[ "$fatal_failure" == "true" ]]; then
    print_summary "$iteration" "FAILED" "\033[31m"
    exit 1
else
    print_summary "$((iteration - 1))" "ITERATION LIMIT REACHED" "\033[33m"
    exit 1
fi

#endregion
