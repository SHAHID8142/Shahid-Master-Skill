#!/usr/bin/env bash
# SPS update — update SPS to the latest version on this machine.
# Preserves the original install profile + agents from ~/.sps/install-manifest.env.
#
# Usage:
#   bash scripts/sps-update.sh --check      # check only, no changes
#   bash scripts/sps-update.sh --yes        # update if available (auto)
#   bash scripts/sps-update.sh --force      # reinstall even when up to date (repair)
#   bash scripts/sps-update.sh              # interactive prompt
#
# Exit codes:
#   0 = up to date or updated successfully
#   1 = update available (--check) or update failed
#   2 = offline / cannot reach repo

set -uo pipefail

REPO_URL="${SPS_REPO_URL:-https://github.com/SHAHID8142/Shahid-Personal-SkillSet.git}"
REPO_DIR="${SPS_REPO_DIR:-$HOME/.sps/src/Shahid-Personal-SkillSet}"
BRANCH="${SPS_BRANCH:-main}"
MANIFEST="$HOME/.sps/install-manifest.env"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

MODE="prompt"
for arg in "$@"; do
  case "$arg" in
    --check) MODE="check" ;;
    --yes|-y) MODE="auto" ;;
    --force|-f) MODE="force" ;;
  esac
done

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'
BOLD='\033[1m'; DIM='\033[2m'; NC='\033[0m'
ok()   { echo -e "  ${GREEN}✓${NC} $*"; }
warn() { echo -e "  ${YELLOW}!${NC} $*"; }
bad()  { echo -e "  ${RED}✗${NC} $*"; }

have() { command -v "$1" >/dev/null 2>&1; }

checker() {
  # prefer sibling check script; else repo clone copy; else fallback logic
  local check=""
  for cand in "$ROOT/scripts/check-update.sh" "$REPO_DIR/scripts/check-update.sh"; do
    if [[ -f "$cand" ]]; then check="$cand"; break; fi
  done
  if [[ -n "$check" ]]; then
    bash "$check" "$@"
    return $?
  fi
  # minimal inline check when check-update.sh is absent (older install)
  local raw="https://raw.githubusercontent.com/SHAHID8142/Shahid-Personal-SkillSet/main/skills/sps/VERSION"
  local installed="unknown" latest=""
  [[ -f "$MANIFEST" ]] && installed="$(grep '^SPS_VERSION=' "$MANIFEST" | cut -d= -f2)"
  [[ "$installed" == "" ]] && installed="unknown"
  if have curl; then latest="$(curl -fsSL --max-time 10 "$raw" 2>/dev/null | tr -d '[:space:]')"; fi
  if [[ -z "$latest" ]]; then
    echo "SPS version check: offline (installed $installed)" >&2
    return 2
  fi
  if [[ "$installed" == "$latest" ]]; then
    echo "SPS is up to date (v$installed)"
    return 0
  fi
  echo "SPS update available: v$installed → v$latest"
  return 1
}

echo ""
echo -e "${BOLD}SPS updater${NC}"

if [[ "$MODE" == "check" ]]; then
  checker --force
  exit $?
fi

checker
rc=$?
if [[ $rc -eq 2 ]]; then
  bad "Offline — cannot check for updates. Try later."
  exit 2
fi
if [[ $rc -eq 0 && "$MODE" != "force" ]]; then
  ok "Nothing to do."
  exit 0
fi

if [[ "$MODE" == "prompt" ]]; then
  read -r -p "Update SPS now? [Y/n] " confirm
  case "${confirm:-Y}" in
    n|N|no|NO) echo "Aborted."; exit 0 ;;
  esac
fi

# 1. Get latest source (clone or pull)
if ! have git; then
  bad "git required to update. Install git and retry."
  exit 1
fi
mkdir -p "$(dirname "$REPO_DIR")"
if [[ -d "$REPO_DIR/.git" ]]; then
  echo -e "${DIM}Pulling latest source:${NC} $REPO_DIR"
  git -C "$REPO_DIR" fetch --prune origin "$BRANCH" || { bad "fetch failed"; exit 1; }
  git -C "$REPO_DIR" checkout "$BRANCH" 2>/dev/null || true
  git -C "$REPO_DIR" pull --ff-only origin "$BRANCH" || {
    git -C "$REPO_DIR" reset --hard "origin/$BRANCH" || { bad "pull failed"; exit 1; }
  }
else
  echo -e "${DIM}Cloning source:${NC} $REPO_DIR"
  rm -rf "$REPO_DIR"
  git clone --depth 1 --branch "$BRANCH" "$REPO_URL" "$REPO_DIR" || { bad "clone failed"; exit 1; }
fi
ok "Source updated"

# 2. Reinstall with same choices (single unified install — no profiles)
cd "$REPO_DIR"
VERSION="$(tr -d '[:space:]' < "$REPO_DIR/skills/sps/VERSION" 2>/dev/null || echo "unknown")"
echo -e "${DIM}Installing SPS v${VERSION}…${NC}"
bash ./install.sh --yes
rc=$?
if [[ $rc -ne 0 ]]; then
  bad "Reinstall failed (exit $rc). See ~/.sps/install.log"
  exit 1
fi

# 4. Verify with doctor
echo ""
if [[ -f "$REPO_DIR/scripts/sps-doctor.sh" ]]; then
  bash "$REPO_DIR/scripts/sps-doctor.sh"
fi

echo ""
ok "SPS updated. Restart your agent session so the new skill body loads."
exit 0