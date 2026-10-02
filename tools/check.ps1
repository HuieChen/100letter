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
    $taskProcess = Start-Process -FilePath $taskGodot -ArgumentList $taskQuoted -WindowStyle Hidden -PassThru -Wait
    if ($taskProcess.ExitCode -ne 0) { throw "$Name failed; see $taskLog" }
}

Push-Location $taskRepo
try {
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
    foreach ($taskSuite in @('mail_physics_state_smoke','final_case_state_smoke','final_walker_smoke','scene_dialogue_input_smoke','postal_desk_live_queue')) {
        Invoke-TaskGodot $taskSuite @('--script',"res://tests/$taskSuite.gd")
    }
    if ($GpuChecks) {
        foreach ($taskSuite in @('field_observation_smoke','field_book_smoke','mail_workbench_input_smoke','resolution_slip_smoke','final_host_boundary_smoke','final_resolution_draft_smoke')) {
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
