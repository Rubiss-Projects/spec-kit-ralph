#!/usr/bin/env bash
# Deterministic mock only; invoked by the regression harness, never a real agent.
set -eu
printf '%s\n' invoked >> "$RALPH_TEST_CALLS"
call_count=$(wc -l < "$RALPH_TEST_CALLS" | tr -d ' ')
spec="$RALPH_TEST_SPEC"
mode="$RALPH_TEST_MODE"
printf '%s\n' 'Blocker: required input unavailable.'

complete_task() {
    sed -i.bak "s/^- \[ \] $1 /- [x] $1 /" "$spec/tasks.md"
    rm -f "$spec/tasks.md.bak"
}
commit_unit() {
    printf '%s\n' "Completed unit on call $call_count" >> "$spec/progress.md"
    printf '%s\n' "- Accepted work on call $call_count" >> "$spec/ralph-memory.md"
    printf '%s\n' "Implementation on call $call_count" >> work.txt
    if ! grep -q '^- \[ \]' "$spec/tasks.md"; then
        cp "$RALPH_TEST_COMPLETE_MEMORY" "$spec/ralph-memory.md"
    fi
    git add .
    git commit -qm "$1"
}
case "$mode" in
    memory)
        printf '%s\n' '- Blocker retained in handoff.' >> "$spec/ralph-memory.md"
        printf '%s\n' 'Blocked attempt retained in audit.' >> "$spec/progress.md"
        ;;
    mixed) if [[ "$call_count" -ne 2 ]]; then exit 7; fi ;;
    add-only|fatal-third)
        if [[ "$mode" == add-only || "$call_count" -eq 3 ]]; then
            printf '%s\n' '- [ ] T007 Investigate follow-up' >> "$spec/tasks.md"
        fi
        ;;
    false-token-third)
        if [[ "$call_count" -eq 3 ]]; then printf '%s\n' '<promise>COMPLETE</promise>'; fi
        ;;
    reset|expansion|equal-expansion)
        if [[ "$call_count" -eq 3 ]]; then
            complete_task T001
            if [[ "$mode" != reset ]]; then
                printf '%s\n' '- [ ] T007 Investigate follow-up' >> "$spec/tasks.md"
            fi
            if [[ "$mode" == expansion ]]; then
                printf '%s\n' '- [ ] T008 Verify follow-up' >> "$spec/tasks.md"
            fi
            commit_unit 'feat: complete initial work'
        fi
        ;;
    repair-stuck|repair-reset|repair-final-stuck|repair-final-success)
        if [[ "$call_count" -eq 1 ]]; then
            case "$mode" in
                repair-final-*) complete_task T006 ;;
                *) complete_task T001 ;;
            esac
            commit_unit 'invalid subject'
        elif [[ "$call_count" -eq 3 && ( "$mode" == repair-reset || "$mode" == repair-final-success ) ]]; then
            git commit --amend -qm 'feat(ralph): complete validated work'
        fi
        ;;
    noop) ;;
    *) exit 99 ;;
esac
exit 0
