#!/usr/bin/env bash
# install.sh - Sanctum Family Pass v1.0 installer
# Hash-pinned 2-step: download, shasum -c, less install.sh, bash install.sh
set -euo pipefail

VERSION="1.0.0"
SANCTUM_HOME="${SANCTUM_HOME:-$HOME/.sanctum}"
SANCTUM_OPT="${SANCTUM_OPT:-/opt/sanctum}"
SANCTUM_REPOS="sanctum-runtime sanctum-screen-time sanctum-cli"
LIMA_VERSION_MIN="2.1"

DRY_RUN=0
SKIP_CONFIRM=0

usage() {
  cat >&2 <<U
Usage: bash install.sh [--dry-run] [--yes]

Sanctum Family Pass v$VERSION installer.

The expected invocation is the two-step pattern:
  curl -fsSLO https://sanctum.haus/install.sh
  curl -fsSLO https://sanctum.haus/install.sh.sha256
  shasum -a 256 -c install.sh.sha256
  less install.sh
  bash install.sh

Options:
  --dry-run   Print every action without executing
  --yes       Skip the confirmation prompt (CI / re-runs)
  -h, --help  Print this help
U
}

while [ $# -gt 0 ]; do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --yes)     SKIP_CONFIRM=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "unknown flag: $1" >&2; usage; exit 2 ;;
  esac
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "  would $*"
  else
    # shellcheck disable=SC2294
    # Callers pass a single command string; eval-as-string is intentional.
    eval "$*"
  fi
}

confirm() {
  local prompt="$1"
  if [ "$SKIP_CONFIRM" -eq 1 ]; then return 0; fi
  read -r -p "$prompt [y/N] " ans
  [ "$ans" = "y" ] || [ "$ans" = "Y" ]
}

log() { printf '[sanctum-install] %s\n' "$*"; }
die() { printf '[sanctum-install] FATAL: %s\n' "$*" >&2; exit 1; }

if [ "$DRY_RUN" -eq 1 ]; then
  echo "=== DRY RUN - no changes will be made ==="
fi

log "Sanctum Family Pass v$VERSION installer"
log "Targets: SANCTUM_HOME=$SANCTUM_HOME  SANCTUM_OPT=$SANCTUM_OPT"
log "Repos:   $SANCTUM_REPOS"
log "What this installer will do:"
cat <<PLAN
  1. Check prerequisites (macOS >=14 arm64, >=16GB RAM, brew, Firewalla reachable)
  2. Install/verify socket_vmnet at /opt/socket_vmnet (root-owned)
  3. Install Lima >=$LIMA_VERSION_MIN via brew
  4. Install /etc/sudoers.d/sanctum-vmnet (one-time sudo)
  5. Clone sanctum-runtime, sanctum-screen-time, sanctum-cli to $SANCTUM_OPT
  6. Generate sops age keypair at ~/.config/sops/age/keys.txt
  7. Write $SANCTUM_HOME/sanctum.yaml stub, open in editor
  8. Boot Lima 'openclaw-staging' VM
  9. Register LaunchAgents
  10. Run 'sanctum self-test' (must pass >=95% probes)
PLAN

if ! confirm "Continue?"; then
  log "Aborted by user."
  exit 0
fi

# --- Step 1: Prereq check ---
log "=== Step 1: Prereq check ==="
osv=$(sw_vers -productVersion)
major=${osv%%.*}
[ "$major" -ge 14 ] || die "macOS $osv too old, need >=14"
log "  macOS $osv [ok]"

arch=$(uname -m)
[ "$arch" = "arm64" ] || die "arch $arch, need arm64 (Apple Silicon)"
log "  Apple Silicon $arch [ok]"

ram_gb=$(( $(sysctl -n hw.memsize) / 1024 / 1024 / 1024 ))
[ "$ram_gb" -ge 16 ] || die "RAM ${ram_gb}GB, need >=16GB"
log "  RAM ${ram_gb}GB [ok]"

command -v brew >/dev/null || die "brew not installed"
log "  brew [ok]"

# (Firewalla reachability checked later - needs sanctum.yaml first)

