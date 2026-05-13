#!/usr/bin/env bash
# scripts/prebuild-install-sh.sh
#
# Pulls install.sh + sha256 from the pinned sanctum-family-pass tag.
# Runs automatically via package.json's prebuild hook.
#
# **Fail-soft:** if gh CLI is missing or unauthenticated (Cloudflare Pages
# build environment lacks auth), skip the refresh and let the committed
# copy in public/ ship as-is. The committed copy is the source of truth
# for production deploys; this prebuild is a developer convenience that
# refreshes the copy from the tag during local builds.
#
# To ship a new release: bump SANCTUM_INSTALL_PIN_TAG, run `npm run build`
# locally, commit the refreshed public/install.sh + .sha256, push. The
# Cloudflare deploy then uses the committed bytes.
set -euo pipefail

PIN_TAG="${SANCTUM_INSTALL_PIN_TAG:-v1.0.0-rc1}"
REPO="Ogilthorp3/sanctum-family-pass"
PUBLIC_DIR="$(cd "$(dirname "$0")/.." && pwd)/public"

mkdir -p "$PUBLIC_DIR"

# Skip refresh if gh CLI is missing or unauthenticated (Cloudflare Pages, CI without GH_TOKEN, etc.)
if ! command -v gh >/dev/null 2>&1; then
  echo "[prebuild] gh CLI not installed — keeping committed install.sh; skipping refresh from $PIN_TAG"
  exit 0
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "[prebuild] gh not authenticated — keeping committed install.sh; skipping refresh from $PIN_TAG"
  exit 0
fi

echo "[prebuild] fetching install.sh from $REPO @ $PIN_TAG"
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

if ! gh api "/repos/$REPO/contents/install.sh?ref=$PIN_TAG" --jq '.content' | base64 -D > "$TMP/install.sh"; then
  echo "[prebuild] WARN: failed to fetch install.sh from $PIN_TAG — keeping committed copy"
  exit 0
fi
if ! gh api "/repos/$REPO/contents/install.sh.sha256?ref=$PIN_TAG" --jq '.content' | base64 -D > "$TMP/install.sh.sha256"; then
  echo "[prebuild] WARN: failed to fetch install.sh.sha256 from $PIN_TAG — keeping committed copy"
  exit 0
fi

cd "$TMP"
if ! shasum -a 256 -c install.sh.sha256 >/dev/null 2>&1; then
  echo "[prebuild] WARN: fetched install.sh sha256 mismatch — keeping committed copy"
  exit 0
fi

cp install.sh "$PUBLIC_DIR/install.sh"
cp install.sh.sha256 "$PUBLIC_DIR/install.sh.sha256"
echo "[prebuild] install.sh ($(wc -c <"$PUBLIC_DIR/install.sh") bytes) pinned to $PIN_TAG: $(cut -c1-16 <"$PUBLIC_DIR/install.sh.sha256")..."
