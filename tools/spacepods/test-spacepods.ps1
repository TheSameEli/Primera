<#
.SYNOPSIS
Compiles and runs the Paradise spacepod port suite in an isolated local deployment.
.DESCRIPTION
Run the normal build first to generate translations, TGUI and behavior trees.
Uses MetaStation because the native roundstart landmark regression is deliberately
disabled on Runtime Station. Artifacts and diagnostics remain under tmp/spacepods-*.
#>
[CmdletBinding()]
param(
    [string]$ByondBin = (Join-Path ${env:ProgramFiles(x86)} 'BYOND\bin'),
    [ValidateRange(30, 3600)][int]$TimeoutSeconds = 600
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$runName = 'spacepods-' + [Guid]::NewGuid().ToString('N').Substring(0, 12)
$runDirectory = Join-Path $repoRoot ('tmp\' + $runName)
$wrapperName = $runName + '.test'
$wrapperPath = Join-Path $repoRoot ($wrapperName + '.dme')
$rootArtifacts = @('.dme', '.dmb', '.rsc') | ForEach-Object { Join-Path $repoRoot ($wrapperName + $_) }
$compiler = Join-Path $ByondBin 'dm.exe'
$daemon = Join-Path $ByondBin 'dd.exe'
foreach ($executable in @($compiler, $daemon)) {
    if (-not (Test-Path -LiteralPath $executable -PathType Leaf)) {
        throw "Missing BYOND executable: $executable"
    }
}

New-Item -ItemType Directory -Path $runDirectory | Out-Null
Write-Output "Spacepod test artifacts: $runDirectory"
Push-Location -LiteralPath $repoRoot
try {
    $testFiles = @(Get-ChildItem -LiteralPath 'modular_bandastation\spacepods\code' -Filter '*_tests.dm' -File)
    $portTests = @($testFiles | Select-String -Pattern '^(/datum/unit_test/spacepod_[^\s(]+)/Run\(' |
        ForEach-Object { $_.Matches[0].Groups[1].Value })
    if (-not $portTests.Count) {
        throw 'No spacepod unit tests found.'
    }
    $regressionTests = @(
        '/datum/unit_test/job_icons',
        '/datum/unit_test/job_display_order',
        '/datum/unit_test/verify_config_tags',
        '/datum/unit_test/station_traits',
        '/datum/unit_test/maptest_job_roundstart_spawnpoints',
        '/datum/unit_test/designs',
        '/datum/unit_test/design_source',
        '/datum/unit_test/design_mats',
        '/datum/unit_test/movement_order_sanity',
        '/datum/unit_test/chain_pull_through_space',
        '/datum/unit_test/move_pulled/to_turf',
        '/datum/unit_test/move_pulled/to_decal',
        '/datum/unit_test/teleporter',
        '/datum/unit_test/hand_teleporter',
        '/datum/unit_test/buckling_self',
        '/datum/unit_test/buckling_others',
        '/datum/unit_test/closet_contents',
        '/datum/unit_test/closet_opening',
        '/datum/unit_test/closet_multitile_contents',
        '/datum/unit_test/mecha_damage',
        '/datum/unit_test/mecha_construction_icons',
        '/datum/unit_test/mech_generator',
        '/datum/unit_test/breath/breath_sanity',
        '/datum/unit_test/focus_only/invalid_research_designs',
        '/datum/unit_test/focus_only/invalid_emissives'
    )
    $focusedTests = @(@($portTests) + @($regressionTests) | Sort-Object -Unique)
    $wrapperLines = @('#include "tgstation.dme"') + @($focusedTests | ForEach-Object { 'TEST_FOCUS(' + $_ + ')' })
    [IO.File]::WriteAllLines($wrapperPath, [string[]]$wrapperLines, $utf8NoBom)
    [IO.File]::WriteAllLines((Join-Path $runDirectory 'focused-tests.txt'), [string[]]$focusedTests, $utf8NoBom)
    Write-Output "Compiling $($focusedTests.Count) focused tests."
    # Map landmark tests need the normal compiled CentCom dimensions. The
    # minimal map makes LoadGroup crop larger stations at negative offsets.
    & $compiler -DCBT -DUNIT_TESTS $wrapperPath 2>&1 |
        Tee-Object -FilePath (Join-Path $runDirectory 'compile.log')
    if ($LASTEXITCODE -ne 0) {
        throw "DM compilation failed. See $runDirectory\compile.log"
    }
    foreach ($extension in @('.dmb', '.rsc')) {
        Move-Item -LiteralPath (Join-Path $repoRoot ($wrapperName + $extension)) -Destination (Join-Path $runDirectory ('spacepods.test' + $extension))
    }

    # Map-preview initialization rewrites icons/obj/fluff/map_previews.dmi.
    # Copy icons so this generated artifact stays inside the isolated deployment.
    foreach ($relative in @('_maps', 'build\behavior_trees', 'code\datums\greyscale\json_configs', 'icons', 'sound\runtime', 'strings', 'tgui\public', 'modular_bandastation')) {
        $source = Join-Path $repoRoot $relative
        if (-not (Test-Path -LiteralPath $source -PathType Container)) {
            throw "Missing build asset directory: $source. Run the normal build first."
        }
        $destination = Join-Path $runDirectory $relative
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $destination) | Out-Null
        if ($relative -eq 'icons') {
            Copy-Item -LiteralPath $source -Destination $destination -Recurse
        } else {
            New-Item -ItemType Junction -Path $destination -Target $source | Out-Null
        }
    }
    Get-ChildItem -LiteralPath $repoRoot -Filter '*.dll' -File | Copy-Item -Destination $runDirectory
    New-Item -ItemType Directory -Force -Path (Join-Path $runDirectory 'data\spritesheets'), (Join-Path $runDirectory 'config') | Out-Null
    # These focused tests own their vacuum/mining fixtures; procedural ruins add unrelated world runtimes.
    $testMap = Get-Content -LiteralPath '_maps\map_jsons\metastation.json' -Raw | ConvertFrom-Json
    $testMap | Add-Member -NotePropertyName space_ruin_levels -NotePropertyValue 0 -Force
    $testMap | Add-Member -NotePropertyName minetype -NotePropertyValue 'none' -Force
    [IO.File]::WriteAllText((Join-Path $runDirectory 'data\next_map.json'), ($testMap | ConvertTo-Json -Depth 10), $utf8NoBom)
    [IO.File]::WriteAllLines((Join-Path $runDirectory 'config\maps.txt'), [string[]]@('map metastation', 'default', 'endmap'), $utf8NoBom)

    $server = Start-Process -FilePath $daemon -WorkingDirectory $runDirectory -WindowStyle Hidden -PassThru -ArgumentList 'spacepods.test.dmb -trusted -invisible -log console.log -params log-directory=spacepods'
    try {
        if (-not $server.WaitForExit($TimeoutSeconds * 1000)) {
            throw "Spacepod tests exceeded $TimeoutSeconds seconds. See $runDirectory\console.log"
        }
        $daemonExitCode = $server.ExitCode
    } finally {
        if (-not $server.HasExited) {
            $server.Kill()
            $server.WaitForExit()
        }
        $server.Dispose()
    }

    $resultsPath = Join-Path $runDirectory 'data\unit_tests.json'
    if (-not (Test-Path -LiteralPath $resultsPath -PathType Leaf)) {
        throw "The daemon did not produce test results. See $runDirectory\console.log"
    }
    $results = Get-Content -LiteralPath $resultsPath -Raw | ConvertFrom-Json
    $actualTests = @($results.PSObject.Properties.Name)
    # focus_only types collect failures from other procs and have no successful Run result.
    $requiredTests = @($focusedTests | Where-Object { $_ -notlike '/datum/unit_test/focus_only/*' })
    $missingTests = @($requiredTests | Where-Object { $_ -notin $actualTests })
    $failedTests = @($results.PSObject.Properties.Value | Where-Object { $_.status -ne 0 })
    foreach ($failedTest in $failedTests) {
        Write-Output ($failedTest.name + ': ' + $failedTest.message)
    }

    $logDirectory = Join-Path $runDirectory 'data\logs\spacepods'
    $cleanMarker = Join-Path $logDirectory 'clean_run.lk'
    $cleanShutdown = (Test-Path -LiteralPath $cleanMarker -PathType Leaf) -and ((Get-Content -LiteralPath $cleanMarker -Raw).Trim() -eq 'Success!')
    # Native BYOND runtimes may only reach dd.log; early failures may precede its redirect.
    $runtimeLogs = @(
        (Join-Path $logDirectory 'dd.log'),
        (Join-Path $logDirectory 'runtime.log.json'),
        (Join-Path $runDirectory 'console.log')
    )
    $missingLogs = @($runtimeLogs | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
    $existingLogs = @($runtimeLogs | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
    $runtimeErrors = @()
    if ($existingLogs.Count) {
        $runtimeErrors = @(Select-String -LiteralPath $existingLogs -Pattern 'Runtime in\b|runtime error\b|uncaught exception\b|Total runtimes:\s*[1-9]|Maximum recursion level reached|Infinite loop suspected|BYOND out of memory')
    }
    foreach ($runtimeError in $runtimeErrors) {
        Write-Output $runtimeError.ToString()
    }
    Write-Output "$($actualTests.Count - $failedTests.Count)/$($actualTests.Count) test result groups passed. Results: $resultsPath"
    if ($daemonExitCode -ne 0 -or $missingTests.Count -or $failedTests.Count -or $missingLogs.Count -or $runtimeErrors.Count -or -not $cleanShutdown) {
        throw "Spacepod validation failed. Exit: $daemonExitCode. Missing tests: $($missingTests -join ', '). Failed tests: $($failedTests.Count). Runtime errors: $($runtimeErrors.Count). Missing logs: $($missingLogs -join ', '). Clean shutdown: $cleanShutdown. Inspect the preserved artifacts."
    }
} finally {
    # Preserve only this run's directly contained compiler artifacts; never move shared directories.
    foreach ($artifact in $rootArtifacts) {
        $absolutePath = [IO.Path]::GetFullPath($artifact)
        if ((Split-Path -Parent $absolutePath) -ne $repoRoot -or (Split-Path -Leaf $absolutePath) -notlike ($wrapperName + '.*')) {
            throw "Refusing to move unexpected path: $absolutePath"
        }
        if (Test-Path -LiteralPath $absolutePath -PathType Leaf) {
            Move-Item -LiteralPath $absolutePath -Destination $runDirectory
        }
    }
    Pop-Location
}
