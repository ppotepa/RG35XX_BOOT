#!/bin/bash
# install_new_kernel.sh
# One-shot installer to build/flash a new kernel (+DTB) on the RG35XX-H, with backups & restore.
# Run on the handheld only. Working dir: ~/DTB

set -euo pipefail

### --- CONFIG / PATHS ---
WORKDIR="${HOME}/DTB"
LOG="${WORKDIR}/install.log"
DATA_MOUNT="/mnt/mmc"            # user/data partition (where we’ve been storing files)
BOOT_PART="/dev/mmcblk0p4"       # 64MB Android boot image partition
BOOTARGS_PART="/dev/mmcblk0p3"   # 16MB bootargs/env partition
BACKUP_DIR="${WORKDIR}/backups"

# Preferred input locations (fallback chain)
NEW_IMAGE_CANDIDATES=(
  "${WORKDIR}/new_Image"
  "${DATA_MOUNT}/new_Image"
  "${HOME}/new_Image"
  "/root/new_Image"
)

NEW_DTB_CANDIDATES=(
  "${WORKDIR}/board-new.dtb"
  "${DATA_MOUNT}/board-new.dtb"
  "${HOME}/board-new.dtb"
  "/root/board-new.dtb"
)

PREBUILT_BOOTIMG_CANDIDATES=(
  "${WORKDIR}/boot_new.img"
  "${DATA_MOUNT}/boot_new.img"
  "${HOME}/boot_new.img"
  "/root/boot_new.img"
)

