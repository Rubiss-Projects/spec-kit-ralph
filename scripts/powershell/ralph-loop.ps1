<#
.SYNOPSIS
    Ralph loop orchestrator for autonomous implementation.

.DESCRIPTION
    Executes an AI agent CLI in a controlled loop, processing tasks from tasks.md.
    Each iteration spawns a fresh agent context with the speckit.ralph profile.
    
    The loop terminates when:
    - Agent outputs <promise>COMPLETE</promise>
    - Max iterations reached
    - All tasks in tasks.md are complete
    - User interrupts with Ctrl+C

    Configuration precedence (highest to lowest):
    1. Script parameters (always win when explicitly provided)
    2. Environment variables (SPECKIT_RALPH_MODEL, SPECKIT_RALPH_MAX_ITERATIONS, SPECKIT_RALPH_AGENT_CLI)
    3. Local config (.specify/extensions/ralph/ralph-config.local.yml)
    4. Project config (.specify/extensions/ralph/ralph-config.yml)
    5. Extension defaults (hardcoded parameter defaults)

.PARAMETER FeatureName
    Name of the feature being implemented (e.g., "001-ralph-loop-implement")

.PARAMETER TasksPath
    Path to tasks.md file

.PARAMETER SpecDir
    Path to the spec directory containing plan.md, spec.md, etc.

.PARAMETER MaxIterations
    Maximum number of iterations before stopping (default: 10)

.PARAMETER Model
    AI model to use (default: claude-sonnet-4.6)

.PARAMETER AgentCli
    Path or name of the agent CLI binary (default: copilot)

.PARAMETER DetailedOutput
    Show detailed iteration output

.EXAMPLE
    .\ralph-loop.ps1 -FeatureName "001-feature" -TasksPath "specs/001-feature/tasks.md" -SpecDir "specs/001-feature" -MaxIterations 10 -Model "claude-sonnet-4.6"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$FeatureName,
    
    [Parameter(Mandatory = $true)]
    [string]$TasksPath,
    
    [Parameter(Mandatory = $true)]
    [string]$SpecDir,
    
    [Parameter(Mandatory = $false)]
    [int]$MaxIterations = 10,
    
    [Parameter(Mandatory = $false)]
    [string]$Model = "claude-sonnet-4.6",
    
    [Parameter(Mandatory = $false)]
    [string]$AgentCli = "copilot",
    
    [Parameter(Mandatory = $false)]
    [string]$WorkingDirectory = "",
    
    [switch]$DetailedOutput
)

# Resolve working directory - if not provided, use the directory containing tasks.md
if (-not $WorkingDirectory) {
    # Infer from TasksPath - go up to find the repo root (directory with .git or .specify)
    $taskDir = Split-Path -Parent ([System.IO.Path]::GetFullPath($TasksPath))
    $searchDir = $taskDir
    while ($searchDir -and -not (Test-Path (Join-Path $searchDir ".git")) -and -not (Test-Path (Join-Path $searchDir ".specify"))) {
        $parent = Split-Path -Parent $searchDir
        if ($parent -eq $searchDir) { break }
        $searchDir = $parent
    }
    if ($searchDir -and ((Test-Path (Join-Path $searchDir ".git")) -or (Test-Path (Join-Path $searchDir ".specify")))) {
        $WorkingDirectory = $searchDir
    } else {
        $WorkingDirectory = (Get-Location).Path
    }
}

# Resolve paths
$RepoRoot = $WorkingDirectory
$TasksPath = [System.IO.Path]::GetFullPath($TasksPath)
$SpecDir = [System.IO.Path]::GetFullPath($SpecDir)
$ProgressPath = Join-Path $SpecDir "progress.md"
$MemoryPath = Join-Path $SpecDir "ralph-memory.md"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ExtensionRoot = Resolve-Path (Join-Path $ScriptDir "..\..") | Select-Object -ExpandProperty Path
$IterateCommandPath = Join-Path $ExtensionRoot "commands\iterate.md"
$MemoryTemplatePath = Join-Path $ExtensionRoot "templates\ralph-memory-template.md"

