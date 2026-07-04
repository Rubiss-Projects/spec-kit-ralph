<#
.SYNOPSIS
    Regression tests for ralph-loop.ps1 helper functions.

.DESCRIPTION
    Extracts and tests functions in isolation without running the full loop.
    Uses a lightweight assertion harness (no Pester dependency).

.EXAMPLE
    pwsh -File tests/regression/powershell/Test-RalphLoop.ps1
#>

$ErrorActionPreference = "Stop"

$ScriptDir = $PSScriptRoot
$RepoRoot = Resolve-Path (Join-Path $ScriptDir "..\..\..") | Select-Object -ExpandProperty Path
$FixtureDir = Join-Path $ScriptDir "..\fixtures"
$SourceScript = Join-Path $RepoRoot "scripts\powershell\ralph-loop.ps1"
$RunCommand = Join-Path $RepoRoot "commands\run.md"

# Test bookkeeping
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0
$script:Failures = @()

#region Test Harness

function Assert-Equal {
    param([string]$TestName, $Expected, $Actual)
    $script:TestsRun++

    if ($Expected -eq $Actual) {
        Write-Host "  PASS " -NoNewline -ForegroundColor Green
        Write-Host $TestName
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL " -NoNewline -ForegroundColor Red
        Write-Host $TestName
        Write-Host "         expected: [$Expected]"
        Write-Host "         actual:   [$Actual]"
        $script:TestsFailed++
        $script:Failures += $TestName
    }
}

function Assert-True {
    param([string]$TestName, [bool]$Condition)
    $script:TestsRun++

    if ($Condition) {
        Write-Host "  PASS " -NoNewline -ForegroundColor Green
        Write-Host $TestName
        $script:TestsPassed++
    } else {
        Write-Host "  FAIL " -NoNewline -ForegroundColor Red
        Write-Host $TestName
        $script:TestsFailed++
        $script:Failures += $TestName
    }
}

function Write-Section {
    param([string]$Name)
    Write-Host ""
    Write-Host "-- $Name --" -ForegroundColor Cyan
}

function New-FakeCopilot {
    param(
        [string]$Directory,
        [string[]]$OutputLines = @(),
        [int]$ExitCode = 0,
        [switch]$EchoArgs
    )

    $isWindowsRunner = ($env:OS -eq "Windows_NT") -or ($PSVersionTable.PSEdition -eq "Desktop")

    if ($isWindowsRunner) {
        $path = Join-Path $Directory "copilot.cmd"
        $lines = @("@echo off")

        if ($EchoArgs) {
            $lines += @(
                "setlocal enabledelayedexpansion",
                'set "out=ARGS:"',
                ":args_loop",
                'if "%~1"=="" goto args_done',
                'set "out=!out! [%~1]"',
                "shift",
                "goto args_loop",
                ":args_done",
                "echo !out!"
            )
        }

        foreach ($line in $OutputLines) {
            $lines += "echo $line"
        }
        $lines += "exit /b $ExitCode"
        Set-Content -Path $path -Value ($lines -join "`r`n") -Encoding ASCII
        return $path
    }

    $path = Join-Path $Directory "copilot"
    $lines = @("#!/usr/bin/env bash")

    if ($EchoArgs) {
        $lines += @(
            "printf 'ARGS:'",
            'for arg in "$@"; do',
            "    printf ' [%s]' ""`$arg""",
            "done",
            "printf '\n'"
        )
    }

    foreach ($line in $OutputLines) {
        $escaped = $line -replace "'", "'\''"
        $lines += "printf '%s\n' '$escaped'"
    }
    $lines += "exit $ExitCode"
    Set-Content -Path $path -Value ($lines -join "`n") -Encoding UTF8
    & chmod +x $path
    return $path
}

#endregion

#region Extract Functions

# Parse the source script to extract function definitions without executing the main body.
# We use AST parsing to safely extract only the function blocks.
$ast = [System.Management.Automation.Language.Parser]::ParseFile($SourceScript, [ref]$null, [ref]$null)
$functionDefs = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)

foreach ($funcDef in $functionDefs) {
    # Define each function in the current scope
    Invoke-Expression $funcDef.Extent.Text
}

#endregion

#region Tests: run command guardrails

Write-Section "run command guardrails"

$runCommandText = Get-Content $RunCommand -Raw
Assert-True "run treats input as launcher arguments only" ($runCommandText -match "launcher arguments only")
Assert-True "run ignores free-form implementation requests" ($runCommandText -match "Free-form requests such as")
Assert-True "run forbids inline implementation" ($runCommandText -match "MUST NOT.*implement tasks")
Assert-True "run warns that ignored text comes from tasks.md scope" ($runCommandText -match "Ralph selects work from.*tasks.md")

