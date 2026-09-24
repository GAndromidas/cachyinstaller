#!/bin/bash
set -uo pipefail

# Bootloader verification (read-only).
# CachyOS ships an optimized bootloader setup — this step only reports
# which loader is in use (GRUB or systemd-boot) and whether its core
# files are present. It never installs, reconfigures, or overwrites
# any bootloader.

if [[ "${DRY_RUN:-false}" == true ]]; then
  ui_info "Dry-run: Bootloader verification would run here."
  return 0
fi

step "Verifying bootloader configuration"

bootloader="$(detect_bootloader 2>/dev/null || echo unknown)"
ui_info "Detected bootloader: $bootloader"

case "$bootloader" in
  grub)
    if sudo test -d /boot/grub 2>/dev/null || sudo test -d /boot/grub2 2>/dev/null; then
      ui_success "GRUB directory present — CachyOS bootloader intact, no changes made."
    else
      log_error "GRUB detected but its /boot directory is missing — reinstall GRUB manually before rebooting."
      return 1
    fi
    ;;
  systemd-boot)
    entries_dir="$(find_systemd_boot_entries_dir 2>/dev/null || true)"
    if [[ -n "$entries_dir" ]]; then
      ui_success "systemd-boot entries found in $entries_dir — no changes made."
    else
      log_error "systemd-boot detected but no loader entries directory found — check your ESP mount."
      return 1
    fi
    ;;
  *)
    ui_warn "Bootloader type unknown — leaving bootloader untouched."
    ui_info "Expected GRUB or systemd-boot on CachyOS; verify manually with: bootctl status"
    ;;
esac

return 0