# Load config from extension config file
function Read-RalphConfig {
    param([string]$RepoRoot)
    
    $config = @{}
    $configPaths = @(
        (Join-Path $RepoRoot ".specify/extensions/ralph/ralph-config.yml"),
        (Join-Path $RepoRoot ".specify/extensions/ralph/ralph-config.local.yml")
    )
    
    foreach ($configPath in $configPaths) {
        if (Test-Path $configPath) {
            Get-Content $configPath | ForEach-Object {
                $line = $_.Trim()
                if ($line -and -not $line.StartsWith('#') -and $line -match '^(\w+)\s*:\s*"?(.+?)"?\s*$') {
                    $config[$Matches[1]] = $Matches[2]
                }
            }
        }
    }
    
    return $config
}

# Apply config defaults (only when script parameter was not explicitly provided)
$config = Read-RalphConfig -RepoRoot $RepoRoot

# Check if parameters were explicitly provided via PSBoundParameters
if (-not $PSBoundParameters.ContainsKey('Model') -and $config.ContainsKey('model')) {
    $Model = $config['model']
}
if (-not $PSBoundParameters.ContainsKey('MaxIterations') -and $config.ContainsKey('max_iterations')) {
    $MaxIterations = [int]$config['max_iterations']
}
if (-not $PSBoundParameters.ContainsKey('AgentCli') -and $config.ContainsKey('agent_cli')) {
    $AgentCli = $config['agent_cli']
}

# Environment variable overrides (higher priority than config, lower than explicit params)
if (-not $PSBoundParameters.ContainsKey('Model') -and $env:SPECKIT_RALPH_MODEL) {
    $Model = $env:SPECKIT_RALPH_MODEL
}
if (-not $PSBoundParameters.ContainsKey('MaxIterations') -and $env:SPECKIT_RALPH_MAX_ITERATIONS) {
    $MaxIterations = [int]$env:SPECKIT_RALPH_MAX_ITERATIONS
}
if (-not $PSBoundParameters.ContainsKey('AgentCli') -and $env:SPECKIT_RALPH_AGENT_CLI) {
    $AgentCli = $env:SPECKIT_RALPH_AGENT_CLI
}

#region Helper Functions

function Write-RalphHeader {
    param([int]$Iteration, [int]$Max)
    
    $border = "=" * 60
    Write-Host ""
    Write-Host $border -ForegroundColor Cyan
    Write-Host "  Ralph Loop - $FeatureName" -ForegroundColor Cyan
    Write-Host "  Iteration $Iteration of $Max" -ForegroundColor White
    Write-Host $border -ForegroundColor Cyan
    Write-Host ""
}

function Write-IterationStatus {
    param(
        [int]$Iteration,
        [string]$Status,
        [string]$Message
    )
    
    $timestamp = Get-Date -Format "HH:mm:ss"
    $statusIcon = switch ($Status) {
        "running"   { "o" }
        "success"   { "*" }
        "failure"   { "x" }
        "skipped"   { "-" }
        default     { "o" }
    }
    $statusColor = switch ($Status) {
        "running"   { "Cyan" }
        "success"   { "Green" }
        "failure"   { "Red" }
        "skipped"   { "Yellow" }
        default     { "White" }
    }
    
    Write-Host "[$timestamp] " -NoNewline -ForegroundColor DarkGray
    Write-Host $statusIcon -NoNewline -ForegroundColor $statusColor
    Write-Host " Iteration $Iteration" -NoNewline -ForegroundColor White
    if ($Message) {
        Write-Host " - $Message" -ForegroundColor DarkGray
    } else {
        Write-Host ""
    }
}

function Get-IncompleteTasks {
    param([string]$Path)
    
    if (-not (Test-Path $Path)) {
        return @()
    }
    
    $content = Get-Content $Path -Raw
    $taskMatches = [regex]::Matches($content, '- \[ \] (T\d+.*?)(?=\r?\n|$)')
    
    return $taskMatches | ForEach-Object { $_.Groups[1].Value }
}

function Get-IncompleteTaskCount {
    param([string]$Path)
    
    return (Get-IncompleteTasks -Path $Path).Count
}

function Initialize-ProgressFile {
    param([string]$Path, [string]$Feature)
    
    if (-not (Test-Path $Path)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $header = @"
# Ralph Progress Log

Feature: $Feature
Started: $timestamp

---

"@
        Set-Content -Path $Path -Value $header -Encoding UTF8
        Write-Host "Created progress log: $Path" -ForegroundColor DarkGray
    }
}

