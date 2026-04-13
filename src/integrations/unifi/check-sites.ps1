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

Write-ProbeBanner -Title 'UniFi Sites Probe'
Write-Host "Endpoint: $sitesUrl"
Write-Host "API key env var: $($uniFiConfig.ApiKeyEnvVar)"

if ($ShowPlanOnly) {
    Write-Host ''
    Write-Host 'Scaffold only: no API request sent.'
    return
}

$response = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath 'v1/sites'
$sites = @($response.Items)

$summary = [pscustomobject]@{
    success = $true
    endpoint = $response.Url
    site_count = $sites.Count
    sites = $sites
    raw = $response.Raw
}

if ($OutputFormat -eq 'Json') {
    $summary | ConvertTo-Json -Depth 10
    return
}

Write-Host ''
Write-Host "Site count: $($summary.site_count)"
if ($sites.Count -gt 0) {
    $sites | Format-Table -AutoSize | Out-String | Write-Host
}
else {
    Write-Host 'No sites returned by the current endpoint.'
}
