<# Stops only the isolated spacepod playtest process recorded by start-local.ps1. #>
[CmdletBinding()]
param()
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$runtime = [IO.Path]::GetFullPath((Join-Path $repoRoot 'tmp\local-spacepods'))
$statePath = Join-Path $runtime 'server.json'
if (-not (Test-Path -LiteralPath $statePath -PathType Leaf)) {
    Write-Output 'No spacepod local server is recorded.'
    exit 0
}
$state = [IO.File]::ReadAllText($statePath) | ConvertFrom-Json
if ([int]$state.Port -ne 1345 -or $state.Runtime -ne $runtime -or [IO.Path]::GetFileName($state.Daemon) -ne 'dd.exe' -or $state.LogName -notmatch '^spacepods-local-[a-f0-9]{12}$') {
    throw 'The local server metadata does not describe this playtest; refusing to stop it.'
}
$candidate = Get-CimInstance Win32_Process -Filter ('ProcessId = ' + [int]$state.ProcessId)
if (-not $candidate) {
    Remove-Item -LiteralPath $statePath
    Write-Output 'The spacepod local server is already stopped.'
    exit 0
}
$server = Get-Process -Id ([int]$state.ProcessId) -ErrorAction Stop
if ($candidate.ExecutablePath -ne $state.Daemon -or $server.StartTime.ToUniversalTime().Ticks -ne [int64]$state.CreationTimeUtcTicks -or
    $candidate.CommandLine -notmatch '(?i)(?:^|\s)"?spacepods\.local\.dmb"?(?:\s|$)' -or
    $candidate.CommandLine -notmatch '(?i)(?:^|\s)-port\s+1345(?:\s|$)' -or
    $candidate.CommandLine -notmatch ([regex]::Escape('log-directory=' + $state.LogName) + '(?:\s|$)')) {
    throw 'The saved process id belongs to another process; refusing to stop it.'
}
Stop-Process -InputObject $server
$server.WaitForExit()
Remove-Item -LiteralPath $statePath
Write-Output 'Spacepod local server stopped. Logs and local save data were preserved.'
