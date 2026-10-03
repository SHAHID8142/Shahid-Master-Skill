# SPS check-update (Windows) - compare installed version against the latest release.
# Cached 24h in ~\.sps\update-state.env; -Force bypasses cache.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts\check-update.ps1
#   powershell -ExecutionPolicy Bypass -File scripts\check-update.ps1 -Force
#
# Exit codes:
#   0 = up to date
#   1 = update available
#   2 = offline / cannot check (non-fatal)

param([switch]$Force)

$ErrorActionPreference = "SilentlyContinue"
$rawUrl = "https://raw.githubusercontent.com/SHAHID8142/Shahid-Personal-SkillSet/main/skills/sps/VERSION"
$stateFile = Join-Path $HOME ".sps\update-state.env"
$ttlSeconds = 86400

function Get-InstalledVersion {
    $manifest = Join-Path $HOME ".sps\install-manifest.env"
    if (Test-Path $manifest) {
        $line = Select-String -Path $manifest -Pattern '^SPS_VERSION=' | Select-Object -First 1
        if ($line) { return ($line.Line -split '=')[1].Trim() }
    }
    $cand = Join-Path $HOME ".sps\src\Shahid-Personal-SkillSet\skills\sps\VERSION"
    if (Test-Path $cand) { return (Get-Content $cand -Raw).Trim() }
    return "unknown"
}

$installed = Get-InstalledVersion

# 1. Cached state fresh enough?
if (-not $Force -and (Test-Path $stateFile)) {
    $last = $null; $latest = $null; $status = $null
    foreach ($line in Get-Content $stateFile) {
        $parts = $line -split '=', 2
        if ($parts[0] -eq "CHECKED_AT") { $last = [int64]$parts[1] }
        elseif ($parts[0] -eq "LATEST") { $latest = $parts[1] }
        elseif ($parts[0] -eq "STATUS") { $status = $parts[1] }
    }
    $now = [int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    if ($last -and (($now - $last) -lt $ttlSeconds)) {
        if (-not $latest) { $latest = "unknown" }
        Write-Host "SPS installed: $installed | latest: $latest | status: $status (cached)"
        if ($status -eq "update-available") { exit 1 }
        if ($status -eq "offline") { exit 2 }
        exit 0
    }
}

# 2. Fresh check
$latest = ""
try {
    $latest = (Invoke-WebRequest -Uri $rawUrl -UseBasicParsing -TimeoutSec 10).Content.Trim()
} catch { $latest = "" }

New-Item -ItemType Directory -Force -Path (Split-Path $stateFile) | Out-Null
if (-not $latest -or $latest -eq "unknown") {
    Write-Host "SPS version check: offline (installed $installed)"
    "CHECKED_AT=$([int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`nSTATUS=offline`nLATEST=unknown" | Set-Content $stateFile
    exit 2
}

if ($installed -eq $latest) {
    Write-Host "SPS is up to date (v$installed)" -ForegroundColor Green
    "CHECKED_AT=$([int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`nSTATUS=up-to-date`nLATEST=$latest" | Set-Content $stateFile
    exit 0
}

Write-Host "SPS update available: v$installed -> v$latest" -ForegroundColor Yellow
Write-Host "Run: powershell -ExecutionPolicy Bypass -File scripts\update-sps.ps1 -Yes"
"CHECKED_AT=$([int64][DateTimeOffset]::UtcNow.ToUnixTimeSeconds())`nSTATUS=update-available`nLATEST=$latest" | Set-Content $stateFile
exit 1