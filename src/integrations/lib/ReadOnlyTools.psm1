Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-IntegrationConfig {
    param(
        [string]$Path
    )

    if (-not $Path) {
        throw 'A configuration path is required.'
    }

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Configuration file not found: $Path"
    }

    Import-PowerShellDataFile -LiteralPath $Path
}

function Invoke-SshReadOnly {
    param(
        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Address,

        [Parameter(Mandatory = $true)]
        [string]$RemoteCommand,

        [int]$ConnectTimeoutSeconds = 8
    )

    $arguments = @(
        '-o', 'BatchMode=yes',
        '-o', "ConnectTimeout=$ConnectTimeoutSeconds",
        "$User@$Address",
        $RemoteCommand
    )

    $output = & ssh @arguments 2>&1
    $exitCode = $LASTEXITCODE

    [pscustomobject]@{
        ExitCode = $exitCode
        Success = ($exitCode -eq 0)
        Output = @($output)
    }
}

function Invoke-CurlReadOnly {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $output = & curl.exe @Arguments 2>&1
    $exitCode = $LASTEXITCODE

    [pscustomobject]@{
        ExitCode = $exitCode
        Success = ($exitCode -eq 0)
        Output = @($output)
    }
}

function Write-ProbeBanner {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title
    )

    Write-Host "== $Title =="
}

function ConvertFrom-JsonSafe {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InputLines
    )

    $text = ($InputLines -join [Environment]::NewLine).Trim()

    if (-not $text) {
        throw 'Expected JSON content but command returned no output.'
    }

    $text | ConvertFrom-Json
}

function ConvertFrom-QmListText {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$InputLines
    )

    $vmRows = @()

    foreach ($line in $InputLines) {
        $trimmed = $line.Trim()

        if (-not $trimmed) {
            continue
        }

        if ($trimmed -like 'VMID NAME*' -or $trimmed -like '----*') {
            continue
        }

        $match = [regex]::Match(
            $line,
            '^\s*(?<vmid>\d+)\s+(?<name>\S+)\s+(?<status>\S+)\s+(?<memoryMb>\d+)\s+(?<bootDiskGb>[0-9.]+)\s+(?<pid>\d+)\s*$'
        )

        if (-not $match.Success) {
            continue
        }

        $vmRows += [pscustomobject]@{
            vmid = [int]$match.Groups['vmid'].Value
            name = $match.Groups['name'].Value
            status = $match.Groups['status'].Value
            memory_mb = [int]$match.Groups['memoryMb'].Value
            boot_disk_gb = [double]$match.Groups['bootDiskGb'].Value
            pid = [int]$match.Groups['pid'].Value
        }
    }

    $vmRows
}

Export-ModuleMember -Function Get-IntegrationConfig, Invoke-SshReadOnly, Invoke-CurlReadOnly, Write-ProbeBanner, ConvertFrom-JsonSafe, ConvertFrom-QmListText