function Initialize-MemoryFile {
    param([string]$Path, [string]$Feature, [string]$TemplatePath = "")
    
    if (-not (Test-Path $Path)) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $header = $null
        if ($TemplatePath) {
            $header = Get-Content -Path $TemplatePath -Raw -ErrorAction SilentlyContinue
        }
        if ([string]::IsNullOrEmpty($header)) {
            $header = @"
# Ralph Memory

Feature: {{FEATURE_NAME}}
Started: {{STARTED_AT}}

## Codebase Patterns

- Durable repo conventions and APIs discovered across iterations.

## Decisions

- Decision, rationale, and affected files.

## Gotchas

- Unexpected behavior, environment quirks, failing commands, generated-file rules.

## Reusable Commands

- Known-good test/lint/build commands and required environment variables.

## Do Not Repeat

- Failed approaches or paths already ruled out.

## Current Handoff

- Short notes the next fresh agent must know before continuing.

"@
        }
        $header = $header.Replace("{{FEATURE_NAME}}", $Feature).Replace("{{STARTED_AT}}", $timestamp)
        Set-Content -Path $Path -Value $header -Encoding UTF8
        Write-Host "Created memory file: $Path" -ForegroundColor DarkGray
    }
}

function Get-AgentCliKind {
    param([string]$Cli)

    $normalizedCli = $Cli -replace '\\', '/'
    $cliName = [System.IO.Path]::GetFileName($normalizedCli).ToLowerInvariant()
    $cliName = $cliName -replace '\.(exe|cmd|bat)$', ''

    switch ($cliName) {
        "copilot" { return "copilot" }
        "codex" { return "codex" }
        "claude" { return "claude" }
        default { return "unsupported" }
    }
}

function Read-SpecKitIntegrationConfig {
    param([string]$RepoRoot)

    $config = @{
        invoke_separator = "."
    }
    $integrationPath = Join-Path (Join-Path $RepoRoot ".specify") "integration.json"

    if (-not (Test-Path $integrationPath)) {
        return $config
    }

    try {
        $integration = Get-Content -Path $integrationPath -Raw | ConvertFrom-Json
    }
    catch {
        return $config
    }

    if ($integration.integration -and $integration.integration -ne "copilot") {
        return $config
    }

    $copilotSettings = $integration
    if ($integration.integration_settings -and $integration.integration_settings.copilot) {
        $copilotSettings = $integration.integration_settings.copilot
    }

    if ($copilotSettings.invoke_separator) {
        $config.invoke_separator = [string]$copilotSettings.invoke_separator
    }
    if ($copilotSettings.raw_options -and (([string]$copilotSettings.raw_options).Trim() -split '\s+' -contains "--skills")) {
        $config.invoke_separator = "-"
    }
    if ($config.invoke_separator -ne "." -and $config.invoke_separator -ne "-") {
        $config.invoke_separator = "."
    }

    return $config
}

function Join-IntegrationCommandName {
    param(
        [string]$CommandName,
        [string]$Separator = "."
    )

    if (-not $Separator) {
        $Separator = "."
    }

    return (($CommandName -split "\.") -join $Separator)
}

function Test-CopilotSkillsMode {
    param([string]$InvokeSeparator)

    return $InvokeSeparator -eq "-"
}

function New-CopilotIterationPrompt {
    param(
        [string]$AgentName,
        [string]$InvokeSeparator,
        [string]$Prompt
    )

    if (Test-CopilotSkillsMode -InvokeSeparator $InvokeSeparator) {
        return "/$AgentName $Prompt"
    }

    return $Prompt
}

function New-IterationPrompt {
    param([int]$Iteration)

    if (Test-Path $IterateCommandPath) {
        $commandText = Get-Content -Path $IterateCommandPath -Raw
    } else {
        $commandText = "Complete at most one work unit from tasks.md. Mark completed tasks, update ralph-memory.md and progress.md, commit only when the current user story is complete, and output <promise>COMPLETE</promise> when all tasks are done."
    }

    return @"
You are running Ralph iteration $Iteration.

Follow the speckit.ralph.iterate command below exactly for this single iteration.

$commandText
"@
}