#endregion

#region Tests: Get-IncompleteTaskCount

Write-Section "Get-IncompleteTaskCount"

$missingPath = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent_ralph_test_$PID.md"
$missingRepo = Join-Path ([System.IO.Path]::GetTempPath()) "nonexistent_ralph_test_$PID"

# Missing file -> 0
$result = Get-IncompleteTaskCount -Path $missingPath
Assert-Equal "missing file returns 0" 0 $result

# Empty file -> 0
$tmpFile = [System.IO.Path]::GetTempFileName()
Set-Content -Path $tmpFile -Value "" -Encoding UTF8
$result = Get-IncompleteTaskCount -Path $tmpFile
Assert-Equal "empty file returns 0" 0 $result
Remove-Item $tmpFile -Force

# No checkboxes -> 0
$result = Get-IncompleteTaskCount -Path (Join-Path $FixtureDir "tasks-empty.md")
Assert-Equal "no checkboxes returns 0" 0 $result

# All done -> 0
$result = Get-IncompleteTaskCount -Path (Join-Path $FixtureDir "tasks-all-done.md")
Assert-Equal "all done returns 0" 0 $result

# Mixed tasks -> correct count (3 incomplete with T\d+ pattern)
$result = Get-IncompleteTaskCount -Path (Join-Path $FixtureDir "tasks-mixed.md")
Assert-Equal "mixed tasks returns 3" 3 $result

#endregion

#region Tests: Get-IncompleteTasks

Write-Section "Get-IncompleteTasks"

# Returns correct task IDs from mixed fixture
$tasks = Get-IncompleteTasks -Path (Join-Path $FixtureDir "tasks-mixed.md")
Assert-Equal "returns 3 incomplete tasks" 3 $tasks.Count

# Verify task ID content
Assert-True "first task contains T002" ($tasks[0] -like "T002*")
Assert-True "second task contains T003" ($tasks[1] -like "T003*")
Assert-True "third task contains T006" ($tasks[2] -like "T006*")

# All done -> empty array
$tasks = Get-IncompleteTasks -Path (Join-Path $FixtureDir "tasks-all-done.md")
Assert-Equal "all done returns empty" 0 $tasks.Count

# Missing file -> empty array
$tasks = Get-IncompleteTasks -Path $missingPath
Assert-Equal "missing file returns empty" 0 $tasks.Count

#endregion

#region Tests: Test-CompletionSignal

Write-Section "Test-CompletionSignal"

Assert-True "rejects signal embedded in prose" (-not (Test-CompletionSignal -Output "Some output <promise>COMPLETE</promise> more text"))

Assert-True "rejects negated prose mention (regression)" (-not (Test-CompletionSignal -Output "stopping here; no <promise>COMPLETE</promise>."))

Assert-True "rejects output without signal" (-not (Test-CompletionSignal -Output "Some output without the signal"))

Assert-True "rejects empty string" (-not (Test-CompletionSignal -Output ""))

$multiLine = "line1`n<promise>COMPLETE</promise>`nline3"
Assert-True "detects signal on its own line" (Test-CompletionSignal -Output $multiLine)

$bt = [char]96  # literal backtick, avoids double-quoted-string escaping ambiguity
$backtickLine = "line1`n$bt<promise>COMPLETE</promise>$bt`nline3"
Assert-True "detects signal wrapped in backticks on its own line" (Test-CompletionSignal -Output $backtickLine)

#endregion

#region Tests: Read-RalphConfig

Write-Section "Read-RalphConfig"

# Create temp directory with config structure
$tmpRepo = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-test-$PID"
$configDir = Join-Path $tmpRepo ".specify\extensions\ralph"
New-Item -ItemType Directory -Path $configDir -Force | Out-Null
Copy-Item (Join-Path $FixtureDir "ralph-config-valid.yml") (Join-Path $configDir "ralph-config.yml")

$config = Read-RalphConfig -RepoRoot $tmpRepo

Assert-Equal "loads model from config" "gpt-4o" $config["model"]
Assert-Equal "loads max_iterations from config" "5" $config["max_iterations"]
Assert-Equal "loads agent_cli from config" "my-custom-cli" $config["agent_cli"]

# Missing config -> empty hashtable
$config = Read-RalphConfig -RepoRoot $missingRepo
Assert-Equal "missing config returns empty" 0 $config.Count

