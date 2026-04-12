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
        echo "         expected: [$expected]"
        echo "         actual:   [$actual]"
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
        echo "         command returned non-zero: $*"
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
        echo "         command should have failed but returned 0: $*"
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
    # Extract test_completion_signal
    sed -n '/^test_completion_signal()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract load_ralph_config
    sed -n '/^load_ralph_config()/,/^}/p' "$SOURCE_SCRIPT"
}

eval "$(extract_functions)"

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
line_count=$(echo "$result" | wc -l | tr -d ' ')
assert_eq "single-line output (regression #1)" "1" "$line_count"

#endregion

#region Tests: test_completion_signal

section "test_completion_signal"

assert_true "detects COMPLETE signal" test_completion_signal "Some output <promise>COMPLETE</promise> more text"

assert_false "rejects output without signal" test_completion_signal "Some output without the signal"

assert_false "rejects empty string" test_completion_signal ""

assert_true "detects signal on its own line" test_completion_signal "line1
<promise>COMPLETE</promise>
line3"

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

#region Tests: initialize_progress_file

section "initialize_progress_file"

TMP_PROGRESS=$(mktemp -d)

# Creates file when missing
PROGRESS_FILE="$TMP_PROGRESS/progress.md"
initialize_progress_file "$PROGRESS_FILE" "test-feature" >/dev/null 2>&1
assert_true "creates progress file" test -f "$PROGRESS_FILE"

# File contains expected header content
assert_true "contains feature name" grep -q "Feature: test-feature" "$PROGRESS_FILE"
assert_true "contains codebase patterns section" grep -q "## Codebase Patterns" "$PROGRESS_FILE"

# Doesn't overwrite existing file
echo "custom content" > "$PROGRESS_FILE"
initialize_progress_file "$PROGRESS_FILE" "other-feature" >/dev/null 2>&1
content=$(cat "$PROGRESS_FILE")
assert_eq "does not overwrite existing file" "custom content" "$content"

rm -rf "$TMP_PROGRESS"

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
        echo "  - $f"
    done
    exit 1
fi

echo ""
echo -e "\033[32mAll tests passed.\033[0m"
exit 0

#endregion
