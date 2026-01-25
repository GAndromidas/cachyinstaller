#!/bin/bash
set -uo pipefail

# --- Function for System Cleanup ---
system_cleanup() {
  ui_info "Performing system cleanup..."

  # Clean package cache (pacman)
  if command_exists paccache; then
    if [ "${DRY_RUN:-false}" = false ]; then
      # Keep the last 1 version of each package
      sudo paccache -rk1 >> "$INSTALL_LOG" 2>&1
      ui_info "  - Pacman cache cleaned."
    else
      ui_info "  - [DRY-RUN] Would clean pacman cache."
    fi
  fi

  # Clean AUR helper cache (paru)
  if command_exists paru; then
    if [ "${DRY_RUN:-false}" = false ]; then
      paru -Sc --noconfirm >> "$INSTALL_LOG" 2>&1
      ui_info "  - AUR (paru) cache cleaned."
    else
      ui_info "  - [DRY-RUN] Would clean AUR (paru) cache."
    fi
  fi

  # Clean unused Flatpak runtimes
  if command_exists flatpak; then
    if [ "${DRY_RUN:-false}" = false ]; then
      flatpak uninstall --unused -y >> "$INSTALL_LOG" 2>&1
      ui_info "  - Unused Flatpak runtimes cleaned."
    else
      ui_info "  - [DRY-RUN] Would clean unused Flatpak runtimes."
    fi
  fi
  ui_success "System cleanup complete."
}

# --- Main Execution ---
system_cleanup

return 0
