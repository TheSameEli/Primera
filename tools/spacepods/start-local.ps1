<# Builds and starts an isolated spacepod playtest on the selected station. #>
[CmdletBinding()]
param(
    [switch]$NoClient,
    [ValidateSet('cyberiad', 'deltastation', 'icebox', 'metastation', 'tramstation', 'nebulastation', 'kilostation', 'wawastation')]
    [string]$Map = 'cyberiad',
    [string]$ByondBin = (Join-Path ${env:ProgramFiles(x86)} 'BYOND\bin'),
    [ValidateRange(30, 600)][int]$ReadyTimeoutSeconds = 180
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$runtime = [IO.Path]::GetFullPath((Join-Path $repoRoot 'tmp\local-spacepods'))
$statePath = Join-Path $runtime 'server.json'
$port = 1345
$compiler = Join-Path $ByondBin 'dm.exe'
$daemon = [IO.Path]::GetFullPath((Join-Path $ByondBin 'dd.exe'))
$client = Join-Path $ByondBin 'dreamseeker.exe'
$utf8 = New-Object System.Text.UTF8Encoding($false)

function Get-RecordedServer($state) {
    if ([int]$state.Port -ne $port -or $state.Runtime -ne $runtime -or $state.Daemon -ne $daemon -or $state.LogName -notmatch '^spacepods-local-[a-f0-9]{12}$') {
        throw 'The local server metadata does not describe this playtest; refusing to reuse it.'
    }
    $candidate = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + [int]$state.ProcessId)
    if (-not $candidate) { return $null }
    $process = Get-Process -Id ([int]$state.ProcessId) -ErrorAction Stop
    if ($candidate.ExecutablePath -ne $daemon -or $process.StartTime.ToUniversalTime().Ticks -ne [int64]$state.CreationTimeUtcTicks -or
        $candidate.CommandLine -notmatch '(?i)(?:^|\s)"?spacepods\.local\.dmb"?(?:\s|$)' -or
        $candidate.CommandLine -notmatch '(?i)(?:^|\s)-port\s+1345(?:\s|$)' -or
        $candidate.CommandLine -notmatch ([regex]::Escape('log-directory=' + $state.LogName) + '(?:\s|$)')) {
        throw 'The saved process id belongs to another process; refusing to reuse it.'
    }
    return $process
}

