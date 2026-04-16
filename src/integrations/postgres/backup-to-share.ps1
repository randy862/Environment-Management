param(
    [string]$ConfigPath,
    [ValidateSet('Text', 'Json')]
    [string]$OutputFormat = 'Text',
    [switch]$ShowPlanOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$rootDir = Split-Path -Parent $scriptDir

if (-not $PSBoundParameters.ContainsKey('ConfigPath')) {
    $ConfigPath = Join-Path $rootDir 'config/local.psd1'
}

Import-Module (Join-Path $rootDir 'lib/ReadOnlyTools.psm1') -Force

function ConvertTo-BashLiteral {
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $replacement = "'" + '"' + "'" + '"' + "'"
    $escaped = $Value.Replace("'", $replacement)
    return "'" + $escaped + "'"
}

function ConvertTo-BashCommand {
    param(
        [Parameter(Mandatory = $true)]
        [string]$CommandText
    )

    return "bash -lc $(ConvertTo-BashLiteral -Value $CommandText)"
}

function Invoke-SshChecked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Address,

        [Parameter(Mandatory = $true)]
        [string]$RemoteCommand
    )

    $result = Invoke-SshReadOnly -User $User -Address $Address -RemoteCommand $RemoteCommand

    if (-not $result.Success) {
        $detail = ($result.Output -join [Environment]::NewLine).Trim()

        if ($detail) {
            throw "SSH command failed with exit code $($result.ExitCode): $detail"
        }

        throw "SSH command failed with exit code $($result.ExitCode)."
    }

    return $result
}

function Receive-ScpFile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$User,

        [Parameter(Mandatory = $true)]
        [string]$Address,

        [Parameter(Mandatory = $true)]
        [string]$RemotePath,

        [Parameter(Mandatory = $true)]
        [string]$LocalPath
    )

    $arguments = @(
        '-q',
        "${User}@${Address}:$RemotePath",
        $LocalPath
    )

    $output = & scp @arguments 2>&1
    $exitCode = $LASTEXITCODE

    if ($exitCode -ne 0) {
        $detail = ($output -join [Environment]::NewLine).Trim()

        if ($detail) {
            throw "scp failed with exit code ${exitCode}: $detail"
        }

        throw "scp failed with exit code $exitCode."
    }
}

function Get-StatusLabel {
    param([bool]$Success)
    if ($Success) { return 'OK' }
    return 'FAIL'
}

function Test-DirectoryAccessible {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    try {
        return [System.IO.Directory]::Exists($Path)
    }
    catch {
        return $false
    }
}

$config = Get-IntegrationConfig -Path $ConfigPath
$sqlHost = $config.Hosts.Sql001
$backupConfig = $config.Backups.Postgres

if (-not $backupConfig.TargetRoot) {
    throw 'Backups.Postgres.TargetRoot is required.'
}

$targetRoot = $backupConfig.TargetRoot
$retentionDays = [int]$backupConfig.RetentionDays
$compressionLevel = [int]$backupConfig.CompressionLevel
$keepDatabases = @($backupConfig.KeepDatabases)
$timestamp = Get-Date
$runId = $timestamp.ToString('yyyyMMdd-HHmmss')
$runFolder = Join-Path $targetRoot $runId
$remoteTempDir = "/var/tmp/postgres-backup-$runId"

$databaseQueryText = 'select datname from pg_database where datallowconn and not datistemplate order by datname;'
$databaseQueryBase64 = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($databaseQueryText))
$databaseQuery = ConvertTo-BashCommand -CommandText "printf '%s' $(ConvertTo-BashLiteral -Value $databaseQueryBase64) | base64 -d | sudo -u postgres psql -At -f -"
$databaseResult = Invoke-SshChecked -User $sqlHost.User -Address $sqlHost.Address -RemoteCommand $databaseQuery
$databases = @(
    $databaseResult.Output |
        ForEach-Object { $_.Trim() } |
        Where-Object { $_ }
)

if ($keepDatabases.Count -gt 0) {
    $databases = @($databases | Where-Object { $keepDatabases -contains $_ })
}

if ($databases.Count -eq 0) {
    throw 'No PostgreSQL databases were selected for backup.'
}

$plan = [pscustomobject]@{
    target_host = $sqlHost.Address
    target_user = $sqlHost.User
    target_root = $targetRoot
    run_folder = $runFolder
    remote_temp_dir = $remoteTempDir
    retention_days = $retentionDays
    compression_level = $compressionLevel
    databases = $databases
}

if ($ShowPlanOnly) {
    if ($OutputFormat -eq 'Json') {
        $plan | ConvertTo-Json -Depth 6
        return
    }

    Write-ProbeBanner -Title 'PostgreSQL Backup Plan'
    Write-Host "Target: $($sqlHost.User)@$($sqlHost.Address)"
    Write-Host "Share: $targetRoot"
    Write-Host "Run folder: $runFolder"
    Write-Host "Remote temp: $remoteTempDir"
    Write-Host "Retention days: $retentionDays"
    Write-Host "Compression level: $compressionLevel"
    Write-Host "Databases: $($databases -join ', ')"
    return
}

