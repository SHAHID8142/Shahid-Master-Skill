#!/usr/bin/env bash
# SPS check-update — compare installed version against the latest release.
# Offline-safe: cached 24h in ~/.sps/update-state.env; --force bypasses cache.
#
# Usage:
#   bash scripts/check-update.sh            # cached check (24h TTL)
#   bash scripts/check-update.sh --force    # fresh network check
#
# Exit codes:
#   0 = up to date
#   1 = update available
#   2 = offline / cannot check (non-fatal)

set -uo pipefail

RAW_VERSION_URL="https://raw.githubusercontent.com/SHAHID8142/Shahid-Personal-SkillSet/main/skills/sps/VERSION"
STATE_FILE="$HOME/.sps/update-state.env"
TTL_SECONDS=86400
FORCE=false

for arg in "$@"; do
  [[ "$arg" == "--force" || "$arg" == "-f" ]] && FORCE=true
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'
DIM='\033[2m'; BOLD='\033[1m'; NC='\033[0m'

installed_version() {
  local manifest="$HOME/.sps/install-manifest.env"
  if [[ -f "$manifest" ]]; then
    local v
    v="$(grep '^SPS_VERSION=' "$manifest" | head -1 | cut -d= -f2)"
    [[ -n "$v" ]] && { echo "$v"; return; }
  fi
  local cand
  for cand in "$HOME/.sps/src/Shahid-Personal-SkillSet/skills/sps/VERSION" \
              "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." 2>/dev/null && pwd)/skills/sps/VERSION"; do
    if [[ -f "$cand" ]]; then
      tr -d '[:space:]' < "$cand"
      return
    fi
  done
  echo "unknown"
}

is_greater() {
  # returns 0 if a > b (numeric semver compare), 1 otherwise
  local a="${1%%-*}" b="${2%%-*}"
  local ai bi
  IFS='.' read -r -a ai <<< "$a"
  IFS='.' read -r -a bi <<< "$b"
  for i in 0 1 2; do
    local av="${ai[$i]:-0}" bv="${bi[$i]:-0}"
    if (( 10#$av > 10#$bv )); then return 0; fi
    if (( 10#$av < 10#$bv )); then return 1; fi
  done
  return 1
}

INSTALLED="$(installed_version)"

# 1. Cached state fresh enough?
if [[ "$FORCE" != true && -f "$STATE_FILE" ]]; then
  last=""
  last="$(grep '^CHECKED_AT=' "$STATE_FILE" 2>/dev/null | cut -d= -f2)"
  now="$(date +%s)"
  if [[ -n "$last" ]] && (( now - last < TTL_SECONDS )); then
    latest="" status=""
    latest="$(grep '^LATEST=' "$STATE_FILE" 2>/dev/null | cut -d= -f2)"
    status="$(grep '^STATUS=' "$STATE_FILE" 2>/dev/null | cut -d= -f2)"
    [[ -z "$latest" ]] && latest="unknown"
    echo "SPS installed: $INSTALLED | latest: $latest | status: $status (cached)"
    [[ "$status" == "update-available" ]] && exit 1
    [[ "$status" == "offline" ]] && exit 2
    exit 0
  fi
fi

# 2. Fresh check
latest=""
if command -v curl >/dev/null 2>&1; then
  latest="$(curl -fsSL --max-time 10 "$RAW_VERSION_URL" 2>/dev/null | tr -d '[:space:]')"
fi

mkdir -p "$HOME/.sps"
if [[ -z "$latest" || "$latest" == "unknown" ]]; then
  echo "SPS version check: offline (installed $INSTALLED)" >&2
  printf 'CHECKED_AT=%s\nSTATUS=offline\nLATEST=unknown\n' "$(date +%s)" > "$STATE_FILE"
  exit 2
fi

if [[ "$INSTALLED" == "$latest" ]]; then
  echo -e "${GREEN}${BOLD}SPS is up to date${NC} (v${INSTALLED})"
  printf 'CHECKED_AT=%s\nSTATUS=up-to-date\nLATEST=%s\n' "$(date +%s)" "$latest" > "$STATE_FILE"
  exit 0
fi

if is_greater "$INSTALLED" "$latest"; then
  # local install is ahead of remote (dev build) — treat as up to date
  echo -e "${GREEN}${BOLD}SPS is up to date${NC} (local v${INSTALLED} > remote v${latest})"
  printf 'CHECKED_AT=%s\nSTATUS=up-to-date\nLATEST=%s\n' "$(date +%s)" "$latest" > "$STATE_FILE"
  exit 0
fi

echo -e "${YELLOW}${BOLD}SPS update available:${NC} v${INSTALLED} → v${latest}"
echo -e "${DIM}Run: bash scripts/sps-update.sh --yes${NC}"
printf 'CHECKED_AT=%s\nSTATUS=update-available\nLATEST=%s\n' "$(date +%s)" "$latest" > "$STATE_FILE"
exit 1