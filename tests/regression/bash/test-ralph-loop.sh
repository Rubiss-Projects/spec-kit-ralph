#!/usr/bin/env bash
#
# Regression tests for ralph-loop.sh helper functions.
# Extracts and tests functions in isolation without running the full loop.
#
# Usage:
#   bash tests/regression/bash/test-ralph-loop.sh
#
# Exit codes:
#   0 - All tests passed
#   1 - One or more tests failed

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
FIXTURE_DIR="$SCRIPT_DIR/../fixtures"
SOURCE_SCRIPT="$REPO_ROOT/scripts/bash/ralph-loop.sh"
RUN_COMMAND="$REPO_ROOT/commands/run.md"
ITERATE_COMMAND="$REPO_ROOT/commands/iterate.md"
MEMORY_TEMPLATE="$REPO_ROOT/templates/ralph-memory-template.md"

# Test bookkeeping
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0
FAILURES=()

#region Test Harness

assert_eq() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    ((TESTS_RUN++))

    if [[ "$expected" == "$actual" ]]; then
        echo -e "  \033[32mPASS\033[0m $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "  \033[31mFAIL\033[0m $test_name"
        printf '         expected: [%s]\n' "$expected"
        printf '         actual:   [%s]\n' "$actual"
        ((TESTS_FAILED++))
        FAILURES+=("$test_name")
    fi
}

assert_true() {
    local test_name="$1"
    shift
    ((TESTS_RUN++))

    if "$@" >/dev/null 2>&1; then
        echo -e "  \033[32mPASS\033[0m $test_name"
        ((TESTS_PASSED++))
    else
        echo -e "  \033[31mFAIL\033[0m $test_name"
        printf '         command returned non-zero: %s\n' "$*"
        ((TESTS_FAILED++))
        FAILURES+=("$test_name")
    fi
}

assert_false() {
    local test_name="$1"
    shift
    ((TESTS_RUN++))

    if "$@" >/dev/null 2>&1; then
        echo -e "  \033[31mFAIL\033[0m $test_name"
        printf '         command should have failed but returned 0: %s\n' "$*"
        ((TESTS_FAILED++))
        FAILURES+=("$test_name")
    else
        echo -e "  \033[32mPASS\033[0m $test_name"
        ((TESTS_PASSED++))
    fi
}

section() {
    echo ""
    echo -e "\033[36m── $1 ──\033[0m"
}

#endregion

#region Extract Functions

# Source only the helper functions from ralph-loop.sh (not the main script body).
# We extract from the Helper Functions region to avoid triggering argument parsing.
extract_functions() {
    # Extract get_incomplete_task_count
    sed -n '/^get_incomplete_task_count()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract initialize_progress_file
    sed -n '/^initialize_progress_file()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract literal replacement helper
    sed -n '/^replace_all_literal()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract initialize_memory_file
    sed -n '/^initialize_memory_file()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract get_agent_cli_kind
    sed -n '/^get_agent_cli_kind()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract Spec Kit integration helpers
    sed -n '/^get_specify_integration_field()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^get_specify_integration_invoke_separator()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^build_integration_command_name()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^is_copilot_skills_mode()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^build_copilot_iteration_prompt()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract build_iteration_prompt
    sed -n '/^build_iteration_prompt()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract invoke_copilot_iteration
    sed -n '/^invoke_copilot_iteration()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract agent resolution failure helper
    sed -n '/^is_agent_resolution_failure()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract invoke_codex_iteration
    sed -n '/^invoke_codex_iteration()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract invoke_claude_iteration
    sed -n '/^invoke_claude_iteration()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract test_completion_signal
    sed -n '/^test_completion_signal()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract test_worktree_clean
    sed -n '/^test_worktree_clean()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract load_ralph_config
    sed -n '/^load_ralph_config()/,/^}/p' "$SOURCE_SCRIPT"
}

eval "$(extract_functions)"

#endregion

#region Tests: run command guardrails

section "run command guardrails"

assert_true "run treats input as launcher arguments only" grep -q "launcher arguments only" "$RUN_COMMAND"
assert_true "run ignores free-form implementation requests" grep -q "Free-form requests such as" "$RUN_COMMAND"
assert_true "run forbids inline implementation" grep -q "MUST NOT.*implement tasks" "$RUN_COMMAND"
assert_true "run warns that ignored text comes from tasks.md scope" grep -q "Ralph selects work from.*tasks.md" "$RUN_COMMAND"

#endregion

#region Tests: iterate command memory contract

section "iterate command memory contract"

assert_true "iterate reads ralph memory first" grep -q "ralph-memory.md.*cross-iteration memory bridge" "$ITERATE_COMMAND"
assert_true "iterate treats progress as audit trail" grep -q "progress.md.*append-only audit trail" "$ITERATE_COMMAND"
assert_true "iterate preserves memory sections" grep -q "Preserve all existing memory sections" "$ITERATE_COMMAND"
assert_true "iterate records do-not-repeat entries" grep -q "## Do Not Repeat" "$ITERATE_COMMAND"
assert_true "iterate records current handoff" grep -q "## Current Handoff" "$ITERATE_COMMAND"
memory_step_line=$(grep -n "5\\. \\*\\*Update memory and progress\\*\\*" "$ITERATE_COMMAND" | cut -d: -f1)
commit_step_line=$(grep -n "6\\. \\*\\*Commit on user story completion\\*\\*" "$ITERATE_COMMAND" | cut -d: -f1)
assert_true "iterate updates memory before commit" test "$memory_step_line" -lt "$commit_step_line"
assert_true "iterate forbids bookkeeping-only commits" grep -q "DO NOT create bookkeeping-only commits" "$ITERATE_COMMAND"
assert_true "iterate requires clean completion" grep -q "Successful completion must leave.*git status --short.*clean" "$ITERATE_COMMAND"
assert_true "memory template exists" test -f "$MEMORY_TEMPLATE"
assert_true "memory template has feature placeholder" grep -q "{{FEATURE_NAME}}" "$MEMORY_TEMPLATE"
assert_true "memory template has timestamp placeholder" grep -q "{{STARTED_AT}}" "$MEMORY_TEMPLATE"

#endregion

#region Tests: get_incomplete_task_count

section "get_incomplete_task_count"

# Missing file → 0
result=$(get_incomplete_task_count "/tmp/_ralph_test_nonexistent_$$")
assert_eq "missing file returns 0" "0" "$result"

# Empty file → 0
TMPFILE=$(mktemp)
result=$(get_incomplete_task_count "$TMPFILE")
assert_eq "empty file returns 0" "0" "$result"
rm -f "$TMPFILE"

# File with no task checkboxes → 0
result=$(get_incomplete_task_count "$FIXTURE_DIR/tasks-empty.md")
assert_eq "no checkboxes returns 0" "0" "$result"

# All tasks done → 0
result=$(get_incomplete_task_count "$FIXTURE_DIR/tasks-all-done.md")
assert_eq "all done returns 0" "0" "$result"

# Mixed tasks → correct incomplete count (3)
result=$(get_incomplete_task_count "$FIXTURE_DIR/tasks-mixed.md")
assert_eq "mixed tasks returns 3" "3" "$result"

# Result is a valid integer for arithmetic comparison
result=$(get_incomplete_task_count "$FIXTURE_DIR/tasks-empty.md")
assert_true "result is arithmetic-safe (0)" test "$result" -eq 0

result=$(get_incomplete_task_count "$FIXTURE_DIR/tasks-mixed.md")
assert_true "result is arithmetic-safe (3)" test "$result" -eq 3

# Single-line result (no double output regression)
result=$(get_incomplete_task_count "$FIXTURE_DIR/tasks-empty.md")
line_count=$(printf '%s\n' "$result" | wc -l | tr -d ' ')
assert_eq "single-line output (regression #1)" "1" "$line_count"

#endregion

#region Tests: test_completion_signal

section "test_completion_signal"

assert_false "rejects signal embedded in prose" test_completion_signal "Some output <promise>COMPLETE</promise> more text"

assert_false "rejects negated prose mention (regression)" test_completion_signal "stopping here; no <promise>COMPLETE</promise>."

assert_false "rejects output without signal" test_completion_signal "Some output without the signal"

assert_false "rejects empty string" test_completion_signal ""

assert_true "detects signal on its own line" test_completion_signal "line1
<promise>COMPLETE</promise>
line3"

assert_true "detects signal wrapped in backticks on its own line" test_completion_signal 'line1
`<promise>COMPLETE</promise>`
line3'

#endregion

#region Tests: load_ralph_config

section "load_ralph_config"

# Create a temp directory mimicking the expected config structure
TMP_REPO=$(mktemp -d)
CONFIG_DIR="$TMP_REPO/.specify/extensions/ralph"
mkdir -p "$CONFIG_DIR"
cp "$FIXTURE_DIR/ralph-config-valid.yml" "$CONFIG_DIR/ralph-config.yml"

# Reset config variables
CONFIG_MODEL=""
CONFIG_MAX_ITERATIONS=""
CONFIG_AGENT_CLI=""

load_ralph_config "$TMP_REPO"

assert_eq "loads model from config" "gpt-4o" "$CONFIG_MODEL"
assert_eq "loads max_iterations from config" "5" "$CONFIG_MAX_ITERATIONS"
assert_eq "loads agent_cli from config" "my-custom-cli" "$CONFIG_AGENT_CLI"

# Reset and test with missing config
CONFIG_MODEL=""
CONFIG_MAX_ITERATIONS=""
CONFIG_AGENT_CLI=""

load_ralph_config "/tmp/_ralph_test_no_config_$$"

assert_eq "missing config leaves model empty" "" "$CONFIG_MODEL"
assert_eq "missing config leaves max_iterations empty" "" "$CONFIG_MAX_ITERATIONS"
assert_eq "missing config leaves agent_cli empty" "" "$CONFIG_AGENT_CLI"

# Test local config overrides project config
cat > "$CONFIG_DIR/ralph-config.local.yml" << 'LOCALCFG'
model: "local-model"
max_iterations: 20
LOCALCFG

CONFIG_MODEL=""
CONFIG_MAX_ITERATIONS=""
CONFIG_AGENT_CLI=""

load_ralph_config "$TMP_REPO"

assert_eq "local config overrides model" "local-model" "$CONFIG_MODEL"
assert_eq "local config overrides max_iterations" "20" "$CONFIG_MAX_ITERATIONS"
assert_eq "local config inherits agent_cli from project" "my-custom-cli" "$CONFIG_AGENT_CLI"

rm -rf "$TMP_REPO"

#endregion

#region Tests: get_agent_cli_kind

section "get_agent_cli_kind"

assert_eq "detects copilot" "copilot" "$(get_agent_cli_kind "copilot")"
assert_eq "detects codex" "codex" "$(get_agent_cli_kind "codex")"
assert_eq "detects codex path" "codex" "$(get_agent_cli_kind "/usr/local/bin/codex")"
assert_eq "detects codex exe path" "codex" "$(get_agent_cli_kind "C:\\Tools\\codex.exe")"
assert_eq "detects claude" "claude" "$(get_agent_cli_kind "claude")"
assert_eq "detects claude path" "claude" "$(get_agent_cli_kind "/usr/local/bin/claude")"
assert_eq "rejects unsupported cli" "unsupported" "$(get_agent_cli_kind "my-custom-cli")"

#endregion

#region Tests: Spec Kit integration command resolution

section "Spec Kit integration command resolution"

TMP_INTEGRATION_REPO=$(mktemp -d)
mkdir -p "$TMP_INTEGRATION_REPO/.specify"

assert_eq "missing integration defaults to dot separator" "." "$(get_specify_integration_invoke_separator "$TMP_INTEGRATION_REPO")"
assert_eq "dot separator keeps dotted command" "speckit.ralph.iterate" "$(build_integration_command_name "speckit.ralph.iterate" ".")"
assert_eq "dash separator builds skills command" "speckit-ralph-iterate" "$(build_integration_command_name "speckit.ralph.iterate" "-")"
assert_true "dash separator enables skills mode" is_copilot_skills_mode "-"
assert_false "dot separator disables skills mode" is_copilot_skills_mode "."
assert_eq "skills mode prompt uses slash command" "/speckit-ralph-iterate Iteration 1 - Complete one work unit from tasks.md" "$(build_copilot_iteration_prompt "speckit-ralph-iterate" "-" "Iteration 1 - Complete one work unit from tasks.md")"
assert_eq "agent mode prompt is plain prompt" "Iteration 1 - Complete one work unit from tasks.md" "$(build_copilot_iteration_prompt "speckit.ralph.iterate" "." "Iteration 1 - Complete one work unit from tasks.md")"

cat > "$TMP_INTEGRATION_REPO/.specify/integration.json" << 'JSON'
{
  "integration": "copilot",
  "raw_options": "--skills",
  "invoke_separator": "-"
}
JSON

separator=$(get_specify_integration_invoke_separator "$TMP_INTEGRATION_REPO")
agent_name=$(build_integration_command_name "speckit.ralph.iterate" "$separator")

assert_eq "reads copilot dash separator" "-" "$separator"
assert_eq "resolves copilot skills agent name" "speckit-ralph-iterate" "$agent_name"

printf '{\n  "integration": "copilot",\n  "raw_options": "--foo\t--skills"\n}\n' > "$TMP_INTEGRATION_REPO/.specify/integration.json"

assert_eq "raw skills option accepts whitespace separators" "-" "$(get_specify_integration_invoke_separator "$TMP_INTEGRATION_REPO")"

cat > "$TMP_INTEGRATION_REPO/.specify/integration.json" << 'JSON'
{
  "integration": "copilot",
  "invoke_separator": ".",
  "nested": { "invoke_separator": "-" }
}
JSON

assert_eq "field reader returns first matching value" "." "$(get_specify_integration_field "$TMP_INTEGRATION_REPO" "invoke_separator")"

cat > "$TMP_INTEGRATION_REPO/.specify/integration.json" << 'JSON'
{
  "integration": "copilot",
  "invoke_separator": "_"
}
JSON

assert_eq "invalid invoke separator falls back to dot" "." "$(get_specify_integration_invoke_separator "$TMP_INTEGRATION_REPO")"

cat > "$TMP_INTEGRATION_REPO/.specify/integration.json" << 'JSON'
{
  "integration": "copilot",
  "raw_options": "--skills"
}
JSON

assert_eq "raw skills option implies dash separator" "-" "$(get_specify_integration_invoke_separator "$TMP_INTEGRATION_REPO")"

cat > "$TMP_INTEGRATION_REPO/.specify/integration.json" << 'JSON'
{
  "integration": "codex",
  "raw_options": "--skills",
  "invoke_separator": "-"
}
JSON

assert_eq "ignores non-copilot separator for copilot path" "." "$(get_specify_integration_invoke_separator "$TMP_INTEGRATION_REPO")"

rm -rf "$TMP_INTEGRATION_REPO"

#endregion

#region Tests: is_agent_resolution_failure

section "is_agent_resolution_failure"

assert_true "detects missing agent" is_agent_resolution_failure "No such agent: speckit.ralph.iterate, available:"
assert_true "detects missing skill" is_agent_resolution_failure "No such skill: speckit-ralph-iterate"
assert_true "detects unknown option" is_agent_resolution_failure "error: unknown option '--skills'"
assert_false "ignores bare unknown option prose" is_agent_resolution_failure "The docs mention an unknown option in prose."
assert_false "ignores unrelated failure output" is_agent_resolution_failure "model request failed"

#endregion

#region Tests: build_iteration_prompt

section "build_iteration_prompt"

TMP_PROMPT_DIR=$(mktemp -d)
ITERATE_COMMAND_PATH="$TMP_PROMPT_DIR/iterate.md"
cat > "$ITERATE_COMMAND_PATH" << 'PROMPT'
## Stop Conditions
Output <promise>COMPLETE</promise> when done.
PROMPT

prompt=$(build_iteration_prompt 7)
assert_true "prompt includes iteration" grep -q "Ralph iteration 7" <<< "$prompt"
assert_true "prompt includes iterate command" grep -q "Stop Conditions" <<< "$prompt"
assert_true "prompt includes completion signal" grep -q "<promise>COMPLETE</promise>" <<< "$prompt"

rm -rf "$TMP_PROMPT_DIR"

#endregion

#region Tests: invoke_copilot_iteration

section "invoke_copilot_iteration"

TMP_COPILOT_DIR=$(mktemp -d)
FAKE_COPILOT="$TMP_COPILOT_DIR/copilot"
cat > "$FAKE_COPILOT" << 'FAKECOPILOT'
#!/usr/bin/env bash
printf 'ARGS:'
for arg in "$@"; do
    printf ' [%s]' "$arg"
done
printf '\n'
printf '%s\n' '-n literal output'
exit 0
FAKECOPILOT
chmod +x "$FAKE_COPILOT"

AGENT_CLI="$FAKE_COPILOT"
VERBOSE=false
OLD_TMPDIR="${TMPDIR:-}"
TMPDIR="$TMP_COPILOT_DIR"

COPILOT_STDERR="$TMP_COPILOT_DIR/copilot.stderr"
copilot_output=$(invoke_copilot_iteration "fake-model" 1 "$TMP_COPILOT_DIR" 2>"$COPILOT_STDERR")
assert_true "dot mode uses --agent" grep -Fq "[--agent] [speckit.ralph.iterate]" <<< "$copilot_output"
assert_true "dot mode sends plain prompt" grep -Fq "[-p] [Iteration 1 - Complete one work unit from tasks.md]" <<< "$copilot_output"
assert_true "preserves leading dash output" grep -Fxq -- "-n literal output" <<< "$copilot_output"
assert_true "streams leading dash output literally" grep -Fxq -- "-n literal output" "$COPILOT_STDERR"

mkdir -p "$TMP_COPILOT_DIR/.specify"
cat > "$TMP_COPILOT_DIR/.specify/integration.json" << 'JSON'
{
  "integration": "copilot",
  "raw_options": "--skills",
  "invoke_separator": "-"
}
JSON

copilot_output=$(invoke_copilot_iteration "fake-model" 2 "$TMP_COPILOT_DIR" 2>/dev/null)
assert_false "skills mode does not use --agent" grep -Fq "[--agent]" <<< "$copilot_output"
assert_true "skills mode sends slash command prompt" grep -Fq "[-p] [/speckit-ralph-iterate Iteration 2 - Complete one work unit from tasks.md]" <<< "$copilot_output"
assert_false "skills mode does not pass --skills runtime flag" grep -Fq "[--skills]" <<< "$copilot_output"
assert_false "removes copilot temp output files" compgen -G "$TMP_COPILOT_DIR/ralph-copilot-output.*"

if [[ -n "$OLD_TMPDIR" ]]; then
    TMPDIR="$OLD_TMPDIR"
else
    unset TMPDIR
fi

rm -rf "$TMP_COPILOT_DIR"

#endregion

#region Tests: fail-fast resolution guard

section "fail-fast resolution guard"

TMP_FALSE_POSITIVE_REPO=$(mktemp -d)
TMP_FALSE_POSITIVE_SPEC="$TMP_FALSE_POSITIVE_REPO/specs/001-false-positive"
mkdir -p "$TMP_FALSE_POSITIVE_SPEC"
cat > "$TMP_FALSE_POSITIVE_SPEC/tasks.md" << 'TASKS'
- [ ] T001 Keep working
TASKS

mkdir -p "$TMP_FALSE_POSITIVE_REPO/ok" "$TMP_FALSE_POSITIVE_REPO/fail"
FAKE_COPILOT_OK="$TMP_FALSE_POSITIVE_REPO/ok/copilot"
cat > "$FAKE_COPILOT_OK" << 'FAKECOPILOTOK'
#!/usr/bin/env bash
printf '%s\n' "The docs mention an unknown option, but this is normal model output."
exit 0
FAKECOPILOTOK
chmod +x "$FAKE_COPILOT_OK"

set +e
false_positive_output=$(cd "$TMP_FALSE_POSITIVE_REPO" && bash "$SOURCE_SCRIPT" --feature-name "001-false-positive" --tasks-path "$TMP_FALSE_POSITIVE_SPEC/tasks.md" --spec-dir "$TMP_FALSE_POSITIVE_SPEC" --max-iterations 1 --model "fake-model" --agent-cli "$FAKE_COPILOT_OK" 2>&1)
false_positive_exit=$?
set -e

assert_eq "matching output with zero exit reaches iteration limit" "1" "$false_positive_exit"
assert_true "matching output with zero exit is not fatal" grep -q "ITERATION LIMIT REACHED" <<< "$false_positive_output"
assert_false "matching output with zero exit does not report unavailable agent" grep -q "Agent command unavailable" <<< "$false_positive_output"

FAKE_COPILOT_FAIL="$TMP_FALSE_POSITIVE_REPO/fail/copilot"
cat > "$FAKE_COPILOT_FAIL" << 'FAKECOPILOTFAIL'
#!/usr/bin/env bash
printf '%s\n' "error: unknown option '--skills'"
exit 2
FAKECOPILOTFAIL
chmod +x "$FAKE_COPILOT_FAIL"

set +e
fatal_output=$(cd "$TMP_FALSE_POSITIVE_REPO" && bash "$SOURCE_SCRIPT" --feature-name "001-false-positive" --tasks-path "$TMP_FALSE_POSITIVE_SPEC/tasks.md" --spec-dir "$TMP_FALSE_POSITIVE_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$FAKE_COPILOT_FAIL" 2>&1)
fatal_exit=$?
set -e

assert_eq "matching output with nonzero exit fails fast" "1" "$fatal_exit"
assert_true "matching output with nonzero exit reports unavailable agent" grep -q "Agent command unavailable" <<< "$fatal_output"

rm -rf "$TMP_FALSE_POSITIVE_REPO"

#endregion

#region Tests: invoke_codex_iteration

section "invoke_codex_iteration"

TMP_CODEX_DIR=$(mktemp -d)
FAKE_CODEX="$TMP_CODEX_DIR/codex"
cat > "$FAKE_CODEX" << 'FAKECODEX'
#!/usr/bin/env bash
printf '%s\n' '{"type":"item.completed","item":{"type":"agent_message","text":"fake failure"}}'
exit 7
FAKECODEX
chmod +x "$FAKE_CODEX"

AGENT_CLI="$FAKE_CODEX"
VERBOSE=false
ITERATE_COMMAND_PATH="$TMP_CODEX_DIR/iterate.md"
printf '%s\n' "Fake iterate command" > "$ITERATE_COMMAND_PATH"

set +e
codex_output=$(invoke_codex_iteration "fake-model" 1 "$TMP_CODEX_DIR" 2>/dev/null)
codex_exit=$?
set -e

assert_eq "propagates codex exit code" "7" "$codex_exit"
assert_true "captures codex output" grep -q "fake failure" <<< "$codex_output"

rm -rf "$TMP_CODEX_DIR"

#endregion

#region Tests: invoke_claude_iteration

section "invoke_claude_iteration"

TMP_CLAUDE_DIR=$(mktemp -d)
FAKE_CLAUDE="$TMP_CLAUDE_DIR/claude"
cat > "$FAKE_CLAUDE" << 'FAKECLAUDE'
#!/usr/bin/env bash
# Echo args so we can assert the claude-specific flags are used
printf '%s\n' "ARGS: $*"
printf '%s\n' "fake claude failure"
exit 9
FAKECLAUDE
chmod +x "$FAKE_CLAUDE"

AGENT_CLI="$FAKE_CLAUDE"
VERBOSE=false
ITERATE_COMMAND_PATH="$TMP_CLAUDE_DIR/iterate.md"
printf '%s\n' "Fake iterate command" > "$ITERATE_COMMAND_PATH"

set +e
claude_output=$(invoke_claude_iteration "fake-model" 1 "$TMP_CLAUDE_DIR" 2>/dev/null)
claude_exit=$?
set -e

assert_eq "propagates claude exit code" "9" "$claude_exit"
assert_true "captures claude output" grep -q "fake claude failure" <<< "$claude_output"
assert_true "uses --dangerously-skip-permissions flag" grep -q -- "--dangerously-skip-permissions" <<< "$claude_output"
# Claude Code has no registered speckit.ralph.iterate agent, so --agent must NOT be passed
assert_false "does not pass --agent flag" grep -q -- "--agent" <<< "$claude_output"

rm -rf "$TMP_CLAUDE_DIR"

#endregion

#region Tests: initialize_progress_file

section "initialize_progress_file"

TMP_PROGRESS=$(mktemp -d)

# Creates file when missing
PROGRESS_FILE="$TMP_PROGRESS/progress.md"
initialize_progress_file "$PROGRESS_FILE" "test-feature" >/dev/null 2>&1
assert_true "creates progress file" test -f "$PROGRESS_FILE"

# File contains expected audit header content
assert_true "contains feature name" grep -q "Feature: test-feature" "$PROGRESS_FILE"
assert_false "progress file does not contain memory sections" grep -q "## Codebase Patterns" "$PROGRESS_FILE"

# Doesn't overwrite existing file
printf '%s\n' "custom content" > "$PROGRESS_FILE"
initialize_progress_file "$PROGRESS_FILE" "other-feature" >/dev/null 2>&1
content=$(cat "$PROGRESS_FILE")
assert_eq "does not overwrite existing file" "custom content" "$content"

rm -rf "$TMP_PROGRESS"

#endregion

#region Tests: initialize_memory_file

section "initialize_memory_file"

TMP_MEMORY=$(mktemp -d)

# Creates file when missing
MEMORY_FILE="$TMP_MEMORY/ralph-memory.md"
initialize_memory_file "$MEMORY_FILE" "test-feature" "$MEMORY_TEMPLATE" >/dev/null 2>&1
assert_true "creates memory file" test -f "$MEMORY_FILE"

# File contains expected memory sections
assert_true "memory contains feature name" grep -q "Feature: test-feature" "$MEMORY_FILE"
assert_false "memory replaces feature placeholder" grep -q "{{FEATURE_NAME}}" "$MEMORY_FILE"
assert_false "memory replaces timestamp placeholder" grep -q "{{STARTED_AT}}" "$MEMORY_FILE"
assert_true "memory contains codebase patterns section" grep -q "## Codebase Patterns" "$MEMORY_FILE"
assert_true "memory contains decisions section" grep -q "## Decisions" "$MEMORY_FILE"
assert_true "memory contains gotchas section" grep -q "## Gotchas" "$MEMORY_FILE"
assert_true "memory contains reusable commands section" grep -q "## Reusable Commands" "$MEMORY_FILE"
assert_true "memory contains do not repeat section" grep -q "## Do Not Repeat" "$MEMORY_FILE"
assert_true "memory contains current handoff section" grep -q "## Current Handoff" "$MEMORY_FILE"

# Escapes replacement-sensitive characters in feature names
SPECIAL_MEMORY_FILE="$TMP_MEMORY/ralph-memory-special.md"
SPECIAL_FEATURE='feature&with\backslash'
initialize_memory_file "$SPECIAL_MEMORY_FILE" "$SPECIAL_FEATURE" "$MEMORY_TEMPLATE" >/dev/null 2>&1
assert_true "memory preserves ampersand and backslash in feature name" grep -Fq "Feature: $SPECIAL_FEATURE" "$SPECIAL_MEMORY_FILE"

# Falls back to the built-in template when a configured template cannot be read
UNREADABLE_TEMPLATE="$TMP_MEMORY/unreadable-template.md"
UNREADABLE_MEMORY_FILE="$TMP_MEMORY/ralph-memory-unreadable.md"
printf '%s\n' "# Unreadable Template" > "$UNREADABLE_TEMPLATE"
chmod 000 "$UNREADABLE_TEMPLATE"
set +e
initialize_memory_file "$UNREADABLE_MEMORY_FILE" "fallback-feature" "$UNREADABLE_TEMPLATE" >/dev/null 2>&1
unreadable_result=$?
set -e
chmod 600 "$UNREADABLE_TEMPLATE"
assert_eq "unreadable memory template does not fail" "0" "$unreadable_result"
assert_true "unreadable memory template uses fallback" grep -q "Feature: fallback-feature" "$UNREADABLE_MEMORY_FILE"
assert_true "fallback memory contains codebase patterns section" grep -q "## Codebase Patterns" "$UNREADABLE_MEMORY_FILE"

# Falls back to the built-in template when a configured template is empty
EMPTY_TEMPLATE="$TMP_MEMORY/empty-template.md"
EMPTY_MEMORY_FILE="$TMP_MEMORY/ralph-memory-empty.md"
: > "$EMPTY_TEMPLATE"
initialize_memory_file "$EMPTY_MEMORY_FILE" "empty-template-feature" "$EMPTY_TEMPLATE" >/dev/null 2>&1
assert_true "empty memory template uses fallback" grep -q "Feature: empty-template-feature" "$EMPTY_MEMORY_FILE"
assert_true "empty fallback memory contains codebase patterns section" grep -q "## Codebase Patterns" "$EMPTY_MEMORY_FILE"

# Doesn't overwrite existing file
printf '%s\n' "custom memory" > "$MEMORY_FILE"
initialize_memory_file "$MEMORY_FILE" "other-feature" "$MEMORY_TEMPLATE" >/dev/null 2>&1
content=$(cat "$MEMORY_FILE")
assert_eq "does not overwrite existing memory file" "custom memory" "$content"

rm -rf "$TMP_MEMORY"

#endregion

#region Tests: test_worktree_clean

section "test_worktree_clean"

TMP_WORKTREE=$(mktemp -d)
git -C "$TMP_WORKTREE" init >/dev/null 2>&1
printf '%s\n' "tracked" > "$TMP_WORKTREE/file.txt"
git -C "$TMP_WORKTREE" add .
git -C "$TMP_WORKTREE" -c user.name="Ralph Test" -c user.email="ralph@example.com" commit -m "test fixture" >/dev/null 2>&1

assert_true "clean repo is clean" test_worktree_clean "$TMP_WORKTREE"

printf '%s\n' "dirty" > "$TMP_WORKTREE/dirty.txt"
assert_false "dirty repo is not clean" test_worktree_clean "$TMP_WORKTREE"
rm "$TMP_WORKTREE/dirty.txt"

set +e
GIT_INDEX_FILE="$TMP_WORKTREE/.git" test_worktree_clean "$TMP_WORKTREE"
status_failure_result=$?
set -e
assert_eq "git status failure is not clean" "1" "$status_failure_result"

rm -rf "$TMP_WORKTREE"

#endregion

#region Tests: dirty completion guard

section "dirty completion guard"

TMP_DIRTY=$(mktemp -d)
DIRTY_SPEC="$TMP_DIRTY/specs/001-dirty"
mkdir -p "$DIRTY_SPEC" "$TMP_DIRTY/bin"
printf '%s\n' "- [ ] T001 Incomplete task" > "$DIRTY_SPEC/tasks.md"
printf '%s\n' "# Ralph Progress Log" > "$DIRTY_SPEC/progress.md"
printf '%s\n' "# Ralph Memory" > "$DIRTY_SPEC/ralph-memory.md"
git -C "$TMP_DIRTY" init >/dev/null 2>&1
git -C "$TMP_DIRTY" add .
git -C "$TMP_DIRTY" -c user.name="Ralph Test" -c user.email="ralph@example.com" commit -m "test fixture" >/dev/null 2>&1
printf '%s\n' "dirty" > "$TMP_DIRTY/dirty.txt"

FAKE_COMPLETE="$TMP_DIRTY/bin/copilot"
cat > "$FAKE_COMPLETE" << 'FAKECOMPLETE'
#!/usr/bin/env bash
printf '%s\n' "<promise>COMPLETE</promise>"
exit 0
FAKECOMPLETE
chmod +x "$FAKE_COMPLETE"

set +e
dirty_output=$(cd "$TMP_DIRTY" && bash "$SOURCE_SCRIPT" --feature-name "001-dirty" --tasks-path "$DIRTY_SPEC/tasks.md" --spec-dir "$DIRTY_SPEC" --max-iterations 1 --model "fake-model" --agent-cli "$FAKE_COMPLETE" 2>&1)
dirty_exit=$?
set -e

assert_eq "dirty completion exits 1" "1" "$dirty_exit"
assert_true "dirty completion refuses success" grep -q "worktree is dirty" <<< "$dirty_output"

rm -rf "$TMP_DIRTY"

#endregion

#region Tests: all-complete startup

section "all-complete startup"

TMP_DONE=$(mktemp -d)
DONE_SPEC="$TMP_DONE/specs/001-done"
mkdir -p "$DONE_SPEC"
printf '%s\n' "- [x] T001 Already done" > "$DONE_SPEC/tasks.md"

set +e
done_output=$(cd "$TMP_DONE" && bash "$SOURCE_SCRIPT" --feature-name "001-done" --tasks-path "$DONE_SPEC/tasks.md" --spec-dir "$DONE_SPEC" --max-iterations 1 --model "fake-model" --agent-cli "missing-agent" 2>&1)
done_exit=$?
set -e

assert_eq "all-complete startup exits 0" "0" "$done_exit"
assert_true "all-complete startup emits completion signal" grep -q "<promise>COMPLETE</promise>" <<< "$done_output"
assert_false "all-complete startup does not create progress log" test -e "$DONE_SPEC/progress.md"
assert_false "all-complete startup does not create memory file" test -e "$DONE_SPEC/ralph-memory.md"

rm -rf "$TMP_DONE"

#endregion

#region Summary

echo ""
echo -e "\033[36m══════════════════════════════════\033[0m"
echo -e "\033[36m  Bash Regression Test Summary\033[0m"
echo -e "\033[36m══════════════════════════════════\033[0m"
echo -e "  Total:  $TESTS_RUN"
echo -e "  Passed: \033[32m$TESTS_PASSED\033[0m"
echo -e "  Failed: \033[31m$TESTS_FAILED\033[0m"

if [[ $TESTS_FAILED -gt 0 ]]; then
    echo ""
    echo -e "\033[31mFailed tests:\033[0m"
    for f in "${FAILURES[@]}"; do
        printf '  - %s\n' "$f"
    done
    exit 1
fi

echo ""
echo -e "\033[32mAll tests passed.\033[0m"
exit 0

#endregion
