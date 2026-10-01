param(
    [Parameter(Mandatory=$true)][string]$GodotPath,
    [Parameter(Mandatory=$true)][string]$TemplatePath,
    [string]$OutputDirectory
)
$ErrorActionPreference='Stop'
$repo=Split-Path -Parent $PSScriptRoot
if (-not $OutputDirectory) { $OutputDirectory=Join-Path (Split-Path -Parent $repo) '100letter-Windows' }
$destination=[IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $destination | Out-Null
& $GodotPath --headless --path $repo --editor --import --quit
if ($LASTEXITCODE -ne 0) { throw 'Import failed' }
& $GodotPath --headless --path $repo --export-pack 'Windows Desktop' (Join-Path $destination '100letter.pck')
if ($LASTEXITCODE -ne 0) { throw 'Export failed' }
Copy-Item -LiteralPath $TemplatePath -Destination (Join-Path $destination '100letter.exe')
$licenses=Join-Path $destination 'Licenses'
New-Item -ItemType Directory -Force -Path $licenses | Out-Null
Copy-Item -LiteralPath (Join-Path $repo 'assets/fonts/OFL.txt') -Destination (Join-Path $licenses 'NotoSans-OFL.txt')
Copy-Item -LiteralPath (Join-Path $repo 'assets/fonts/Caveat-OFL.txt') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/GODOT_LICENSE.txt') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/GODOT_COPYRIGHT.txt') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/THIRD_PARTY.md') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/AUDIO_PROVENANCE.md') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/CHARACTER_GENERATION.md') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/GENERATED_ASSETS.md') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/ENVIRONMENT_GENERATION.json') -Destination $licenses
Copy-Item -LiteralPath (Join-Path $repo 'docs/ENVIRONMENT_REFINEMENT.json') -Destination $licenses
$audioLicenses=Join-Path $licenses 'Audio'
New-Item -ItemType Directory -Force -Path $audioLicenses | Out-Null
foreach ($audioRecord in @('sample_manifest.json','source_downloads.json','KENNEY_CC0.txt')) {
    Copy-Item -LiteralPath (Join-Path $repo ('assets/audio/foley/' + $audioRecord)) -Destination $audioLicenses
}
Copy-Item -LiteralPath (Join-Path $repo 'docs/WINDOWS_README.txt') -Destination (Join-Path $destination '开始游玩.txt')
Get-FileHash -Algorithm SHA256 -LiteralPath (Join-Path $destination '100letter.exe'),(Join-Path $destination '100letter.pck') | Format-Table
