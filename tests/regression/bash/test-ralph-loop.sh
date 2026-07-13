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
ITERATE_GUIDANCE="$REPO_ROOT/commands/iterate.md"

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
    # Extract Ralph memory helpers
    sed -n '/^extract_ralph_memory_lines()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^is_valid_utc_timestamp()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^load_ralph_memory_schema()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^validate_ralph_memory_template()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^get_current_handoff_content()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^validate_ralph_memory_file()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^render_ralph_memory()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^prepare_ralph_memory()/,/^}/p' "$SOURCE_SCRIPT"
    # Extract coordinated commit helpers
    sed -n '/^get_git_head_snapshot()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^get_task_state_snapshot()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^validate_iteration_commit_history()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^validate_initial_commit_postconditions()/,/^}/p' "$SOURCE_SCRIPT"
    sed -n '/^validate_completion_gate()/,/^}/p' "$SOURCE_SCRIPT"
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
    # Extract load_ralph_config
    sed -n '/^load_ralph_config()/,/^}/p' "$SOURCE_SCRIPT"
}

eval "$(extract_functions)"

#endregion

#region Tests: centralized completion gate

section "centralized completion gate"

completion_helper=$(sed -n '/^validate_completion_gate()/,/^}/p' "$SOURCE_SCRIPT")
assert_false "completion gate has no Git mutation or repair" grep -Eq 'git .*([[:space:]])(commit|add|amend|reset|rebase|revert|checkout|stash)([[:space:]]|$)' <<< "$completion_helper"
initial_gate_line=$(grep -n 'validate_completion_gate "absent"' "$SOURCE_SCRIPT" | head -n 1 | cut -d: -f1)
signal_gate_line=$(grep -n 'validate_completion_gate "$exit_code"' "$SOURCE_SCRIPT" | head -n 1 | cut -d: -f1)
assert_true "initial task-zero uses centralized gate" test -n "$initial_gate_line"
assert_true "post-agent candidates use centralized gate" test -n "$signal_gate_line"

TMP_GATE_ROOT=$(mktemp -d)
TMP_INITIAL_REPO="$TMP_GATE_ROOT/initial"
TMP_INITIAL_SPEC="$TMP_INITIAL_REPO/specs/test-feature"
mkdir -p "$TMP_INITIAL_SPEC"
git -C "$TMP_INITIAL_REPO" init -q
git -C "$TMP_INITIAL_REPO" config user.name "Ralph Test"
git -C "$TMP_INITIAL_REPO" config user.email "ralph@example.test"
cp "$FIXTURE_DIR/tasks-all-done.md" "$TMP_INITIAL_SPEC/tasks.md"
cp "$FIXTURE_DIR/ralph-memory-valid-complete.md" "$TMP_INITIAL_SPEC/ralph-memory.md"
printf '%s\n' '# Ralph Progress Log' > "$TMP_INITIAL_SPEC/progress.md"
printf '%s\n' 'initial' > "$TMP_INITIAL_REPO/source.txt"
git -C "$TMP_INITIAL_REPO" add .
git -C "$TMP_INITIAL_REPO" commit -qm "initial complete state"