function Invoke-CopilotIteration {
    param(
        [string]$Model,
        [int]$Iteration,
        [string]$WorkDir,
        [switch]$Verbose
    )
    
    # Simple prompt - the speckit.ralph agent already knows to complete one work unit
    $basePrompt = "Iteration $Iteration - Complete one work unit from tasks.md"
    $integrationConfig = Read-SpecKitIntegrationConfig -RepoRoot $WorkDir
    $agentName = Join-IntegrationCommandName -CommandName "speckit.ralph.iterate" -Separator $integrationConfig.invoke_separator
    $prompt = New-CopilotIterationPrompt -AgentName $agentName -InvokeSeparator $integrationConfig.invoke_separator -Prompt $basePrompt
    
    # Only show debug info when verbose
    if ($Verbose) {
        Write-Host "DEBUG: Prompt = $prompt" -ForegroundColor Magenta
        Write-Host "DEBUG: WorkDir = $WorkDir" -ForegroundColor Magenta
        Write-Host "DEBUG: AgentName = $agentName" -ForegroundColor Magenta
        Write-Host "DEBUG: InvokeSeparator = $($integrationConfig.invoke_separator)" -ForegroundColor Magenta
    }
    
    try {
        # Change to working directory so copilot finds the correct agents
        $originalDir = Get-Location
        if ($WorkDir -and (Test-Path $WorkDir)) {
            Push-Location $WorkDir
            if ($Verbose) {
                Write-Host "DEBUG: Changed to $WorkDir" -ForegroundColor Magenta
            }
        }
        
        # Refresh PATH to ensure pwsh is available (copilot CLI requires PowerShell 7+)
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        # Ensure UTF-8 so copilot output (em dashes, etc.) renders correctly
        $prevOutputEncoding = $OutputEncoding
        $prevConsoleEncoding = [Console]::OutputEncoding
        $nativeErrorPreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
        if ($nativeErrorPreference) {
            $prevNativeCommandUseErrorActionPreference = $PSNativeCommandUseErrorActionPreference
            $PSNativeCommandUseErrorActionPreference = $false
        }
        $OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        
        try {
            # Always stream copilot output in real-time so user can see what the agent is doing
            Write-Host ""
            Write-Host "--- Copilot Agent Output ---" -ForegroundColor DarkCyan
            $outputLines = @()
            $copilotArgs = if (Test-CopilotSkillsMode -InvokeSeparator $integrationConfig.invoke_separator) {
                @("-p", $prompt, "--model", $Model, "--yolo", "-s")
            } else {
                @("--agent", $agentName, "-p", $prompt, "--model", $Model, "--yolo", "-s")
            }
            & $AgentCli @copilotArgs 2>&1 | ForEach-Object {
                # Stderr lines arrive as ErrorRecord objects; extract the message string
                $line = if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ }
                Write-Host $line
                $outputLines += $line
            }
            $output = $outputLines -join "`n"
            $exitCode = $LASTEXITCODE
            Write-Host "--- End Agent Output ---" -ForegroundColor DarkCyan
            Write-Host ""
        }
        finally {
            $OutputEncoding = $prevOutputEncoding
            [Console]::OutputEncoding = $prevConsoleEncoding
            if ($nativeErrorPreference) {
                $PSNativeCommandUseErrorActionPreference = $prevNativeCommandUseErrorActionPreference
            }
            if ($WorkDir -and (Test-Path $WorkDir)) {
                Pop-Location
            }
        }
        
        if ($Verbose) {
            Write-Host "DEBUG: copilot exit code = $exitCode" -ForegroundColor Magenta
        }
    }
    catch {
        $output = "Error invoking copilot: $_"
        $exitCode = 1
    }
    
    return @{
        Output = $output
        ExitCode = $exitCode
    }
}

function Test-AgentResolutionFailure {
    param([string]$Output)

    return $Output -match '(?i)(No such agent|No such skill|Unknown agent|Unknown skill|agent .*not found|skill .*not found|error: unknown option)'
}

