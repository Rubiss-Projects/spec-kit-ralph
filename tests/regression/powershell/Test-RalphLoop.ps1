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
$MemoryTemplate = Join-Path $RepoRoot "templates\ralph-memory.md"

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

function ConvertTo-BatchEchoLiteral {
    param([string]$Value)

    return $Value.Replace("^", "^^").Replace("%", "%%").Replace("&", "^&").Replace("|", "^|").Replace("<", "^<").Replace(">", "^>")
}

function New-FakeCopilot {
    param(
        [string]$Directory,
        [string[]]$OutputLines = @(),
        [int]$ExitCode = 0,
        [switch]$EchoArgs,
        [string]$RequiredFile = "",
        [string]$InvocationLog = "",
        [string]$PowerShellScript = ""
    )

    $isWindowsRunner = ($env:OS -eq "Windows_NT") -or ($PSVersionTable.PSEdition -eq "Desktop")

    if ($isWindowsRunner) {
        $path = Join-Path $Directory "copilot.cmd"
        $lines = @("@echo off")

        if ($InvocationLog) {
            $lines += "echo invoked>>`"$InvocationLog`""
        }
        if ($PowerShellScript) {
            $lines += @(
                "powershell.exe -NoLogo -NoProfile -File `"$PowerShellScript`"",
                "exit /b %errorlevel%"
            )
        }

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

        if ($RequiredFile) {
            $lines += @(
                "if not exist `"$RequiredFile`" exit /b 91",
                "echo MEMORY_READY"
            )
        }

        foreach ($line in $OutputLines) {
            $lines += "echo $(ConvertTo-BatchEchoLiteral -Value $line)"
        }
        $lines += "exit /b $ExitCode"
        Set-Content -Path $path -Value ($lines -join "`r`n") -Encoding ASCII
        return $path
    }

    $path = Join-Path $Directory "copilot"
    $lines = @("#!/usr/bin/env bash")

    if ($InvocationLog) {
        $escapedInvocationLog = $InvocationLog -replace "'", "'\''"
        $lines += "printf '%s\n' 'invoked' >> '$escapedInvocationLog'"
    }
    if ($PowerShellScript) {
        $escapedPowerShellScript = $PowerShellScript -replace "'", "'\''"
        $lines += @(
            "pwsh -NoLogo -NoProfile -File '$escapedPowerShellScript'",
            'exit $?'
        )
    }

    if ($EchoArgs) {
        $lines += @(
            "printf 'ARGS:'",
            'for arg in "$@"; do',
            "    printf ' [%s]' ""`$arg""",
            "done",
            "printf '\n'"
        )
    }

    if ($RequiredFile) {
        $escapedRequiredFile = $RequiredFile -replace "'", "'\''"
        $lines += @(
            "test -f '$escapedRequiredFile' || exit 91",
            "printf '%s\n' 'MEMORY_READY'"
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

function Invoke-TestGit {
    param(
        [string]$Repository,
        [string[]]$Arguments
    )

    $output = & git -C $Repository @Arguments 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($Arguments -join ' ') failed: $($output -join "`n")"
    }
    return $output
}

function New-TransactionTestRepository {
    param([string]$Name)

    $repository = Join-Path ([System.IO.Path]::GetTempPath()) "$Name-$PID"
    $specDir = Join-Path $repository "specs/test-feature"
    New-Item -ItemType Directory -Path $specDir -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $repository "src") -Force | Out-Null

    Invoke-TestGit -Repository $repository -Arguments @("init", "-q") | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @("config", "user.email", "ralph-tests@example.invalid") | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @("config", "user.name", "Ralph Tests") | Out-Null

    Set-Content -Path (Join-Path $specDir "tasks.md") -Value "- [ ] T001 Complete transaction" -Encoding UTF8
    Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-active.md") (Join-Path $specDir "ralph-memory.md")
    Set-Content -Path (Join-Path $specDir "progress.md") -Value "# Ralph Progress Log`n`nFeature: test-feature`n`n---" -Encoding UTF8
    Set-Content -Path (Join-Path $repository "src/work.txt") -Value "baseline" -Encoding UTF8
    Invoke-TestGit -Repository $repository -Arguments @("add", ".") | Out-Null
    Invoke-TestGit -Repository $repository -Arguments @("commit", "-q", "-m", "test: baseline") | Out-Null

    return [pscustomobject]@{
        Root = $repository
        SpecDir = $specDir
        TasksPath = Join-Path $specDir "tasks.md"
        MemoryPath = Join-Path $specDir "ralph-memory.md"
        ProgressPath = Join-Path $specDir "progress.md"
        SubstantivePath = Join-Path $repository "src/work.txt"
    }
}

#endregion

#region Extract Functions

# Parse the source script to extract function definitions without executing the main body.
# We use AST parsing to safely extract only the function blocks.
$sourceText = [System.IO.File]::ReadAllText($SourceScript)
$ast = [System.Management.Automation.Language.Parser]::ParseFile($SourceScript, [ref]$null, [ref]$null)
$functionDefs = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $false)

foreach ($funcDef in $functionDefs) {
    # Define each function in the current scope
    Invoke-Expression $funcDef.Extent.Text
}

#endregion

#region Tests: Ralph memory preparation

Write-Section "Ralph memory preparation"

$tmpMemoryDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-memory-$PID"
New-Item -ItemType Directory -Path $tmpMemoryDir -Force | Out-Null
$memoryFile = Join-Path $tmpMemoryDir "ralph-memory.md"

$templateText = [System.IO.File]::ReadAllText($MemoryTemplate)
Assert-True "shared memory template uses LF after checkout" (-not $templateText.Contains("`r"))

$prepared = Prepare-RalphMemory -Path $memoryFile -TemplatePath $MemoryTemplate -Feature "test-feature"
Assert-True "missing memory renders successfully" $prepared
Assert-True "missing memory creates a file" (Test-Path $memoryFile)

$memoryBytes = [System.IO.File]::ReadAllBytes($memoryFile)
$memoryText = [System.IO.File]::ReadAllText($memoryFile)
Assert-True "rendered memory is UTF-8 without BOM" (-not ($memoryBytes.Length -ge 3 -and $memoryBytes[0] -eq 0xEF -and $memoryBytes[1] -eq 0xBB -and $memoryBytes[2] -eq 0xBF))
Assert-True "rendered memory uses LF line endings" (-not $memoryText.Contains("`r"))
Assert-True "rendered memory replaces feature token" ($memoryText -match '(?m)^Feature: test-feature$')
Assert-True "rendered memory replaces timestamp token" ($memoryText -match '(?m)^Started: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$')
Assert-True "rendered memory has no unresolved tokens" (-not ($memoryText -match '\{\{[^{}]+\}\}'))
Assert-Equal "rendered memory has six canonical sections" 6 ([regex]::Matches($memoryText, '(?m)^## ').Count)
$expectedHeadings = @(
    "# Ralph Memory",
    "## Codebase Patterns",
    "## Decisions",
    "## Gotchas",
    "## Reusable Commands",
    "## Do Not Repeat",
    "## Current Handoff"
)
$actualHeadings = [regex]::Matches($memoryText, '(?m)^#{1,2} .+$') | ForEach-Object { $_.Value }
Assert-Equal "parity contract uses canonical heading set and order" ($expectedHeadings -join "`n") ($actualHeadings -join "`n")
Assert-Equal "parity contract has one Feature metadata field" 1 ([regex]::Matches($memoryText, '(?m)^Feature: test-feature$').Count)
Assert-Equal "parity contract has one Started metadata field" 1 ([regex]::Matches($memoryText, '(?m)^Started: \d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z$').Count)

$renderedBefore = [System.IO.File]::ReadAllBytes($memoryFile)
$prepared = Prepare-RalphMemory -Path $memoryFile -TemplatePath $MemoryTemplate -Feature "test-feature"
$renderedAfter = [System.IO.File]::ReadAllBytes($memoryFile)
Assert-True "existing valid memory prepares successfully" $prepared
Assert-Equal "existing valid memory is byte-preserved" ([Convert]::ToBase64String($renderedBefore)) ([Convert]::ToBase64String($renderedAfter))

$crlfActiveText = [System.IO.File]::ReadAllText((Join-Path $FixtureDir "ralph-memory-valid-active.md")).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
[System.IO.File]::WriteAllText($memoryFile, $crlfActiveText, (New-Object System.Text.UTF8Encoding($false)))
$crlfActiveBefore = [System.IO.File]::ReadAllBytes($memoryFile)
Assert-True "accepts CRLF feature memory by semantic structure" (Prepare-RalphMemory -Path $memoryFile -TemplatePath $MemoryTemplate -Feature "test-feature")
Assert-Equal "preserves valid CRLF feature memory byte-for-byte" ([Convert]::ToBase64String($crlfActiveBefore)) ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($memoryFile)))

$crlfCompleteText = [System.IO.File]::ReadAllText((Join-Path $FixtureDir "ralph-memory-valid-complete.md")).Replace("`r`n", "`n").Replace("`r", "`n").Replace("`n", "`r`n")
[System.IO.File]::WriteAllText($memoryFile, $crlfCompleteText, (New-Object System.Text.UTF8Encoding($false)))
$crlfCompleteValidation = Test-RalphMemoryFile -Path $memoryFile -Feature "test-feature" -TemplatePath $MemoryTemplate -RequireCompletedHandoff
Assert-True "accepts terminal handoff in CRLF feature memory" $crlfCompleteValidation.IsValid

$validMemoryText = [System.IO.File]::ReadAllText((Join-Path $FixtureDir "ralph-memory-valid-active.md"))
$startedRegex = [regex]'(?m)^Started: [^\r\n]*'
$invalidStartedValues = @(
    "2026-07-11T12:00:00+00:00",
    "2026-07-11 12:00:00Z",
    "2026-07-11T12:00:00",
    "2026-07-11T12:00:00.000Z",
    "2026-02-29T12:00:00Z"
)
foreach ($invalidStartedValue in $invalidStartedValues) {
    $invalidStartedText = $startedRegex.Replace($validMemoryText, "Started: $invalidStartedValue", 1)
    [System.IO.File]::WriteAllText($memoryFile, $invalidStartedText, (New-Object System.Text.UTF8Encoding($false)))
    $invalidStartedValidation = Test-RalphMemoryFile -Path $memoryFile -Feature "test-feature" -TemplatePath $MemoryTemplate
    Assert-True "rejects noncanonical Started value $invalidStartedValue" (-not $invalidStartedValidation.IsValid)
    Assert-Equal "reports one started-invalid for $invalidStartedValue" 1 (($invalidStartedValidation.Defects | Where-Object { $_ -like 'started-invalid:*' }).Count)
}

Copy-Item (Join-Path $FixtureDir "ralph-memory-malformed.md") $memoryFile -Force
$malformedBefore = [System.IO.File]::ReadAllBytes($memoryFile)
$validation = Test-RalphMemoryFile -Path $memoryFile -Feature "test-feature" -TemplatePath $MemoryTemplate
$expectedCategories = @(
    "title-invalid",
    "feature-invalid",
    "started-invalid",
    "section-missing",
    "section-duplicate",
    "section-unexpected",
    "section-order",
    "token-unresolved"
)
foreach ($category in $expectedCategories) {
    Assert-True "malformed memory reports $category" (($validation.Defects | Where-Object { $_ -like "${category}:*" }).Count -gt 0)
}
Assert-True "malformed memory reports aggregate defects" ($validation.Defects.Count -ge $expectedCategories.Count)
$actualCategories = @($validation.Defects | ForEach-Object { ($_ -split ':', 2)[0] } | Sort-Object -Unique)
Assert-Equal "parity contract reports only canonical diagnostic categories" (($expectedCategories | Sort-Object) -join "`n") ($actualCategories -join "`n")
$prepared = Prepare-RalphMemory -Path $memoryFile -TemplatePath $MemoryTemplate -Feature "test-feature"
$malformedAfter = [System.IO.File]::ReadAllBytes($memoryFile)
Assert-True "malformed memory blocks preparation" (-not $prepared)
Assert-Equal "malformed memory remains byte-for-byte unchanged" ([Convert]::ToBase64String($malformedBefore)) ([Convert]::ToBase64String($malformedAfter))

$invalidTemplate = Join-Path $tmpMemoryDir "invalid-template.md"
Set-Content -Path $invalidTemplate -Value "# Not Ralph Memory`n`n{{FEATURE_NAME}}" -Encoding UTF8
$missingTarget = Join-Path $tmpMemoryDir "from-invalid-template.md"
$prepared = Prepare-RalphMemory -Path $missingTarget -TemplatePath $invalidTemplate -Feature "test-feature"
Assert-True "invalid template blocks preparation" (-not $prepared)
Assert-True "invalid template does not create memory" (-not (Test-Path $missingTarget))

# Preparation is required before every fresh launch, not just once at startup.
Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-active.md") $memoryFile -Force
Assert-True "first repeated preparation accepts canonical memory" (Prepare-RalphMemory -Path $memoryFile -TemplatePath $MemoryTemplate -Feature "test-feature")
Copy-Item (Join-Path $FixtureDir "ralph-memory-malformed.md") $memoryFile -Force
$repeatBefore = [System.IO.File]::ReadAllBytes($memoryFile)
Assert-True "later repeated preparation rejects newly malformed memory" (-not (Prepare-RalphMemory -Path $memoryFile -TemplatePath $MemoryTemplate -Feature "test-feature"))
Assert-Equal "later repeated preparation preserves malformed bytes" ([Convert]::ToBase64String($repeatBefore)) ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($memoryFile)))

Remove-Item $tmpMemoryDir -Recurse -Force

#endregion

#region Tests: coordinated commit postconditions

Write-Section "coordinated commit postconditions"

$transactionRepo = New-TransactionTestRepository -Name "ralph-transaction"

# A failed attempt may retain useful memory/audit changes, but may not change
# task state or advance HEAD. Validation itself must leave retained work intact.
$failedBefore = New-RalphIterationSnapshot -RepoRoot $transactionRepo.Root -TasksPath $transactionRepo.TasksPath
$failedHead = $failedBefore.Head
$failedMemory = [System.IO.File]::ReadAllText($transactionRepo.MemoryPath).Replace(
    "## Current Handoff",
    "- Retained failed approach.`n`n## Current Handoff"
)
[System.IO.File]::WriteAllText($transactionRepo.MemoryPath, $failedMemory, (New-Object System.Text.UTF8Encoding($false)))
Add-Content -Path $transactionRepo.ProgressPath -Value "`nFailed attempt retained." -Encoding UTF8
$failedMemoryBeforeValidation = [System.IO.File]::ReadAllBytes($transactionRepo.MemoryPath)
$failedProgressBeforeValidation = [System.IO.File]::ReadAllBytes($transactionRepo.ProgressPath)

$failedValidation = Test-RalphIterationPostconditions `
    -BeforeSnapshot $failedBefore `
    -RepoRoot $transactionRepo.Root `
    -TasksPath $transactionRepo.TasksPath `
    -SpecDir $transactionRepo.SpecDir `
    -AgentExitCode 1

Assert-True "failed attempt retention passes with unchanged tasks and HEAD" $failedValidation.IsValid
Assert-Equal "failed attempt does not advance HEAD" $failedHead ((New-RalphIterationSnapshot -RepoRoot $transactionRepo.Root -TasksPath $transactionRepo.TasksPath).Head)
Assert-Equal "failed attempt memory remains retained" ([Convert]::ToBase64String($failedMemoryBeforeValidation)) ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($transactionRepo.MemoryPath)))
Assert-Equal "failed attempt audit remains retained" ([Convert]::ToBase64String($failedProgressBeforeValidation)) ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($transactionRepo.ProgressPath)))

# The next substantive work-unit commit consumes the retained state and includes
# tasks, memory, progress, and at least one substantive path in one transaction.
$followUpBefore = New-RalphIterationSnapshot -RepoRoot $transactionRepo.Root -TasksPath $transactionRepo.TasksPath
Set-Content -Path $transactionRepo.TasksPath -Value "- [x] T001 Complete transaction" -Encoding UTF8
$followUpMemory = [System.IO.File]::ReadAllText($transactionRepo.MemoryPath).Replace(
    "- Continue the first incomplete work unit.",
    "- Feature complete; no handoff required."
)
[System.IO.File]::WriteAllText($transactionRepo.MemoryPath, $followUpMemory, (New-Object System.Text.UTF8Encoding($false)))
Add-Content -Path $transactionRepo.ProgressPath -Value "`nFollow-up work unit completed." -Encoding UTF8
Add-Content -Path $transactionRepo.SubstantivePath -Value "`nsubstantive change" -Encoding UTF8
Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("add", ".") | Out-Null
Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("commit", "-q", "-m", "feat: coordinated transaction") | Out-Null
$followUpHead = (Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()

$followUpValidation = Test-RalphIterationPostconditions `
    -BeforeSnapshot $followUpBefore `
    -RepoRoot $transactionRepo.Root `
    -TasksPath $transactionRepo.TasksPath `
    -SpecDir $transactionRepo.SpecDir `
    -AgentExitCode 0

Assert-True "later substantive commit includes retained coordinated state" $followUpValidation.IsValid
Assert-Equal "coordinated validation leaves substantive HEAD unchanged" $followUpHead ((Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())
Assert-True "coordinated commit includes tasks" ((Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("show", "--pretty=format:", "--name-only", "HEAD")) -contains "specs/test-feature/tasks.md")
Assert-True "coordinated commit includes memory" ((Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("show", "--pretty=format:", "--name-only", "HEAD")) -contains "specs/test-feature/ralph-memory.md")
Assert-True "coordinated commit includes progress" ((Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("show", "--pretty=format:", "--name-only", "HEAD")) -contains "specs/test-feature/progress.md")
Assert-True "coordinated commit includes substantive path" ((Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("show", "--pretty=format:", "--name-only", "HEAD")) -contains "src/work.txt")
Assert-True "follow-up commit carries retained failure knowledge" (((Invoke-TestGit -Repository $transactionRepo.Root -Arguments @("show", "HEAD:specs/test-feature/ralph-memory.md")) -join "`n") -match "Retained failed approach")

Remove-Item $transactionRepo.Root -Recurse -Force

# A failed agent that advances HEAD without completing a task reports the
# history violation exactly once, even when commit-content diagnostics follow.
$failedAdvanceRepo = New-TransactionTestRepository -Name "ralph-failed-advanced-head"
$failedAdvanceBefore = New-RalphIterationSnapshot -RepoRoot $failedAdvanceRepo.Root -TasksPath $failedAdvanceRepo.TasksPath
Add-Content -Path $failedAdvanceRepo.SubstantivePath -Value "`nfailed agent commit" -Encoding UTF8
Invoke-TestGit -Repository $failedAdvanceRepo.Root -Arguments @("add", "src/work.txt") | Out-Null
Invoke-TestGit -Repository $failedAdvanceRepo.Root -Arguments @("commit", "-q", "-m", "test: failed agent advanced head") | Out-Null
$failedAdvanceValidation = Test-RalphIterationPostconditions `
    -BeforeSnapshot $failedAdvanceBefore `
    -RepoRoot $failedAdvanceRepo.Root `
    -TasksPath $failedAdvanceRepo.TasksPath `
    -SpecDir $failedAdvanceRepo.SpecDir `
    -AgentExitCode 7
$failedAdvanceDefects = @($failedAdvanceValidation.Defects | Where-Object { $_ -like 'failed-iteration-advanced-head:*' })
Assert-Equal "failed agent HEAD advance emits one diagnostic" 1 $failedAdvanceDefects.Count
Remove-Item $failedAdvanceRepo.Root -Recurse -Force

# A bookkeeping-only commit is reported but never repaired, rewritten, reset,
# amended, reverted, or hidden by the validator.
$bookkeepingRepo = New-TransactionTestRepository -Name "ralph-bookkeeping"
$bookkeepingBefore = New-RalphIterationSnapshot -RepoRoot $bookkeepingRepo.Root -TasksPath $bookkeepingRepo.TasksPath
Set-Content -Path $bookkeepingRepo.TasksPath -Value "- [x] T001 Complete transaction" -Encoding UTF8
Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-complete.md") $bookkeepingRepo.MemoryPath -Force
Add-Content -Path $bookkeepingRepo.ProgressPath -Value "`nBookkeeping only." -Encoding UTF8
Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("add", "specs/test-feature/tasks.md", "specs/test-feature/ralph-memory.md", "specs/test-feature/progress.md") | Out-Null
Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("commit", "-q", "-m", "chore: bookkeeping only") | Out-Null
$bookkeepingHeadBeforeValidation = (Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()
$bookkeepingStatusBeforeValidation = (Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("status", "--short", "--untracked-files=all")) -join "`n"
$bookkeepingHistoryBeforeValidation = (Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim()

$bookkeepingValidation = Test-RalphIterationPostconditions `
    -BeforeSnapshot $bookkeepingBefore `
    -RepoRoot $bookkeepingRepo.Root `
    -TasksPath $bookkeepingRepo.TasksPath `
    -SpecDir $bookkeepingRepo.SpecDir `
    -AgentExitCode 0

Assert-True "bookkeeping-only commit is rejected" (-not $bookkeepingValidation.IsValid)
Assert-True "bookkeeping-only diagnostic is reported" (($bookkeepingValidation.Defects | Where-Object { $_ -like 'bookkeeping-only:*' }).Count -gt 0)
Assert-Equal "bookkeeping validator does not move HEAD" $bookkeepingHeadBeforeValidation ((Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())
Assert-Equal "bookkeeping validator does not change worktree or index" $bookkeepingStatusBeforeValidation ((Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("status", "--short", "--untracked-files=all")) -join "`n")
Assert-Equal "bookkeeping validator does not rewrite history" $bookkeepingHistoryBeforeValidation ((Invoke-TestGit -Repository $bookkeepingRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim())

Remove-Item $bookkeepingRepo.Root -Recurse -Force

# A substantive commit is still inconsistent when it omits any coordinated
# state artifact. Reporting the omission must also remain read-only.
$incompleteRepo = New-TransactionTestRepository -Name "ralph-incomplete-commit"
$incompleteBefore = New-RalphIterationSnapshot -RepoRoot $incompleteRepo.Root -TasksPath $incompleteRepo.TasksPath
Set-Content -Path $incompleteRepo.TasksPath -Value "- [x] T001 Complete transaction" -Encoding UTF8
Add-Content -Path $incompleteRepo.ProgressPath -Value "`nIncomplete coordinated commit." -Encoding UTF8
Add-Content -Path $incompleteRepo.SubstantivePath -Value "`nsubstantive but incomplete" -Encoding UTF8
Invoke-TestGit -Repository $incompleteRepo.Root -Arguments @("add", "specs/test-feature/tasks.md", "specs/test-feature/progress.md", "src/work.txt") | Out-Null
Invoke-TestGit -Repository $incompleteRepo.Root -Arguments @("commit", "-q", "-m", "feat: incomplete transaction") | Out-Null
$incompleteHead = (Invoke-TestGit -Repository $incompleteRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()

$incompleteValidation = Test-RalphIterationPostconditions `
    -BeforeSnapshot $incompleteBefore `
    -RepoRoot $incompleteRepo.Root `
    -TasksPath $incompleteRepo.TasksPath `
    -SpecDir $incompleteRepo.SpecDir `
    -AgentExitCode 0

Assert-True "substantive commit missing memory is rejected" (-not $incompleteValidation.IsValid)
Assert-True "missing coordinated memory diagnostic is reported" (($incompleteValidation.Defects | Where-Object { $_ -like 'coordinated-commit-invalid:*ralph-memory.md' }).Count -gt 0)
Assert-Equal "incomplete transaction validator leaves HEAD unchanged" $incompleteHead ((Invoke-TestGit -Repository $incompleteRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())

$postconditionFunction = $functionDefs | Where-Object { $_.Name -eq "Test-RalphIterationPostconditions" } | Select-Object -First 1
Assert-True "postcondition validator contains no mutating Git command" (-not ($postconditionFunction.Extent.Text -match '(?im)&\s+git\b[^\r\n]*\s+(add|commit|reset|rebase|revert|checkout|stash)(?:\s|$)'))

Remove-Item $incompleteRepo.Root -Recurse -Force

#endregion

#region Tests: centralized completion gate

Write-Section "centralized completion gate"

Assert-Equal "batch fake agent escapes completion-token metacharacters" "^<promise^>COMPLETE^</promise^>" (ConvertTo-BatchEchoLiteral -Value "<promise>COMPLETE</promise>")

$handoffValidationActive = Test-RalphMemoryFile `
    -Path (Join-Path $FixtureDir "ralph-memory-valid-active.md") `
    -Feature "test-feature" `
    -TemplatePath $MemoryTemplate `
    -RequireCompletedHandoff
Assert-True "active memory is invalid for completion" (-not $handoffValidationActive.IsValid)
Assert-True "active memory reports handoff-invalid" (($handoffValidationActive.Defects | Where-Object { $_ -like 'handoff-invalid:*' }).Count -eq 1)

$handoffValidationComplete = Test-RalphMemoryFile `
    -Path (Join-Path $FixtureDir "ralph-memory-valid-complete.md") `
    -Feature "test-feature" `
    -TemplatePath $MemoryTemplate `
    -RequireCompletedHandoff
Assert-True "exact terminal handoff is valid for completion" $handoffValidationComplete.IsValid

$noBlankHandoffPath = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-no-blank-handoff-$PID.md"
$noBlankHandoffText = [System.IO.File]::ReadAllText((Join-Path $FixtureDir "ralph-memory-valid-complete.md")).
    Replace("## Current Handoff`r`n`r`n-", "## Current Handoff`r`n-").
    Replace("## Current Handoff`n`n-", "## Current Handoff`n-")
[System.IO.File]::WriteAllText($noBlankHandoffPath, $noBlankHandoffText, (New-Object System.Text.UTF8Encoding($false)))
$noBlankHandoffValidation = Test-RalphMemoryFile `
    -Path $noBlankHandoffPath `
    -Feature "test-feature" `
    -TemplatePath $MemoryTemplate `
    -RequireCompletedHandoff
Assert-True "terminal handoff without blank spacer is valid for completion" $noBlankHandoffValidation.IsValid
Remove-Item $noBlankHandoffPath -Force

$handoffValidationMalformed = Test-RalphMemoryFile `
    -Path (Join-Path $FixtureDir "ralph-memory-malformed.md") `
    -Feature "test-feature" `
    -TemplatePath $MemoryTemplate `
    -RequireCompletedHandoff
Assert-True "malformed completion validation aggregates handoff-invalid" (($handoffValidationMalformed.Defects | Where-Object { $_ -like 'handoff-invalid:*' }).Count -eq 1)
foreach ($category in $expectedCategories) {
    Assert-True "malformed completion retains $category" (($handoffValidationMalformed.Defects | Where-Object { $_ -like "${category}:*" }).Count -gt 0)
}

$extraHandoffPath = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-extra-handoff-$PID.md"
Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-complete.md") $extraHandoffPath
Add-Content -Path $extraHandoffPath -Value "- stale extra instruction" -Encoding UTF8
$extraHandoffValidation = Test-RalphMemoryFile `
    -Path $extraHandoffPath `
    -Feature "test-feature" `
    -TemplatePath $MemoryTemplate `
    -RequireCompletedHandoff
Assert-True "extra terminal handoff content is rejected" (-not $extraHandoffValidation.IsValid)
Assert-True "extra terminal handoff content reports handoff-invalid" (($extraHandoffValidation.Defects | Where-Object { $_ -like 'handoff-invalid:*' }).Count -eq 1)
Remove-Item $extraHandoffPath -Force

$completionFunction = $functionDefs | Where-Object { $_.Name -eq "Test-RalphCompletionGate" } | Select-Object -First 1
Assert-True "completion gate contains no mutating Git command" (-not ($completionFunction.Extent.Text -match '(?im)&\s+git\b[^\r\n]*\s+(add|commit|reset|rebase|revert|checkout|stash)(?:\s|$)'))

$consoleFunction = $functionDefs | Where-Object { $_.Name -eq "Set-RalphConsoleControlCMode" } | Select-Object -First 1
Assert-True "console control-c helper exists" ($null -ne $consoleFunction)
Assert-True "console control-c helper catches non-console host errors" ($consoleFunction.Extent.Text -match '(?s)try\s*\{.*TreatControlCAsInput.*\}\s*catch')
Assert-Equal "console control-c assignment is isolated to guarded helper" 1 ([regex]::Matches($sourceText, '\[Console\]::TreatControlCAsInput\s*=').Count)
Assert-Equal "main loop disables console control-c through guarded helper twice" 2 ([regex]::Matches($sourceText, 'Set-RalphConsoleControlCMode -TreatAsInput \$false').Count)

# Initial clean completion succeeds without invoking an agent and leaves Git
# history, index, and worktree byte-for-byte equivalent.
$initialRepo = New-TransactionTestRepository -Name "ralph-initial-complete"
Set-Content -Path $initialRepo.TasksPath -Value "- [x] T001 Complete transaction" -Encoding UTF8
Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-complete.md") $initialRepo.MemoryPath -Force
Add-Content -Path $initialRepo.ProgressPath -Value "`nFeature completed." -Encoding UTF8
Add-Content -Path $initialRepo.SubstantivePath -Value "`nfinal substantive work" -Encoding UTF8
Invoke-TestGit -Repository $initialRepo.Root -Arguments @("add", ".") | Out-Null
Invoke-TestGit -Repository $initialRepo.Root -Arguments @("commit", "-q", "-m", "test: complete feature") | Out-Null
$initialCliDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-initial-cli-$PID"
New-Item -ItemType Directory -Path $initialCliDir -Force | Out-Null
$initialLog = Join-Path $initialCliDir "invocations.log"
$initialCli = New-FakeCopilot -Directory $initialCliDir -OutputLines @("AGENT_INVOKED") -InvocationLog $initialLog
$initialHead = (Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()
$initialHistory = (Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim()

$initialOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "test-feature" `
    -TasksPath $initialRepo.TasksPath `
    -SpecDir $initialRepo.SpecDir `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $initialCli `
    -WorkingDirectory $initialRepo.Root 2>&1
$initialExit = $LASTEXITCODE
$initialText = $initialOutput -join "`n"

Assert-Equal "initial clean completion exits zero" 0 $initialExit
Assert-True "initial clean completion emits completion signal" ($initialText -match '<promise>COMPLETE</promise>')
Assert-True "initial clean completion invokes no agent" (-not (Test-Path $initialLog))
Assert-Equal "initial clean completion preserves HEAD" $initialHead ((Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())
Assert-Equal "initial clean completion preserves history" $initialHistory ((Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim())
Assert-Equal "initial clean completion preserves clean status" "" ((Invoke-TestGit -Repository $initialRepo.Root -Arguments @("status", "--short", "--untracked-files=all")) -join "`n")

# Every dirty porcelain line blocks all-complete state immediately. The gate
# reports all paths, invokes no agent, and performs no cleanup or history edit.
Add-Content -Path $initialRepo.SubstantivePath -Value "`ndirty tracked path" -Encoding UTF8
New-Item -ItemType Directory -Path (Join-Path $initialRepo.Root "nested") -Force | Out-Null
Set-Content -Path (Join-Path $initialRepo.Root "untracked-one.txt") -Value "one" -Encoding UTF8
Set-Content -Path (Join-Path $initialRepo.Root "nested/untracked-two.txt") -Value "two" -Encoding UTF8
$dirtyLines = @(Invoke-TestGit -Repository $initialRepo.Root -Arguments @("status", "--short", "--untracked-files=all"))
$dirtyHead = (Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()
$dirtyHistory = (Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim()

$dirtyOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "test-feature" `
    -TasksPath $initialRepo.TasksPath `
    -SpecDir $initialRepo.SpecDir `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $initialCli `
    -WorkingDirectory $initialRepo.Root 2>&1
$dirtyExit = $LASTEXITCODE
$dirtyText = $dirtyOutput -join "`n"

Assert-Equal "dirty all-complete state exits one" 1 $dirtyExit
foreach ($dirtyLine in $dirtyLines) {
    Assert-True "dirty completion reports $dirtyLine" ($dirtyText -match [regex]::Escape([string]$dirtyLine))
}
Assert-True "dirty all-complete state invokes no agent" (-not (Test-Path $initialLog))
Assert-Equal "dirty completion preserves HEAD" $dirtyHead ((Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())
Assert-Equal "dirty completion preserves history" $dirtyHistory ((Invoke-TestGit -Repository $initialRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim())
Assert-Equal "dirty completion preserves all porcelain state" ($dirtyLines -join "`n") ((Invoke-TestGit -Repository $initialRepo.Root -Arguments @("status", "--short", "--untracked-files=all")) -join "`n")

Remove-Item $initialRepo.Root -Recurse -Force
Remove-Item $initialCliDir -Recurse -Force

# Initial validation must not manufacture a missing audit file. Even with a
# clean repository, the absent active state artifact blocks completion.
$missingProgressRoot = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-missing-progress-$PID"
$missingProgressSpec = Join-Path $missingProgressRoot "specs/test-feature"
New-Item -ItemType Directory -Path $missingProgressSpec -Force | Out-Null
New-Item -ItemType Directory -Path (Join-Path $missingProgressRoot "src") -Force | Out-Null
Invoke-TestGit -Repository $missingProgressRoot -Arguments @("init", "-q") | Out-Null
Invoke-TestGit -Repository $missingProgressRoot -Arguments @("config", "user.email", "ralph-tests@example.invalid") | Out-Null
Invoke-TestGit -Repository $missingProgressRoot -Arguments @("config", "user.name", "Ralph Tests") | Out-Null
$missingProgressTasks = Join-Path $missingProgressSpec "tasks.md"
$missingProgressMemory = Join-Path $missingProgressSpec "ralph-memory.md"
$missingProgressPath = Join-Path $missingProgressSpec "progress.md"
Set-Content -Path $missingProgressTasks -Value "- [x] T001 Complete transaction" -Encoding UTF8
Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-complete.md") $missingProgressMemory
Set-Content -Path (Join-Path $missingProgressRoot "src/work.txt") -Value "completed without audit" -Encoding UTF8
Invoke-TestGit -Repository $missingProgressRoot -Arguments @("add", ".") | Out-Null
Invoke-TestGit -Repository $missingProgressRoot -Arguments @("commit", "-q", "-m", "test: missing progress") | Out-Null
$missingProgressCliDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-missing-progress-cli-$PID"
New-Item -ItemType Directory -Path $missingProgressCliDir -Force | Out-Null
$missingProgressLog = Join-Path $missingProgressCliDir "invocations.log"
$missingProgressCli = New-FakeCopilot -Directory $missingProgressCliDir -OutputLines @("AGENT_INVOKED") -InvocationLog $missingProgressLog

$missingProgressOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "test-feature" `
    -TasksPath $missingProgressTasks `
    -SpecDir $missingProgressSpec `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $missingProgressCli `
    -WorkingDirectory $missingProgressRoot 2>&1
$missingProgressExit = $LASTEXITCODE
$missingProgressText = $missingProgressOutput -join "`n"

Assert-Equal "missing progress blocks initial completion" 1 $missingProgressExit
Assert-True "missing progress reports coordinated commit defect" ($missingProgressText -match 'coordinated-commit-invalid:')
Assert-True "blocked initial completion does not create progress" (-not (Test-Path $missingProgressPath))
Assert-True "blocked missing-progress completion invokes no agent" (-not (Test-Path $missingProgressLog))

Remove-Item $missingProgressRoot -Recurse -Force
Remove-Item $missingProgressCliDir -Recurse -Force

# The latest active-state commit must itself be coordinated and substantive;
# an older valid baseline cannot mask a bookkeeping-only final state commit.
$initialCommitRepo = New-TransactionTestRepository -Name "ralph-initial-incomplete-commit"
Set-Content -Path $initialCommitRepo.TasksPath -Value "- [x] T001 Complete transaction" -Encoding UTF8
Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-complete.md") $initialCommitRepo.MemoryPath -Force
Invoke-TestGit -Repository $initialCommitRepo.Root -Arguments @("add", "specs/test-feature/tasks.md", "specs/test-feature/ralph-memory.md") | Out-Null
Invoke-TestGit -Repository $initialCommitRepo.Root -Arguments @("commit", "-q", "-m", "test: incomplete active state") | Out-Null
$initialCommitCliDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-initial-incomplete-cli-$PID"
New-Item -ItemType Directory -Path $initialCommitCliDir -Force | Out-Null
$initialCommitLog = Join-Path $initialCommitCliDir "invocations.log"
$initialCommitCli = New-FakeCopilot -Directory $initialCommitCliDir -OutputLines @("AGENT_INVOKED") -InvocationLog $initialCommitLog
$initialCommitHead = (Invoke-TestGit -Repository $initialCommitRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()

$initialCommitOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "test-feature" `
    -TasksPath $initialCommitRepo.TasksPath `
    -SpecDir $initialCommitRepo.SpecDir `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $initialCommitCli `
    -WorkingDirectory $initialCommitRepo.Root 2>&1
$initialCommitExit = $LASTEXITCODE
$initialCommitText = $initialCommitOutput -join "`n"

Assert-Equal "incomplete initial active-state commit exits one" 1 $initialCommitExit
Assert-True "incomplete initial active-state commit reports bookkeeping-only" ($initialCommitText -match 'bookkeeping-only:')
Assert-True "incomplete initial active-state commit reports coordinated artifact defect" ($initialCommitText -match 'coordinated-commit-invalid:')
Assert-True "incomplete initial active-state commit invokes no agent" (-not (Test-Path $initialCommitLog))
Assert-Equal "incomplete initial commit validation preserves HEAD" $initialCommitHead ((Invoke-TestGit -Repository $initialCommitRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())

Remove-Item $initialCommitRepo.Root -Recurse -Force
Remove-Item $initialCommitCliDir -Recurse -Force

# All tasks with a stale handoff is inconsistent even when Git is clean.
$staleRepo = New-TransactionTestRepository -Name "ralph-stale-handoff"
Set-Content -Path $staleRepo.TasksPath -Value "- [x] T001 Complete transaction" -Encoding UTF8
Invoke-TestGit -Repository $staleRepo.Root -Arguments @("add", ".") | Out-Null
Invoke-TestGit -Repository $staleRepo.Root -Arguments @("commit", "-q", "-m", "test: stale handoff") | Out-Null
$staleCliDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-stale-cli-$PID"
New-Item -ItemType Directory -Path $staleCliDir -Force | Out-Null
$staleLog = Join-Path $staleCliDir "invocations.log"
$staleCli = New-FakeCopilot -Directory $staleCliDir -OutputLines @("AGENT_INVOKED") -InvocationLog $staleLog
$staleHead = (Invoke-TestGit -Repository $staleRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()

$staleOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "test-feature" `
    -TasksPath $staleRepo.TasksPath `
    -SpecDir $staleRepo.SpecDir `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $staleCli `
    -WorkingDirectory $staleRepo.Root 2>&1
$staleExit = $LASTEXITCODE
$staleText = $staleOutput -join "`n"

Assert-Equal "stale all-complete handoff exits one" 1 $staleExit
Assert-True "stale all-complete handoff reports handoff-invalid" ($staleText -match 'handoff-invalid:')
Assert-True "stale all-complete handoff invokes no agent" (-not (Test-Path $staleLog))
Assert-Equal "stale handoff validation preserves HEAD" $staleHead ((Invoke-TestGit -Repository $staleRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())

Remove-Item $staleRepo.Root -Recurse -Force
Remove-Item $staleCliDir -Recurse -Force

# A successful post-agent candidate performs one coordinated commit, passes the
# same gate, and receives no reconciliation iteration.
$postRepo = New-TransactionTestRepository -Name "ralph-post-complete"
$postCliDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-post-cli-$PID"
New-Item -ItemType Directory -Path $postCliDir -Force | Out-Null
$postAction = Join-Path $postCliDir "complete.ps1"
$postLog = Join-Path $postCliDir "invocations.log"
$postRepoLiteral = $postRepo.Root.Replace("'", "''")
$postTasksLiteral = $postRepo.TasksPath.Replace("'", "''")
$postMemoryLiteral = $postRepo.MemoryPath.Replace("'", "''")
$postCompleteFixtureLiteral = (Join-Path $FixtureDir "ralph-memory-valid-complete.md").Replace("'", "''")
$postProgressLiteral = $postRepo.ProgressPath.Replace("'", "''")
$postSourceLiteral = $postRepo.SubstantivePath.Replace("'", "''")
@"
`$ErrorActionPreference = 'Stop'
Set-Content -Path '$postTasksLiteral' -Value '- [x] T001 Complete transaction' -Encoding UTF8
Copy-Item '$postCompleteFixtureLiteral' '$postMemoryLiteral' -Force
Add-Content -Path '$postProgressLiteral' -Value "`nCompleted iteration." -Encoding UTF8
Add-Content -Path '$postSourceLiteral' -Value "`nsubstantive completion" -Encoding UTF8
& git -C '$postRepoLiteral' add .
if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
& git -C '$postRepoLiteral' commit -q -m 'feat: completed work unit'
if (`$LASTEXITCODE -ne 0) { exit `$LASTEXITCODE }
Write-Output '<promise>COMPLETE</promise>'
"@ | Set-Content -Path $postAction -Encoding UTF8
$postCli = New-FakeCopilot -Directory $postCliDir -InvocationLog $postLog -PowerShellScript $postAction
$postHistoryBefore = [int]((Invoke-TestGit -Repository $postRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim())

$postOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "test-feature" `
    -TasksPath $postRepo.TasksPath `
    -SpecDir $postRepo.SpecDir `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $postCli `
    -WorkingDirectory $postRepo.Root 2>&1
$postExit = $LASTEXITCODE

Assert-Equal "post-agent clean completion exits zero" 0 $postExit
Assert-Equal "post-agent clean completion invokes one iteration" 1 (@(Get-Content $postLog).Count)
Assert-Equal "post-agent clean completion adds exactly one commit" ($postHistoryBefore + 1) ([int]((Invoke-TestGit -Repository $postRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim()))
Assert-Equal "post-agent clean completion leaves repository clean" "" ((Invoke-TestGit -Repository $postRepo.Root -Arguments @("status", "--short", "--untracked-files=all")) -join "`n")

# Restore an active coordinated baseline, then let one final work unit commit
# successfully while leaving multiple new dirty paths. The gate must report all
# paths, fail immediately, and add no repair/reconciliation commit.
Set-Content -Path $postRepo.TasksPath -Value "- [ ] T001 Complete transaction" -Encoding UTF8
Copy-Item (Join-Path $FixtureDir "ralph-memory-valid-active.md") $postRepo.MemoryPath -Force
Add-Content -Path $postRepo.ProgressPath -Value "`nActive baseline for dirty completion." -Encoding UTF8
Add-Content -Path $postRepo.SubstantivePath -Value "`nactive dirty baseline" -Encoding UTF8
Invoke-TestGit -Repository $postRepo.Root -Arguments @("add", ".") | Out-Null
Invoke-TestGit -Repository $postRepo.Root -Arguments @("commit", "-q", "-m", "test: active dirty baseline") | Out-Null
Remove-Item $postLog -Force
$dirtyPostAction = Join-Path $postCliDir "complete-dirty.ps1"
$dirtyOneLiteral = (Join-Path $postRepo.Root "dirty-one.txt").Replace("'", "''")
$dirtyTwoLiteral = (Join-Path $postRepo.Root "dirty-two.txt").Replace("'", "''")
$dirtyPostText = [System.IO.File]::ReadAllText($postAction).Replace(
    "Write-Output '<promise>COMPLETE</promise>'",
    "Set-Content -Path '$dirtyOneLiteral' -Value 'one' -Encoding UTF8`nSet-Content -Path '$dirtyTwoLiteral' -Value 'two' -Encoding UTF8`nWrite-Output '<promise>COMPLETE</promise>'"
)
[System.IO.File]::WriteAllText($dirtyPostAction, $dirtyPostText, (New-Object System.Text.UTF8Encoding($false)))
$dirtyPostCli = New-FakeCopilot -Directory $postCliDir -InvocationLog $postLog -PowerShellScript $dirtyPostAction
$dirtyPostHistoryBefore = [int]((Invoke-TestGit -Repository $postRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim())

$dirtyPostOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "test-feature" `
    -TasksPath $postRepo.TasksPath `
    -SpecDir $postRepo.SpecDir `
    -MaxIterations 3 `
    -Model "fake-model" `
    -AgentCli $dirtyPostCli `
    -WorkingDirectory $postRepo.Root 2>&1
$dirtyPostExit = $LASTEXITCODE
$dirtyPostText = $dirtyPostOutput -join "`n"

Assert-Equal "dirty post-agent completion exits one" 1 $dirtyPostExit
Assert-True "dirty post-agent completion reports first path" ($dirtyPostText -match [regex]::Escape("dirty-path: ?? dirty-one.txt"))
Assert-True "dirty post-agent completion reports second path" ($dirtyPostText -match [regex]::Escape("dirty-path: ?? dirty-two.txt"))
Assert-Equal "dirty post-agent completion invokes no next iteration" 1 (@(Get-Content $postLog).Count)
Assert-Equal "dirty post-agent gate creates no repair commit" ($dirtyPostHistoryBefore + 1) ([int]((Invoke-TestGit -Repository $postRepo.Root -Arguments @("rev-list", "--count", "HEAD") | Select-Object -First 1).Trim()))

Remove-Item $postRepo.Root -Recurse -Force
Remove-Item $postCliDir -Recurse -Force

# A completion token cannot override failure, remaining tasks, or active
# handoff. Both invalid candidates terminate immediately with no next iteration.
$completionParityTexts = @($dirtyText, $initialCommitText, $staleText, $dirtyPostText)
foreach ($tokenCase in @(
    [pscustomobject]@{ Name = "failed-agent-token"; ExitCode = 7; Expected = "agent-result-invalid:" },
    [pscustomobject]@{ Name = "remaining-task-token"; ExitCode = 0; Expected = "tasks-incomplete:" }
)) {
    $tokenRepo = New-TransactionTestRepository -Name "ralph-$($tokenCase.Name)"
    $tokenCliDir = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-$($tokenCase.Name)-cli-$PID"
    New-Item -ItemType Directory -Path $tokenCliDir -Force | Out-Null
    $tokenLog = Join-Path $tokenCliDir "invocations.log"
    $tokenCli = New-FakeCopilot `
        -Directory $tokenCliDir `
        -OutputLines @("TOKEN_CASE_$($tokenCase.Name)", "<promise>COMPLETE</promise>") `
        -ExitCode $tokenCase.ExitCode `
        -InvocationLog $tokenLog
    $tokenHead = (Invoke-TestGit -Repository $tokenRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim()
    $tokenStatus = (Invoke-TestGit -Repository $tokenRepo.Root -Arguments @("status", "--short", "--untracked-files=all")) -join "`n"

    $tokenOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
        -FeatureName "test-feature" `
        -TasksPath $tokenRepo.TasksPath `
        -SpecDir $tokenRepo.SpecDir `
        -MaxIterations 3 `
        -Model "fake-model" `
        -AgentCli $tokenCli `
        -WorkingDirectory $tokenRepo.Root `
        -DetailedOutput 2>&1
    $tokenExit = $LASTEXITCODE
    $tokenText = $tokenOutput -join "`n"
    $completionParityTexts += $tokenText

    Assert-Equal "$($tokenCase.Name) exits one" 1 $tokenExit
    Assert-True "$($tokenCase.Name) reports $($tokenCase.Expected)" ($tokenText -match [regex]::Escape($tokenCase.Expected))
    Assert-Equal "$($tokenCase.Name) invokes no next iteration" 1 (@(Get-Content $tokenLog).Count)
    Assert-Equal "$($tokenCase.Name) preserves HEAD" $tokenHead ((Invoke-TestGit -Repository $tokenRepo.Root -Arguments @("rev-parse", "HEAD") | Select-Object -First 1).Trim())
    Assert-Equal "$($tokenCase.Name) preserves status" $tokenStatus ((Invoke-TestGit -Repository $tokenRepo.Root -Arguments @("status", "--short", "--untracked-files=all")) -join "`n")

    Remove-Item $tokenRepo.Root -Recurse -Force
    Remove-Item $tokenCliDir -Recurse -Force
}

$expectedCompletionCategories = @(
    "agent-result-invalid",
    "bookkeeping-only",
    "commit-postcondition-invalid",
    "coordinated-commit-invalid",
    "dirty-path",
    "handoff-invalid",
    "tasks-incomplete"
)
$completionCategoryPattern = '(?m)^(agent-result-invalid|bookkeeping-only|commit-postcondition-invalid|coordinated-commit-invalid|dirty-path|handoff-invalid|tasks-incomplete):'
$actualCompletionCategories = @(
    [regex]::Matches(($completionParityTexts -join "`n"), $completionCategoryPattern) |
        ForEach-Object { $_.Groups[1].Value } |
        Sort-Object -Unique
)
Assert-Equal "completion parity exposes the canonical diagnostic categories" ($expectedCompletionCategories -join "`n") ($actualCompletionCategories -join "`n")

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

#region Tests: full-script memory preflight

Write-Section "full-script memory preflight"

$tmpPreflightRepo = Join-Path ([System.IO.Path]::GetTempPath()) "ralph-memory-preflight-$PID"
$tmpPreflightSpec = Join-Path $tmpPreflightRepo "specs/001-memory-preflight"
$tmpPreflightCli = Join-Path $tmpPreflightRepo "cli"
New-Item -ItemType Directory -Path $tmpPreflightSpec -Force | Out-Null
New-Item -ItemType Directory -Path $tmpPreflightCli -Force | Out-Null
Set-Content -Path (Join-Path $tmpPreflightSpec "tasks.md") -Value "- [ ] T001 Keep working" -Encoding UTF8
$preflightMemory = Join-Path $tmpPreflightSpec "ralph-memory.md"
$fakePreflightCli = New-FakeCopilot -Directory $tmpPreflightCli -RequiredFile $preflightMemory -ExitCode 0

$preflightOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "001-memory-preflight" `
    -TasksPath (Join-Path $tmpPreflightSpec "tasks.md") `
    -SpecDir $tmpPreflightSpec `
    -MaxIterations 1 `
    -Model "fake-model" `
    -AgentCli $fakePreflightCli `
    -WorkingDirectory $tmpPreflightRepo 2>&1
$preflightExit = $LASTEXITCODE
$preflightText = $preflightOutput -join "`n"

Assert-Equal "full loop with incomplete work reaches iteration limit" 1 $preflightExit
Assert-True "full loop creates memory before agent output" (Test-Path $preflightMemory)
Assert-True "full loop reaches fake agent only after valid preflight" ($preflightText -match "MEMORY_READY")
Assert-True "full loop renders active feature identity" (([System.IO.File]::ReadAllText($preflightMemory)) -match '(?m)^Feature: 001-memory-preflight$')

Copy-Item (Join-Path $FixtureDir "ralph-memory-malformed.md") $preflightMemory -Force
$preflightMalformedBefore = [System.IO.File]::ReadAllBytes($preflightMemory)
$invalidOutput = & pwsh -NoLogo -NoProfile -File $SourceScript `
    -FeatureName "001-memory-preflight" `
    -TasksPath (Join-Path $tmpPreflightSpec "tasks.md") `
    -SpecDir $tmpPreflightSpec `
    -MaxIterations 1 `
    -Model "fake-model" `
    -AgentCli $fakePreflightCli `
    -WorkingDirectory $tmpPreflightRepo 2>&1
$invalidExit = $LASTEXITCODE
$invalidText = $invalidOutput -join "`n"

Assert-Equal "full loop rejects malformed memory before selection" 1 $invalidExit
foreach ($category in $expectedCategories) {
    Assert-True "full loop prints $category" ($invalidText -match [regex]::Escape("${category}:"))
}
Assert-True "full loop does not invoke agent for malformed memory" (-not ($invalidText -match "MEMORY_READY"))
Assert-Equal "full loop preserves malformed memory bytes" ([Convert]::ToBase64String($preflightMalformedBefore)) ([Convert]::ToBase64String([System.IO.File]::ReadAllBytes($preflightMemory)))

Remove-Item $tmpPreflightRepo -Recurse -Force

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
$progressBytes = [System.IO.File]::ReadAllBytes($progressFile)
Assert-True "contains feature name" ($content -match "Feature: test-feature")
Assert-True "new progress file is audit-only" (-not ($content -match "## Codebase Patterns"))
Assert-True "new progress file has audit delimiter" ($content -match '(?m)^---$')
Assert-True "new progress file uses UTF-8 without BOM" (-not ($progressBytes.Length -ge 3 -and $progressBytes[0] -eq 0xEF -and $progressBytes[1] -eq 0xBB -and $progressBytes[2] -eq 0xBF))
Assert-True "new progress file uses LF line endings" (-not $content.Contains("`r"))

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