function Ensure-PrivateDirectory([string]$path) {
    $absolute = [IO.Path]::GetFullPath($path)
    if ($absolute -ne $runtime -and -not $absolute.StartsWith($runtime + '\', [StringComparison]::OrdinalIgnoreCase)) {
        throw "Unexpected private directory: $absolute"
    }
    if (Test-Path -LiteralPath $absolute) {
        $entry = Get-Item -LiteralPath $absolute -Force
        if (-not $entry.PSIsContainer -or ($entry.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
            throw "Private playtest data must be an ordinary directory: $absolute"
        }
    } else {
        New-Item -ItemType Directory -Path $absolute -Force | Out-Null
    }
}

foreach ($required in @($compiler, $daemon, (Join-Path $repoRoot 'tools\spacepods\local-playtest.dm'))) {
    if (-not (Test-Path -LiteralPath $required -PathType Leaf)) { throw "Missing local playtest file: $required" }
}
if (-not $NoClient -and -not (Test-Path -LiteralPath $client -PathType Leaf)) { throw "Missing BYOND client: $client" }
# Fail before compiling if this shell cannot verify process identity.
$null = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + $PID)
Ensure-PrivateDirectory $runtime
$server = $null
$state = $null
if (Test-Path -LiteralPath $statePath -PathType Leaf) {
    $state = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
    $server = Get-RecordedServer $state
    if ($server -and $state.Map -ne $Map) {
        throw "The running playtest uses another map. Run stop-local.ps1 before starting $Map."
    }
}

if (-not $server) {
    if (Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue) {
        throw "Port $port is already in use; existing servers were left running."
    }
    $runId = [Guid]::NewGuid().ToString('N').Substring(0, 12)
    $wrapperName = 'spacepods-local-build-' + $runId
    $wrapperPath = Join-Path $repoRoot ($wrapperName + '.dme')
    $buildLog = Join-Path $runtime ('compile-' + $runId + '.log')
    $wrapperLines = @(
        '#include "tgstation.dme"',
        '#ifdef UNIT_TESTS',
        '#error Local playtest must be compiled without UNIT_TESTS',
        '#endif',
        '#ifdef MINIMAL_CENTCOM',
        '#error Local station playtests require normal CentCom dimensions',
        '#endif',
        '#include "tools/spacepods/local-playtest.dm"'
    )
    [IO.File]::WriteAllLines($wrapperPath, [string[]]$wrapperLines, $utf8)
    Push-Location -LiteralPath $repoRoot
    try {
        & $compiler -DCBT $wrapperPath 2>&1 | Tee-Object -FilePath $buildLog
        if ($LASTEXITCODE -ne 0) { throw "Local playtest compilation failed. See $buildLog" }
        foreach ($extension in @('.dmb', '.rsc')) {
            Move-Item -LiteralPath (Join-Path $repoRoot ($wrapperName + $extension)) -Destination (Join-Path $runtime ('spacepods.local' + $extension)) -Force
        }
    } finally {
        foreach ($extension in @('.dme', '.dmb', '.rsc')) {
            $artifact = [IO.Path]::GetFullPath((Join-Path $repoRoot ($wrapperName + $extension)))
            if ((Split-Path -Parent $artifact) -ne $repoRoot -or (Split-Path -Leaf $artifact) -notlike ($wrapperName + '.*')) {
                throw "Refusing to move unexpected compiler artifact: $artifact"
            }
            if (Test-Path -LiteralPath $artifact -PathType Leaf) {
                Move-Item -LiteralPath $artifact -Destination $runtime
            }
        }
        Pop-Location
    }

    $assetDirectories = @('_maps', 'build\behavior_trees', 'code\datums\greyscale\json_configs', 'html', 'icons', 'interface', 'strings', 'tgui\public', 'tgui\packages', 'modular_bandastation')
    # statbrowser is read at client login; sound length queries also need original files on disk.
    $assetDirectories += @(Get-ChildItem -LiteralPath (Join-Path $repoRoot 'sound') -Directory | ForEach-Object { 'sound\' + $_.Name })
    foreach ($relative in $assetDirectories) {
        $source = Join-Path $repoRoot $relative
        $destination = Join-Path $runtime $relative
        if (-not (Test-Path -LiteralPath $source -PathType Container)) { throw "Missing build asset directory: $source" }
        New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force | Out-Null
        if ($relative -eq 'icons') {
            # Map-preview generation writes into icons, so those assets must be private.
            Ensure-PrivateDirectory $destination
            Get-ChildItem -LiteralPath $source -Force | Copy-Item -Destination $destination -Recurse -Force
        } elseif (Test-Path -LiteralPath $destination) {
            $existing = Get-Item -LiteralPath $destination -Force
            if (-not ($existing.Attributes -band [IO.FileAttributes]::ReparsePoint) -or
                [IO.Path]::GetFullPath(@($existing.Target)[0]) -ne [IO.Path]::GetFullPath($source)) {
                throw "Unexpected existing playtest asset path: $destination"
            }
        } else {
            New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
        }
    }
    Get-ChildItem -LiteralPath $repoRoot -Filter '*.dll' -File | Copy-Item -Destination $runtime -Force
    $configDirectory = Join-Path $runtime 'config'
    $dataDirectory = Join-Path $runtime 'data'
    Ensure-PrivateDirectory $configDirectory
    Ensure-PrivateDirectory $dataDirectory
    Ensure-PrivateDirectory (Join-Path $dataDirectory 'spritesheets')
    $configLines = @(
        'SERVERNAME PrimeDream - Spacepods Local Playtest',
        'STATIONNAME Spacepod Playtest',
        'LOBBY_COUNTDOWN 15',
        'ROUND_END_COUNTDOWN 30',
        'ADMIN_LEGACY_SYSTEM',
        'ENABLE_LOCALHOST_RANK',
        'RESUME_AFTER_INITIALIZATIONS',
        '$include resources.txt',
        '$include game_options.txt'
    )
    [IO.File]::WriteAllLines((Join-Path $configDirectory 'config.txt'), [string[]]$configLines, $utf8)
    [IO.File]::WriteAllLines((Join-Path $configDirectory 'resources.txt'), [string[]]@('ASSET_TRANSPORT simple'), $utf8)
    [IO.File]::WriteAllLines((Join-Path $configDirectory 'maps.txt'), [string[]]@(('map ' + $Map), 'default', 'endmap'), $utf8)
    $raceOptions = @(Get-Content -LiteralPath (Join-Path $repoRoot 'config\game_options.txt') |
        Where-Object { $_ -match '^\s*ROUNDSTART_RACES\s+\S+' })
    [IO.File]::WriteAllLines((Join-Path $configDirectory 'game_options.txt'), [string[]](@('FORBID_STATION_TRAITS') + $raceOptions), $utf8)
    # Only game balance tiers are copied; deployment credentials and service config stay in the checkout.
    $inGreenshift = $false
    $foundGreenshift = $false
    $dynamicLines = @(Get-Content -LiteralPath (Join-Path $repoRoot 'config\dynamic.toml') | ForEach-Object {
        if ($_ -match '^\["([^\"]+)"\]\s*$') {
            $inGreenshift = $Matches[1] -eq 'Greenshift'
            if ($inGreenshift) { $foundGreenshift = $true }
        }
        if ($_ -match '^weight\s*=') { 'weight = ' + $(if ($inGreenshift) { '100' } else { '0' }) } else { $_ }
    })
    if (-not $foundGreenshift) { throw 'The native Greenshift tier was not found.' }
    [IO.File]::WriteAllLines((Join-Path $configDirectory 'dynamic.toml'), [string[]]$dynamicLines, $utf8)
    Copy-Item -LiteralPath (Join-Path $repoRoot ('_maps\map_jsons\' + $Map + '.json')) -Destination (Join-Path $dataDirectory 'next_map.json') -Force

    $logName = 'spacepods-local-' + $runId
    $consolePath = Join-Path $runtime ('console-' + $runId + '.log')
    $arguments = @('spacepods.local.dmb', '-port', "$port", '-trusted', '-invisible', '-log', ('console-' + $runId + '.log'), '-params', ('log-directory=' + $logName))
    $server = Start-Process -FilePath $daemon -ArgumentList $arguments -WorkingDirectory $runtime -WindowStyle Hidden -PassThru
    $state = [ordered]@{
        ProcessId = $server.Id
        CreationTimeUtcTicks = $server.StartTime.ToUniversalTime().Ticks
        Port = $port
        Map = $Map
        Runtime = $runtime
        Daemon = $daemon
        LogName = $logName
        WorldLog = (Join-Path $runtime ('data\logs\' + $logName + '\dd.log'))
        ConsoleLog = $consolePath
        BuildLog = $buildLog
    }
    [IO.File]::WriteAllText($statePath, ($state | ConvertTo-Json), $utf8)
    Write-Output "Local server started, PID $($server.Id)."
} else {
    Write-Output "Using the existing spacepod playtest, PID $($server.Id). Stop it first to rebuild."
}

# Derive the native log path when reusing metadata from an earlier launcher.
$state.WorldLog = Join-Path $runtime ('data\logs\' + $state.LogName + '\dd.log')
$deadline = [DateTime]::UtcNow.AddSeconds($ReadyTimeoutSeconds)
$clientHandled = [bool]$NoClient
while ($true) {
    $server.Refresh()
    if ($server.HasExited) { throw "The local server exited. Inspect $($state.ConsoleLog)" }
    $ready = (Test-Path -LiteralPath $state.WorldLog -PathType Leaf) -and
        (Select-String -LiteralPath $state.WorldLog -Pattern 'SPACEPODS_LOCAL_READY' -Quiet)
    $ownListener = Get-NetTCPConnection -State Listen -LocalPort $port -ErrorAction SilentlyContinue |
        Where-Object { $_.OwningProcess -eq $server.Id } | Select-Object -First 1
    # BYOND can sleep after initialization until a client connects, before the arena's first tick.
    if (-not $clientHandled -and $ownListener) {
        $localUrl = "byond://127.0.0.1:$port"
        $connectedProcessIds = @(Get-NetTCPConnection -RemotePort $port -State Established -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess)
        $existingClient = Get-CimInstance Win32_Process -Filter "Name = 'dreamseeker.exe'" |
            Where-Object { $_.ProcessId -in $connectedProcessIds -and $_.ExecutablePath -eq $client -and $_.CommandLine -match ([regex]::Escape($localUrl) + '(?:/|"|\s|$)') } |
            Select-Object -First 1
        if ($existingClient) {
            Write-Output 'The BYOND client for this playtest is already open.'
        } else {
            Start-Process -FilePath $client -ArgumentList $localUrl -WindowStyle Normal | Out-Null
        }
        $clientHandled = $true
    }
    if ($ready -and $ownListener) { break }
    if ([DateTime]::UtcNow -ge $deadline) {
        throw "The server is still loading; it was left running. Inspect $($state.WorldLog)"
    }
    Start-Sleep -Milliseconds 500
}
Write-Output "Spacepod playtest is ready: byond://127.0.0.1:$port"
Write-Output "World log: $($state.WorldLog)"