function Invoke-ClaudeIteration {
    param(
        [string]$Model,
        [int]$Iteration,
        [string]$WorkDir,
        [switch]$Verbose
    )

    # Claude Code has no registered speckit.ralph.iterate agent (that's a Copilot mechanism),
    # so inline the iterate command text into the prompt, the same way the codex path does.
    $prompt = New-IterationPrompt -Iteration $Iteration

    if ($Verbose) {
        Write-Host "DEBUG: Prompt = Ralph iteration $Iteration using $IterateCommandPath" -ForegroundColor Magenta
        Write-Host "DEBUG: WorkDir = $WorkDir" -ForegroundColor Magenta
        Write-Host "DEBUG: AgentCLI = $AgentCli" -ForegroundColor Magenta
    }

    try {
        $originalDir = Get-Location
        if ($WorkDir -and (Test-Path $WorkDir)) {
            Push-Location $WorkDir
            if ($Verbose) {
                Write-Host "DEBUG: Changed to $WorkDir" -ForegroundColor Magenta
            }
        }

        $prevOutputEncoding = $OutputEncoding
        $prevConsoleEncoding = [Console]::OutputEncoding
        $OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        try {
            Write-Host ""
            Write-Host "--- Claude Agent Output ---" -ForegroundColor DarkCyan
            $outputLines = @()
            # Claude Code uses --dangerously-skip-permissions for unattended execution (vs copilot's --yolo -s)
            & $AgentCli -p $prompt --model $Model --dangerously-skip-permissions 2>&1 | ForEach-Object {
                $line = if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ }
                Write-Host $line
                $outputLines += $line
            }
            $output = $outputLines -join "`n"
            $exitCode = $LASTEXITCODE
            Write-Host "--- End Agent Output ---" -ForegroundColor DarkCyan
            Write-Host ""
        }
        finally {
            $OutputEncoding = $prevOutputEncoding
            [Console]::OutputEncoding = $prevConsoleEncoding
            if ($WorkDir -and (Test-Path $WorkDir)) {
                Pop-Location
            }
        }

        if ($Verbose) {
            Write-Host "DEBUG: claude exit code = $exitCode" -ForegroundColor Magenta
        }
    }
    catch {
        $output = "Error invoking claude: $_"
        $exitCode = 1
    }

    return @{
        Output = $output
        ExitCode = $exitCode
    }
}

function Invoke-CodexIteration {
    param(
        [string]$Model,
        [int]$Iteration,
        [string]$WorkDir,
        [switch]$Verbose
    )

    $prompt = New-IterationPrompt -Iteration $Iteration

    if ($Verbose) {
        Write-Host "DEBUG: Prompt = Ralph iteration $Iteration using $IterateCommandPath" -ForegroundColor Magenta
        Write-Host "DEBUG: WorkDir = $WorkDir" -ForegroundColor Magenta
        Write-Host "DEBUG: AgentCLI = $AgentCli" -ForegroundColor Magenta
    }

    try {
        $prevOutputEncoding = $OutputEncoding
        $prevConsoleEncoding = [Console]::OutputEncoding
        $OutputEncoding = [System.Text.Encoding]::UTF8
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8

        try {
            Write-Host ""
            Write-Host "--- Codex Agent Output ---" -ForegroundColor DarkCyan
            $outputLines = @()
            $codexArgs = @("exec", "--json", "--model", $Model, "--sandbox", "danger-full-access")

            if ($WorkDir -and (Test-Path $WorkDir)) {
                $codexArgs += @("--cd", $WorkDir)
            }

            $codexArgs += "-"

            $prompt | & $AgentCli @codexArgs 2>&1 | ForEach-Object {
                $line = if ($_ -is [System.Management.Automation.ErrorRecord]) { $_.Exception.Message } else { $_ }
                $outputLines += $line
                try {
                    $event = $line | ConvertFrom-Json -ErrorAction Stop
                    switch ($event.type) {
                        "item.completed" {
                            if ($event.item.type -eq "agent_message" -and $event.item.text) {
                                Write-Host $event.item.text
                            } elseif ($event.item.type -eq "command_execution" -and $event.item.command) {
                                Write-Host "exec: $($event.item.command)"
                            }
                        }
                        "turn.failed" {
                            Write-Host $line
                        }
                        "error" {
                            Write-Host $line
                        }
                    }
                }
                catch {
                    Write-Host $line
                }
            }
            $output = $outputLines -join "`n"
            $exitCode = $LASTEXITCODE
            Write-Host "--- End Agent Output ---" -ForegroundColor DarkCyan
            Write-Host ""
        }
        finally {
            $OutputEncoding = $prevOutputEncoding
            [Console]::OutputEncoding = $prevConsoleEncoding
        }

        if ($Verbose) {
            Write-Host "DEBUG: $AgentCli exit code = $exitCode" -ForegroundColor Magenta
        }
    }
    catch {
        $output = "Error invoking codex: $_"
        $exitCode = 1
    }

    return @{
        Output = $output
        ExitCode = $exitCode
    }
}