# Local config overrides project config
@"
model: "local-model"
max_iterations: 20
"@ | Set-Content (Join-Path $configDir "ralph-config.local.yml") -Encoding UTF8

$config = Read-RalphConfig -RepoRoot $tmpRepo

Assert-Equal "local config overrides model" "local-model" $config["model"]
Assert-Equal "local config overrides max_iterations" "20" $config["max_iterations"]
Assert-Equal "local config inherits agent_cli" "my-custom-cli" $config["agent_cli"]

Remove-Item $tmpRepo -Recurse -Force

#endregion

#region Tests: Get-AgentCliKind

Write-Section "Get-AgentCliKind"

Assert-Equal "detects copilot" "copilot" (Get-AgentCliKind -Cli "copilot")
Assert-Equal "detects codex" "codex" (Get-AgentCliKind -Cli "codex")
Assert-Equal "detects codex path" "codex" (Get-AgentCliKind -Cli "C:\Tools\codex.exe")
Assert-Equal "detects claude" "claude" (Get-AgentCliKind -Cli "claude")
Assert-Equal "detects claude path" "claude" (Get-AgentCliKind -Cli "C:\Tools\claude.exe")
Assert-Equal "rejects unsupported cli" "unsupported" (Get-AgentCliKind -Cli "my-custom-cli")

#endregion

#region Tests: Spec Kit integration command resolution

Write-Section "Spec Kit integration command resolution"

$tmpIntegrationRepo = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-integration-$PID"
$tmpSpecifyDir = Join-Path $tmpIntegrationRepo ".specify"
New-Item -ItemType Directory -Path $tmpSpecifyDir -Force | Out-Null

$integrationConfig = Read-SpecKitIntegrationConfig -RepoRoot $tmpIntegrationRepo
Assert-Equal "missing integration defaults to dot separator" "." $integrationConfig.invoke_separator
Assert-Equal "dot separator keeps dotted command" "speckit.ralph.iterate" (Join-IntegrationCommandName -CommandName "speckit.ralph.iterate" -Separator ".")
Assert-Equal "dash separator builds skills command" "speckit-ralph-iterate" (Join-IntegrationCommandName -CommandName "speckit.ralph.iterate" -Separator "-")
Assert-True "dash separator enables skills mode" (Test-CopilotSkillsMode -InvokeSeparator "-")
Assert-True "dot separator disables skills mode" (-not (Test-CopilotSkillsMode -InvokeSeparator "."))
Assert-Equal "skills mode prompt uses slash command" "/speckit-ralph-iterate Iteration 1 - Complete one work unit from tasks.md" (New-CopilotIterationPrompt -AgentName "speckit-ralph-iterate" -InvokeSeparator "-" -Prompt "Iteration 1 - Complete one work unit from tasks.md")
Assert-Equal "agent mode prompt is plain prompt" "Iteration 1 - Complete one work unit from tasks.md" (New-CopilotIterationPrompt -AgentName "speckit.ralph.iterate" -InvokeSeparator "." -Prompt "Iteration 1 - Complete one work unit from tasks.md")

@"
{
  "integration": "copilot",
  "integration_settings": {
    "copilot": {
      "raw_options": "--skills",
      "invoke_separator": "-"
    }
  }
}
"@ | Set-Content -Path (Join-Path $tmpSpecifyDir "integration.json") -Encoding UTF8

$integrationConfig = Read-SpecKitIntegrationConfig -RepoRoot $tmpIntegrationRepo
$agentName = Join-IntegrationCommandName -CommandName "speckit.ralph.iterate" -Separator $integrationConfig.invoke_separator

Assert-Equal "reads copilot dash separator" "-" $integrationConfig.invoke_separator
Assert-Equal "resolves copilot skills agent name" "speckit-ralph-iterate" $agentName

@"
{
  "integration": "copilot",
  "raw_options": "--skills",
  "invoke_separator": "-"
}
"@ | Set-Content -Path (Join-Path $tmpSpecifyDir "integration.json") -Encoding UTF8

$integrationConfig = Read-SpecKitIntegrationConfig -RepoRoot $tmpIntegrationRepo
Assert-Equal "legacy top-level copilot settings still work" "-" $integrationConfig.invoke_separator

@"
{
  "integration": "copilot",
  "integration_settings": {
    "copilot": {
      "raw_options": "--skills"
    }
  }
}
"@ | Set-Content -Path (Join-Path $tmpSpecifyDir "integration.json") -Encoding UTF8

$integrationConfig = Read-SpecKitIntegrationConfig -RepoRoot $tmpIntegrationRepo
Assert-Equal "raw skills option implies dash separator" "-" $integrationConfig.invoke_separator