NEVER_AGENT="$TMP_GATE_ROOT/copilot"
cat > "$NEVER_AGENT" << 'NEVERAGENT'
#!/usr/bin/env bash
printf '%s\n' invoked >> "$RALPH_TEST_CALLS"
exit 99
NEVERAGENT
chmod +x "$NEVER_AGENT"
INITIAL_CALLS="$TMP_GATE_ROOT/initial.calls"
initial_head=$(git -C "$TMP_INITIAL_REPO" rev-parse HEAD)
set +e
initial_output=$(cd "$TMP_INITIAL_REPO" && RALPH_TEST_CALLS="$INITIAL_CALLS" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_INITIAL_SPEC/tasks.md" --spec-dir "$TMP_INITIAL_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$NEVER_AGENT" 2>&1)
initial_exit=$?
set -e
assert_eq "clean initial task-zero exits success" "0" "$initial_exit"
assert_true "clean initial task-zero reports completion" grep -q '<promise>COMPLETE</promise>' <<< "$initial_output"
assert_false "clean initial task-zero invokes no agent" test -e "$INITIAL_CALLS"
assert_eq "clean initial gate leaves history unchanged" "$initial_head" "$(git -C "$TMP_INITIAL_REPO" rev-parse HEAD)"

printf '%s\n' 'dirty tracked' >> "$TMP_INITIAL_REPO/source.txt"
printf '%s\n' 'dirty untracked' > "$TMP_INITIAL_REPO/dirty-two.txt"
dirty_head=$(git -C "$TMP_INITIAL_REPO" rev-parse HEAD)
set +e
dirty_output=$(cd "$TMP_INITIAL_REPO" && RALPH_TEST_CALLS="$INITIAL_CALLS" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_INITIAL_SPEC/tasks.md" --spec-dir "$TMP_INITIAL_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$NEVER_AGENT" 2>&1)
dirty_exit=$?
set -e
assert_eq "dirty initial task-zero exits one" "1" "$dirty_exit"
assert_true "dirty gate reports tracked porcelain" grep -Fq 'dirty-path:  M source.txt' <<< "$dirty_output"
assert_true "dirty gate reports untracked porcelain" grep -Fq 'dirty-path: ?? dirty-two.txt' <<< "$dirty_output"
assert_false "dirty initial task-zero invokes no agent" test -e "$INITIAL_CALLS"
assert_eq "dirty completion reporting leaves history unchanged" "$dirty_head" "$(git -C "$TMP_INITIAL_REPO" rev-parse HEAD)"
printf '%s\n' 'initial' > "$TMP_INITIAL_REPO/source.txt"
rm -f "$TMP_INITIAL_REPO/dirty-two.txt"

cp "$FIXTURE_DIR/ralph-memory-valid-active.md" "$TMP_INITIAL_SPEC/ralph-memory.md"
git -C "$TMP_INITIAL_REPO" add "$TMP_INITIAL_SPEC/ralph-memory.md"
git -C "$TMP_INITIAL_REPO" commit -qm "stale handoff fixture"
stale_head=$(git -C "$TMP_INITIAL_REPO" rev-parse HEAD)
set +e
stale_output=$(cd "$TMP_INITIAL_REPO" && RALPH_TEST_CALLS="$INITIAL_CALLS" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_INITIAL_SPEC/tasks.md" --spec-dir "$TMP_INITIAL_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$NEVER_AGENT" 2>&1)
stale_exit=$?
set -e
assert_eq "nonterminal handoff blocks initial completion" "1" "$stale_exit"
assert_true "nonterminal handoff reports handoff-invalid" grep -q '^handoff-invalid:' <<< "$stale_output"
assert_false "stale handoff starts no reconciliation agent" test -e "$INITIAL_CALLS"
assert_eq "stale handoff leaves history unchanged" "$stale_head" "$(git -C "$TMP_INITIAL_REPO" rev-parse HEAD)"

cp "$FIXTURE_DIR/ralph-memory-valid-complete.md" "$TMP_INITIAL_SPEC/ralph-memory.md"
printf '%s\n' '- extra completion content' >> "$TMP_INITIAL_SPEC/ralph-memory.md"
git -C "$TMP_INITIAL_REPO" add "$TMP_INITIAL_SPEC/ralph-memory.md"
git -C "$TMP_INITIAL_REPO" commit -qm "invalid handoff shape fixture"
set +e
shape_output=$(cd "$TMP_INITIAL_REPO" && RALPH_TEST_CALLS="$INITIAL_CALLS" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_INITIAL_SPEC/tasks.md" --spec-dir "$TMP_INITIAL_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$NEVER_AGENT" 2>&1)
shape_exit=$?
set -e
assert_eq "extra handoff content blocks completion" "1" "$shape_exit"
assert_true "extra handoff content reports handoff-invalid" grep -q '^handoff-invalid:' <<< "$shape_output"
assert_true "initial completion rejects incomplete coordinated state commit" grep -q '^commit-postcondition-invalid:' <<< "$shape_output"

TMP_ACTIVE_REPO="$TMP_GATE_ROOT/active"
TMP_ACTIVE_SPEC="$TMP_ACTIVE_REPO/specs/test-feature"
mkdir -p "$TMP_ACTIVE_SPEC"
git -C "$TMP_ACTIVE_REPO" init -q
git -C "$TMP_ACTIVE_REPO" config user.name "Ralph Test"
git -C "$TMP_ACTIVE_REPO" config user.email "ralph@example.test"
printf '%s\n' '- [ ] T001 Complete work' > "$TMP_ACTIVE_SPEC/tasks.md"
cp "$FIXTURE_DIR/ralph-memory-valid-active.md" "$TMP_ACTIVE_SPEC/ralph-memory.md"
printf '%s\n' '# Ralph Progress Log' > "$TMP_ACTIVE_SPEC/progress.md"
printf '%s\n' 'initial' > "$TMP_ACTIVE_REPO/source.txt"
git -C "$TMP_ACTIVE_REPO" add .
git -C "$TMP_ACTIVE_REPO" commit -qm "active state"

mkdir -p "$TMP_GATE_ROOT/active-agent"
ACTIVE_AGENT="$TMP_GATE_ROOT/active-agent/copilot"
cat > "$ACTIVE_AGENT" << 'ACTIVEAGENT'
#!/usr/bin/env bash
printf '%s\n' invoked >> "$RALPH_TEST_CALLS"
case "$RALPH_TEST_MODE" in
    failed-token)
        printf '%s\n' '<promise>COMPLETE</promise>'
        exit 7
        ;;
    remaining-token)
        printf '%s\n' '<promise>COMPLETE</promise>'
        exit 0
        ;;
    complete|complete-dirty)
        sed -i.bak 's/- \[ \] T001/- [x] T001/' "$RALPH_TEST_SPEC/tasks.md"
        rm -f "$RALPH_TEST_SPEC/tasks.md.bak"
        cp "$RALPH_TEST_COMPLETE_MEMORY" "$RALPH_TEST_SPEC/ralph-memory.md"
        printf '%s\n' 'completed iteration' >> "$RALPH_TEST_SPEC/progress.md"
        printf '%s\n' 'substantive completion' >> source.txt
        git add source.txt "$RALPH_TEST_SPEC/tasks.md" "$RALPH_TEST_SPEC/ralph-memory.md" "$RALPH_TEST_SPEC/progress.md"
        git commit -qm "complete work unit"
        if [[ "$RALPH_TEST_MODE" == "complete-dirty" ]]; then
            printf '%s\n' one > dirty-one.txt
            printf '%s\n' two > dirty-two.txt
        fi
        printf '%s\n' '<promise>COMPLETE</promise>'
        exit 0
        ;;
esac
ACTIVEAGENT
chmod +x "$ACTIVE_AGENT"

ACTIVE_CALLS="$TMP_GATE_ROOT/active.calls"
set +e
failed_token_output=$(cd "$TMP_ACTIVE_REPO" && RALPH_TEST_CALLS="$ACTIVE_CALLS" RALPH_TEST_MODE=failed-token RALPH_TEST_SPEC="$TMP_ACTIVE_SPEC" RALPH_TEST_COMPLETE_MEMORY="$FIXTURE_DIR/ralph-memory-valid-complete.md" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_ACTIVE_SPEC/tasks.md" --spec-dir "$TMP_ACTIVE_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$ACTIVE_AGENT" 2>&1)
failed_token_exit=$?
set -e
assert_eq "failed agent completion token exits one" "1" "$failed_token_exit"
assert_true "failed token reports agent result" grep -q '^agent-result-invalid:' <<< "$failed_token_output"
assert_eq "failed token starts no next iteration" "1" "$(wc -l < "$ACTIVE_CALLS" | tr -d ' ')"

rm -f "$ACTIVE_CALLS"
set +e
remaining_token_output=$(cd "$TMP_ACTIVE_REPO" && RALPH_TEST_CALLS="$ACTIVE_CALLS" RALPH_TEST_MODE=remaining-token RALPH_TEST_SPEC="$TMP_ACTIVE_SPEC" RALPH_TEST_COMPLETE_MEMORY="$FIXTURE_DIR/ralph-memory-valid-complete.md" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_ACTIVE_SPEC/tasks.md" --spec-dir "$TMP_ACTIVE_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$ACTIVE_AGENT" 2>&1)
remaining_token_exit=$?
set -e
assert_eq "completion token with remaining task exits one" "1" "$remaining_token_exit"
assert_true "remaining-task token reports task count" grep -q '^tasks-incomplete: 1' <<< "$remaining_token_output"
assert_eq "remaining-task token starts no next iteration" "1" "$(wc -l < "$ACTIVE_CALLS" | tr -d ' ')"

rm -f "$ACTIVE_CALLS"
set +e
post_output=$(cd "$TMP_ACTIVE_REPO" && RALPH_TEST_CALLS="$ACTIVE_CALLS" RALPH_TEST_MODE=complete RALPH_TEST_SPEC="$TMP_ACTIVE_SPEC" RALPH_TEST_COMPLETE_MEMORY="$FIXTURE_DIR/ralph-memory-valid-complete.md" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_ACTIVE_SPEC/tasks.md" --spec-dir "$TMP_ACTIVE_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$ACTIVE_AGENT" 2>&1)
post_exit=$?
set -e
assert_eq "clean post-agent completion exits success" "0" "$post_exit"
assert_true "clean post-agent completion reports promise" grep -q '<promise>COMPLETE</promise>' <<< "$post_output"
assert_eq "clean post-agent completion invokes once" "1" "$(wc -l < "$ACTIVE_CALLS" | tr -d ' ')"

TMP_POST_DIRTY_REPO="$TMP_GATE_ROOT/post-dirty"
cp -R "$TMP_ACTIVE_REPO" "$TMP_POST_DIRTY_REPO"
TMP_POST_DIRTY_SPEC="$TMP_POST_DIRTY_REPO/specs/test-feature"
# Restore an active baseline in the copied repository with a new coordinated commit.
printf '%s\n' '- [ ] T001 Complete work' > "$TMP_POST_DIRTY_SPEC/tasks.md"
cp "$FIXTURE_DIR/ralph-memory-valid-active.md" "$TMP_POST_DIRTY_SPEC/ralph-memory.md"
printf '%s\n' 'active again' >> "$TMP_POST_DIRTY_SPEC/progress.md"
printf '%s\n' 'active baseline' >> "$TMP_POST_DIRTY_REPO/source.txt"
git -C "$TMP_POST_DIRTY_REPO" add .
git -C "$TMP_POST_DIRTY_REPO" commit -qm "active baseline for dirty completion"
post_dirty_baseline_head=$(git -C "$TMP_POST_DIRTY_REPO" rev-parse HEAD)
POST_DIRTY_CALLS="$TMP_GATE_ROOT/post-dirty.calls"
set +e
post_dirty_output=$(cd "$TMP_POST_DIRTY_REPO" && RALPH_TEST_CALLS="$POST_DIRTY_CALLS" RALPH_TEST_MODE=complete-dirty RALPH_TEST_SPEC="$TMP_POST_DIRTY_SPEC" RALPH_TEST_COMPLETE_MEMORY="$FIXTURE_DIR/ralph-memory-valid-complete.md" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_POST_DIRTY_SPEC/tasks.md" --spec-dir "$TMP_POST_DIRTY_SPEC" --max-iterations 3 --model "fake-model" --agent-cli "$ACTIVE_AGENT" 2>&1)
post_dirty_exit=$?
set -e
post_dirty_head=$(git -C "$TMP_POST_DIRTY_REPO" rev-parse HEAD)
assert_eq "dirty post-agent completion exits one" "1" "$post_dirty_exit"
assert_true "dirty post-agent gate reports first path" grep -Fq 'dirty-path: ?? dirty-one.txt' <<< "$post_dirty_output"
assert_true "dirty post-agent gate reports second path" grep -Fq 'dirty-path: ?? dirty-two.txt' <<< "$post_dirty_output"
assert_eq "dirty post-agent starts no next iteration" "1" "$(wc -l < "$POST_DIRTY_CALLS" | tr -d ' ')"
assert_eq "dirty post-agent creates only its work-unit commit" "1" "$(git -C "$TMP_POST_DIRTY_REPO" rev-list --count "$post_dirty_baseline_head..$post_dirty_head")"
assert_eq "dirty post-agent reporting adds no repair history" "$post_dirty_head" "$(git -C "$TMP_POST_DIRTY_REPO" rev-parse HEAD)"

cp "$FIXTURE_DIR/ralph-memory-malformed.md" "$TMP_GATE_ROOT/malformed-completion.md"
set +e
aggregate_handoff_output=$(validate_ralph_memory_file "$REPO_ROOT/templates/ralph-memory.md" "$TMP_GATE_ROOT/malformed-completion.md" "test-feature" true 2>&1)
aggregate_handoff_exit=$?
set -e
assert_eq "completion memory aggregate exits one" "1" "$aggregate_handoff_exit"
assert_true "completion memory aggregate includes structural defect" grep -q '^title-invalid:' <<< "$aggregate_handoff_output"
assert_true "completion memory aggregate includes handoff-invalid" grep -q '^handoff-invalid:' <<< "$aggregate_handoff_output"

expected_completion_categories="agent-result-invalid
bookkeeping-only
commit-postcondition-invalid
coordinated-commit-invalid
dirty-path
handoff-invalid
tasks-incomplete"
completion_parity_output="$dirty_output
$shape_output
$failed_token_output
$remaining_token_output
$post_dirty_output
$stale_output"
actual_completion_categories=$(sed -n -E 's/^(agent-result-invalid|bookkeeping-only|commit-postcondition-invalid|coordinated-commit-invalid|dirty-path|handoff-invalid|tasks-incomplete):.*/\1/p' <<< "$completion_parity_output" | LC_ALL=C sort -u)
assert_eq "completion parity exposes the canonical diagnostic categories" "$expected_completion_categories" "$actual_completion_categories"

rm -rf "$TMP_GATE_ROOT"

#endregion

#region Tests: coordinated iteration commits

section "coordinated iteration commits"

persist_line=$(grep -n 'Persist the iteration outcome before any commit' "$ITERATE_GUIDANCE" | head -n 1 | cut -d: -f1)
stage_line=$(grep -n 'Stage substantive files together' "$ITERATE_GUIDANCE" | head -n 1 | cut -d: -f1)
commit_line=$(grep -n 'Create one substantive commit only after coordinated persistence' "$ITERATE_GUIDANCE" | head -n 1 | cut -d: -f1)
assert_true "guidance persists state before staging" test -n "$persist_line" -a "$persist_line" -lt "$stage_line"
assert_true "guidance stages coordinated state before commit" test -n "$stage_line" -a "$stage_line" -lt "$commit_line"

snapshot_line=$(grep -n 'iteration_head_before=$(get_git_head_snapshot' "$SOURCE_SCRIPT" | head -n 1 | cut -d: -f1)
invoke_line=$(grep -n 'output=$(invoke_agent_iteration' "$SOURCE_SCRIPT" | head -n 1 | cut -d: -f1)
validation_line=$(grep -n 'validate_iteration_commit_history' "$SOURCE_SCRIPT" | tail -n 1 | cut -d: -f1)
assert_true "snapshots HEAD before agent invocation" test -n "$snapshot_line" -a "$snapshot_line" -lt "$invoke_line"
assert_true "validates commit history after agent invocation" test -n "$validation_line" -a "$validation_line" -gt "$invoke_line"
history_helper=$(sed -n '/^validate_iteration_commit_history()/,/^}/p' "$SOURCE_SCRIPT")
assert_false "commit validator has no repair or commit mutation" grep -Eq 'git .*([[:space:]])(commit|add|amend|reset|rebase|revert|checkout|stash)([[:space:]]|$)' <<< "$history_helper"

TMP_COMMIT_REPO=$(mktemp -d)
git -C "$TMP_COMMIT_REPO" init -q
git -C "$TMP_COMMIT_REPO" config user.name "Ralph Test"
git -C "$TMP_COMMIT_REPO" config user.email "ralph@example.test"
TMP_COMMIT_SPEC="$TMP_COMMIT_REPO/specs/test-feature"
mkdir -p "$TMP_COMMIT_SPEC"
printf '%s\n' '- [ ] T001 First work' '- [ ] T002 Second work' > "$TMP_COMMIT_SPEC/tasks.md"
cp "$FIXTURE_DIR/ralph-memory-valid-active.md" "$TMP_COMMIT_SPEC/ralph-memory.md"
printf '%s\n' '# Ralph Progress Log' > "$TMP_COMMIT_SPEC/progress.md"
printf '%s\n' 'initial' > "$TMP_COMMIT_REPO/source.txt"
git -C "$TMP_COMMIT_REPO" add .
git -C "$TMP_COMMIT_REPO" commit -qm "initial"

before_head=$(get_git_head_snapshot "$TMP_COMMIT_REPO")
before_state=$(get_task_state_snapshot "$TMP_COMMIT_SPEC/tasks.md")
before_count=$(get_incomplete_task_count "$TMP_COMMIT_SPEC/tasks.md")
printf '%s\n' 'substantive one' >> "$TMP_COMMIT_REPO/source.txt"
sed -i.bak 's/- \[ \] T001/- [x] T001/' "$TMP_COMMIT_SPEC/tasks.md"
rm -f "$TMP_COMMIT_SPEC/tasks.md.bak"
printf '%s\n' '- durable learning' >> "$TMP_COMMIT_SPEC/ralph-memory.md"
printf '%s\n' 'iteration one' >> "$TMP_COMMIT_SPEC/progress.md"
git -C "$TMP_COMMIT_REPO" add .
git -C "$TMP_COMMIT_REPO" commit -qm "coordinated work"
after_count=$(get_incomplete_task_count "$TMP_COMMIT_SPEC/tasks.md")
assert_true "accepts substantive commit containing all state artifacts" validate_iteration_commit_history "$TMP_COMMIT_REPO" "$before_head" "$before_state" "$before_count" "$after_count" 0 "$TMP_COMMIT_SPEC/tasks.md" "$TMP_COMMIT_SPEC/progress.md" "$TMP_COMMIT_SPEC/ralph-memory.md"

# A failed attempt may retain memory and audit changes, but must leave tasks and
# HEAD untouched so the next substantive transaction can include the records.
failed_head=$(get_git_head_snapshot "$TMP_COMMIT_REPO")
failed_state=$(get_task_state_snapshot "$TMP_COMMIT_SPEC/tasks.md")
failed_count=$(get_incomplete_task_count "$TMP_COMMIT_SPEC/tasks.md")
printf '%s\n' '- failed approach retained' >> "$TMP_COMMIT_SPEC/ralph-memory.md"
printf '%s\n' 'failed iteration retained' >> "$TMP_COMMIT_SPEC/progress.md"
assert_true "accepts failed-attempt retention without HEAD advance" validate_iteration_commit_history "$TMP_COMMIT_REPO" "$failed_head" "$failed_state" "$failed_count" "$failed_count" 7 "$TMP_COMMIT_SPEC/tasks.md" "$TMP_COMMIT_SPEC/progress.md" "$TMP_COMMIT_SPEC/ralph-memory.md"
assert_eq "failed attempt leaves HEAD unchanged" "$failed_head" "$(get_git_head_snapshot "$TMP_COMMIT_REPO")"
assert_true "failed attempt retains memory change" grep -q 'failed approach retained' "$TMP_COMMIT_SPEC/ralph-memory.md"
assert_true "failed attempt retains audit change" grep -q 'failed iteration retained' "$TMP_COMMIT_SPEC/progress.md"

followup_head=$(get_git_head_snapshot "$TMP_COMMIT_REPO")
followup_state=$(get_task_state_snapshot "$TMP_COMMIT_SPEC/tasks.md")
followup_before=$(get_incomplete_task_count "$TMP_COMMIT_SPEC/tasks.md")
printf '%s\n' 'substantive two' >> "$TMP_COMMIT_REPO/source.txt"
sed -i.bak 's/- \[ \] T002/- [x] T002/' "$TMP_COMMIT_SPEC/tasks.md"
rm -f "$TMP_COMMIT_SPEC/tasks.md.bak"
git -C "$TMP_COMMIT_REPO" add .
git -C "$TMP_COMMIT_REPO" commit -qm "follow-up coordinated work"
followup_after=$(get_incomplete_task_count "$TMP_COMMIT_SPEC/tasks.md")
assert_true "accepts later substantive inclusion of retained records" validate_iteration_commit_history "$TMP_COMMIT_REPO" "$followup_head" "$followup_state" "$followup_before" "$followup_after" 0 "$TMP_COMMIT_SPEC/tasks.md" "$TMP_COMMIT_SPEC/progress.md" "$TMP_COMMIT_SPEC/ralph-memory.md"
followup_paths=$(git -C "$TMP_COMMIT_REPO" show --pretty=format: --name-only HEAD)
assert_true "follow-up commit contains retained memory" grep -Fxq 'specs/test-feature/ralph-memory.md' <<< "$followup_paths"
assert_true "follow-up commit contains retained audit" grep -Fxq 'specs/test-feature/progress.md' <<< "$followup_paths"

bookkeeping_head=$(get_git_head_snapshot "$TMP_COMMIT_REPO")
bookkeeping_state=$(get_task_state_snapshot "$TMP_COMMIT_SPEC/tasks.md")
bookkeeping_count=$(get_incomplete_task_count "$TMP_COMMIT_SPEC/tasks.md")
printf '%s\n' 'bookkeeping only' >> "$TMP_COMMIT_SPEC/progress.md"
git -C "$TMP_COMMIT_REPO" add "$TMP_COMMIT_SPEC/progress.md"
git -C "$TMP_COMMIT_REPO" commit -qm "bookkeeping only"
bookkeeping_committed_head=$(git -C "$TMP_COMMIT_REPO" rev-parse HEAD)
set +e
bookkeeping_output=$(validate_iteration_commit_history "$TMP_COMMIT_REPO" "$bookkeeping_head" "$bookkeeping_state" "$bookkeeping_count" "$bookkeeping_count" 0 "$TMP_COMMIT_SPEC/tasks.md" "$TMP_COMMIT_SPEC/progress.md" "$TMP_COMMIT_SPEC/ralph-memory.md" 2>&1)
bookkeeping_exit=$?
set -e
assert_eq "bookkeeping-only commit validation exits one" "1" "$bookkeeping_exit"
assert_true "reports bookkeeping-only violation" grep -q '^bookkeeping-only:' <<< "$bookkeeping_output"
assert_eq "bookkeeping reporting does not mutate HEAD" "$bookkeeping_committed_head" "$(get_git_head_snapshot "$TMP_COMMIT_REPO")"

rm -rf "$TMP_COMMIT_REPO"

#endregion

#region Tests: Ralph memory preparation

section "Ralph memory preparation"

TMP_MEMORY_ROOT=$(mktemp -d)
MEMORY_TEMPLATE="$REPO_ROOT/templates/ralph-memory.md"
MEMORY_FILE="$TMP_MEMORY_ROOT/ralph-memory.md"

prepare_ralph_memory "$MEMORY_TEMPLATE" "$MEMORY_FILE" "test-feature" >/dev/null 2>&1
assert_true "renders missing memory from shared template" test -f "$MEMORY_FILE"
assert_true "renders exact feature identity" grep -Fxq "Feature: test-feature" "$MEMORY_FILE"
assert_true "renders parseable UTC timestamp" grep -Eq '^Started: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$MEMORY_FILE"
assert_false "resolves every declared template token" grep -Eq '\{\{[^}]+\}\}' "$MEMORY_FILE"
assert_true "rendered memory validates" validate_ralph_memory_file "$MEMORY_TEMPLATE" "$MEMORY_FILE" "test-feature"

expected_headings="# Ralph Memory
## Codebase Patterns
## Decisions
## Gotchas
## Reusable Commands
## Do Not Repeat
## Current Handoff"
actual_headings=$(awk '/^# / || /^## / { print }' "$MEMORY_FILE")
assert_eq "parity contract uses canonical heading set and order" "$expected_headings" "$actual_headings"
assert_eq "parity contract has one Feature metadata field" "1" "$(grep -c '^Feature: test-feature$' "$MEMORY_FILE")"
assert_eq "parity contract has one Started metadata field" "1" "$(grep -Ec '^Started: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$' "$MEMORY_FILE")"

cp "$FIXTURE_DIR/ralph-memory-valid-active.md" "$MEMORY_FILE"
cp "$MEMORY_FILE" "$TMP_MEMORY_ROOT/valid.before"
prepare_ralph_memory "$MEMORY_TEMPLATE" "$MEMORY_FILE" "test-feature" >/dev/null 2>&1
assert_true "preserves an existing valid memory byte-for-byte" cmp -s "$TMP_MEMORY_ROOT/valid.before" "$MEMORY_FILE"

CRLF_ACTIVE_MEMORY="$TMP_MEMORY_ROOT/valid-active-crlf.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$FIXTURE_DIR/ralph-memory-valid-active.md" > "$CRLF_ACTIVE_MEMORY"
cp "$CRLF_ACTIVE_MEMORY" "$TMP_MEMORY_ROOT/valid-active-crlf.before"
assert_true "accepts CRLF feature memory by semantic structure" validate_ralph_memory_file "$MEMORY_TEMPLATE" "$CRLF_ACTIVE_MEMORY" "test-feature"
assert_true "preserves valid CRLF feature memory byte-for-byte" prepare_ralph_memory "$MEMORY_TEMPLATE" "$CRLF_ACTIVE_MEMORY" "test-feature"
assert_true "CRLF preparation performs no normalization" cmp -s "$TMP_MEMORY_ROOT/valid-active-crlf.before" "$CRLF_ACTIVE_MEMORY"

CRLF_COMPLETE_MEMORY="$TMP_MEMORY_ROOT/valid-complete-crlf.md"
awk '{ sub(/\r$/, ""); printf "%s\r\n", $0 }' "$FIXTURE_DIR/ralph-memory-valid-complete.md" > "$CRLF_COMPLETE_MEMORY"
assert_true "accepts terminal handoff in CRLF feature memory" validate_ralph_memory_file "$MEMORY_TEMPLATE" "$CRLF_COMPLETE_MEMORY" "test-feature" true

cp "$FIXTURE_DIR/ralph-memory-malformed.md" "$MEMORY_FILE"
cp "$MEMORY_FILE" "$TMP_MEMORY_ROOT/malformed.before"
set +e
malformed_output=$(prepare_ralph_memory "$MEMORY_TEMPLATE" "$MEMORY_FILE" "test-feature" 2>&1)
malformed_exit=$?
set -e
assert_eq "aggregate malformed memory exits one" "1" "$malformed_exit"
for category in title-invalid feature-invalid started-invalid section-missing section-duplicate section-unexpected section-order token-unresolved; do
    assert_true "reports aggregate defect $category" grep -q "^$category:" <<< "$malformed_output"
done
expected_categories="feature-invalid
section-duplicate
section-missing
section-order
section-unexpected
started-invalid
title-invalid
token-unresolved"
actual_categories=$(sed -n 's/^\([a-z-]*\):.*/\1/p' <<< "$malformed_output" | LC_ALL=C sort -u)
assert_eq "parity contract reports only canonical diagnostic categories" "$expected_categories" "$actual_categories"
assert_true "preserves malformed memory byte-for-byte" cmp -s "$TMP_MEMORY_ROOT/malformed.before" "$MEMORY_FILE"

INVALID_TEMPLATE="$TMP_MEMORY_ROOT/invalid-template.md"
printf '%s\n' '# Ralph Memory' 'Feature: {{FEATURE_NAME}}' > "$INVALID_TEMPLATE"
set +e
invalid_template_output=$(prepare_ralph_memory "$INVALID_TEMPLATE" "$TMP_MEMORY_ROOT/from-invalid.md" "test-feature" 2>&1)
invalid_template_exit=$?
set -e
assert_eq "invalid shared template exits one" "1" "$invalid_template_exit"
assert_true "invalid shared template reports template-unavailable" grep -q '^template-unavailable:' <<< "$invalid_template_output"
assert_false "invalid shared template creates no feature memory" test -e "$TMP_MEMORY_ROOT/from-invalid.md"

rm -rf "$TMP_MEMORY_ROOT"

#endregion

#region Tests: full-script memory preflight

section "full-script memory preflight"

TMP_PREFLIGHT_REPO=$(mktemp -d)
TMP_PREFLIGHT_SPEC="$TMP_PREFLIGHT_REPO/specs/test-feature"
mkdir -p "$TMP_PREFLIGHT_SPEC"
printf '%s\n' '- [ ] T001 Keep working' > "$TMP_PREFLIGHT_SPEC/tasks.md"

FAKE_PREFLIGHT_CLI="$TMP_PREFLIGHT_REPO/copilot"
cat > "$FAKE_PREFLIGHT_CLI" << 'FAKEPREFLIGHT'
#!/usr/bin/env bash
if [[ -f "$RALPH_TEST_MEMORY_PATH" ]] && grep -Fxq 'Feature: test-feature' "$RALPH_TEST_MEMORY_PATH"; then
    printf '%s\n' 'MEMORY_READY_BEFORE_AGENT'
else
    printf '%s\n' 'MEMORY_MISSING_AT_AGENT'
fi
exit 0
FAKEPREFLIGHT
chmod +x "$FAKE_PREFLIGHT_CLI"

set +e
preflight_output=$(cd "$TMP_PREFLIGHT_REPO" && RALPH_TEST_MEMORY_PATH="$TMP_PREFLIGHT_SPEC/ralph-memory.md" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_PREFLIGHT_SPEC/tasks.md" --spec-dir "$TMP_PREFLIGHT_SPEC" --max-iterations 1 --model "fake-model" --agent-cli "$FAKE_PREFLIGHT_CLI" 2>&1)
preflight_exit=$?
set -e
assert_eq "prepared-memory run reaches iteration limit" "1" "$preflight_exit"
assert_true "prepares memory before fake agent invocation" grep -q 'MEMORY_READY_BEFORE_AGENT' <<< "$preflight_output"

cp "$FIXTURE_DIR/ralph-memory-malformed.md" "$TMP_PREFLIGHT_SPEC/ralph-memory.md"
cp "$TMP_PREFLIGHT_SPEC/ralph-memory.md" "$TMP_PREFLIGHT_REPO/malformed.before"
set +e
blocked_output=$(cd "$TMP_PREFLIGHT_REPO" && RALPH_TEST_MEMORY_PATH="$TMP_PREFLIGHT_SPEC/ralph-memory.md" bash "$SOURCE_SCRIPT" --feature-name "test-feature" --tasks-path "$TMP_PREFLIGHT_SPEC/tasks.md" --spec-dir "$TMP_PREFLIGHT_SPEC" --max-iterations 1 --model "fake-model" --agent-cli "$FAKE_PREFLIGHT_CLI" 2>&1)
blocked_exit=$?
set -e
assert_eq "malformed preflight exits one" "1" "$blocked_exit"
assert_false "malformed preflight never invokes agent" grep -q 'MEMORY_.*_AGENT' <<< "$blocked_output"
assert_true "malformed preflight preserves exact bytes" cmp -s "$TMP_PREFLIGHT_REPO/malformed.before" "$TMP_PREFLIGHT_SPEC/ralph-memory.md"

rm -rf "$TMP_PREFLIGHT_REPO"

#endregion

#region Tests: run command guardrails

section "run command guardrails"

assert_true "run treats input as launcher arguments only" grep -q "launcher arguments only" "$RUN_COMMAND"
assert_true "run ignores free-form implementation requests" grep -q "Free-form requests such as" "$RUN_COMMAND"
assert_true "run forbids inline implementation" grep -q "MUST NOT.*implement tasks" "$RUN_COMMAND"
assert_true "run warns that ignored text comes from tasks.md scope" grep -q "Ralph selects work from.*tasks.md" "$RUN_COMMAND"

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

# File contains expected audit-only header content
assert_true "contains feature name" grep -q "Feature: test-feature" "$PROGRESS_FILE"
assert_false "does not initialize durable codebase patterns in audit log" grep -q "## Codebase Patterns" "$PROGRESS_FILE"

# Doesn't overwrite existing file
printf '%s\n' "custom content" > "$PROGRESS_FILE"
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
        printf '  - %s\n' "$f"
    done
    exit 1
fi

echo ""
echo -e "\033[32mAll tests passed.\033[0m"
exit 0

#endregion
