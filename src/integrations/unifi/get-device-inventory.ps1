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
$sitesUrl = Get-UniFiApiUrl -GatewayConfig $gatewayConfig -RelativePath 'v1/sites'

Write-ProbeBanner -Title 'UniFi Device Inventory Scaffold'
Write-Host "Sites endpoint: $sitesUrl"
Write-Host "API key env var: $($uniFiConfig.ApiKeyEnvVar)"

if ($ShowPlanOnly) {
    Write-Host ''
    Write-Host 'Scaffold only: no API request sent.'
    return
}

$siteResolution = Resolve-UniFiSite -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig
$siteSelector = $siteResolution.Selector
$siteId = $siteResolution.Id
$response = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath "v1/sites/$siteId/devices"
$devices = @($response.Items)

$summary = [pscustomobject]@{
    success = $true
    site_selector = $siteSelector
    resolved_site_id = $siteId
    endpoint = $response.Url
    device_count = $devices.Count
    devices = $devices
    raw = $response.Raw
}

if ($OutputFormat -eq 'Json') {
    $summary | ConvertTo-Json -Depth 10
    return
}

Write-Host ''
Write-Host "Device count: $($summary.device_count)"
if ($devices.Count -gt 0) {
    $devices | Select-Object name, mac, ipAddress, model, state |
        Format-Table -AutoSize |
        Out-String |
        Write-Host
}
else {
    Write-Host 'No devices returned by the current endpoint.'
}
