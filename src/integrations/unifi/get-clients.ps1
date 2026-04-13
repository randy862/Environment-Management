param(
    [string]$ConfigPath,
    [switch]$ShowPlanOnly,
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
Import-Module (Join-Path $scriptDir 'UniFiTools.psm1') -Force

$config = Get-IntegrationConfig -Path $ConfigPath
$gatewayConfig = $config.Hosts.Gateway001
$uniFiConfig = $config.UniFi

Write-ProbeBanner -Title 'UniFi Clients Probe'
Write-Host "Site selector: $($gatewayConfig.Site)"
Write-Host "API key env var: $($uniFiConfig.ApiKeyEnvVar)"

if ($ShowPlanOnly) {
    Write-Host ''
    Write-Host 'Scaffold only: no API request sent.'
    return
}

$siteResolution = Resolve-UniFiSite -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig
$response = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath "v1/sites/$($siteResolution.Id)/clients"
$clients = @($response.Items)

$summary = [pscustomobject]@{
    success = $true
    site_selector = $siteResolution.Selector
    resolved_site_id = $siteResolution.Id
    endpoint = $response.Url
    client_count = $clients.Count
    clients = $clients
    raw = $response.Raw
}

if ($OutputFormat -eq 'Json') {
    $summary | ConvertTo-Json -Depth 10
    return
}

Write-Host ''
Write-Host "Client count: $($summary.client_count)"
if ($clients.Count -gt 0) {
    $clients | Select-Object name, hostname, ipAddress, macAddress, type, state |
        Format-Table -AutoSize |
        Out-String |
        Write-Host
}
else {
    Write-Host 'No clients returned by the current endpoint.'
}
