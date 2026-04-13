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

Write-ProbeBanner -Title 'UniFi Interfaces Probe'
Write-Host "Site selector: $($gatewayConfig.Site)"
Write-Host "API key env var: $($uniFiConfig.ApiKeyEnvVar)"

if ($ShowPlanOnly) {
    Write-Host ''
    Write-Host 'Scaffold only: no API request sent.'
    return
}

$siteResolution = Resolve-UniFiSite -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig
$response = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath "v1/sites/$($siteResolution.Id)/interfaces"
$interfaces = @($response.Items)

$summary = [pscustomobject]@{
    success = $true
    site_selector = $siteResolution.Selector
    resolved_site_id = $siteResolution.Id
    endpoint = $response.Url
    interface_count = $interfaces.Count
    interfaces = $interfaces
    raw = $response.Raw
}

if ($OutputFormat -eq 'Json') {
    $summary | ConvertTo-Json -Depth 10
    return
}

Write-Host ''
Write-Host "Interface count: $($summary.interface_count)"
if ($interfaces.Count -gt 0) {
    $interfaces | Select-Object name, type, macAddress, status, ipAddress |
        Format-Table -AutoSize |
        Out-String |
        Write-Host
}
else {
    Write-Host 'No interfaces returned by the current endpoint.'
}
