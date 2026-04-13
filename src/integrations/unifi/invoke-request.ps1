param(
    [string]$ConfigPath,
    [Parameter(Mandatory = $true)]
    [string]$RelativePath,
    [switch]$ResolveSitePlaceholders,
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
$effectiveRelativePath = $RelativePath

Write-ProbeBanner -Title 'UniFi Generic Request'
Write-Host "Relative path: $RelativePath"
Write-Host "Resolve site placeholders: $ResolveSitePlaceholders"
Write-Host "API key env var: $($uniFiConfig.ApiKeyEnvVar)"

if ($ShowPlanOnly) {
    Write-Host ''
    Write-Host 'Scaffold only: no API request sent.'
    return
}

if ($ResolveSitePlaceholders) {
    $siteResolution = Resolve-UniFiSite -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig
    $effectiveRelativePath = $effectiveRelativePath.Replace('{siteId}', $siteResolution.Id)
    $effectiveRelativePath = $effectiveRelativePath.Replace('{site}', $siteResolution.Selector)
}

$response = Invoke-UniFiGetJson -GatewayConfig $gatewayConfig -UniFiConfig $uniFiConfig -RelativePath $effectiveRelativePath

$summary = [pscustomobject]@{
    success = $true
    relative_path = $effectiveRelativePath
    endpoint = $response.Url
    item_count = @($response.Items).Count
    items = @($response.Items)
    raw = $response.Raw
}

if ($OutputFormat -eq 'Json') {
    $summary | ConvertTo-Json -Depth 20
    return
}

Write-Host ''
Write-Host "Item count: $($summary.item_count)"
$summary.raw | ConvertTo-Json -Depth 10 | Write-Host