@"
{
  "integration": "copilot",
  "invoke_separator": "_"
}
"@ | Set-Content -Path (Join-Path $tmpSpecifyDir "integration.json") -Encoding UTF8

$integrationConfig = Read-SpecKitIntegrationConfig -RepoRoot $tmpIntegrationRepo
Assert-Equal "invalid invoke separator falls back to dot" "." $integrationConfig.invoke_separator

@"
{
  "integration": "codex",
  "raw_options": "--skills",
  "invoke_separator": "-"
}
"@ | Set-Content -Path (Join-Path $tmpSpecifyDir "integration.json") -Encoding UTF8

$integrationConfig = Read-SpecKitIntegrationConfig -RepoRoot $tmpIntegrationRepo
Assert-Equal "ignores non-copilot separator for copilot path" "." $integrationConfig.invoke_separator

Remove-Item $tmpIntegrationRepo -Recurse -Force

#endregion

#region Tests: Test-AgentResolutionFailure

Write-Section "Test-AgentResolutionFailure"

Assert-True "detects missing agent" (Test-AgentResolutionFailure -Output "No such agent: speckit.ralph.iterate, available:")
Assert-True "detects missing skill" (Test-AgentResolutionFailure -Output "No such skill: speckit-ralph-iterate")
Assert-True "detects unknown option" (Test-AgentResolutionFailure -Output "error: unknown option '--skills'")
Assert-True "ignores bare unknown option prose" (-not (Test-AgentResolutionFailure -Output "The docs mention an unknown option in prose."))
Assert-True "ignores unrelated failure output" (-not (Test-AgentResolutionFailure -Output "model request failed"))

#endregion

#region Tests: New-IterationPrompt

Write-Section "New-IterationPrompt"

$tmpPromptDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-prompt-$PID"
New-Item -ItemType Directory -Path $tmpPromptDir -Force | Out-Null
$script:IterateCommandPath = Join-Path $tmpPromptDir "iterate.md"
@"
## Stop Conditions
Output <promise>COMPLETE</promise> when done.
"@ | Set-Content -Path $script:IterateCommandPath -Encoding UTF8

$prompt = New-IterationPrompt -Iteration 7
Assert-True "prompt includes iteration" ($prompt -match "Ralph iteration 7")
Assert-True "prompt includes iterate command" ($prompt -match "Stop Conditions")
Assert-True "prompt includes completion signal" ($prompt -match "<promise>COMPLETE</promise>")

Remove-Item $tmpPromptDir -Recurse -Force

#endregion

#region Tests: Invoke-CopilotIteration

Write-Section "Invoke-CopilotIteration"

$tmpCopilotDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-copilot-$PID"
New-Item -ItemType Directory -Path $tmpCopilotDir -Force | Out-Null
$fakeCopilot = New-FakeCopilot -Directory $tmpCopilotDir -EchoArgs

$script:AgentCli = $fakeCopilot

$result = Invoke-CopilotIteration -Model "fake-model" -Iteration 1 -WorkDir $tmpCopilotDir
Assert-True "dot mode uses --agent" ($result.Output -match "\[--agent\] \[speckit\.ralph\.iterate\]")
Assert-True "dot mode sends plain prompt" ($result.Output -match "\[-p\] \[Iteration 1 - Complete one work unit from tasks\.md\]")

$tmpSpecifyDir = Join-Path $tmpCopilotDir ".specify"
New-Item -ItemType Directory -Path $tmpSpecifyDir -Force | Out-Null
@"
{
  "integration": "copilot",
  "integration_settings": {
    "copilot": {
      "raw_options": "--skills",
      "invoke_separator": "-"
    }
  }
}
"@ | Set-Content -Path (Join-Path $tmpSpecifyDir "integration.json") -Encoding UTF8

$result = Invoke-CopilotIteration -Model "fake-model" -Iteration 2 -WorkDir $tmpCopilotDir
Assert-True "skills mode does not use --agent" (-not ($result.Output -match "\[--agent\]"))
Assert-True "skills mode sends slash command prompt" ($result.Output -match "\[-p\] \[/speckit-ralph-iterate Iteration 2 - Complete one work unit from tasks\.md\]")
Assert-True "skills mode does not pass --skills runtime flag" (-not ($result.Output -match "\[--skills\]"))

Remove-Item $tmpCopilotDir -Recurse -Force

#endregion

#region Tests: fail-fast resolution guard

Write-Section "fail-fast resolution guard"

