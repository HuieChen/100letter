param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [Parameter(Mandatory=$true)][string]$PackageDirectory
)
$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
$taskEngine = (Resolve-Path -LiteralPath $GodotPath).Path
$taskPackage = (Resolve-Path -LiteralPath $PackageDirectory).Path
$taskExecutable = Join-Path $taskPackage '100letter.exe'
$taskPack = Join-Path $taskPackage '100letter.pck'
foreach ($taskFile in @($taskExecutable,$taskPack)) {
    if (-not (Test-Path -LiteralPath $taskFile -PathType Leaf)) { throw "Missing package file: $taskFile" }
}
$taskRun = Join-Path $taskRepo ('test-results/verify-package-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $taskRun | Out-Null
$taskOldAppData = $env:APPDATA
$taskOldLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = Join-Path $taskRun 'AppData/Roaming'
$env:LOCALAPPDATA = Join-Path $taskRun 'AppData/Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
function Invoke-PackageProbe {
    param([string]$Name,[string]$Executable,[string[]]$Arguments,[int]$TimeoutMilliseconds=60000)
    $taskQuoted = ($Arguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $taskProcess = Start-Process -FilePath $Executable -ArgumentList $taskQuoted -WorkingDirectory $taskPackage -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRun "$Name.stdout.log") -RedirectStandardError (Join-Path $taskRun "$Name.stderr.log")
    if (-not $taskProcess.WaitForExit($TimeoutMilliseconds)) {
        # Stop only the exact child launched by this bounded verification.
        Stop-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue
        throw "$Name exceeded its bounded verification time."
    }
    $taskProcess.Refresh()
    if ($taskProcess.ExitCode -ne 0) { throw "$Name exited $($taskProcess.ExitCode); see $taskRun" }
    $taskErrorLog = Get-Content -LiteralPath (Join-Path $taskRun "$Name.stderr.log") -Raw
    if ($taskErrorLog -match 'SCRIPT ERROR|Parse Error|Failed loading resource|Cannot open file|Failed to instantiate') {
        throw "$Name reported a runtime/resource error; see $taskRun"
    }
}
try {
    $taskReport = Join-Path $taskRun 'content.json'
    # The release executable intentionally disallows external --script overrides.
    # Inspect actual PCK imports with the matching editor, then boot the real exe.
    Invoke-PackageProbe 'content' $taskEngine @('--headless','--audio-driver','Dummy','--main-pack',$taskPack,'--script',(Join-Path $taskRepo 'tests/packaged_content_smoke.gd'),'--',"--package-report=$taskReport")
    if (-not (Test-Path -LiteralPath $taskReport)) { throw 'PCK inspector did not write its result.' }
    $taskContent = Get-Content -LiteralPath $taskReport -Raw | ConvertFrom-Json
    if ($taskContent.failures.Count -ne 0) { throw 'Packaged resource assertions failed.' }
    Invoke-PackageProbe 'release-gpu-boot' $taskExecutable @('--audio-driver','Dummy','--rendering-driver','opengl3','--position=-12000,-12000','--quit-after','120')
    @{
        executable_sha256=(Get-FileHash -LiteralPath $taskExecutable -Algorithm SHA256).Hash.ToLowerInvariant()
        pck_sha256=(Get-FileHash -LiteralPath $taskPack -Algorithm SHA256).Hash.ToLowerInvariant()
        packaged_content_checks=$taskContent.checks
        packaged_content_failures=$taskContent.failures
        release_gpu_boot_exit=0
        release_frames_requested=120
        scope='Actual PCK decoding using the matching editor inspector, then the official release executable GPU boot. Isolated saves; no source game fallback.'
        limits=@('No full native input playthrough, visual reference acceptance or audio listening is implied.','Review stderr logs separately; Windows root certificate store warnings may occur.')
    } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskRun 'verification.json') -Encoding utf8
    Write-Host "Package verification results: $taskRun"
} finally {
    $env:APPDATA = $taskOldAppData
    $env:LOCALAPPDATA = $taskOldLocalAppData
}
