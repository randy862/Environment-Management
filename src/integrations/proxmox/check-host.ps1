param(
    [string]$ConfigPath,
    [ValidateSet('Text', 'Json')]
    [string]$OutputFormat = 'Text'
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
$hostConfig = $config.Hosts.Command001

$hostResult = Invoke-SshReadOnly -User $hostConfig.User -Address $hostConfig.Address -RemoteCommand 'hostnamectl'

if (-not $hostResult.Success) {
    throw "Failed to inspect COMMAND001 via SSH. Exit code: $($hostResult.ExitCode)"
}

$versionResult = Invoke-SshReadOnly -User $hostConfig.User -Address $hostConfig.Address -RemoteCommand 'pveversion'

if (-not $versionResult.Success) {
    throw "Failed to query Proxmox version on COMMAND001. Exit code: $($versionResult.ExitCode)"
}

$vmResult = Invoke-SshReadOnly -User $hostConfig.User -Address $hostConfig.Address -RemoteCommand 'qm list'

if (-not $vmResult.Success) {
    throw "Failed to query qm list on COMMAND001. Exit code: $($vmResult.ExitCode)"
}

$hostText = ($hostResult.Output -join [Environment]::NewLine)
$versionText = ($versionResult.Output -join [Environment]::NewLine).Trim()
$vmList = @(ConvertFrom-QmListText -InputLines $vmResult.Output)

if ($OutputFormat -eq 'Json') {
    [pscustomobject]@{
        source = 'qm'
        target_host = $hostConfig.Address
        target_user = $hostConfig.User
        collected_at = (Get-Date).ToString('o')
        host = @{
            hostnamectl = $hostText
            pveversion = $versionText
        }
        vm_count = $vmList.Count
        vms = $vmList
    } | ConvertTo-Json -Depth 8

    return
}

Write-ProbeBanner -Title 'Proxmox Host Check'
Write-Host "Target: $($hostConfig.User)@$($hostConfig.Address)"
Write-Host 'Commands: hostnamectl, pveversion, qm list'
$hostResult.Output | ForEach-Object { Write-Host $_ }
Write-Host ''
Write-Host $versionText
Write-Host ''
Write-Host "VM count: $($vmList.Count)"
Write-Host ''
$vmList |
    Format-Table -AutoSize |
    Out-String |
    Write-Host
