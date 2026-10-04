# Full backup of Basirah: everything needed to restore it after damage, or
# to run it on another machine (see docs/RESTORE.md).
#   powershell -ExecutionPolicy Bypass -File tool/backup.ps1
#   powershell -ExecutionPolicy Bypass -File tool/backup.ps1 -Out D:\Backups\Basirah
#
# The backup folder holds:
#   basirah.bundle        the git repository with its whole history
#   basirah_files.zip     the project files as they are now (uncommitted work too)
#   runtime_data.zip      server/data (the Quran dataset) and server/cache
#                         (tafsir, hadith, audio links, answers, usage statistics)
#   secrets/server.env    the AI keys: keep private, never upload or share
#   project_documents.zip the challenge files, decks, descriptions and images
#   tools/cloudflared.exe the public-link tool, if present
#   RESTORE.md, SHA256SUMS.txt
param([string]$Out)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$root = Split-Path $PSScriptRoot -Parent       # ...\basirah
$project = Split-Path $root -Parent            # ...\IslamicAI
$stamp = Get-Date -Format 'yyyy-MM-dd_HHmm'
if (-not $Out) { $Out = Join-Path $project "backups\Basirah_Backup_$stamp" }
New-Item -ItemType Directory -Force $Out | Out-Null
$stage = Join-Path $env:TEMP "basirah_backup_stage_$stamp"
if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Force $stage | Out-Null

function Zip([string]$from, [string]$to) {
  if (Test-Path $to) { Remove-Item -Force $to }
  # UTF-8 entry names keep the Arabic file names intact.
  [System.IO.Compression.ZipFile]::CreateFromDirectory($from, $to, [System.IO.Compression.CompressionLevel]::Optimal, $true, [System.Text.Encoding]::UTF8)
}
function Copy-Tree([string]$from, [string]$to, [string[]]$excludeDirs, [string[]]$excludeFiles) {
  $rcArgs = @($from, $to, '/E', '/NFL', '/NDL', '/NJH', '/NJS', '/NP')
  if ($excludeDirs) { $rcArgs += '/XD'; $rcArgs += $excludeDirs }
  if ($excludeFiles) { $rcArgs += '/XF'; $rcArgs += $excludeFiles }
  & robocopy @rcArgs | Out-Null
  if ($LASTEXITCODE -ge 8) { throw "robocopy failed ($LASTEXITCODE) for $from" }
}

Set-Location $root
$dirty = git status --porcelain
if ($dirty) { Write-Warning 'There are uncommitted changes: they are in basirah_files.zip but not in basirah.bundle.' }

Write-Output '1/6 git history...'
# git writes progress to stderr, which Windows PowerShell 5.1 would treat as
# an error under 'Stop': judge git by its exit code instead.
$ErrorActionPreference = 'Continue'
git bundle create "$Out\basirah.bundle" --all 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'git bundle create failed' }
git bundle verify "$Out\basirah.bundle" 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { throw 'git bundle verify failed' }
$ErrorActionPreference = 'Stop'

Write-Output '2/6 project files...'
Copy-Tree $root "$stage\basirah" @("$root\build", "$root\.dart_tool", "$root\.git", "$root\server\.dart_tool", "$root\server\cache", "$root\server\data", "$root\packages\basirah_core\.dart_tool", "$root\.idea") @('.env')
Zip "$stage\basirah" "$Out\basirah_files.zip"

Write-Output '3/6 runtime data...'
New-Item -ItemType Directory -Force "$stage\runtime" | Out-Null
foreach ($d in 'data', 'cache') { if (Test-Path "$root\server\$d") { Copy-Tree "$root\server\$d" "$stage\runtime\$d" @() @() } }
Zip "$stage\runtime" "$Out\runtime_data.zip"

Write-Output '4/6 secrets...'
New-Item -ItemType Directory -Force "$Out\secrets" | Out-Null
if (Test-Path "$root\server\.env") { Copy-Item "$root\server\.env" "$Out\secrets\server.env" -Force }
Set-Content -Encoding utf8 "$Out\secrets\README.txt" @'
server.env holds the AI keys (Claude, Gemini). Keep it private: never upload it to GitHub,
never send it in a chat, never share the backup folder with it inside.
To restore: copy it to basirah\server\.env
'@

Write-Output '5/6 project documents...'
Copy-Tree $project "$stage\documents" @("$project\basirah", "$project\backups", "$project\tools") @()
Zip "$stage\documents" "$Out\project_documents.zip"

Write-Output '6/6 tools, guide, checksums...'
$cf = Join-Path $project 'tools\cloudflared.exe'
if (Test-Path $cf) { New-Item -ItemType Directory -Force "$Out\tools" | Out-Null; Copy-Item $cf "$Out\tools\" -Force }
Copy-Item "$root\docs\RESTORE.md" "$Out\RESTORE.md" -Force
Remove-Item -Recurse -Force $stage
$sums = Get-ChildItem -Recurse -File $Out | Where-Object { $_.Name -ne 'SHA256SUMS.txt' } | ForEach-Object {
  "$((Get-FileHash -Algorithm SHA256 $_.FullName).Hash)  $($_.FullName.Substring($Out.Length + 1))"
}
Set-Content -Encoding utf8 "$Out\SHA256SUMS.txt" $sums

$head = git rev-parse --short HEAD
$size = [math]::Round(((Get-ChildItem -Recurse -File $Out | Measure-Object -Property Length -Sum).Sum / 1MB), 1)
Write-Output "`nBackup ready: $Out ($size MB), git HEAD $head"
