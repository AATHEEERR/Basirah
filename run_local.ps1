# Runs Basirah locally: the API in a new window, then the app in Chrome.
#   powershell -ExecutionPolicy Bypass -File run_local.ps1
# Put your key in server\.env first (copy server\.env.example). Without a key
# the API still serves curated + offline answers.
$root = $PSScriptRoot
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  if (Test-Path 'C:\src\flutter\bin') { $env:Path = "C:\src\flutter\bin;$env:Path" }
}
if (-not (Test-Path "$root\server\.env")) {
  Write-Host "No server\.env found - the chatbot will run WITHOUT the AI layer." -ForegroundColor Yellow
  Write-Host "Copy server\.env.example to server\.env and set ANTHROPIC_API_KEY to enable it." -ForegroundColor Yellow
}
Start-Process powershell -WorkingDirectory "$root\server" -ArgumentList '-NoExit', '-Command', 'dart pub get; dart run bin/server.dart'
Start-Sleep -Seconds 6
Set-Location $root
flutter run -d chrome --dart-define=API_BASE=http://localhost:8080