function Invoke-AgentIteration {
    param(
        [string]$Model,
        [int]$Iteration,
        [string]$WorkDir,
        [switch]$Verbose
    )

    $agentKind = Get-AgentCliKind -Cli $AgentCli
    switch ($agentKind) {
        "copilot" { return Invoke-CopilotIteration -Model $Model -Iteration $Iteration -WorkDir $WorkDir -Verbose:$Verbose }
        "codex" { return Invoke-CodexIteration -Model $Model -Iteration $Iteration -WorkDir $WorkDir -Verbose:$Verbose }
        "claude" { return Invoke-ClaudeIteration -Model $Model -Iteration $Iteration -WorkDir $WorkDir -Verbose:$Verbose }
        default {
            Write-Host "Unsupported agent CLI: $AgentCli" -ForegroundColor Red
            Write-Host "Supported agent CLIs: copilot, codex, claude" -ForegroundColor Red
            return @{
                Output = "Unsupported agent CLI: $AgentCli"
                ExitCode = 2
            }
        }
    }
}

function Test-CompletionSignal {
    param([string]$Output)

    # Only honor the signal when it stands alone on a line (ignoring surrounding
    # whitespace/backticks). Agents often mention the token in prose — e.g.
    # "stopping here; no <promise>COMPLETE</promise>" — which must NOT complete the loop.
    return $Output -match '(?m)^[\s`]*<promise>COMPLETE</promise>[\s`]*$'
}

function Test-WorktreeClean {
    param([string]$WorkDir)

    if (-not $WorkDir) {
        $WorkDir = "."
    }

    & git -C $WorkDir rev-parse --is-inside-work-tree *> $null
    if ($LASTEXITCODE -ne 0) {
        return $false
    }

    $status = & git -C $WorkDir status --porcelain 2>$null
    return $LASTEXITCODE -eq 0 -and -not $status
}

function Write-DirtyCompletion {
    param([string]$WorkDir)

    if (-not $WorkDir) {
        $WorkDir = "."
    }

    Write-Output "Completion signal received, but worktree is dirty. Refusing successful completion."
    & git -C $WorkDir status --short 2>$null | ForEach-Object { Write-Output $_ }
}

#endregion

#region Main Loop

# Check initial task count
$initialTasks = Get-IncompleteTaskCount -Path $TasksPath
if ($initialTasks -eq 0) {
    Write-Host "All tasks are already complete!" -ForegroundColor Green
    Write-Host "<promise>COMPLETE</promise>"
    exit 0
}

# Initialize progress and memory files
Initialize-ProgressFile -Path $ProgressPath -Feature $FeatureName
Initialize-MemoryFile -Path $MemoryPath -Feature $FeatureName -TemplatePath $MemoryTemplatePath

Write-Host "Found $initialTasks incomplete task(s)" -ForegroundColor White

# Iteration tracking
$iteration = 1
$lastIterationRun = 0
$consecutiveFailures = 0
$maxConsecutiveFailures = 3
$completed = $false
$circuitBreaker = $false
$fatalFailure = $false

# Register Ctrl+C handler
$interrupted = $false
[Console]::TreatControlCAsInput = $false

