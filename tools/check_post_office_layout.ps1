param([Parameter(Mandatory=$true)][string]$GodotPath, [switch]$GameplayRegression)
$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
$taskGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$taskProof = Join-Path $taskRepo 'test-results/post-office-layout-20261019'
$taskOverride = Join-Path $taskRepo 'override.cfg'
$taskOverrideBytes = [Text.Encoding]::UTF8.GetBytes("[display]`nwindow/size/no_focus=true`n")
$taskOwnsOverride = $false
$taskOldAppData = $env:APPDATA
$taskOldLocalAppData = $env:LOCALAPPDATA
New-Item -ItemType Directory -Force -Path $taskProof | Out-Null
$env:APPDATA = Join-Path $taskProof 'AppData/Roaming'
$env:LOCALAPPDATA = Join-Path $taskProof 'AppData/Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null

function Invoke-LayoutEngine {
    param([string]$Name, [string[]]$EngineArguments)
    $taskLog = Join-Path $taskProof ($Name + '.log')
    $taskArguments = @('--path',$taskRepo,'--log-file',$taskLog) + $EngineArguments
    $taskQuoted = ($taskArguments | ForEach-Object { '"' + $_ + '"' }) -join ' '
    $taskProcess = Start-Process -FilePath $taskGodot -ArgumentList $taskQuoted -WindowStyle Hidden -PassThru
    $taskTimer = [Diagnostics.Stopwatch]::StartNew()
    while (-not $taskProcess.WaitForExit(1000)) {
        $taskErrors = (Test-Path -LiteralPath $taskLog) -and ((Get-Content -LiteralPath $taskLog -Raw) -match '(?m)SCRIPT ERROR:|SHADER ERROR:|^ERROR:')
        if ($taskErrors -or $taskTimer.Elapsed.TotalSeconds -gt 600) {
            Stop-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
            throw "$Name failed or timed out; see $taskLog"
        }
    }
    $taskOutput = Get-Content -LiteralPath $taskLog -Raw
    if ($taskProcess.ExitCode -ne 0 -or $taskOutput -match '(?m)SCRIPT ERROR:|SHADER ERROR:|^ERROR:' ) {
        throw "$Name failed; see $taskLog"
    }
    Write-Output $taskOutput
}

try {
    if (Test-Path -LiteralPath $taskOverride) { throw 'An existing override.cfg will not be overwritten.' }
    Invoke-LayoutEngine 'isolated-import' @('--headless','--editor','--import','--quit')
    $taskStream = [IO.File]::Open($taskOverride,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
    try {
        $taskOwnsOverride = $true
        $taskStream.Write($taskOverrideBytes,0,$taskOverrideBytes.Length)
    } finally { $taskStream.Dispose() }
    if ($GameplayRegression) {
        foreach ($taskSuite in @('counter_onboarding_input','core_review_input','final_host_boundary_smoke','settings_effects_input')) {
            Invoke-LayoutEngine $taskSuite @('--rendering-driver','opengl3','--position=-12000,-12000','--resolution','1600x900','--audio-driver','Dummy','--script',"res://tests/$taskSuite.gd")
        }
        foreach ($taskRoute in @('sealed','delegate')) {
            Invoke-LayoutEngine ("route-" + $taskRoute) @('--rendering-driver','opengl3','--position=-12000,-12000','--resolution','1600x900','--audio-driver','Dummy','--script','res://tests/final_five_case_input.gd','--',("--route=" + $taskRoute))
        }
    } else {
        Invoke-LayoutEngine 'input' @('--rendering-driver','opengl3','--position=-12000,-12000','--resolution','1920x1080','--audio-driver','Dummy','--script','res://tests/post_office_layout_input.gd')
        Invoke-LayoutEngine 'opening' @('--rendering-driver','opengl3','--position=-12000,-12000','--resolution','1920x1080','--audio-driver','Dummy','--script','res://tests/post_office_opening_input.gd')
    }
} finally {
    try {
        if ($taskOwnsOverride) {
            if (-not (Test-Path -LiteralPath $taskOverride)) { throw 'Owned QA override disappeared.' }
            if ([Convert]::ToBase64String([IO.File]::ReadAllBytes($taskOverride)) -cne [Convert]::ToBase64String($taskOverrideBytes)) {
                throw 'QA override changed; refusing to remove unknown bytes.'
            }
            Remove-Item -LiteralPath $taskOverride
        }
    } finally {
        $env:APPDATA = $taskOldAppData
        $env:LOCALAPPDATA = $taskOldLocalAppData
    }
}
