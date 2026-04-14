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

function Test-TcpPort {
    param(
        [Parameter(Mandatory = $true)]
        [string]$HostName,

        [Parameter(Mandatory = $true)]
        [int]$Port
    )

    try {
        $client = [System.Net.Sockets.TcpClient]::new()
        $asyncResult = $client.BeginConnect($HostName, $Port, $null, $null)

        if (-not $asyncResult.AsyncWaitHandle.WaitOne(3000, $false)) {
            $client.Close()
            return $false
        }

        $client.EndConnect($asyncResult)
        $client.Close()
        return $true
    }
    catch {
        return $false
    }
}

function Get-StatusLabel {
    param([bool]$Success)
    if ($Success) { return 'OK' }
    return 'FAIL'
}

$config = Get-IntegrationConfig -Path $ConfigPath
$monitoring = $config.Monitoring

$checks = [System.Collections.Generic.List[object]]::new()

$hostResult = Invoke-SshReadOnly -User $config.Hosts.Command001.User -Address $config.Hosts.Command001.Address -RemoteCommand 'hostnamectl; echo; uptime'
$checks.Add([pscustomobject]@{
    name = 'host_ssh'
    target = $config.Hosts.Command001.Address
    success = $hostResult.Success
    detail = if ($hostResult.Success) { 'Host SSH probe succeeded.' } else { "Exit code $($hostResult.ExitCode)" }
})

$vmResult = Invoke-SshReadOnly -User $config.Hosts.Command001.User -Address $config.Hosts.Command001.Address -RemoteCommand 'qm list'
$vmList = @()

if ($vmResult.Success) {
    $vmList = @(ConvertFrom-QmListText -InputLines $vmResult.Output)
}

$expectedVmNames = @('APP001', 'WEB001', 'SQL001', 'DNS001')
foreach ($vmName in $expectedVmNames) {
    $vm = $vmList | Where-Object { $_.name -eq $vmName } | Select-Object -First 1
    $isRunning = $null -ne $vm -and $vm.status -eq 'running'
    $checks.Add([pscustomobject]@{
        name = "vm_$vmName"
        target = $vmName
        success = $isRunning
        detail = if ($vm) { "Status: $($vm.status)" } else { 'VM not found in qm list.' }
    })
}

foreach ($dnsName in $monitoring.DnsNames) {
    $resolved = $false
    $detail = ''

    try {
        $records = Resolve-DnsName -Name $dnsName -ErrorAction Stop
        $addresses = @($records | Where-Object { $_.Type -eq 'A' } | Select-Object -ExpandProperty IPAddress)
        $resolved = $addresses.Count -gt 0
        $detail = if ($resolved) { "A: $($addresses -join ', ')" } else { 'No A records returned.' }
    }
    catch {
        $detail = $_.Exception.Message
    }

    $checks.Add([pscustomobject]@{
        name = "dns_$dnsName"
        target = $dnsName
        success = $resolved
        detail = $detail
    })
}

$dbTcp = Test-TcpPort -HostName $config.Hosts.Sql001.Address -Port $monitoring.DatabasePort
$checks.Add([pscustomobject]@{
    name = 'sql_tcp'
    target = "$($config.Hosts.Sql001.Address):$($monitoring.DatabasePort)"
    success = $dbTcp
    detail = if ($dbTcp) { 'Database port is reachable.' } else { 'Database port did not accept a TCP connection.' }
})

$dnsTcp = Test-TcpPort -HostName $config.Hosts.Dns001.Address -Port $monitoring.DnsPort
$checks.Add([pscustomobject]@{
    name = 'dns_tcp'
    target = "$($config.Hosts.Dns001.Address):$($monitoring.DnsPort)"
    success = $dnsTcp
    detail = if ($dnsTcp) { 'DNS port is reachable.' } else { 'DNS port did not accept a TCP connection.' }
})

$healthResponse = Invoke-CurlReadOnly -Arguments @('-s', '-i', $monitoring.WebHealthUrl)
$healthOk = $healthResponse.Success -and (($healthResponse.Output -join [Environment]::NewLine) -match 'HTTP/\d\.\d 200')
$checks.Add([pscustomobject]@{
    name = 'web_health'
    target = $monitoring.WebHealthUrl
    success = $healthOk
    detail = if ($healthOk) { 'Health endpoint returned HTTP 200.' } else { 'Health endpoint did not return HTTP 200.' }
})

$controlResponse = Invoke-CurlReadOnly -Arguments @('-s', '-i', $monitoring.WebControlUrl)
$controlOk = $controlResponse.Success -and (($controlResponse.Output -join [Environment]::NewLine) -match 'HTTP/\d\.\d 200')
$checks.Add([pscustomobject]@{
    name = 'web_control'
    target = $monitoring.WebControlUrl
    success = $controlOk
    detail = if ($controlOk) { 'Control page returned HTTP 200.' } else { 'Control page did not return HTTP 200.' }
})

$overallSuccess = -not ($checks | Where-Object { -not $_.success })
$result = [pscustomobject]@{
    collected_at = (Get-Date).ToString('o')
    overall_success = $overallSuccess
    check_count = $checks.Count
    checks = @($checks)
}

if ($OutputFormat -eq 'Json') {
    $result | ConvertTo-Json -Depth 6
    if (-not $overallSuccess) {
        exit 1
    }

    exit 0
}

Write-ProbeBanner -Title 'Platform Health Check'
Write-Host "Collected at: $($result.collected_at)"
Write-Host "Overall: $(Get-StatusLabel -Success $overallSuccess)"
Write-Host ''

$checks |
    Select-Object @{ Name = 'Status'; Expression = { Get-StatusLabel -Success $_.success } }, name, target, detail |
    Format-Table -Wrap -AutoSize |
    Out-String |
    Write-Host

if (-not $overallSuccess) {
    exit 1
}
