#!/usr/bin/env bash
#
# build-anonsurf-gui.sh
# Build and install the official ParrotSec AnonSurf 6 GUI (Qt6/QML) from source.
#
# Tested on: MX 25.2 "Infinity" (Debian 13 trixie, amd64, Fluxbox)
# Upstream:  https://gitlab.com/parrotsec/packages/anonsurf  (GPL-2.0)
#
# There is no prebuilt .deb you can download (the GitLab package registry
# requires a sign-in), so this builds the official source instead.
#
# WARNING: installing is harmless, but STARTING AnonSurf routes ALL TCP + DNS
# through Tor and blocks public UDP. Tailscale/SSH die while it runs.
# See README.md before pressing START.
#
set -euo pipefail

UPSTREAM="https://gitlab.com/parrotsec/packages/anonsurf.git"
WORKDIR="${1:-$HOME/anonsurf-build}"
BACKUP_DIR="$HOME/anonsurf-backup-$(date +%Y%m%d-%H%M%S)"

log() { printf '\n\033[1;36m==>\033[0m %s\n' "$*"; }

log "Installing build dependencies (cmake, golang-go, Qt6 QML dev)"
sudo apt-get update
sudo apt-get install -y --no-install-recommends \
    cmake golang-go qt6-declarative-dev fonts-inter

log "Cloning upstream source"
mkdir -p "$WORKDIR"
if [ -d "$WORKDIR/anonsurf/.git" ]; then
    echo "    already cloned, updating"
    git -C "$WORKDIR/anonsurf" fetch --depth 1 origin
    git -C "$WORKDIR/anonsurf" reset --hard origin/HEAD
else
    git clone --depth 1 "$UPSTREAM" "$WORKDIR/anonsurf"
fi
cd "$WORKDIR/anonsurf"

log "Building (Go CLI + Qt6/QML GUI) - slow on old CPUs, be patient"
make build

log "Fixing the unregistered 'anonsurf' desktop category (cosmetic)"
sed -i 's/^Categories=Network;Security;anonsurf;$/Categories=Network;Security;/' \
    gui/org.parrotsec.Anonsurf.desktop

log "Backing up previous AnonSurf files to $BACKUP_DIR"
sudo mkdir -p "$BACKUP_DIR"
sudo cp -a /usr/bin/anonsurf /usr/bin/pandora /etc/init.d/anonsurf \
    /etc/tor/torrc /etc/tor/onion.pac /etc/tor/torrc.orig \
    "$BACKUP_DIR/" 2>/dev/null || true

log "Installing"
sudo make install

log "Enabling the recovery safety service (no-op unless a session was interrupted)"
sudo systemctl daemon-reload
sudo systemctl enable anonsurf-recovery.service

log "Done. Launch it:"
echo "    anonsurf-gui          # or: application menu -> AnonSurf GUI"
echo
echo "Optional: remove the build dependencies to reclaim ~391 MB:"
echo "    sudo apt-get remove --auto-remove cmake golang-go qt6-declarative-dev fonts-inter"
