# Builds the web app for the one-link deployment and puts it in server/web,
# where the Dockerfile picks it up. The app calls the API on its own host.
#   powershell -File tool/build_web_for_deploy.ps1      (from the repo root)
$ErrorActionPreference = 'Stop'
flutter build web --release --dart-define=API_BASE=same-origin
if (Test-Path server/web) { Remove-Item -Recurse -Force server/web }
Copy-Item -Recurse build/web server/web
# CanvasKit loads from Google's CDN (the default), so the local copy is not
# shipped.
Remove-Item -Recurse -Force server/web/canvaskit
Write-Output "server/web ready: $((Get-ChildItem -Recurse server/web | Measure-Object -Property Length -Sum).Sum / 1MB) MB"
