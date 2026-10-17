param([Parameter(Mandatory=$true)][string]$GodotPath,[switch]$ExternalClose,[switch]$EngineClose)
$ErrorActionPreference='Stop'
if($ExternalClose -and $EngineClose){throw 'External native input and supplemental engine-close modes are mutually exclusive.'}
$taskRepo=Split-Path -Parent $PSScriptRoot
$taskEngine=(Resolve-Path -LiteralPath $GodotPath).Path
# The official Windows console launcher creates a separate GUI child. For this
# exact HWND/PID ownership probe launch the matching GUI binary directly; keep
# the ownership guard intact instead of accepting a different process ID.
if ([IO.Path]::GetFileName($taskEngine) -like '*_console.exe') {
 $taskGui=Join-Path ([IO.Path]::GetDirectoryName($taskEngine)) ([IO.Path]::GetFileName($taskEngine).Replace('_console.exe','.exe'))
 if(-not (Test-Path -LiteralPath $taskGui -PathType Leaf)){throw 'Matching Godot GUI executable is required for the exact window-close probe.'}
 $taskEngine=(Resolve-Path -LiteralPath $taskGui).Path
}
$taskRun=Join-Path $taskRepo ('test-results/window-close-'+(Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $taskRun | Out-Null
$taskOldAppData=$env:APPDATA
$taskOldLocalAppData=$env:LOCALAPPDATA
$env:APPDATA=Join-Path $taskRun 'AppData/Roaming'
$env:LOCALAPPDATA=Join-Path $taskRun 'AppData/Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
$taskReady=Join-Path $taskRun 'ready.json'
$taskResult=Join-Path $taskRun 'reload.json'
$taskSave=Join-Path $taskRun 'isolated-state.json'
$taskProcess=$null
if (-not $EngineClose -and -not ('SolmereCloseProbe' -as [type])) {
 Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class SolmereCloseProbe {
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
 [DllImport("user32.dll", SetLastError=true)] public static extern bool PostMessage(IntPtr hwnd, uint message, IntPtr wParam, IntPtr lParam);
}
'@
}
function Start-CloseProbe {
 param([string]$Name,[string[]]$ProbeArguments)
 $taskQuoted=($ProbeArguments | ForEach-Object {'"'+$_.Replace('"','\"')+'"'}) -join ' '
 return Start-Process -FilePath $taskEngine -ArgumentList $taskQuoted -WindowStyle Hidden -PassThru -RedirectStandardOutput (Join-Path $taskRun "$Name.stdout.log") -RedirectStandardError (Join-Path $taskRun "$Name.stderr.log")
}
try {
 $taskCommon=@('--path',$taskRepo,'--script','res://tests/final_window_close_input.gd','--audio-driver','Dummy')
 $taskUser=@('--',"--close-ready=$taskReady","--close-report=$taskResult","--final-save=$taskSave")
 $taskPosition=if($ExternalClose){'--position=120,80'}else{'--position=-12000,-12000'}
 if($ExternalClose){$taskUser+=@('--external-close')}
 if($EngineClose){$taskUser+=@('--engine-close')}
 $taskProcess=Start-CloseProbe 'input' (@('--rendering-driver','opengl3',$taskPosition,'--resolution','1600x900','--verbose')+$taskCommon+$taskUser)
 $taskDeadline=(Get-Date).AddSeconds(75)
 while (-not (Test-Path -LiteralPath $taskReady)) {
  $taskProcess.Refresh()
  if($taskProcess.HasExited){throw "Input process exited before WM_CLOSE readiness: $($taskProcess.ExitCode)"}
  if((Get-Date) -gt $taskDeadline){throw 'Input process did not reach close-ready state.'}
  Start-Sleep -Milliseconds 100
 }
 $taskBefore=Get-Content -LiteralPath $taskReady -Raw | ConvertFrom-Json
 if($taskBefore.failures.Count -ne 0){throw 'Input preparation reported failed assertions.'}
 $taskProcess.Refresh()
 $taskWindow=[IntPtr]([int64]$taskBefore.window_handle)
 Write-Host "Ready child=$($taskProcess.Id), engine=$($taskBefore.engine_pid), server=$($taskBefore.display_server), HWND=$taskWindow"
 if($EngineClose){
  if($taskBefore.engine_pid -ne $taskProcess.Id){throw 'Engine-generated fixture readiness does not belong to the exact launched process.'}
  if($taskBefore.close_method -ne 'engine-generated close notification (supplemental; no OS/native input)'){throw 'Fixture did not select the explicitly requested supplemental engine-close route.'}
  Write-Host 'Supplemental engine-generated notification; shell sends no OS/native UI input and performs no HWND ownership query.'
 } else {
  [uint32]$taskWindowOwner=0
  [void][SolmereCloseProbe]::GetWindowThreadProcessId($taskWindow,[ref]$taskWindowOwner)
  if($taskWindow -eq [IntPtr]::Zero -or $taskWindowOwner -ne $taskProcess.Id -or $taskBefore.engine_pid -ne $taskProcess.Id){throw 'No verified HWND belongs to the exact test child; no window message sent.'}
  if($ExternalClose){Write-Host 'External native X-click required now; the harness sends no UI input.'}
  elseif(-not [SolmereCloseProbe]::PostMessage($taskWindow,0x0010,[IntPtr]::Zero,[IntPtr]::Zero)){throw 'WM_CLOSE could not be posted to the verified test window.'}
 }
 $taskCloseDeadline=(Get-Date).AddSeconds($(if($ExternalClose){120}else{20}))
 while(-not $taskProcess.WaitForExit(1000)){
  if((Get-Date) -gt $taskCloseDeadline){throw 'The test process did not close after its checkpoint within the bounded wait.'}
 }
 $taskProcess.Refresh()
 if($taskProcess.ExitCode -ne 0){throw "Window-close child exited $($taskProcess.ExitCode)"}
 $taskInputExit=$taskProcess.ExitCode
 $taskProcess=Start-CloseProbe 'reload' (@('--headless')+$taskCommon+$taskUser+@('--close-mode=verify'))
 if(-not $taskProcess.WaitForExit(30000)){throw 'Fresh-process reload timed out.'}
 $taskProcess.Refresh()
 if($taskProcess.ExitCode -ne 0){throw "Reload verification failed: $($taskProcess.ExitCode)"}
 $taskAfter=Get-Content -LiteralPath $taskResult -Raw | ConvertFrom-Json
 if($taskAfter.failures.Count -ne 0){throw 'Reload assertions failed.'}
 @{
  scope=$(if($EngineClose){'Supplemental routed input in an isolated GPU child, then deferred engine-generated close notification through the actual host save/audio-drain path, then fresh-process reload; no OS title-bar/native input or shell UI actuation.'}elseif($ExternalClose){'Actual isolated GPU input, external native title-bar X click to the verified child window, then fresh-process reload; the shell issued no UI input.'}else{'Actual input in an isolated GPU child, then Win32 WM_CLOSE to that exact PID-owned HWND, then fresh-process reload.'})
  close_method=$taskBefore.close_method
  input_checks=$taskBefore.checks;reload_checks=$taskAfter.checks
  input_events=$taskBefore.input_events.Count;failures=@()
  child_exit=$taskInputExit;reload_exit=$taskProcess.ExitCode
  warning='Automated input is not independent human usability, audio listening or art acceptance. See retained stderr logs.'
 } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath (Join-Path $taskRun 'report.json') -Encoding utf8
 Write-Host "Window-close integration verified: $taskRun"
} finally {
 # On failure stop only the child created by this script, never another window.
 if($null -ne $taskProcess){$taskProcess.Refresh();if(-not $taskProcess.HasExited){Stop-Process -Id $taskProcess.Id -ErrorAction SilentlyContinue}}
 $env:APPDATA=$taskOldAppData
 $env:LOCALAPPDATA=$taskOldLocalAppData
}
