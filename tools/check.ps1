param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [string]$PythonPath = 'python',
    [switch]$GpuChecks,
    [switch]$ExternalWindowClose,
    [switch]$EngineWindowClose,
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
$taskGpuOverride = Join-Path $taskRepo 'override.cfg'
$taskGpuOverrideBytes = [Text.Encoding]::UTF8.GetBytes("[display]`nwindow/size/no_focus=true`n")
$taskGpuOverrideOwned = $false
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
        $taskScriptError=(Test-Path -LiteralPath $taskLog) -and ((Get-Content -LiteralPath $taskLog -Raw) -match 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed')
        if ($taskScriptError -or $taskTimer.Elapsed.TotalSeconds -gt 600) {
            # Stop only this harness's launcher and engine carrying its exact log.
            Get-CimInstance Win32_Process -Filter "Name LIKE 'Godot%'" | Where-Object { $_.CommandLine.Contains($taskLog) } | ForEach-Object { Stop-Process -Id $_.ProcessId -ErrorAction SilentlyContinue }
            throw "$Name stopped after script error or 600-second bound; see $taskLog"
        }
    }
    if ((Get-Content -LiteralPath $taskLog -Raw) -match 'SCRIPT ERROR:|SHADER ERROR:|Shader compilation failed') { throw "$Name script/shader error; see $taskLog" }
    if ($taskProcess.ExitCode -ne 0) { throw "$Name failed; see $taskLog" }
}

Push-Location $taskRepo
try {
    if ($GpuChecks -and (Test-Path -LiteralPath $taskGpuOverride)) {
        throw 'GPU QA requires an absent override.cfg; an existing MovieWriter/user override will not be overwritten.'
    }
    & $taskPython tools/studio.py verify
    if ($LASTEXITCODE -ne 0) { throw 'Studio upstream/adapter integrity failed' }
    & $taskPython tools/studio.py status
    if ($LASTEXITCODE -ne 0) { throw 'Studio production structure failed' }
    & $taskPython -m unittest discover -s tests -p 'test_studio_*.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Studio evidence gate regression failed' }
    & $taskPython -m unittest discover -s tests -p 'test_pastel_assets.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Active generated art/export integrity failed' }
    & $taskPython -m unittest discover -s tests -p 'test_video_courier.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Supplied courier frame/transparency/provenance checks failed' }
    & $taskPython -m unittest discover -s tests -p 'test_settings_media.py' -v
    if ($LASTEXITCODE -ne 0) { throw 'Commercial font and water audio integrity failed' }
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
    foreach ($taskSuite in @('preferences_smoke','mail_physics_state_smoke','final_case_state_smoke','final_walker_smoke','scene_dialogue_input_smoke','postal_desk_live_queue','envelope_text_bounds_smoke')) {
        Invoke-TaskGodot $taskSuite @('--script',"res://tests/$taskSuite.gd")
    }
    if ($GpuChecks) {
        # Create the no-focus flag before any GPU root Window exists. Setting
        # root.unfocusable after creation does not revoke its startup focus and
        # a delayed native focus-out can cancel a synthetic down/up pair.
        # CreateNew also rejects an override created by another owner meanwhile.
        $taskOverrideStream = [IO.File]::Open($taskGpuOverride,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
        try {
            $taskGpuOverrideOwned = $true
            $taskOverrideStream.Write($taskGpuOverrideBytes,0,$taskGpuOverrideBytes.Length)
        } finally {
            $taskOverrideStream.Dispose()
        }
        if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($taskGpuOverride)) -cne [Convert]::ToBase64String($taskGpuOverrideBytes)) {
            throw 'Owned GPU QA override bytes do not match the exact startup flag.'
        }
        Write-Host 'GPU fixtures started native FLAG_NO_FOCUS; no OS UI injection. Temporary QA override only; production project.godot is unchanged.'
        foreach ($taskSuite in @('display_preferences_input','pointer_window_focus_input','game_identity_input','coastal_layout_input','settings_art_edges_input','settings_save_failure_input','audio_shutdown_input','notebook_dialogue_input','lemon_matte_render','lemon_press_input','lemon_press_gui_input','lemon_companion_input','coastal_settings_input','coastal_physics_input','water_field_input','water_feedback_input','visible_ripple_input','courier_visual_probe','settings_manipulation_input','field_observation_smoke','field_book_smoke','mail_workbench_input_smoke','tactile_mail_input','resolution_slip_smoke','final_host_boundary_smoke','final_resolution_draft_smoke','counter_onboarding_input','core_review_input')) {
            Invoke-TaskGodot $taskSuite @('--script',"res://tests/$taskSuite.gd",'--resolution','1600x900','--audio-driver','Dummy') -Gpu
        }
        foreach ($taskRoute in @('sealed','delegate')) {
            Invoke-TaskGodot ("five_case_" + $taskRoute) @('--script','res://tests/final_five_case_input.gd','--resolution','1600x900','--audio-driver','Dummy','--',("--route=" + $taskRoute)) -Gpu
        }
        Invoke-TaskGodot 'amended_handoff' @('--script','res://tests/final_amended_handoff_input.gd','--resolution','1600x900','--audio-driver','Dummy') -Gpu
        & (Join-Path $PSScriptRoot 'test_window_close.ps1') -GodotPath $taskGodot -ExternalClose:$ExternalWindowClose -EngineClose:$EngineWindowClose
        Write-Host 'Automated GPU checks completed; not human usability, reference fidelity or listening approval.'
    } else {
        Write-Host 'Headless checks completed. GPU checks were NOT run; use -GpuChecks.'
    }
    Write-Host "Logs and isolated userdata: $taskRun"
} finally {
    try {
        if ($taskGpuOverrideOwned) {
            if (-not (Test-Path -LiteralPath $taskGpuOverride -PathType Leaf)) {
                throw 'Owned GPU QA override disappeared; its cleanup cannot be verified.'
            }
            if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($taskGpuOverride)) -cne [Convert]::ToBase64String($taskGpuOverrideBytes)) {
                throw 'GPU QA override was changed by another owner; refusing to remove unverified bytes.'
            }
            Remove-Item -LiteralPath $taskGpuOverride
            Write-Host 'Exact owned GPU QA override removed before packaging.'
        }
    } finally {
        $env:APPDATA = $taskOldAppData
        $env:LOCALAPPDATA = $taskOldLocalAppData
        $env:SOLMERE_ARCHIVE_ROOT = $taskOldArchiveRoot
        Pop-Location
    }
}
