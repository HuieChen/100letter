param([Parameter(Mandatory=$true)][string]$GodotPath)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
Push-Location $repo
try {
    & $GodotPath --headless --path $repo --editor --import --quit
    if ($LASTEXITCODE -ne 0) { throw 'Godot import failed' }
    foreach ($suite in @('core_smoke','physical_smoke','attachment_smoke','walker_smoke','daylight_smoke','deduction_smoke','ui_flow_smoke','cohort_smoke')) {
        & $GodotPath --headless --path $repo --script "res://tests/$suite.gd"
        if ($LASTEXITCODE -ne 0) { throw "$suite failed" }
    }
} finally { Pop-Location }
