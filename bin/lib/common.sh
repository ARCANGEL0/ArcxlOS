#!/usr/bin/env bash

set -euo pipefail

AX_EDITIONS=(home gaming fallen netinstall)

AX_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AX_ROOT="$(cd "${AX_LIB_DIR}/../.." && pwd)"
AX_VERSION="$(tr -d '[:space:]' < "${AX_ROOT}/VERSION" 2>/dev/null || true)"
AX_VERSION="${AX_VERSION:-0.0}"

ax_log()  { printf '[+] %s\n' "$*"; }
ax_warn() { printf '[!] %s\n' "$*" >&2; }
ax_die()  { printf '[-] ERROR: %s\n' "$*" >&2; exit 1; }

ax_editions_list() { printf '%s\n' "${AX_EDITIONS[@]}"; }

ax_usage() {
  cat <<EOF
ArchangelOS ISO builder — version ${AX_VERSION}

Usage: sudo ./build.sh [edition] [options]

Editions:
  --home          Build the Home Edition ISO
  --gaming        Build the Gaming Edition ISO
  --fallen        Build the Fallen Edition ISO
  --netinstall    Build the NetInstall Edition ISO
  --all           Build every edition, one after another

Options:
  --no-stage      Skip staging the shared overlay and wallpaper pool
                  (use when the profile already carries the staged files)
  -h, --help      Show this help and exit

Output:
  build/<edition>/out/*.iso

Examples:
  sudo ./build.sh --home
  sudo ./build.sh --gaming --no-stage
  sudo ./build.sh --all
EOF
}

ax_check_edition() {
  local edition="$1" found=0
  for e in "${AX_EDITIONS[@]}"; do
    [ "${e}" = "${edition}" ] && found=1
  done
  [ "${found}" -eq 1 ] || ax_die "unknown edition '${edition}'. Valid: ${AX_EDITIONS[*]}"
  [ -d "${AX_ROOT}/system/${edition}" ] || ax_die "profile '${AX_ROOT}/system/${edition}' does not exist."
}

ax_check_env() {
  [ "$(id -u)" -eq 0 ] || ax_die "root privileges are required to build squashfs images. Run: sudo ./build.sh $*"
  command -v mkarchiso >/dev/null 2>&1 || ax_die "'mkarchiso' not found. Install it with: sudo pacman -S archiso"
}

ax_min_free_gb() {
  case "$1" in
    netinstall) echo 12 ;;
    home)       echo 20 ;;
    gaming)     echo 25 ;;
    fallen)     echo 40 ;;
    *)          echo 20 ;;
  esac
}

ax_check_space() {
  local edition="$1"
  local target="${2:-${AX_ROOT}}"
  local need="${AX_MIN_FREE_GB:-$(ax_min_free_gb "${edition}")}"
  local avail
  avail="$(df -BG --output=avail "${target}" | tail -n 1 | tr -dc '0-9')"
  ax_log "Free space on ${target}: ${avail} GB (need about ${need} GB for ${edition})"
  if [ "${avail}" -lt "${need}" ]; then
    ax_die "not enough free space for the ${edition} build: ${avail} GB available, about ${need} GB needed.
    Free some space, move the build directory, or override the estimate with AX_MIN_FREE_GB=<n>."
  fi
}

ax_stage() {
  local edition="$1"
  local airootfs="${AX_ROOT}/system/${edition}/airootfs"
  local pool_dest="${airootfs}/usr/share/backgrounds/archangelos/wallpapers"

  ax_log "Staging shared overlay (system/common/airootfs)..."
  cp -a "${AX_ROOT}/system/common/airootfs/." "${airootfs}/"
  chmod +x "${airootfs}/usr/bin/archangelos-wallpaper" \
           "${airootfs}/usr/bin/archangelos-wallpaper-setup" \
           "${airootfs}/usr/bin/archangelos-lock" \
           "${airootfs}/usr/bin/archangelos-settings" \
           "${airootfs}/usr/bin/archangelos-shell" \
           "${airootfs}/usr/lib/archangelos/ghostwired" \
           "${airootfs}/usr/lib/archangelos/ghostwired-exempt" \
           "${airootfs}/usr/lib/archangelos/axs-admin" \
           "${airootfs}/usr/lib/archangelos/power-mode" \
           "${airootfs}/usr/bin/archangelos-fastfetch-setup" \
           "${airootfs}/usr/bin/archangelos-theme-setup" \
           "${airootfs}/usr/bin/archangelos-region" \
           "${airootfs}/usr/bin/archangelos-screenshot" \
           "${airootfs}/usr/bin/archangelos-screenrecord" \
           "${airootfs}/usr/bin/archangelos-launcher" \
           "${airootfs}/usr/bin/archangelos-launcher-toggle" \
           "${airootfs}/usr/bin/archangelos-welcome" \
           "${airootfs}/usr/bin/arcfetch" \
           "${airootfs}/usr/bin/onionchat" \
           "${airootfs}/usr/bin/archangelos-redops-tools" 2>/dev/null || true

  ax_log "Stamping release version (system/${edition}/airootfs/etc/archangelos/version)..."
  mkdir -p "${airootfs}/etc/archangelos"
  printf '%s\n' "${AX_VERSION}" > "${airootfs}/etc/archangelos/version"

  ax_log "Staging wallpaper pool (assets/wallpapers)..."
  mkdir -p "${pool_dest}"
  rm -f "${pool_dest}"/* 2>/dev/null || true
  if [ "${edition}" = "netinstall" ]; then
    find "${AX_ROOT}/assets/wallpapers" -maxdepth 1 -type f -name '*.png' \
      -exec cp -f {} "${pool_dest}/" \; 2>/dev/null || true
  else
    find "${AX_ROOT}/assets/wallpapers" -maxdepth 1 -type f \
      -exec cp -f {} "${pool_dest}/" \; 2>/dev/null || true
  fi
  ax_log "Staged $(find "${pool_dest}" -maxdepth 1 -type f | wc -l) wallpaper file(s)."
}

ax_build() {
  local edition="$1" stage="$2"
  local profile_dir="${AX_ROOT}/system/${edition}"
  # AX_BUILD_DIR relocates the scratch/output tree onto a larger volume
  # (used in CI, where the roomy disk is mounted outside the checkout).
  local build_base="${AX_BUILD_DIR:-${AX_ROOT}/build}"
  local work_dir="${build_base}/${edition}/work"
  local out_dir="${build_base}/${edition}/out"

  echo "========================================================"
  echo "    ArchangelOS ${edition} ISO Build  —  version ${AX_VERSION}"
  echo "========================================================"
  echo "[+] Profile        : ${profile_dir}"
  echo "[+] Work directory : ${work_dir}"
  echo "[+] Output         : ${out_dir}"
  echo "========================================================"

  mkdir -p "${build_base}"
  ax_check_space "${edition}" "${build_base}"

  if [ "${stage}" -eq 1 ]; then
    ax_stage "${edition}"
  fi

  ax_log "Cleaning previous work directory..."
  # A killed mkarchiso can leave arch-chroot bind mounts (/dev, /dev/pts, ...)
  # under the work airootfs; unmount them (deepest-first) before removing, or
  # rm -rf leaves a populated root and the next pacstrap hits file conflicts.
  local m pass
  for pass in 1 2 3; do
    mount | awk -v w="${work_dir}" 'index($3, w) == 1 {print length($3), $3}' \
      | sort -rn | cut -d' ' -f2- | while read -r m; do
        [ -n "${m}" ] && { umount -R "${m}" 2>/dev/null || umount -lf "${m}" 2>/dev/null || true; }
      done || true
  done
  rm -rf "${work_dir}"
  # Don't pre-create work_dir: mkarchiso cancels -r when the directory already exists.
  mkdir -p "${out_dir}"

  ax_log "Building ISO via mkarchiso..."
  # -r: drop the unpacked rootfs once it is compressed, before the ISO is written, so the
  # rootfs, the squashfs and the ISO never sit on disk all at once (the gaming build ran
  # out of space at exactly that point).
  ARCHANGELOS_VERSION="${AX_VERSION}" \
    mkarchiso -v -r -w "${work_dir}" -o "${out_dir}" "${profile_dir}"

  echo "========================================================"
  echo "    SUCCESS! ArchangelOS ${edition} ISO build complete."
  echo "========================================================"
  ls -lh "${out_dir}"/*.iso 2>/dev/null || true
  echo "========================================================"
}
