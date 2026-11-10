param(
 [Parameter(Mandatory=$true)][string]$GodotPath,
 [Parameter(Mandatory=$true)][string]$OutputDirectory,
 [string]$MainPack
)
$ErrorActionPreference='Stop'
$taskRepo=Split-Path -Parent $PSScriptRoot
$taskOut=[IO.Path]::GetFullPath($OutputDirectory)
$taskGodot=(Resolve-Path -LiteralPath $GodotPath).Path
$taskPriorAppData=$env:APPDATA
$taskPriorLocalAppData=$env:LOCALAPPDATA
$taskRunId=Get-Date -Format yyyyMMdd-HHmmss
New-Item -ItemType Directory -Force "$taskOut/empty-runtime","$taskOut/AppData","$taskOut/LocalAppData" | Out-Null
$env:APPDATA="$taskOut/AppData"
$env:LOCALAPPDATA="$taskOut/LocalAppData"
try {
 foreach ($taskSuite in @('exploration_photo_20261110','exploration_recorder_20261110','exploration_navigation_20261110','host_photo_capture_close_20261108')) {
  $taskLog="$taskOut/$taskSuite.log"
  $taskArgs=@('--position=-12000,-12000','--rendering-driver','opengl3','--audio-driver','Dummy','--log-file',$taskLog)
  if ($MainPack) { $taskArgs+=@('--path',"$taskOut/empty-runtime",'--main-pack',(Resolve-Path -LiteralPath $MainPack).Path,'--script',"$taskRepo/tests/$taskSuite.gd") }
  else { $taskArgs+=@('--path',$taskRepo,'--script',"res://tests/$taskSuite.gd") }
  $taskArgs+=@('--',"--qa-out=$taskOut/$taskSuite","--final-save=user://qa/$taskRunId/$taskSuite/save.json")
  $taskQuoted=($taskArgs | ForEach-Object {'"'+$_.Replace('"','\"')+'"'}) -join ' '
  $taskProcess=Start-Process -FilePath $taskGodot -ArgumentList $taskQuoted -WindowStyle Hidden -PassThru
  $taskTimer=[Diagnostics.Stopwatch]::StartNew()
  while (-not $taskProcess.WaitForExit(1000)) {
   if ($taskTimer.Elapsed.TotalSeconds -gt 180 -or ((Test-Path $taskLog) -and ((Get-Content $taskLog -Raw) -match 'SCRIPT ERROR:|SHADER ERROR:'))) { Stop-Process -Id $taskProcess.Id; throw "$taskSuite timed out or script error; see $taskLog" }
  }
  if ($taskProcess.ExitCode -ne 0) { throw "$taskSuite failed; see $taskLog" }
  $taskReceipt=Get-Content "$taskOut/$taskSuite/receipt.json" -Raw | ConvertFrom-Json
  if ($taskReceipt.failures.Count -gt 0) { throw "$taskSuite receipt contains failures" }
  Write-Output "$taskSuite : $($taskReceipt.checks) checks, zero failures"
 }
 Write-Output 'Offscreen GPU / Dummy mixer checks only. Native window and listening acceptance are separate.'
} finally {
 $env:APPDATA=$taskPriorAppData
 $env:LOCALAPPDATA=$taskPriorLocalAppData
}
