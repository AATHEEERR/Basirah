# Runs Basirah live on this machine: builds the web app, starts the server
# (the site and the AI on port 8080) and opens a public Cloudflare link.
#   powershell -ExecutionPolicy Bypass -File tool/start_live.ps1
#   powershell -ExecutionPolicy Bypass -File tool/start_live.ps1 -SkipBuild
# Keep the two windows it opens running: closing them stops the link.
# The link changes each time this script runs.
param([switch]$SkipBuild)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  if (Test-Path 'C:\src\flutter\bin') { $env:Path = "C:\src\flutter\bin;$env:Path" }
  else { throw 'Flutter is not installed: see docs/RESTORE.md (Flutter 3.41.9).' }
}
if (-not (Test-Path "$root\server\.env")) {
  Write-Warning 'server\.env is missing: Basirah will run WITHOUT the AI. Copy it from the backup (secrets\server.env).'
}
if (-not (Test-Path "$root\server\data\quran.json")) {
  Write-Warning 'server\data\quran.json is missing: the server downloads it on first start (a few minutes), or unzip runtime_data.zip from the backup into server\.'
}
Set-Location $root
if (-not $SkipBuild) { & "$root\tool\build_web_for_deploy.ps1" }

# The server, in its own window (site + AI).
Start-Process powershell -WorkingDirectory "$root\server" -ArgumentList '-NoExit', '-Command', '$env:WEB_DIR = ''web''; dart pub get; dart run bin/server.dart'
Write-Output 'Waiting for the server...'
$up = $false
for ($i = 0; $i -lt 90 -and -not $up; $i++) {
  Start-Sleep -Seconds 2
  try { $up = (Invoke-WebRequest -UseBasicParsing -Uri 'http://127.0.0.1:8080/health' -TimeoutSec 3).StatusCode -eq 200 } catch {}
}
if (-not $up) { throw 'The server did not start: read its window for the error.' }

# The public link (Cloudflare quick tunnel, no account needed).
$cf = Join-Path (Split-Path $root -Parent) 'tools\cloudflared.exe'
if (-not (Test-Path $cf)) {
  New-Item -ItemType Directory -Force (Split-Path $cf) | Out-Null
  Write-Output 'Downloading cloudflared (Cloudflare''s official tool)...'
  Invoke-WebRequest -UseBasicParsing 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-amd64.exe' -OutFile $cf
}
$log = Join-Path $env:TEMP 'basirah_tunnel.log'
if (Test-Path $log) { Remove-Item $log -Force }
Start-Process $cf -ArgumentList 'tunnel', '--no-autoupdate', '--url', 'http://localhost:8080' -RedirectStandardError $log -WindowStyle Minimized
$url = $null
for ($i = 0; $i -lt 30 -and -not $url; $i++) {
  Start-Sleep -Seconds 2
  if (Test-Path $log) { $url = (Select-String -Path $log -Pattern 'https://[a-z0-9-]+\.trycloudflare\.com' -AllMatches | Select-Object -First 1).Matches.Value }
}
if ($url) { Write-Output "`nBasirah is live: $url`n" } else { Write-Warning "No link yet: see $log" }
