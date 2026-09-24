#!/bin/bash
set -uo pipefail

# Hardware/system detection, cached to avoid redundant checks.
# Adapted for CachyOS: bootloader detection covers the layouts CachyOS
# deploys (GRUB and systemd-boot). GPU detection reports every GPU so
# hybrid (iGPU + dGPU) systems are not misreported. Laptop detection uses
# battery presence plus DMI chassis type.

declare -gA SYSTEM_CACHE=()

if ! declare -f find_systemd_boot_entries_dir >/dev/null 2>&1; then
find_systemd_boot_entries_dir() {
  for dir in "/boot/loader/entries" "/efi/loader/entries" "/boot/efi/loader/entries"; do
    if sudo test -d "$dir" 2>/dev/null; then
      echo "$dir"
      return 0
    fi
  done
  return 1
}
fi

# Report every detected GPU vendor (one per line, de-duplicated).
# Uses multi-line matching so hybrid graphics are fully reported.
detect_gpu_vendor() {
  local cache_key="gpu_vendor"
  if [[ -n "${SYSTEM_CACHE[$cache_key]:-}" ]]; then
    echo "${SYSTEM_CACHE[$cache_key]}"
    return 0
  fi
  local vendors=()
  local pci_out=""
  pci_out=$(lspci 2>/dev/null | grep -iE 'vga|3d controller|display controller' || true)
  if [[ -n "$pci_out" ]]; then
    echo "$pci_out" | grep -Eiq 'vga.*nvidia|3d.*nvidia|display.*nvidia' && vendors+=("nvidia")
    echo "$pci_out" | grep -Eiq 'vga.*amd|3d.*amd|display.*amd|vga.*radeon|3d.*radeon|display.*radeon' && vendors+=("amd")
    echo "$pci_out" | grep -Eiq 'vga.*intel|3d.*intel|display.*intel' && vendors+=("intel")
  fi
  local result=""
  if ((${#vendors[@]} > 0)); then
    result=$(printf '%s\n' "${vendors[@]}" | sort -u | tr '\n' ' ' | xargs)
  fi
  SYSTEM_CACHE[$cache_key]="$result"
  echo "$result"
}

is_laptop() {
  local cache_key="is_laptop"
  if [[ -n "${SYSTEM_CACHE[$cache_key]:-}" ]]; then
    [[ "${SYSTEM_CACHE[$cache_key]}" == "true" ]]
    return $?
  fi
  local laptop=false
  if [[ -d "/sys/class/power_supply" ]]; then
    while IFS= read -r supply; do
      if [[ "$supply" == *"BAT"* ]]; then
        laptop=true
        break
      fi
    done < <(ls /sys/class/power_supply 2>/dev/null)
  fi
  if command -v dmidecode &>/dev/null; then
    local chassis=""
    chassis=$(sudo dmidecode -s chassis-type 2>/dev/null | tr '[:upper:]' '[:lower:]' || true)
    case "$chassis" in
      *laptop*|*notebook*|*portable*) laptop=true ;;
    esac
  fi
  SYSTEM_CACHE[$cache_key]="$laptop"
  [[ "$laptop" == "true" ]]
}

if ! declare -f is_btrfs_system >/dev/null 2>&1; then
is_btrfs_system() {
  local cache_key="is_btrfs"
  if [[ -n "${SYSTEM_CACHE[$cache_key]:-}" ]]; then
    [[ "${SYSTEM_CACHE[$cache_key]}" == "true" ]]
    return $?
  fi
  local result="false"
  findmnt -no FSTYPE / 2>/dev/null | grep -q btrfs && result="true"
  SYSTEM_CACHE[$cache_key]="$result"
  [[ "$result" == "true" ]]
}
fi

# Bootloader detection limited to the layouts this installer supports.
# CachyOS ships GRUB or systemd-boot; this helper only distinguishes
# those two (plus "unknown") and never implies other loaders.
if ! declare -f detect_bootloader >/dev/null 2>&1; then
detect_bootloader() {
  local cache_key="bootloader"
  if [[ -n "${SYSTEM_CACHE[$cache_key]:-}" ]]; then
    echo "${SYSTEM_CACHE[$cache_key]}"
    return 0
  fi
  local bootloader="unknown"
  if sudo test -d /boot/grub 2>/dev/null || sudo test -d /boot/grub2 2>/dev/null || \
     sudo test -d /boot/efi/EFI/grub 2>/dev/null || sudo test -d /efi/EFI/grub 2>/dev/null || \
     command -v grub-mkconfig &>/dev/null || pacman -Q grub &>/dev/null 2>&1; then
    bootloader="grub"
  elif sudo test -d /boot/loader/entries 2>/dev/null || sudo test -d /efi/loader/entries 2>/dev/null || \
       sudo test -f /boot/loader/loader.conf 2>/dev/null || sudo test -f /efi/loader/loader.conf 2>/dev/null || \
       sudo test -d /boot/EFI/systemd 2>/dev/null || sudo test -d /efi/EFI/systemd 2>/dev/null || \
       sudo test -d /boot/loader 2>/dev/null || command -v bootctl &>/dev/null; then
    bootloader="systemd-boot"
  elif [ -d /sys/firmware/efi ]; then
    bootloader="systemd-boot"
  fi
  SYSTEM_CACHE[$cache_key]="$bootloader"
  echo "$bootloader"
}
fi

if ! declare -f is_vm >/dev/null 2>&1; then
is_vm() {
  if command -v systemd-detect-virt &>/dev/null && systemd-detect-virt --vm &>/dev/null; then
    return 0
  fi
  if [ -f /proc/1/cgroup ] && grep -q hypervisor /proc/1/cgroup 2>/dev/null; then
    return 0
  fi
  if [ -d /sys/hypervisor/type ] 2>/dev/null || [ -n "$(ls -A /sys/hypervisor 2>/dev/null)" ]; then
    return 0
  fi
  if grep -iqw "virtual" /sys/class/dmi/id/product_name 2>/dev/null; then
    return 0
  fi
  return 1
}
fi

if ! declare -f is_headless_system >/dev/null 2>&1; then
is_headless_system() {
  if systemctl is-active --quiet gdm 2>/dev/null || \
     systemctl is-active --quiet sddm 2>/dev/null || \
     systemctl is-active --quiet lightdm 2>/dev/null || \
     systemctl is-active --quiet lxdm 2>/dev/null; then
    return 1
  fi
  if pgrep -x X >/dev/null 2>&1 || pgrep -x Xorg >/dev/null 2>&1; then
    return 1
  fi
  if pgrep -x weston >/dev/null 2>&1 || pgrep -x gnome-shell >/dev/null 2>&1; then
    return 1
  fi
  if [[ -n "${XDG_CURRENT_DESKTOP:-}" ]]; then
    return 1
  fi
  return 0
}
fi
