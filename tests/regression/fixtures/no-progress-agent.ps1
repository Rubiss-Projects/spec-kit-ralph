# Deterministic mock only; invoked by the regression harness, never a real agent.
$ErrorActionPreference = 'Stop'
Add-Content -LiteralPath $env:RALPH_TEST_CALLS -Value 'invoked'
$callCount = @(Get-Content -LiteralPath $env:RALPH_TEST_CALLS).Count
$spec = $env:RALPH_TEST_SPEC
$mode = $env:RALPH_TEST_MODE
$tasks = Join-Path $spec 'tasks.md'
$memory = Join-Path $spec 'ralph-memory.md'
$progress = Join-Path $spec 'progress.md'
Write-Output 'Blocker: required input unavailable.'

function Complete-Task([string]$Id) {
    $text = [System.IO.File]::ReadAllText($tasks).Replace("- [ ] $Id ", "- [x] $Id ")
    [System.IO.File]::WriteAllText($tasks, $text, (New-Object System.Text.UTF8Encoding($false)))
}
function Commit-Unit([string]$Subject) {
    Add-Content -LiteralPath $progress -Value "Completed unit on call $callCount"
    Add-Content -LiteralPath $memory -Value "- Accepted work on call $callCount"
    Add-Content -LiteralPath 'work.txt' -Value "Implementation on call $callCount"
    if (-not ([System.IO.File]::ReadAllText($tasks) -match '(?m)^- \[ \]')) {
        Copy-Item -LiteralPath $env:RALPH_TEST_COMPLETE_MEMORY -Destination $memory -Force
    }
    & git add .
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    & git commit -q -m $Subject
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
switch ($mode) {
    'memory' {
        Add-Content -LiteralPath $memory -Value '- Blocker retained in handoff.'
        Add-Content -LiteralPath $progress -Value 'Blocked attempt retained in audit.'
    }
    'mixed' { if ($callCount -ne 2) { exit 7 } }
    { $_ -in @('add-only', 'fatal-third') } {
        if ($mode -eq 'add-only' -or $callCount -eq 3) {
            Add-Content -LiteralPath $tasks -Value '- [ ] T007 Investigate follow-up'
        }
    }
    'false-token-third' {
        if ($callCount -eq 3) { Write-Output '<promise>COMPLETE</promise>' }
    }
    { $_ -in @('reset', 'expansion', 'equal-expansion') } {
        if ($callCount -eq 3) {
            Complete-Task 'T001'
            if ($mode -ne 'reset') { Add-Content -LiteralPath $tasks -Value '- [ ] T007 Investigate follow-up' }
            if ($mode -eq 'expansion') { Add-Content -LiteralPath $tasks -Value '- [ ] T008 Verify follow-up' }
            Commit-Unit 'feat: complete initial work'
        }
    }
    { $_ -in @('repair-stuck', 'repair-reset', 'repair-final-stuck', 'repair-final-success') } {
        if ($callCount -eq 1) {
            if ($mode -like 'repair-final-*') { Complete-Task 'T006' } else { Complete-Task 'T001' }
            Commit-Unit 'invalid subject'
        } elseif ($callCount -eq 3 -and $mode -in @('repair-reset', 'repair-final-success')) {
            & git commit --amend -q -m 'feat(ralph): complete validated work'
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }
    }
    'noop' { }
    default { exit 99 }
}
exit 0
