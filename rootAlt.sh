#!/bin/sh

# === Konfigurasi dasar ===
ROOTFS_DIR="$(pwd)"
export PATH="$PATH:$HOME/.local/usr/bin"
max_retries=50
timeout=5
ARCH="$(uname -m)"

# Deteksi arsitektur
if [ "$ARCH" = "x86_64" ]; then
  ARCH_ALT=amd64
elif [ "$ARCH" = "aarch64" ]; then
  ARCH_ALT=arm64
else
  printf "Unsupported CPU architecture: %s\n" "$ARCH"
  exit 1
fi

# === Instalasi pertama kali ===
if [ ! -e "$ROOTFS_DIR/.installed" ]; then
  echo "#######################################################################################"
  echo "#"
  echo "#                                      Foxytoux INSTALLER"
  echo "#"
  echo "#                           Copyright (C) 2024, RecodeStudios.Cloud"
  echo "#"
  echo "#######################################################################################"
  echo

  # Tanya mau install Ubuntu atau tidak
  printf "Do you want to install Ubuntu? (YES/no): "
  read install_ubuntu

  case "$install_ubuntu" in
    [yY][eE][sS]|[yY]|"")
      echo "Downloading Ubuntu rootfs (${ARCH_ALT})..."
      wget --tries="$max_retries" --timeout="$timeout" --no-hsts -O /tmp/rootfs.tar.gz \
        "http://cdimage.ubuntu.com/ubuntu-base/releases/25.04/release/ubuntu-base-25.04-base-${ARCH_ALT}.tar.gz"

      echo "Extracting rootfs..."
      mkdir -p "$ROOTFS_DIR"
      tar -xzf /tmp/rootfs.tar.gz -C "$ROOTFS_DIR"
      rm -f /tmp/rootfs.tar.gz

      # Pastikan /usr/bin/sh ada (symlink ke /bin/sh di dalam rootfs)
      if [ ! -e "$ROOTFS_DIR/usr/bin/sh" ]; then
        mkdir -p "$ROOTFS_DIR/usr/bin"
        ln -sf /bin/sh "$ROOTFS_DIR/usr/bin/sh"
      fi
      ;;
    *)
      echo "Skipping Ubuntu installation."
      ;;
  esac

  # Download proot (kalau belum ada)
  if [ ! -e "$ROOTFS_DIR/usr/local/bin/proot" ]; then
    mkdir -p "$ROOTFS_DIR/usr/local/bin"

    echo "Downloading proot (${ARCH})..."
    wget --tries="$max_retries" --timeout="$timeout" --no-hsts \
      -O "$ROOTFS_DIR/usr/local/bin/proot" \
      "https://raw.githubusercontent.com/foxytouxxx/freeroot/main/proot-${ARCH}"

    chmod 755 "$ROOTFS_DIR/usr/local/bin/proot"
  fi

  # resolv.conf untuk DNS di dalam rootfs
  mkdir -p "$ROOTFS_DIR/etc"
  printf "nameserver 1.1.1.1\nnameserver 1.0.0.1\n" > "$ROOTFS_DIR/etc/resolv.conf"

  # Bersih-bersih
  rm -rf /tmp/rootfs.tar.xz /tmp/sbin 2>/dev/null || true

  # Tanda sudah terinstall
  touch "$ROOTFS_DIR/.installed"
fi

# === Tampilan "Mission Completed" ===
CYAN='\e[0;36m'
WHITE='\e[0;37m'
RESET_COLOR='\e[0m'

display_gg() {
  printf "${WHITE}___________________________________________________${RESET_COLOR}\n"
  printf "\n"
  printf "           ${CYAN}-----> Mission Completed ! <----${RESET_COLOR}\n"
}

clear
display_gg

# === Pilih shell di dalam rootfs ===
if [ -x "$ROOTFS_DIR/bin/bash" ]; then
  ROOT_SHELL="/bin/bash"
elif [ -x "$ROOTFS_DIR/bin/sh" ]; then
  ROOT_SHELL="/bin/sh"
else
  echo "Tidak menemukan /bin/bash atau /bin/sh di rootfs!"
  exit 1
fi

# === Jalankan proot + Ubuntu ===
exec "$ROOTFS_DIR/usr/local/bin/proot" \
  --rootfs="$ROOTFS_DIR" \
  -0 \
  -w "/root" \
  -b /dev \
  -b /sys \
  -b /proc \
  -b /etc/resolv.conf \
  --kill-on-exit \
  "$ROOT_SHELL"
