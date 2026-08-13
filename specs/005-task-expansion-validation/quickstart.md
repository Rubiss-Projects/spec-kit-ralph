# Quickstart: Validating Task Expansion Progress

**Feature**: 005-task-expansion-validation | **Date**: 2026-08-13

This guide proves that Ralph accepts valid task expansion, rejects task churn,
and keeps iteration limits as the clear loop boundary.

## Prerequisites

- Repository checked out on branch `005-task-expansion-validation`.
- `git`, `bash`, and PowerShell available.
- No new external dependencies are required.

## 1. Regression harnesses

Run both platform harnesses:

```sh
bash tests/regression/bash/test-ralph-loop.sh
```

```powershell
pwsh tests/regression/powershell/Test-RalphLoop.ps1
```

Expected task-expansion cases:

- Completing existing tasks while adding more unchecked tasks is accepted.
- Remaining-task count may increase without causing `failed-iteration-advanced-head`.
- Adding unchecked tasks without completing existing tasks is rejected.
- Replacing task IDs without completing existing tasks is rejected.
- Accepted expansion produces equivalent results in both execution paths.

## 2. Manual reproduction of issue #49

Prepare a task list where one task explicitly produces follow-up tasks:

```markdown
- [ ] T044 Inspect command family coverage
- [ ] T045 Add missing coverage notes
- [ ] T046 Validate proof workflow
- [ ] T047 Update progress and memory
- [ ] T048 Create follow-up implementation slices
```

Run one iteration that completes T044-T048 and adds T058-T069 as unchecked
follow-up tasks.

Expected outcome:

- T044-T048 are checked.
- T058-T069 remain unchecked.
- Ralph accepts the iteration as completed progress.
- Ralph reports that new tasks were added and shows the updated remaining count.
- The loop continues instead of failing with `failed-iteration-advanced-head`.

## 3. Negative guardrail check

Run an iteration that only adds unchecked tasks without checking off any
previously incomplete task.

Expected outcome:

- Ralph rejects the task-state change.
- The result uses the existing failed/no-work task-state diagnostics.
- The iteration is not counted as completed progress.

## 4. Iteration-limit check

Run with a low `max_iterations` and allow a valid expansion to add more tasks
than can be completed within the limit.

Expected outcome:

- Valid expansion iterations are accepted while the limit remains available.
- When the limit is reached with remaining unchecked tasks, Ralph stops with the
  normal iteration-limit result.
- The summary reports completed tasks and remaining tasks without a spurious
  work-unit validation failure.

## 5. Documentation review

Confirm README and iterate guidance explain:

- task expansion is allowed only with completed existing work;
- expansion can increase remaining work;
- `max_iterations` remains the loop boundary;
- failed/no-work iterations must not mutate task state.

## Success

All checks pass when issue #49's dynamic-task scenario is accepted as progress
and invalid task churn remains rejected.
