#!/bin/sh
set -eu

# Foxytoux Ubuntu RootFS Launcher (proot)
# Single-file, non-interactive installer & runner

ROOTFS_DIR="$(pwd)"
export PATH="$PATH:$HOME/.local/usr/bin:$PATH"
MAX_RETRIES=50
TIMEOUT=5
ARCH="$(uname -m)"

log() { printf "%s\n" "$*"; }

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log "ERROR: Required command not found: $1"
    exit 1
  fi
}

ensure_group_gid() {
  GID="$1"
  NAME="${2:-hostgrp}"

  mkdir -p "$ROOTFS_DIR/etc"
  [ -f "$ROOTFS_DIR/etc/group" ] || : > "$ROOTFS_DIR/etc/group"

  if grep -qE "^[^:]+:x:${GID}:" "$ROOTFS_DIR/etc/group"; then
    return 0
  fi

  if grep -qE "^${NAME}:" "$ROOTFS_DIR/etc/group"; then
    NAME="${NAME}_${GID}"
  fi

  log "Fix: adding group mapping inside rootfs -> ${NAME}:x:${GID}:"
  printf "%s:x:%s:\n" "$NAME" "$GID" >> "$ROOTFS_DIR/etc/group"
}

# Arch
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT="amd64"
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT="arm64"
else
  log "ERROR: Unsupported CPU architecture: $ARCH"
  exit 1
fi

# Host requirements
require_cmd wget
require_cmd tar
require_cmd chmod

# Install once (no prompts)
if [ ! -e "$ROOTFS_DIR/.installed" ]; then
  log "============================================================"
  log " Foxytoux Ubuntu RootFS Installer (non-interactive)"
  log "============================================================"

  log "Downloading Ubuntu Base rootfs (${ARCH_ALT})..."
  wget --tries="$MAX_RETRIES" --timeout="$TIMEOUT" --no-hsts \
    -O /tmp/rootfs.tar.gz \
    "http://cdimage.ubuntu.com/ubuntu-base/releases/25.04/release/ubuntu-base-25.04-base-${ARCH_ALT}.tar.gz"

  log "Extracting root filesystem..."
  mkdir -p "$ROOTFS_DIR"
  tar -xzf /tmp/rootfs.tar.gz -C "$ROOTFS_DIR"
  rm -f /tmp/rootfs.tar.gz

  # Ensure /usr/bin/sh exists
  if [ ! -e "$ROOTFS_DIR/usr/bin/sh" ]; then
    mkdir -p "$ROOTFS_DIR/usr/bin"
    ln -sf /bin/sh "$ROOTFS_DIR/usr/bin/sh"
  fi

  # Download proot
  if [ ! -e "$ROOTFS_DIR/usr/local/bin/proot" ]; then
    log "Downloading proot binary (${ARCH})..."
    mkdir -p "$ROOTFS_DIR/usr/local/bin"
    wget --tries="$MAX_RETRIES" --timeout="$TIMEOUT" --no-hsts \
      -O "$ROOTFS_DIR/usr/local/bin/proot" \
      "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"
    chmod 755 "$ROOTFS_DIR/usr/local/bin/proot"
  fi

  # DNS
  mkdir -p "$ROOTFS_DIR/etc"
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" > "$ROOTFS_DIR/etc/resolv.conf"

  touch "$ROOTFS_DIR/.installed"
fi

clear
# Banner (plain)
log "___________________________________________________"
log ""
log "           -----> Mission Completed ! <----"
log ""

# Fix 'groups: cannot find name for group ID 997'
ensure_group_gid 997 hostgrp

# Select shell
if [ -x "$ROOTFS_DIR/bin/bash" ]; then
  ROOT_SHELL="/bin/bash"
elif [ -x "$ROOTFS_DIR/bin/sh" ]; then
  ROOT_SHELL="/bin/sh"
else
  log "ERROR: No usable shell found in rootfs."
  log "Expected /bin/bash or /bin/sh to exist."
  exit 1
fi

# Launch
exec "$ROOTFS_DIR/usr/local/bin/proot" \
  --rootfs="$ROOTFS_DIR" \
  -0 \
  -w "/root" \
  -b /dev \
  -b /sys \
  -b /proc \
  -b /etc/resolv.conf:/etc/resolv.conf \
  --kill-on-exit \
  "$ROOT_SHELL"