$tmpFalsePositiveRepo = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-false-positive-$PID"
$tmpFalsePositiveSpec = Join-Path $tmpFalsePositiveRepo "specs/001-false-positive"
New-Item -ItemType Directory -Path $tmpFalsePositiveSpec -Force | Out-Null
Set-Content -Path (Join-Path $tmpFalsePositiveSpec "tasks.md") -Value "- [ ] T001 Keep working" -Encoding UTF8

$fakeCopilotOkDir = Join-Path $tmpFalsePositiveRepo "ok"
$fakeCopilotFailDir = Join-Path $tmpFalsePositiveRepo "fail"
New-Item -ItemType Directory -Path $fakeCopilotOkDir -Force | Out-Null
New-Item -ItemType Directory -Path $fakeCopilotFailDir -Force | Out-Null

$fakeCopilotOk = New-FakeCopilot `
    -Directory $fakeCopilotOkDir `
    -OutputLines @("The docs mention an unknown option, but this is normal model output.") `
    -ExitCode 0

$falsePositiveOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "001-false-positive" `
    -TasksPath (Join-Path $tmpFalsePositiveSpec "tasks.md") `
    -SpecDir $tmpFalsePositiveSpec `
    -MaxIterations 1 `
    -Model "fake-model" `
    -AgentCli $fakeCopilotOk `
    -WorkingDirectory $tmpFalsePositiveRepo 2>&1
$falsePositiveExit = $LASTEXITCODE
$falsePositiveText = $falsePositiveOutput -join "`n"

Assert-Equal "matching output with zero exit reaches iteration limit" 1 $falsePositiveExit
Assert-True "matching output with zero exit is not fatal" ($falsePositiveText -match "ITERATION LIMIT REACHED")
Assert-True "matching output with zero exit does not report unavailable agent" (-not ($falsePositiveText -match "Agent command unavailable"))

$fakeCopilotFail = New-FakeCopilot `
    -Directory $fakeCopilotFailDir `
    -OutputLines @("error: unknown option '--skills'") `
    -ExitCode 2

$fatalOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "001-false-positive" `
    -TasksPath (Join-Path $tmpFalsePositiveSpec "tasks.md") `
    -SpecDir $tmpFalsePositiveSpec `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $fakeCopilotFail `
    -WorkingDirectory $tmpFalsePositiveRepo 2>&1
$fatalExit = $LASTEXITCODE
$fatalText = $fatalOutput -join "`n"

Assert-Equal "matching output with nonzero exit fails fast" 1 $fatalExit
Assert-True "matching output with nonzero exit reports unavailable agent" ($fatalText -match "Agent command unavailable")

Remove-Item $tmpFalsePositiveRepo -Recurse -Force

#endregion

#region Tests: Initialize-ProgressFile

Write-Section "Initialize-ProgressFile"

$tmpDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-progress-$PID"
New-Item -ItemType Directory -Path $tmpDir -Force | Out-Null

# Creates file when missing
$progressFile = Join-Path $tmpDir "progress.md"
Initialize-ProgressFile -Path $progressFile -Feature "test-feature"
Assert-True "creates progress file" (Test-Path $progressFile)

$content = Get-Content $progressFile -Raw
Assert-True "contains feature name" ($content -match "Feature: test-feature")
Assert-True "contains codebase patterns section" ($content -match "## Codebase Patterns")

# Doesn't overwrite existing file
Set-Content -Path $progressFile -Value "custom content" -Encoding UTF8
Initialize-ProgressFile -Path $progressFile -Feature "other-feature"
$content = (Get-Content $progressFile -Raw).Trim()
Assert-Equal "does not overwrite existing file" "custom content" $content

Remove-Item $tmpDir -Recurse -Force

#endregion

#region Summary

Write-Host ""
Write-Host ("=" * 40) -ForegroundColor Cyan
Write-Host "  PowerShell Regression Test Summary" -ForegroundColor Cyan
Write-Host ("=" * 40) -ForegroundColor Cyan
Write-Host "  Total:  $script:TestsRun"
Write-Host "  Passed: " -NoNewline; Write-Host "$script:TestsPassed" -ForegroundColor Green
Write-Host "  Failed: " -NoNewline; Write-Host "$script:TestsFailed" -ForegroundColor Red

if ($script:TestsFailed -gt 0) {
    Write-Host ""
    Write-Host "Failed tests:" -ForegroundColor Red
    foreach ($f in $script:Failures) {
        Write-Host "  - $f"
    }
    exit 1
}

Write-Host ""
Write-Host "All tests passed." -ForegroundColor Green
exit 0

#endregion