if (-not (Test-DirectoryAccessible -Path $targetRoot)) {
    throw "Backup target root is not accessible from this workstation: $targetRoot. Confirm the share exists and that Windows has an authenticated SMB session to it before running the backup."
}

New-Item -ItemType Directory -Path $runFolder -Force | Out-Null

$manifest = [ordered]@{
    collected_at = $timestamp.ToString('o')
    source_host = $sqlHost.Address
    source_user = $sqlHost.User
    target_root = $targetRoot
    run_folder = $runFolder
    remote_temp_dir = $remoteTempDir
    retention_days = $retentionDays
    compression_level = $compressionLevel
    globals_file = 'globals.sql.gz'
    databases = @()
    pruned_runs = @()
}

try {
    Invoke-SshChecked -User $sqlHost.User -Address $sqlHost.Address -RemoteCommand "mkdir -p $(ConvertTo-BashLiteral -Value $remoteTempDir)" | Out-Null

    $globalsRemotePath = "$remoteTempDir/globals.sql.gz"
    $globalsCommand = ConvertTo-BashCommand -CommandText "sudo -u postgres pg_dumpall --globals-only | gzip -c > $(ConvertTo-BashLiteral -Value $globalsRemotePath)"
    Invoke-SshChecked -User $sqlHost.User -Address $sqlHost.Address -RemoteCommand $globalsCommand | Out-Null
    Receive-ScpFile -User $sqlHost.User -Address $sqlHost.Address -RemotePath $globalsRemotePath -LocalPath (Join-Path $runFolder 'globals.sql.gz')

    foreach ($database in $databases) {
        $remoteFileName = "$database.dump"
        $remotePath = "$remoteTempDir/$remoteFileName"
        $localPath = Join-Path $runFolder $remoteFileName
        $dumpCommand = ConvertTo-BashCommand -CommandText "sudo -u postgres pg_dump --format=custom --compress=$compressionLevel --file $(ConvertTo-BashLiteral -Value $remotePath) --dbname $(ConvertTo-BashLiteral -Value $database)"

        Invoke-SshChecked -User $sqlHost.User -Address $sqlHost.Address -RemoteCommand $dumpCommand | Out-Null
        Receive-ScpFile -User $sqlHost.User -Address $sqlHost.Address -RemotePath $remotePath -LocalPath $localPath

        $item = Get-Item -Path $localPath
        $manifest.databases += [pscustomobject]@{
            name = $database
            file = $remoteFileName
            size_bytes = $item.Length
        }
    }
}
finally {
    $cleanupCommand = "rm -rf $(ConvertTo-BashLiteral -Value $remoteTempDir)"
    try {
        Invoke-SshReadOnly -User $sqlHost.User -Address $sqlHost.Address -RemoteCommand $cleanupCommand | Out-Null
    }
    catch {
    }
}

$cutoff = (Get-Date).AddDays(-$retentionDays)
$prunedRuns = [System.Collections.Generic.List[string]]::new()

Get-ChildItem -Path $targetRoot -Directory |
    Where-Object { $_.Name -match '^\d{8}-\d{6}$' -and $_.LastWriteTime -lt $cutoff } |
    ForEach-Object {
        Remove-Item -Path $_.FullName -Recurse -Force
        $prunedRuns.Add($_.Name)
    }

$manifest.pruned_runs = @($prunedRuns)
$manifestPath = Join-Path $runFolder 'manifest.json'
$manifest | ConvertTo-Json -Depth 6 | Set-Content -Path $manifestPath -Encoding ascii

$result = [pscustomobject]@{
    collected_at = $manifest.collected_at
    success = $true
    status = Get-StatusLabel -Success $true
    target_host = $sqlHost.Address
    target_root = $targetRoot
    run_folder = $runFolder
    database_count = $databases.Count
    databases = $manifest.databases
    pruned_runs = $manifest.pruned_runs
    manifest_path = $manifestPath
}

if ($OutputFormat -eq 'Json') {
    $result | ConvertTo-Json -Depth 6
    return
}

Write-ProbeBanner -Title 'PostgreSQL Backup'
Write-Host "Target: $($sqlHost.User)@$($sqlHost.Address)"
Write-Host "Share: $targetRoot"
Write-Host "Run folder: $runFolder"
Write-Host "Databases backed up: $($databases.Count)"
Write-Host "Pruned runs: $($prunedRuns.Count)"
Write-Host ''

$manifest.databases |
    Select-Object name, file, size_bytes |
    Format-Table -AutoSize |
    Out-String |
    Write-Host
