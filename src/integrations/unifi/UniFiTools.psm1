Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-UniFiBaseUrl {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$GatewayConfig
    )

    $scheme = $GatewayConfig.Scheme
    if (-not $scheme) {
        $scheme = 'https'
    }

    "${scheme}://$($GatewayConfig.Address)"
}

function Get-UniFiApiUrl {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$GatewayConfig,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $baseUrl = Get-UniFiBaseUrl -GatewayConfig $GatewayConfig
    $basePath = $GatewayConfig.ApiBasePath
    if (-not $basePath) {
        $basePath = ''
    }

    $trimmedBasePath = $basePath.TrimEnd('/')
    $trimmedRelativePath = $RelativePath.TrimStart('/')

    if ($trimmedBasePath) {
        "$baseUrl$trimmedBasePath/$trimmedRelativePath"
    }
    else {
        "$baseUrl/$trimmedRelativePath"
    }
}

function Get-UniFiApiKey {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UniFiConfig
    )

    $envVarName = $UniFiConfig.ApiKeyEnvVar
    if (-not $envVarName) {
        throw 'UniFi.ApiKeyEnvVar is not configured.'
    }

    $apiKey = [Environment]::GetEnvironmentVariable($envVarName)
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        throw "Set environment variable $envVarName before attempting a UniFi API request."
    }

    $apiKey
}

function Get-UniFiCurlBaseArguments {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$UniFiConfig
    )

    $arguments = @('-s')

    if (-not $UniFiConfig.VerifyTls) {
        $arguments += '-k'
    }

    $arguments
}

function Get-UniFiItemsFromResponse {
    param(
        [Parameter(Mandatory = $true)]
        [object]$ResponseObject
    )

    if ($ResponseObject -is [System.Collections.IEnumerable] -and -not ($ResponseObject -is [string]) -and -not ($ResponseObject -is [psobject])) {
        return @($ResponseObject)
    }

    if ($ResponseObject.PSObject.Properties.Name -contains 'data') {
        return @($ResponseObject.data)
    }

    if ($ResponseObject.PSObject.Properties.Name -contains 'items') {
        return @($ResponseObject.items)
    }

    if ($ResponseObject.PSObject.Properties.Name -contains 'results') {
        return @($ResponseObject.results)
    }

    @()
}

function Invoke-UniFiGetJson {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$GatewayConfig,

        [Parameter(Mandatory = $true)]
        [hashtable]$UniFiConfig,

        [Parameter(Mandatory = $true)]
        [string]$RelativePath
    )

    $apiKey = Get-UniFiApiKey -UniFiConfig $UniFiConfig
    $url = Get-UniFiApiUrl -GatewayConfig $GatewayConfig -RelativePath $RelativePath

    $curlArgs = @()
    $curlArgs += Get-UniFiCurlBaseArguments -UniFiConfig $UniFiConfig
    $curlArgs += @(
        '-H', "X-API-KEY: $apiKey",
        '-H', 'Accept: application/json',
        $url
    )

    $result = Invoke-CurlReadOnly -Arguments $curlArgs

    if (-not $result.Success) {
        throw "UniFi GET request failed for $RelativePath. Exit code: $($result.ExitCode)"
    }

    $responseObject = ConvertFrom-JsonSafe -InputLines $result.Output

    [pscustomobject]@{
        RelativePath = $RelativePath
        Url = $url
        Raw = $responseObject
        Items = @(Get-UniFiItemsFromResponse -ResponseObject $responseObject)
    }
}

function Resolve-UniFiSite {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$GatewayConfig,

        [Parameter(Mandatory = $true)]
        [hashtable]$UniFiConfig
    )

    $sitesResponse = Invoke-UniFiGetJson -GatewayConfig $GatewayConfig -UniFiConfig $UniFiConfig -RelativePath 'v1/sites'
    $siteSelector = $GatewayConfig.Site
    $selectedSite = $sitesResponse.Items | Where-Object {
        $_.id -eq $siteSelector -or $_.internalReference -eq $siteSelector -or $_.name -eq $siteSelector
    } | Select-Object -First 1

    if (-not $selectedSite) {
        throw "Unable to resolve site '$siteSelector'. Available site selectors: $($sitesResponse.Items | ForEach-Object { $_.internalReference })"
    }

    [pscustomobject]@{
        Selector = $siteSelector
        Id = $selectedSite.id
        Site = $selectedSite
        AllSites = $sitesResponse.Items
        SitesUrl = $sitesResponse.Url
    }
}

Export-ModuleMember -Function Get-UniFiBaseUrl, Get-UniFiApiUrl, Get-UniFiApiKey, Get-UniFiCurlBaseArguments, Get-UniFiItemsFromResponse, Invoke-UniFiGetJson, Resolve-UniFiSite
