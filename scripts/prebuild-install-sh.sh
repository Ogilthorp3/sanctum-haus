#!/usr/bin/env bash
# scripts/prebuild-install-sh.sh
# Pulls install.sh + sha256 from the pinned sanctum-family-pass tag so
# pilots always get an immutable, tested version (not HEAD).
# Runs automatically via package.json's prebuild hook.
set -euo pipefail

PIN_TAG="${SANCTUM_INSTALL_PIN_TAG:-v1.0.0-rc1}"
REPO="Ogilthorp3/sanctum-family-pass"
PUBLIC_DIR="$(cd "$(dirname "$0")/.." && pwd)/public"

mkdir -p "$PUBLIC_DIR"

echo "[prebuild] fetching install.sh from $REPO @ $PIN_TAG"
# gh API gets us a private-repo bytes-faithful download. Authenticated via Bert's gh.
gh api "/repos/$REPO/contents/install.sh?ref=$PIN_TAG" --jq '.content' | base64 -D > "$PUBLIC_DIR/install.sh"
gh api "/repos/$REPO/contents/install.sh.sha256?ref=$PIN_TAG" --jq '.content' | base64 -D > "$PUBLIC_DIR/install.sh.sha256"

cd "$PUBLIC_DIR"
shasum -a 256 -c install.sh.sha256 || {
  echo "[prebuild] FATAL: downloaded install.sh does not match its sha256 — aborting build"
  exit 1
}
echo "[prebuild] install.sh ($(wc -c <install.sh) bytes) pinned to $PIN_TAG: $(cat install.sh.sha256 | cut -c1-16)..."