try {
    while ($iteration -le $MaxIterations -and -not $completed -and -not $interrupted -and -not $circuitBreaker -and -not $fatalFailure) {
        $lastIterationRun = $iteration
        Write-RalphHeader -Iteration $iteration -Max $MaxIterations
        Write-IterationStatus -Iteration $iteration -Status "running" -Message "Starting iteration"
        
        # Invoke configured agent CLI with speckit.ralph.iterate behavior
        $verboseSwitch = @{}
        if ($DetailedOutput) { $verboseSwitch['Verbose'] = $true }
        $result = Invoke-AgentIteration -Model $Model -Iteration $iteration -WorkDir $WorkingDirectory @verboseSwitch
        
        if ($DetailedOutput -or $result.ExitCode -ne 0) {
            Write-Host $result.Output
        }
        
        # Check for completion signal
        if (Test-CompletionSignal -Output $result.Output) {
            if (Test-WorktreeClean -WorkDir $WorkingDirectory) {
                Write-IterationStatus -Iteration $iteration -Status "success" -Message "COMPLETE signal received"
                $completed = $true
            } else {
                Write-IterationStatus -Iteration $iteration -Status "failure" -Message "COMPLETE signal received with dirty worktree"
                Write-DirtyCompletion -WorkDir $WorkingDirectory
                $fatalFailure = $true
            }
            break
        }

        if ($result.ExitCode -ne 0 -and (Test-AgentResolutionFailure -Output $result.Output)) {
            Write-IterationStatus -Iteration $iteration -Status "failure" -Message "Agent command unavailable"
            Write-Host "Resolved agent command is unavailable. Stopping loop before consuming more iterations." -ForegroundColor Red
            $fatalFailure = $true
            break
        }
        
        # Check exit code
        if ($result.ExitCode -ne 0) {
            $consecutiveFailures++
            Write-IterationStatus -Iteration $iteration -Status "failure" -Message "Exit code $($result.ExitCode) (failure $consecutiveFailures/$maxConsecutiveFailures)"
            
            if ($consecutiveFailures -ge $maxConsecutiveFailures) {
                Write-Host "Too many consecutive failures. Stopping loop." -ForegroundColor Red
                $circuitBreaker = $true
                break
            }
        } else {
            $consecutiveFailures = 0
            Write-IterationStatus -Iteration $iteration -Status "success" -Message "Iteration completed"
        }
        
        # Check remaining tasks
        $remainingTasks = Get-IncompleteTaskCount -Path $TasksPath
        if ($remainingTasks -eq 0) {
            if (Test-WorktreeClean -WorkDir $WorkingDirectory) {
                Write-Host "All tasks complete!" -ForegroundColor Green
                $completed = $true
            } else {
                Write-IterationStatus -Iteration $iteration -Status "failure" -Message "All tasks complete but worktree is dirty"
                Write-DirtyCompletion -WorkDir $WorkingDirectory
                $fatalFailure = $true
            }
            break
        }
        
        Write-Host "$remainingTasks task(s) remaining" -ForegroundColor DarkGray
        
        $iteration++
    }
}
catch {
    if ($_.Exception.GetType().Name -eq "PipelineStoppedException") {
        $interrupted = $true
        Write-Host "`nInterrupted by user" -ForegroundColor Yellow
    } else {
        throw
    }
}
finally {
    [Console]::TreatControlCAsInput = $false
}

#endregion

#region Summary

Write-Host ""
Write-Host ("=" * 60) -ForegroundColor Cyan
Write-Host "  Ralph Loop Summary" -ForegroundColor Cyan
Write-Host ("=" * 60) -ForegroundColor Cyan

$finalTasks = Get-IncompleteTaskCount -Path $TasksPath
$tasksCompleted = $initialTasks - $finalTasks

if ($completed) {
    $iterationsRun = $lastIterationRun
} elseif ($interrupted) {
    $iterationsRun = [Math]::Max(0, $lastIterationRun - 1)
} else {
    $iterationsRun = $lastIterationRun
}
Write-Host "  Iterations run: $iterationsRun" -ForegroundColor White
Write-Host "  Tasks completed: $tasksCompleted" -ForegroundColor White
Write-Host "  Tasks remaining: $finalTasks" -ForegroundColor White

if ($completed) {
    Write-Host "  Status: " -NoNewline -ForegroundColor White
    Write-Host "COMPLETED" -ForegroundColor Green
    exit 0
} elseif ($interrupted) {
    Write-Host "  Status: " -NoNewline -ForegroundColor White
    Write-Host "INTERRUPTED" -ForegroundColor Yellow
    exit 130
} elseif ($fatalFailure) {
    Write-Host "  Status: " -NoNewline -ForegroundColor White
    Write-Host "FAILED" -ForegroundColor Red
    exit 1
} elseif ($circuitBreaker) {
    Write-Host "  Status: " -NoNewline -ForegroundColor White
    Write-Host "FAILED" -ForegroundColor Red
    exit 1
} else {
    Write-Host "  Status: " -NoNewline -ForegroundColor White
    Write-Host "ITERATION LIMIT REACHED" -ForegroundColor Yellow
    exit 1
}

#endregion
