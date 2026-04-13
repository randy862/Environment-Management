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

Write-ProbeBanner -Title 'UniFi Site Summary'
Write-Host "Site selector: $($gatewayConfig.Site)"
Write-Host "API key env var: $($uniFiConfig.ApiKeyEnvVar)"

if ($ShowPlanOnly) {
    Write-Host ''
    Write-Host 'Scaffold only: no API requests sent.'
    return
}

$siteResolution = Resolve-UniFiSite -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig
$deviceResponse = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath "v1/sites/$($siteResolution.Id)/devices"
$clientResponse = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath "v1/sites/$($siteResolution.Id)/clients"
$interfaceResponse = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath "v1/sites/$($siteResolution.Id)/interfaces"

$summary = [pscustomobject]@{
    success = $true
    site_selector = $siteResolution.Selector
    resolved_site_id = $siteResolution.Id
    site = $siteResolution.Site
    counts = [pscustomobject]@{
        devices = @($deviceResponse.Items).Count
        clients = @($clientResponse.Items).Count
        interfaces = @($interfaceResponse.Items).Count
    }
    devices = @($deviceResponse.Items)
    clients = @($clientResponse.Items)
    interfaces = @($interfaceResponse.Items)
}

if ($OutputFormat -eq 'Json') {
    $summary | ConvertTo-Json -Depth 20
    return
}

Write-Host ''
Write-Host "Devices: $($summary.counts.devices)"
Write-Host "Clients: $($summary.counts.clients)"
Write-Host "Interfaces: $($summary.counts.interfaces)"
