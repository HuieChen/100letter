param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [Parameter(Mandatory=$true)][string]$TemplatePath,
    [string]$TemplateManifestPath,
    [string]$OutputDirectory,
    [string]$PythonPath = 'python',
    [switch]$GpuChecks,
    [switch]$ArchiveChecks,
    [string]$ArchiveRoot,
    [switch]$SkipChecks
)
$ErrorActionPreference = 'Stop'
$taskRepo = Split-Path -Parent $PSScriptRoot
$taskGodot = (Resolve-Path -LiteralPath $GodotPath).Path
$taskTemplate = (Resolve-Path -LiteralPath $TemplatePath).Path
if (-not $TemplateManifestPath) { $TemplateManifestPath = Join-Path $taskRepo 'work/official_godot_4_7_2/source.json' }
$taskTemplateRecord = Get-Content -LiteralPath $TemplateManifestPath -Raw | ConvertFrom-Json
$taskOfficialArchiveHash = 'f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011'
if ($taskTemplateRecord.metadata_source -ne 'https://api.github.com/repos/godotengine/godot-builds/releases/tags/4.7.2-stable' -or
    $taskTemplateRecord.version -ne '4.7.2.stable' -or
    $taskTemplateRecord.verified_archive_sha256 -ne $taskOfficialArchiveHash) {
    throw 'A SHA-verified official Godot 4.7.2 template manifest is required before packaging.'
}
$taskReleaseRecord = @($taskTemplateRecord.members | Where-Object member -EQ 'templates/windows_release_x86_64.exe')
if ($taskReleaseRecord.Count -ne 1 -or (Get-FileHash -LiteralPath $taskTemplate -Algorithm SHA256).Hash.ToLowerInvariant() -ne $taskReleaseRecord[0].sha256) {
    throw 'Windows release template bytes do not match the extracted, verified official archive.'
}
if (-not $OutputDirectory) { $OutputDirectory = Join-Path (Split-Path -Parent $taskRepo) '100letter-Windows-Faefever-20261002' }
$taskDestination = [IO.Path]::GetFullPath($OutputDirectory)
$taskProject = Get-Content -LiteralPath (Join-Path $taskRepo 'project.godot') -Raw
if ($taskProject -notmatch 'run/main_scene="res://scenes/final_slice.tscn"') {
    throw 'The release entry must be scenes/final_slice.tscn; do not package the old main scene.'
}
& $PythonPath (Join-Path $PSScriptRoot 'refresh_export_selection.py')
if ($LASTEXITCODE -ne 0) { throw 'Adopted runtime asset selection could not be verified.' }
$taskPreset = Get-Content -LiteralPath (Join-Path $taskRepo 'export_presets.cfg') -Raw
if ($taskPreset -notmatch '(?m)^export_filter="resources"\s*$') {
    throw 'Godot selected-resource export must serialize as export_filter="resources".'
}
if (-not $SkipChecks) {
    & (Join-Path $PSScriptRoot 'check.ps1') -GodotPath $taskGodot -PythonPath $PythonPath -GpuChecks:$GpuChecks -ArchiveChecks:$ArchiveChecks -ArchiveRoot $ArchiveRoot
} else {
    Write-Warning 'Automated checks explicitly skipped. This build is not a new validation result.'
}
$taskAuditDirectory = Join-Path $taskRepo ('test-results/package-' + (Get-Date -Format 'yyyyMMdd-HHmmss'))
New-Item -ItemType Directory -Force -Path $taskDestination,$taskAuditDirectory | Out-Null
$taskOldAppData = $env:APPDATA
$taskOldLocalAppData = $env:LOCALAPPDATA
$env:APPDATA = Join-Path $taskAuditDirectory 'AppData/Roaming'
$env:LOCALAPPDATA = Join-Path $taskAuditDirectory 'AppData/Local'
New-Item -ItemType Directory -Force -Path $env:APPDATA,$env:LOCALAPPDATA | Out-Null
function Invoke-BuildGodot {
    param([string]$Name, [string[]]$EngineArguments)
    $taskLog = Join-Path $taskAuditDirectory ($Name + '.log')
    $taskArguments = @('--headless','--path',$taskRepo,'--log-file',$taskLog) + $EngineArguments
    $taskQuoted = ($taskArguments | ForEach-Object { '"' + $_.Replace('"','\"') + '"' }) -join ' '
    $taskProcess = Start-Process -FilePath $taskGodot -ArgumentList $taskQuoted -WindowStyle Hidden -PassThru -Wait
    if ($taskProcess.ExitCode -ne 0) { throw "$Name failed; see $taskLog" }
}
try {
    Invoke-BuildGodot 'import' @('--editor','--import','--quit')
    # Same-preset ZIP inventory is inspectable with the installed .NET runtime.
    $taskAuditZip = Join-Path $taskAuditDirectory 'selected-runtime.zip'
    Invoke-BuildGodot 'export-audit' @('--export-pack','Windows Desktop',$taskAuditZip)
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    $taskZip = [IO.Compression.ZipFile]::OpenRead($taskAuditZip)
    try {
        $taskEntries = @($taskZip.Entries | ForEach-Object { $_.FullName.Replace('\','/') -replace '^res://','' })
    } finally { $taskZip.Dispose() }
    $taskRequired = @(
        'scenes/final_slice.tscn',
        'scripts/rebuild/final_playable.gd','scripts/rebuild/final_case_state.gd',
        'scripts/rebuild/mail_physics_state.gd','scripts/rebuild/field_book.gd',
        'scripts/rebuild/field_observation.gd','scripts/rebuild/resolution_slip.gd',
        'scripts/rebuild/resolution_draft_store.gd',
        'data/rebuild/final_cases.json','data/rebuild/player_amendments.json',
        'scripts/rebuild/physical_art.gd','scripts/rebuild/postal_desk.gd',
        'assets/faefever_v2/manifest.json','assets/faefever_v2/characters/courier_walk_regions.json',
        'data/rebuild/final_dialogues.json',
        'assets/fonts/SolmereSans.ttf','assets/fonts/Caveat.ttf',
        'assets/fonts/OFL.txt','assets/fonts/Caveat-OFL.txt'
    )
    # Every explicitly selected dynamic asset must survive actual export, too.
    $taskSelection = [regex]::Match($taskPreset,'(?m)^export_files=PackedStringArray\((.*)\)$').Groups[1].Value
    $taskRequired += @([regex]::Matches($taskSelection,'"res://([^"]+)"') | ForEach-Object { $_.Groups[1].Value })
    $taskRequired = @($taskRequired | Sort-Object -Unique)
    foreach ($taskPath in $taskRequired) {
        if ($taskPath -notin $taskEntries -and ($taskPath+'.remap') -notin $taskEntries -and ($taskPath+'.import') -notin $taskEntries) {
            throw "Selected export is missing required runtime content: $taskPath"
        }
    }
    $taskForbidden = @($taskEntries | Where-Object {
        $_ -match '^(work|artifacts|specification|docs|tools|tests|test-results|local-data|builds)/' -or
        $_ -match '^assets/(locked_user|display_user|generated|characters|reference_gate)/' -or
        $_ -match '^scripts/reference_gate/' -or $_ -match '^scenes/reference_fidelity_prototype\.tscn' -or
        $_ -match '^assets/generated/(post_office_interior|post_office_counter_integrated_v3)\.png' -or
        $_ -match '^scripts/(main\.gd|core/|rebuild/(post_office_room|title_screen)\.gd)' -or
        $_ -match '^scenes/main\.tscn' -or $_ -eq 'data/game.json' -or $_ -match '\.psd$'
    })
    if ($taskForbidden.Count -gt 0) { throw ('Excluded content entered export: ' + ($taskForbidden -join ', ')) }
    @{
        preset='Windows Desktop'; mode='resources (selected and dependencies)'
        required=$taskRequired; excluded_matches=$taskForbidden
        files=$taskEntries; scope='ZIP inventory with the same preset; not a native executable playtest.'
    } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath (Join-Path $taskAuditDirectory 'export-audit.json') -Encoding utf8
    Invoke-BuildGodot 'export-pck' @('--export-pack','Windows Desktop',(Join-Path $taskDestination '100letter.pck'))
    # The caller supplies the matching release template; no automatic download.
    Copy-Item -LiteralPath $taskTemplate -Destination (Join-Path $taskDestination '100letter.exe')
    Copy-Item -LiteralPath $TemplateManifestPath -Destination (Join-Path $taskDestination 'GODOT_TEMPLATE_SOURCE.json')
    $taskLicenses = Join-Path $taskDestination 'Licenses'
    New-Item -ItemType Directory -Force -Path $taskLicenses | Out-Null
    $taskLicenseSources = @(
        'assets/fonts/OFL.txt','assets/fonts/Caveat-OFL.txt',
        'docs/GODOT_LICENSE.txt','docs/GODOT_COPYRIGHT.txt','docs/THIRD_PARTY.md',
        'docs/AUDIO_PROVENANCE.md',
        'assets/faefever_v2/manifest.json',
        'assets/audio/foley/KENNEY_CC0.txt','assets/audio/foley/sample_manifest.json',
        'assets/audio/foley/source_downloads.json'
    )
    foreach ($taskRecord in $taskLicenseSources) {
        Copy-Item -LiteralPath (Join-Path $taskRepo $taskRecord) -Destination $taskLicenses
    }
    $taskPlayerReadme = @(
        '一百信 · Solmere Post',
        '双击 100letter.exe。新班次从邮局柜台、主管的短交代和实体邮件箱开始。',
        'WASD / 方向键 / 点地面行走；B 信袋，J 档案，M 地图；Esc 暂停，F11 全屏。',
        '松锁扣、点开或掀起箱盖、点击或拖出信件。点击信封右边缘翻面，也支持右键；拉开桌沿抽屉取工具。',
        '交付与记录分开：每封信处理后回柜台填写处置单，复核并亲手拖章。',
        '新版存档位于 Godot 用户目录下 final_v2；旧版进度不被覆盖。',
        '字体、声音、引擎与新生成美术的许可及来源说明见 Licenses。',
        '本地构建不等于参考验收、真人试玩或商业发行审核已经完成。'
    )
    $taskPlayerReadme | Set-Content -LiteralPath (Join-Path $taskDestination '开始游玩.txt') -Encoding utf8
    Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $taskDestination '100letter.exe'),(Join-Path $taskDestination '100letter.pck') | Format-Table
    Write-Host "Selected-resource inventory: $taskAuditDirectory/export-audit.json"
    Write-Host 'Local build created. Native playtest, reference review and GitHub publication remain separate steps.'
} finally {
    $env:APPDATA = $taskOldAppData
    $env:LOCALAPPDATA = $taskOldLocalAppData
}
