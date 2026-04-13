param(
    [string]$ConfigPath = (Join-Path $rootDir 'config/local.psd1'),
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
$appHost = $config.Hosts.App001
$proxmoxCtl = $config.Paths.ProxmoxCtl

$result = Invoke-SshReadOnly -User $appHost.User -Address $appHost.Address -RemoteCommand "$proxmoxCtl vms"

if (-not $result.Success) {
    throw "Failed to run proxmoxctl via SSH. Exit code: $($result.ExitCode)"
}

$parsedJson = ConvertFrom-JsonSafe -InputLines $result.Output
$vmList = @($parsedJson.data)

if ($OutputFormat -eq 'Json') {
    [pscustomobject]@{
        source = 'proxmoxctl'
        target_host = $appHost.Address
        target_user = $appHost.User
        collected_at = (Get-Date).ToString('o')
        vm_count = $vmList.Count
        vms = $vmList
    } | ConvertTo-Json -Depth 8

    return
}

Write-ProbeBanner -Title 'Proxmox VM Inventory'
Write-Host "Target: $($appHost.User)@$($appHost.Address)"
Write-Host "Command: $proxmoxCtl vms"
Write-Host "VM count: $($vmList.Count)"
Write-Host ''
$vmList |
    Select-Object vmid, name, status, node, maxcpu, maxmem, maxdisk |
    Format-Table -AutoSize |
    Out-String |
    Write-Host
