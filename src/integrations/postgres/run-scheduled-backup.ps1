param(
    [string]$ConfigPath,
    [string]$LogsRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

if (-not $PSBoundParameters.ContainsKey('ConfigPath')) {
    $ConfigPath = Join-Path $rootDir 'config/local.psd1'
}

if (-not $PSBoundParameters.ContainsKey('LogsRoot')) {
    $LogsRoot = Join-Path $rootDir 'tmp/postgres-backup'
}

$backupScript = Join-Path $scriptDir 'backup-to-share.ps1'
$timestamp = Get-Date
$runId = $timestamp.ToString('yyyyMMdd-HHmmss')
$runDir = Join-Path $LogsRoot $runId
$logPath = Join-Path $runDir 'run.log'
$summaryPath = Join-Path $runDir 'summary.json'
$latestSummaryPath = Join-Path $LogsRoot 'latest.json'

New-Item -ItemType Directory -Path $runDir -Force | Out-Null

$commandArguments = @(
    '-NoProfile',
    '-ExecutionPolicy', 'Bypass',
    '-File', $backupScript,
    '-ConfigPath', $ConfigPath,
    '-OutputFormat', 'Json'
)

$commandDescription = 'powershell ' + (($commandArguments | ForEach-Object {
            if ($_ -match '\s') { '"' + $_ + '"' } else { $_ }
        }) -join ' ')

$outputLines = @()
$startedAt = Get-Date
$exitCode = $null
$success = $false
$backupResult = $null
$errorMessage = $null

try {
    $outputLines = @(& powershell @commandArguments 2>&1 | ForEach-Object { $_.ToString() })
    $exitCode = $LASTEXITCODE

    if ($exitCode -eq 0) {
        $jsonText = ($outputLines -join [Environment]::NewLine).Trim()
        $backupResult = $jsonText | ConvertFrom-Json
        $success = $true
    }
    else {
        $errorMessage = if ($outputLines.Count -gt 0) {
            ($outputLines -join [Environment]::NewLine).Trim()
        }
        else {
            "Backup script exited with code $exitCode."
        }
    }
}
catch {
    $exitCode = 1
    $errorMessage = $_ | Out-String
}

$finishedAt = Get-Date
$durationSeconds = [Math]::Round(($finishedAt - $startedAt).TotalSeconds, 2)

$logLines = @(
    "started_at=$($startedAt.ToString('o'))",
    "finished_at=$($finishedAt.ToString('o'))",
    "duration_seconds=$durationSeconds",
    "success=$success",
    "exit_code=$exitCode",
    "command=$commandDescription",
    ''
)

if ($success) {
    $logLines += 'result_json='
    $logLines += ($backupResult | ConvertTo-Json -Depth 8)
}
else {
    $logLines += 'error_output='
    $logLines += ($errorMessage.TrimEnd())
}

$logLines | Set-Content -Path $logPath -Encoding ascii

$summary = [ordered]@{
    started_at = $startedAt.ToString('o')
    finished_at = $finishedAt.ToString('o')
    duration_seconds = $durationSeconds
    success = $success
    exit_code = $exitCode
    command = $commandDescription
    log_path = $logPath
    summary_path = $summaryPath
    backup = $backupResult
    error = $errorMessage
}

$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $summaryPath -Encoding ascii
$summary | ConvertTo-Json -Depth 8 | Set-Content -Path $latestSummaryPath -Encoding ascii

if (-not $success) {
    Write-Error ($errorMessage.TrimEnd())
    exit $exitCode
}

Write-Host "PostgreSQL scheduled backup completed successfully."
Write-Host "Log: $logPath"
Write-Host "Summary: $summaryPath"
