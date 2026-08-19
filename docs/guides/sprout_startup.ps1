param(
  [switch]$Reset
)

$RepoUrl            = "https://github.com/Child-Focus-NJ/sprout.git"
$RepoDir            = "sprout"
$GoogleClientId     = ""
$GoogleClientSecret = ""
$DockerDesktopPath  = "C:\Program Files\Docker\Docker\Docker Desktop.exe"
$WslDistro          = "Ubuntu"
$DockerWaitSeconds  = 25

if (-not (Get-Process -Name "Docker Desktop" -ErrorAction SilentlyContinue)) {
  Write-Host "Starting Docker Desktop..." -ForegroundColor Yellow
  if (-not (Test-Path $DockerDesktopPath)) {
    Write-Error "Docker Desktop not found at: $DockerDesktopPath"
    exit 1
  }
  Start-Process $DockerDesktopPath
  Start-Sleep -Seconds $DockerWaitSeconds
}

wsl --set-default $WslDistro | Out-Null

$dockerReady = $false
for ($attempt = 1; $attempt -le 12; $attempt++) {
  wsl -- bash -lc "docker info >/dev/null 2>&1"
  if ($LASTEXITCODE -eq 0) {
    $dockerReady = $true
    break
  }
  Write-Host "Waiting for Docker... ($attempt/12)" -ForegroundColor Yellow
  Start-Sleep -Seconds 5
}

if (-not $dockerReady) {
  Write-Error "Docker daemon is not running. Open Docker Desktop -> Settings -> Resources -> WSL Integration -> enable $WslDistro."
  exit 1
}

$DevDockerArgs = if ($Reset) { "--reset" } else { "" }

$SetupScript = @"
set -e
if [ -d '$RepoDir/.git' ]; then
  echo 'Repository exists. Pulling latest changes...'
  cd '$RepoDir'
  git pull --ff-only
else
  echo 'Cloning repository...'
  git clone '$RepoUrl' '$RepoDir'
  cd '$RepoDir'
fi
printf 'GOOGLE_CLIENT_ID=%s\nGOOGLE_CLIENT_SECRET=%s\n' '$GoogleClientId' '$GoogleClientSecret' > .env
sed -i 's/\r$//' ./bin/dev-docker ./bin/docker-entrypoint-dev 2>/dev/null || true
chmod +x ./bin/dev-docker
echo 'Setup complete.'
"@

Write-Host "Setting up repo in WSL ($WslDistro)..." -ForegroundColor Cyan
($SetupScript -replace "`r`n", "`n") | wsl --cd ~ bash -s
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Building/starting Sprout..." -ForegroundColor Cyan
if ($DevDockerArgs) {
  wsl --cd ~/$RepoDir bash -lc "./bin/dev-docker $DevDockerArgs"
} else {
  wsl --cd ~/$RepoDir bash -lc "./bin/dev-docker"
}