### --- ARGS ---
MODE="install"   # install | restore | dry-run
[ $# -ge 1 ] && MODE="$1"

mkdir -p "${WORKDIR}" "${BACKUP_DIR}"
exec > >(tee -a "${LOG}") 2>&1

echo "[*] RG35XX-H kernel installer started ($(date))"
echo "[*] Mode: ${MODE}"
echo "[*] Workdir: ${WORKDIR}"

### --- HELPERS ---
need_root() {
  if [ "$(id -u)" -ne 0 ]; then
    echo "[!] Please run as root (sudo -i)."
    exit 1
  fi
}

find_first_existing() {
  # prints first existing path from args
  for p in "$@"; do
    if [ -f "$p" ]; then
      echo "$p"
      return 0
    fi
  done
  return 1
}

android_magic_ok() {
  # Check ANDROID! header at offset 0
  local f="$1"
  if [ ! -f "$f" ]; then return 1; fi
  local sig
  sig=$(dd if="$f" bs=8 count=1 status=none | strings -n 8 || true)
  [ "$sig" = "ANDROID!" ]
}

trap_cleanup() {
  echo "[!] An error occurred. See log: ${LOG}"
}
trap trap_cleanup ERR

need_root

### --- BASIC CHECKS ---
echo "[*] Checking block devices..."
if ! lsblk -o NAME,SIZE,TYPE,MOUNTPOINTS | grep -q "mmcblk0"; then
  echo "[!] mmcblk0 not found. Are we on the handheld?"
  exit 1
fi

if [ ! -b "${BOOT_PART}" ]; then
  echo "[!] Boot partition ${BOOT_PART} not found."
  exit 1
fi

if [ ! -d "${DATA_MOUNT}" ]; then
  echo "[!] Data mount ${DATA_MOUNT} not found; continuing anyway."
fi

### --- BACKUPS ---
timestamp="$(date +%Y%m%d-%H%M%S)"
BOOT_BAK="${BACKUP_DIR}/boot_p4_${timestamp}.img"
P3_BAK="${BACKUP_DIR}/p3_bootargs_${timestamp}.img"

if [ "${MODE}" = "restore" ]; then
  echo "[*] Restore mode selected."
  last_boot_bak=$(ls -1t ${BACKUP_DIR}/boot_p4_*.img 2>/dev/null | head -n1 || true)
  if [ -z "${last_boot_bak}" ]; then
    echo "[!] No boot partition backup found in ${BACKUP_DIR}."
    exit 1
  fi
  echo "[*] Restoring ${last_boot_bak} -> ${BOOT_PART} ..."
  dd if="${last_boot_bak}" of="${BOOT_PART}" bs=4M conv=fsync status=progress
  sync
  echo "[*] Restore complete. Reboot to test."
  exit 0
fi

echo "[*] Backing up boot partition (${BOOT_PART}) to ${BOOT_BAK} ..."
dd if="${BOOT_PART}" of="${BOOT_BAK}" bs=4M conv=fsync status=progress
echo "[*] Backing up bootargs partition (${BOOTARGS_PART}) to ${P3_BAK} ..."
dd if="${BOOTARGS_PART}" of="${P3_BAK}" bs=1M conv=fsync status=progress

### --- BUILD OR USE PREBUILT BOOT.IMG ---
OUT_BOOTIMG="${WORKDIR}/boot_new_built.img"
USE_BOOTIMG=""

# Try to build if abootimg exists and kernel+dtb are provided
if command -v abootimg >/dev/null 2>&1; then
  echo "[*] abootimg found; will attempt local build."

  NEW_IMAGE="$(find_first_existing "${NEW_IMAGE_CANDIDATES[@]}" || true)"
  NEW_DTB="$(find_first_existing "${NEW_DTB_CANDIDATES[@]}" || true)"

  if [ -n "${NEW_IMAGE}" ] && [ -n "${NEW_DTB}" ]; then
    echo "[*] New kernel: ${NEW_IMAGE}"
    echo "[*] New DTB:    ${NEW_DTB}"

    echo "[*] Dumping current boot partition to file for extraction..."
    ORIG_BOOT_LOCAL="${WORKDIR}/boot_orig_${timestamp}.img"
    dd if="${BOOT_PART}" of="${ORIG_BOOT_LOCAL}" bs=4M conv=fsync status=progress

    echo "[*] Extracting current boot image (ramdisk + cfg)..."
    ( cd "${WORKDIR}" && abootimg -x "${ORIG_BOOT_LOCAL}" )

    if [ ! -f "${WORKDIR}/initrd.img" ] || [ ! -f "${WORKDIR}/bootimg.cfg" ]; then
      echo "[!] Failed to extract initrd/cfg from original boot image."
      exit 1
    fi

    echo "[*] Concatenating new kernel + DTB..."
    cat "${NEW_IMAGE}" "${NEW_DTB}" > "${WORKDIR}/new_kernel_with_dtb"

    echo "[*] Building new boot image..."
    abootimg --create "${OUT_BOOTIMG}" \
      -f "${WORKDIR}/bootimg.cfg" \
      -k "${WORKDIR}/new_kernel_with_dtb" \
      -r "${WORKDIR}/initrd.img"

    if android_magic_ok "${OUT_BOOTIMG}"; then
      echo "[*] New boot image built: ${OUT_BOOTIMG}"
      USE_BOOTIMG="${OUT_BOOTIMG}"
    else
      echo "[!] Built image missing ANDROID! header. Build failed."
      exit 1
    fi
  else
    echo "[!] abootimg is present, but new Image/DTB were not found."
    echo "    Will try to use a prebuilt boot image instead."
  fi
fi

# If not built, use a prebuilt boot_new.img copied onto the handheld
if [ -z "${USE_BOOTIMG}" ]; then
  echo "[*] Looking for a prebuilt boot_new.img on the device..."
  PREBUILT="$(find_first_existing "${PREBUILT_BOOTIMG_CANDIDATES[@]}" || true)"
  if [ -z "${PREBUILT}" ]; then
    echo "[!] No prebuilt boot_new.img found."
    echo "    Provide one at one of these paths, or install abootimg + provide new_Image & board-new.dtb:"
    printf '      - %s\n' "${PREBUILT_BOOTIMG_CANDIDATES[@]}"
    exit 1
  fi
  echo "[*] Using prebuilt: ${PREBUILT}"
  if ! android_magic_ok "${PREBUILT}"; then
    echo "[!] Prebuilt image ${PREBUILT} lacks ANDROID! header (not an Android boot image)."
    exit 1
  fi
  USE_BOOTIMG="${PREBUILT}"
fi

### --- DRY RUN? ---
if [ "${MODE}" = "dry-run" ]; then
  echo "[*] Dry run: would flash ${USE_BOOTIMG} -> ${BOOT_PART}"
  echo "[*] Backups stored in ${BACKUP_DIR}"
  exit 0
fi

### --- FLASH ---
echo "[*] Flashing ${USE_BOOTIMG} -> ${BOOT_PART} ..."
dd if="${USE_BOOTIMG}" of="${BOOT_PART}" bs=4M conv=fsync status=progress
sync

echo "[*] Verifying header on-partition..."
ONDISK_TMP="${WORKDIR}/ondisk_verify_${timestamp}.img"
dd if="${BOOT_PART}" of="${ONDISK_TMP}" bs=1M count=1 status=none
if android_magic_ok "${ONDISK_TMP}"; then
  echo "[*] ANDROID! header present on boot partition. Flash looks good."
else
  echo "[!] ANDROID! header NOT found after flash. Something is wrong."
  echo "    You can restore with:  $0 restore"
  exit 1
fi

echo "[*] Done. You can now reboot to test the new kernel:"
echo "    reboot"
