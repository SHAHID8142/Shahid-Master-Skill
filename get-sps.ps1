# One-command SPS bootstrap for Windows: clone/pull repo, then install.
#
# Recommended:
#   irm https://raw.githubusercontent.com/SHAHID8142/Shahid-Personal-SkillSet/main/get-sps.ps1 | iex
#
# With options:
#   & ([scriptblock]::Create((irm https://raw.githubusercontent.com/SHAHID8142/Shahid-Personal-SkillSet/main/get-sps.ps1))) -Yes
#
# Local:
#   powershell -ExecutionPolicy Bypass -File get-sps.ps1 -Yes

param(
    [string]$Agents = "*",
    [switch]$Yes,
    [switch]$Interactive
)

$ErrorActionPreference = "Stop"
$repoUrl = if ($env:SPS_REPO_URL) { $env:SPS_REPO_URL } else { "https://github.com/SHAHID8142/Shahid-Personal-SkillSet.git" }
$repoDir = if ($env:SPS_REPO_DIR) { $env:SPS_REPO_DIR } else { Join-Path $env:USERPROFILE ".sps\src\Shahid-Personal-SkillSet" }
$branch = if ($env:SPS_BRANCH) { $env:SPS_BRANCH } else { "main" }

Write-Host ""
Write-Host "+============================================================+" -ForegroundColor Cyan
Write-Host "|  Shahid Personal SkillSet  -  one-command setup            |" -ForegroundColor Cyan
Write-Host "+============================================================+" -ForegroundColor Cyan
Write-Host ""

function Have($cmd) { [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }

if (-not (Have git)) { Write-Host "git is required." -ForegroundColor Yellow; exit 1 }
if (-not (Have node) -or -not (Have npx)) {
    Write-Host "Node.js + npx are required: https://nodejs.org" -ForegroundColor Yellow
    exit 1
}

New-Item -ItemType Directory -Force -Path (Split-Path $repoDir -Parent) | Out-Null

if (Test-Path (Join-Path $repoDir ".git")) {
    Write-Host "Updating existing clone: $repoDir" -ForegroundColor DarkGray
    git -C $repoDir fetch --prune origin $branch
    git -C $repoDir checkout $branch
    git -C $repoDir pull --ff-only origin $branch
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Fast-forward failed; hard reset to origin/$branch" -ForegroundColor Yellow
        git -C $repoDir reset --hard "origin/$branch"
    }
    Write-Host "[OK] Repo updated" -ForegroundColor Green
} else {
    Write-Host "Cloning: $repoUrl" -ForegroundColor DarkGray
    Write-Host "Into:    $repoDir" -ForegroundColor DarkGray
    if (Test-Path $repoDir) { Remove-Item -Recurse -Force $repoDir }
    git clone --depth 1 --branch $branch $repoUrl $repoDir
    Write-Host "[OK] Repo cloned" -ForegroundColor Green
}

$versionFile = Join-Path $repoDir "skills\sps\VERSION"
$version = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { "unknown" }
Write-Host "SPS version: $version" -ForegroundColor DarkGray
Write-Host ""

$install = Join-Path $repoDir "install.ps1"
$argsList = @()
if ($Agents) { $argsList += @("-Agents", $Agents) }
if ($Yes) { $argsList += "-Yes" }
if ($Interactive) { $argsList += "-Interactive" }

& $install @argsList
exit $LASTEXITCODE
