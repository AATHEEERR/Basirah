# Deploys Basirah (the API and the web app, one service) to Google Cloud Run,
# within its free tier: the service scales to zero when idle and wakes on the
# first request, with no pinging.
#   powershell -ExecutionPolicy Bypass -File tool\cloud_run_deploy.ps1 -Project <project-id>
#
# Before the first run: `gcloud auth login` (a browser sign-in, done by the
# person), and a billing account on the project (Cloud Run needs one even
# within the free tier).
# The keys are read from server\.env and stored in Secret Manager; nothing
# in this script prints them, and .gcloudignore keeps server\.env out of the
# upload. Build the web app first (tool\build_web_for_deploy.ps1).
param(
  [Parameter(Mandatory = $true)][string]$Project,
  [string]$Region = 'europe-west1',
  [string]$Service = 'basirah'
)
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
Set-Location $root

# gcloud writes its progress to stderr; judge it by its exit code.
function Run([string[]]$cmdArgs) {
  $ErrorActionPreference = 'Continue'
  & gcloud @cmdArgs 2>&1 | ForEach-Object { "$_" }
  $code = $LASTEXITCODE
  $ErrorActionPreference = 'Stop'
  if ($code -ne 0) { throw "gcloud $($cmdArgs[0]) $($cmdArgs[1]) failed ($code)" }
}

# server\.env → a map (KEY=VALUE lines; spaces around = and quotes allowed).
$envFile = Join-Path $root 'server\.env'
if (-not (Test-Path $envFile)) { throw 'server\.env not found: the keys live there' }
$vars = @{}
foreach ($line in Get-Content $envFile) {
  if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*?)\s*$') {
    $v = $Matches[2].Trim('"').Trim("'")
    if ($v -ne '') { $vars[$Matches[1]] = $v }
  }
}
foreach ($k in 'ANTHROPIC_API_KEY', 'SPECIALIST_ACCOUNTS') {
  if (-not $vars.ContainsKey($k)) { throw "$k is missing from server\.env" }
}
if (-not (Test-Path (Join-Path $root 'server\web\index.html'))) { throw 'server\web is empty: run tool\build_web_for_deploy.ps1 first' }

Write-Output "1/5 project $Project"
Run @('config', 'set', 'project', $Project)
Run @('services', 'enable', 'run.googleapis.com', 'cloudbuild.googleapis.com', 'artifactregistry.googleapis.com', 'secretmanager.googleapis.com')

Write-Output '2/5 secrets (values never printed)'
$secrets = @{ 'ANTHROPIC_API_KEY' = 'basirah-anthropic-api-key'; 'SPECIALIST_ACCOUNTS' = 'basirah-specialist-accounts' }
if ($vars.ContainsKey('GEMINI_API_KEY')) { $secrets['GEMINI_API_KEY'] = 'basirah-gemini-api-key' }
$setSecrets = @()
foreach ($k in $secrets.Keys) {
  $name = $secrets[$k]
  $tmp = [IO.Path]::GetTempFileName()
  try {
    # No trailing newline: the value exactly as it is in .env.
    [IO.File]::WriteAllText($tmp, $vars[$k])
    $ErrorActionPreference = 'Continue'
    & gcloud secrets describe $name --project $Project 2>&1 | Out-Null
    $exists = ($LASTEXITCODE -eq 0)
    $ErrorActionPreference = 'Stop'
    if ($exists) { Run @('secrets', 'versions', 'add', $name, "--data-file=$tmp") }
    else { Run @('secrets', 'create', $name, "--data-file=$tmp", '--replication-policy=automatic') }
  } finally { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
  $setSecrets += "$k=${name}:latest"
}

Write-Output '3/5 the service account may read the secrets'
$projectNumber = (& gcloud projects describe $Project --format 'value(projectNumber)' 2>$null)
if (-not $projectNumber) { throw 'could not read the project number' }
$sa = "$projectNumber-compute@developer.gserviceaccount.com"
foreach ($name in $secrets.Values) {
  Run @('secrets', 'add-iam-policy-binding', $name, "--member=serviceAccount:$sa", '--role=roles/secretmanager.secretAccessor', '--quiet')
}

Write-Output '4/5 build and deploy (Cloud Build compiles the server; about 10 minutes)'
# The non-secret settings, as in render.yaml. The metrics seed carries the
# counts gathered on the temporary link (once; the file is anonymous).
$envVars = @(
  'AI_PROVIDER=claude',
  'CLAUDE_MODEL=claude-sonnet-5-5',
  'CLAUDE_EFFORT=medium',
  'CLAUDE_FALLBACKS=default',
  'GEMINI_MODEL=gemini-3.8-flash,gemini-3.7-flash,gemini-3.6-flash,gemini-3.5-flash,gemini-3-flash-preview,gemini-3.5-flash-lite,gemini-3.1-flash-lite,gemini-3.1-flash-lite-preview',
  'ALLOWED_ORIGIN=*',
  'METRICS_SEED=/app/seed/metrics.jsonl'
) -join '|'
# «^|^» once at the front tells gcloud the items are separated by «|»
# (the model lists hold commas).
Run @('run', 'deploy', $Service,
  '--quiet',
  '--source', '.',
  '--region', $Region,
  '--platform', 'managed',
  '--allow-unauthenticated',
  '--memory', '1Gi',
  '--cpu', '1',
  '--timeout', '120',
  '--concurrency', '20',
  '--min-instances', '0',
  '--max-instances', '3',
  "--set-env-vars=^|^" + $envVars,
  "--set-secrets=$($setSecrets -join ',')")

Write-Output '5/5 the link'
$url = (& gcloud run services describe $Service --region $Region --format 'value(status.url)' 2>$null)
Write-Output "Basirah is at: $url"
Write-Output "Specialists' panel: $url/#/specialist (username and password from server\specialist_accounts.local.txt)"
