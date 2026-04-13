param(
    [string]$ConfigPath,
    [string]$ZoneName = 'school.local'
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
$dnsHost = $config.Hosts.Dns001
$escapedZoneName = $ZoneName.Replace("'", "'\''")
$remoteCommand = "bash -lc 'systemctl is-active named.service; grep -R ''$escapedZoneName'' /etc/bind 2>/dev/null | head -n 20'"

Write-ProbeBanner -Title 'DNS Zone Check'
Write-Host "Target: $($dnsHost.User)@$($dnsHost.Address)"
Write-Host "Zone: $ZoneName"

$result = Invoke-SshReadOnly -User $dnsHost.User -Address $dnsHost.Address -RemoteCommand $remoteCommand

if (-not $result.Success) {
    throw "Failed to inspect bind9 via SSH. Exit code: $($result.ExitCode)"
}

$result.Output | ForEach-Object { Write-Host $_ }
