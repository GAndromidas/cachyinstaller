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

# --- Function for Btrfs Snapshot Setup ---
setup_btrfs_snapshots() {
  # Check if the root filesystem is btrfs
  if [ "$(findmnt -n -o FSTYPE /)" != "btrfs" ]; then
    ui_info "Root filesystem is not Btrfs. Skipping snapshot setup."
    return 0
  fi

  local confirm_snapshots=false
  ui_info "Btrfs filesystem detected. Automatic snapshots can be configured using Snapper."
  ui_warn "This will install snapper, snap-pac, and btrfs-assistant, and configure automatic snapshots."

  if [ "${DRY_RUN:-false}" = true ]; then
      ui_info "[DRY-RUN] Would ask to configure Btrfs snapshots."
      confirm_snapshots=true
  elif supports_gum; then
      gum confirm "Configure Btrfs snapshots for system rollbacks?" && confirm_snapshots=true
  else
      read -r -p "Configure Btrfs snapshots for system rollbacks? [y/N]: " response
      [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]] && confirm_snapshots=true
  fi

  if ! $confirm_snapshots; then
      ui_warn "Skipping Btrfs snapshot setup as requested."
      return 0
  fi

  # Remove Timeshift to prevent conflicts with Snapper
  if pacman -Q timeshift &>/dev/null; then
    ui_warn "The 'timeshift' package conflicts with Snapper and will be removed."
    if [ "${DRY_RUN:-false}" = false ]; then
        if sudo pacman -Rns --noconfirm timeshift >> "$INSTALL_LOG" 2>&1; then
            ui_success "'timeshift' has been removed."
        else
            log_error "Failed to remove 'timeshift'. This may cause conflicts with Snapper."
        fi
    else
        ui_info "[DRY-RUN] Would remove the 'timeshift' package."
    fi
  fi

  # 1. Install packages
  ui_info "Installing snapshot tools (snapper, snap-pac, btrfs-assistant)..."
  install_packages_quietly snapper snap-pac btrfs-assistant || {
    log_error "Failed to install snapshot tools. Aborting snapshot setup."
    return 1
  }

  # 2. Configure Snapper
  ui_info "Configuring Snapper for the root filesystem..."
  if [ "${DRY_RUN:-false}" = false ]; then
    # Check if a config for '/' already exists
    if ! sudo snapper list-configs | grep -q 'root'; then
        sudo snapper create-config / >> "$INSTALL_LOG" 2>&1
        # Configure limits for the newly created config
        sudo snapper set-config "NUMBER_CLEANUP=yes" "NUMBER_LIMIT=10" "TIMELINE_CLEANUP=yes" "TIMELINE_LIMIT_HOURLY=5" "TIMELINE_LIMIT_DAILY=7" >> "$INSTALL_LOG" 2>&1
        ui_success "Snapper configuration for '/' created and configured."
    else
        ui_info "Snapper configuration for '/' already exists. Skipping creation."
    fi
  else
      ui_info "[DRY-RUN] Would create and configure Snapper for '/'."
  fi

  # 3. Enable Snapper systemd timers
  ui_info "Enabling Snapper automatic snapshot timers..."
  local snapper_timers=("snapper-timeline.timer" "snapper-cleanup.timer")
  if [ "${DRY_RUN:-false}" = false ]; then
    for timer in "${snapper_timers[@]}"; do
        if sudo systemctl enable --now "$timer" >> "$INSTALL_LOG" 2>&1; then
            ui_info "  - Enabled: $timer"
        else
            log_error "Failed to enable $timer"
        fi
    done
  else
    ui_info "[DRY-RUN] Would enable and start Snapper timers."
  fi

  # 4. snap-pac is hook-based, so just installing it is enough. No manual hook creation needed.
  ui_success "Btrfs snapshot setup is complete."
  ui_info "Snapshots will now be taken automatically before and after pacman transactions."
}


# --- Main Execution ---
system_cleanup
setup_btrfs_snapshots

return 0
