param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string]$PythonPath = 'python',
    [switch]$GpuChecks,
    [switch]$ArchiveChecks,
    [string]$ArchiveRoot
)
$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
$taskGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$taskPython = (Get-Command $PythonPath -ErrorAction Stop).Source
$taskRun = Join-Path $taskRepo ('test-results/check-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
$taskOldAppData = $env:APPDATA
$taskOldLocalAppData = $env:LOCALAPPDATA
$taskOldArchiveRoot = $env:SOLMERE_ARCHIVE_ROOT
New-Item -ItemType Directory -Force -Path $taskRun | Out-Null
$env:APPDATA = Join-Path $taskRun 'AppData/Roaming'
$env:LOCALAPPDATA = Join-Path $taskRun 'AppData/Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null

function Invoke-TaskGodot {
    param([string]$Name, [string[]]$EngineArguments, [switch]$Gpu)
    $taskLog = Join-Path $taskRun ($Name + '.log')
    $taskArguments = @('--path',$taskRepo,'--log-file',$taskLog) + $EngineArguments
    Write-Host ("Running {0} ({1})" -f $Name, $(if ($Gpu) {'GPU input/rendering'} else {'headless; no visual approval'}))
    # Godot's Windows GUI executable may return immediately through PowerShell's
    # call operator. Always wait on its process and inspect that actual exit code.
    if (-not $Gpu) { $taskArguments = @('--headless') + $taskArguments }
    else {
        # Hidden process startup alone does not guarantee that a renderer-created
        # window stays out of the user's foreground. Keep GPU fixtures offscreen.
        $taskArguments = @('--rendering-driver','opengl3','--position=-12000,-12000') + $taskArguments
    }
    $taskQuoted = ($taskArguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $taskProcess = Start-Process -FilePath $taskGodot -ArgumentList $taskQuoted -WindowStyle Hidden -PassThru
    $taskTimer=[Diagnostics.Stopwatch]::StartNew()
    while (-not $taskProcess.WaitForExit(1000)) {
        $taskScriptError=(Test-Path -LiteralPath $taskLog) -and ((Get-Content -LiteralPath $taskLog -Raw) -match 'SCRIPT ERROR:')
        if ($taskScriptError -or $taskTimer.Elapsed.TotalSeconds -gt 600) {
            # Stop only this harness's launcher and engine carrying its exact log.
            Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" | Where-Object { $_.CommandLine.Contains($taskLog) } | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
            throw "$Name stopped after script error or 600-second bound; see $taskLog"
        }
    }
    if ((Get-Content -LiteralPath $taskLog -Raw) -match 'SCRIPT ERROR:') { throw "$Name script error; see $taskLog" }
    if ($taskProcess.ExitCode -ne 0) { throw "$Name failed; see $taskLog" }
}

Push-Location $taskRepo
try {
    & $taskPython tools/studio.py verify
    if ($LASTEXITCODE -ne 0) { throw 'Studio upstream/adapter integrity failed' }
    & $taskPython tools/studio.py status
    if ($LASTEXITCODE -ne 0) { throw 'Studio production structure failed' }
    & $taskPython -m unittest discover -s tests -p 'test_studio_*.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Studio evidence gate regression failed' }
    & $taskPython -m unittest discover -s tests -p 'test_pastel_assets.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Active generated art/export integrity failed' }
    if ($ArchiveChecks) {
        if (-not $ArchiveRoot) { $ArchiveRoot = $taskRepo }
        $taskArchive = (Resolve-Path -LiteralPath $ArchiveRoot).Path
        $taskPrivateOriginal = Join-Path $taskArchive 'assets/locked_user/street_scenery_USER_20261001_LOCKED.psd'
        if (-not (Test-Path -LiteralPath $taskPrivateOriginal -PathType Leaf)) {
            throw 'ArchiveChecks requires a separately retained local archive. Supply -ArchiveRoot; private PSDs are intentionally absent from public source.'
        }
        $env:SOLMERE_ARCHIVE_ROOT = $taskArchive
        & $taskPython tools/check_locked_assets.py --root $taskArchive
        if ($LASTEXITCODE -ne 0) { throw 'Local archive verification failed' }
        & $taskPython -m unittest discover -s tests -p test_locked_assets.py -v
        if ($LASTEXITCODE -ne 0) { throw 'Local archive corruption/missing-file regression failed' }
    } else {
        Write-Host 'ArchiveChecks NOT RUN (default): private original/PSD archival verification is separate from public gameplay checks.'
    }
    Invoke-TaskGodot 'import' @('--editor','--import','--quit')
    # Current models and independent compatible components, not old GameSession.
    foreach ($taskSuite in @('mail_physics_state_smoke','final_case_state_smoke','final_walker_smoke','scene_dialogue_input_smoke','postal_desk_live_queue','envelope_text_bounds_smoke')) {
        Invoke-TaskGodot $taskSuite @('--script',"res://tests/$taskSuite.gd")
    }
    if ($GpuChecks) {
        foreach ($taskSuite in @('field_observation_smoke','field_book_smoke','mail_workbench_input_smoke','tactile_mail_input','resolution_slip_smoke','final_host_boundary_smoke','final_resolution_draft_smoke','counter_onboarding_input','core_review_input')) {
            Invoke-TaskGodot $taskSuite @('--script',"res://tests/$taskSuite.gd",'--resolution','1600x900','--audio-driver','Dummy') -Gpu
        }
        foreach ($taskRoute in @('sealed','delegate')) {
            Invoke-TaskGodot ("five_case_" + $taskRoute) @('--script','res://tests/final_five_case_input.gd','--resolution','1600x900','--audio-driver','Dummy','--',("--route=" + $taskRoute)) -Gpu
        }
        Invoke-TaskGodot 'amended_handoff' @('--script','res://tests/final_amended_handoff_input.gd','--resolution','1600x900','--audio-driver','Dummy') -Gpu
        & (Join-Path $PSScriptRoot 'test_window_close.ps1') -GodotPath $taskGodot
        Write-Host 'Automated GPU checks completed; not human usability, reference fidelity or listening approval.'
    } else {
        Write-Host 'Headless checks completed. GPU checks were NOT run; use -GpuChecks.'
    }
    Write-Host "Logs and isolated userdata: $taskRun"
} finally {
    $env:APPDATA = $taskOldAppData
    $env:LOCALAPPDATA = $taskOldLocalAppData
    $env:SOLMERE_ARCHIVE_ROOT = $taskOldArchiveRoot
    Pop-Location
}