# --- Step 2: socket_vmnet at /opt/socket_vmnet ---
log "=== Step 2: socket_vmnet ==="
if [ -x /opt/socket_vmnet/bin/socket_vmnet ]; then
  log "  socket_vmnet already installed at /opt/socket_vmnet [ok]"
else
  log "  installing socket_vmnet via brew, copying to /opt/socket_vmnet..."
  run "brew install socket_vmnet"
  run "sudo mkdir -p /opt/socket_vmnet/bin"
  run "sudo cp /opt/homebrew/opt/socket_vmnet/bin/socket_vmnet /opt/socket_vmnet/bin/"
  run "sudo cp /opt/homebrew/opt/socket_vmnet/bin/socket_vmnet_client /opt/socket_vmnet/bin/"
  run "sudo chown -R root:wheel /opt/socket_vmnet"
fi

# Sudoers for Lima
if [ -f /etc/sudoers.d/lima ]; then
  log "  /etc/sudoers.d/lima already present [ok]"
else
  log "  generating Lima sudoers entry"
  run "limactl sudoers > /tmp/lima.sudoers"
  run "sudo install -o root -m 0644 /tmp/lima.sudoers /etc/sudoers.d/lima"
fi

# --- Step 3: Lima ---
log "=== Step 3: Lima ==="
if command -v limactl >/dev/null 2>&1; then
  log "  $(limactl --version 2>&1 | head -1) already installed [ok]"
else
  run "brew install lima"
fi

# --- Step 4: Clone repos ---
log "=== Step 4: Clone repos ==="
run "sudo mkdir -p $SANCTUM_OPT"
run "sudo chown $(whoami):staff $SANCTUM_OPT"
# shellcheck disable=SC2086
# SANCTUM_REPOS is a controlled whitespace-separated list defined near the head of this file.
for repo in $SANCTUM_REPOS; do
  if [ -d "$SANCTUM_OPT/$repo/.git" ]; then
    log "  $repo already present, pulling latest"
    run "git -C $SANCTUM_OPT/$repo pull --ff-only"
  else
    run "git clone https://github.com/Ogilthorp3/$repo.git $SANCTUM_OPT/$repo"
  fi
done

# --- Step 5: sops age keypair ---
log "=== Step 5: sops age keypair ==="
AGE_KEYS="$HOME/.config/sops/age/keys.txt"
if [ -f "$AGE_KEYS" ]; then
  log "  age key already exists at $AGE_KEYS [ok]"
else
  run "mkdir -p $(dirname "$AGE_KEYS")"
  run "age-keygen -o $AGE_KEYS"
  run "chmod 600 $AGE_KEYS"
  log "  !! IMPORTANT: this key is your haushold's sole decryption key for sops secrets."
  log "      Back it up immediately after install with:"
  log "        sanctum keys backup ~/Desktop/sanctum-keys.age"
fi

# --- Step 6: sanctum.yaml stub ---
log "=== Step 6: sanctum.yaml stub ==="
run "mkdir -p $SANCTUM_HOME"
if [ -f "$SANCTUM_HOME/sanctum.yaml" ]; then
  log "  $SANCTUM_HOME/sanctum.yaml already exists, not overwriting"
else
  if [ -f "$SANCTUM_OPT/sanctum-cli/sanctum.yaml.example" ]; then
    run "cp $SANCTUM_OPT/sanctum-cli/sanctum.yaml.example $SANCTUM_HOME/sanctum.yaml"
  elif [ -f "$SANCTUM_OPT/sanctum-screen-time/sanctum.yaml.example" ]; then
    # T1.3 placed sanctum.yaml.example in sanctum-screen-time
    run "cp $SANCTUM_OPT/sanctum-screen-time/sanctum.yaml.example $SANCTUM_HOME/sanctum.yaml"
  else
    log "  no sanctum.yaml.example found in repos - writing minimal stub"
    if [ "$DRY_RUN" -eq 1 ]; then
      echo "  would write sanctum.yaml stub to $SANCTUM_HOME/sanctum.yaml"
    else
      cat > "$SANCTUM_HOME/sanctum.yaml" <<'STUB'
