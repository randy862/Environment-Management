param(
    [string]$ConfigPath
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
$gatewayHost = $config.Hosts.Gateway001

Write-ProbeBanner -Title 'UniFi Gateway Reachability'
Write-Host "Target: https://$($gatewayHost.Address)/"
Write-Host 'Request: curl.exe -k -s -I'

$headerResult = Invoke-CurlReadOnly -Arguments @('-k', '-s', '-I', "https://$($gatewayHost.Address)/")

if (-not $headerResult.Success) {
    throw "Failed to fetch UniFi gateway headers. Exit code: $($headerResult.ExitCode)"
}

$headerResult.Output | ForEach-Object { Write-Host $_ }

Write-Host ''
Write-Host 'Landing page identity:'

$bodyResult = Invoke-CurlReadOnly -Arguments @('-k', '-s', "https://$($gatewayHost.Address)/")

if (-not $bodyResult.Success) {
    throw "Failed to fetch UniFi gateway page. Exit code: $($bodyResult.ExitCode)"
}

$bodyText = ($bodyResult.Output -join [Environment]::NewLine)
$manifestMatch = [regex]::Match($bodyText, 'shortName":"(?<name>[^"]+)"')

if ($manifestMatch.Success) {
    Write-Host $manifestMatch.Groups['name'].Value
}
else {
    Write-Host 'Unable to identify gateway model from landing page.'
}
