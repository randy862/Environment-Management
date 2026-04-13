param(
    [string]$ConfigPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

if (-not $PSBoundParameters.ContainsKey('ConfigPath')) {
    $ConfigPath = Join-Path $rootDir 'config/local.psd1'
}

Import-Module (Join-Path $rootDir 'lib/ReadOnlyTools.psm1') -Force

$config = Get-IntegrationConfig -Path $ConfigPath
$sqlHost = $config.Hosts.Sql001
$remoteCommand = "bash -lc 'systemctl is-active postgresql.service; systemctl is-active postgresql@17-main.service 2>/dev/null || true; psql --version 2>/dev/null || true'"

Write-ProbeBanner -Title 'PostgreSQL Service Check'
Write-Host "Target: $($sqlHost.User)@$($sqlHost.Address)"

$result = Invoke-SshReadOnly -User $sqlHost.User -Address $sqlHost.Address -RemoteCommand $remoteCommand

if (-not $result.Success) {
    throw "Failed to inspect PostgreSQL via SSH. Exit code: $($result.ExitCode)"
}

$result.Output | ForEach-Object { Write-Host $_ }