haushold:
  name: "Your Haushold"
  slug: "yourhaushold"
firewalla:
  host: "192.168.1.1"
  bridge_token_keychain_label: "firewalla-bridge-token"
paths:
  sanctum_home: "${HOME}/.sanctum"
  openclaw_home: "${HOME}/.openclaw"
modules: {}
STUB
    fi
  fi
  log "  Stub written to $SANCTUM_HOME/sanctum.yaml. Opening in your \$EDITOR..."
  log "  Fill in Firewalla bridge token (Keychain label) + haushold name + devices."
  if [ "$DRY_RUN" -eq 0 ]; then
    "${EDITOR:-nano}" "$SANCTUM_HOME/sanctum.yaml"
  fi
fi

# --- Step 7: Lima VM ---
log "=== Step 7: Lima VM ==="
LIMA_INSTANCE="${LIMA_INSTANCE:-openclaw-staging}"
LIMA_READY=0
if LIMA_HOME="$HOME/.lima" limactl list "$LIMA_INSTANCE" >/dev/null 2>&1; then
  log "  Lima instance '$LIMA_INSTANCE' already exists"
  LIMA_READY=1
else
  if [ -f "$SANCTUM_OPT/sanctum-runtime/lima/openclaw.yaml" ]; then
    run "LIMA_HOME=$HOME/.lima limactl create --name $LIMA_INSTANCE $SANCTUM_OPT/sanctum-runtime/lima/openclaw.yaml"
    LIMA_READY=1
  else
    log "  WARN: no sanctum-runtime/lima/openclaw.yaml found - Lima VM creation skipped"
    log "        (T3.4 ships the canonical Lima config; complete that first or copy your own openclaw.yaml here)"
  fi
fi
if [ "$LIMA_READY" -eq 1 ]; then
  run "LIMA_HOME=$HOME/.lima limactl start $LIMA_INSTANCE --tty=false"
else
  log "  Lima start skipped because instance was not created."
fi

# --- Step 8: LaunchAgents (pilot subset only, with path rewrite) ---
log "=== Step 8: LaunchAgents ==="
PILOT_LA_DIR="$SANCTUM_OPT/sanctum-runtime/launchagents/pilot"
if [ -d "$PILOT_LA_DIR" ]; then
  for plist in "$PILOT_LA_DIR"/com.sanctum.*.plist; do
    [ -e "$plist" ] || continue
    label=$(basename "$plist" .plist)
    target_path="$HOME/Library/LaunchAgents/$label.plist"
    # Rewrite hardcoded /Users/bert/ paths to current $HOME at install time.
    # Source plists in sanctum-runtime/launchagents/pilot/ are author-side templates
    # and intentionally carry the canonical /Users/bert/ prefix so the rewrite is mechanical.
    run "sed 's|/Users/bert/|$HOME/|g' $plist > $target_path"
    run "launchctl bootstrap gui/$(id -u) $target_path || true"
  done
else
  log "  WARN: $PILOT_LA_DIR not found - skipping LaunchAgent registration"
  log "        (Expected: sanctum-runtime/launchagents/pilot/ should ship 7 plists)"
fi

# --- Step 9: self-test (launch gate) ---
log "=== Step 9: self-test (launch gate) ==="
log "  Running 'sanctum self-test' as the hard install gate..."
export PATH="$SANCTUM_OPT/sanctum-cli/bin:$PATH"
if [ "$DRY_RUN" -eq 0 ]; then
  if sanctum self-test; then
    log "  [ok] Install verified by self-test."
    log ""
    log "Sanctum Family Pass v$VERSION is ready."
    log "   Next: sanctum keys backup ~/Desktop/sanctum-keys.age   <- do this NOW"
    log "         sanctum status                                   <- daily health check"
  else
    log "  [FAIL] Self-test failed. Sanctum is partially installed; see output above."
    log "  Common fixes: re-run 'sanctum doctor', check $SANCTUM_HOME/sanctum.yaml,"
    log "                verify Firewalla bridge token via 'security find-generic-password -s firewalla-bridge-token'"
    exit 1
  fi
else
  log "  (dry-run - would run sanctum self-test)"
fi
