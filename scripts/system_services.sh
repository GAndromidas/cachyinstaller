#!/bin/bash
set -uo pipefail

# --- Function to setup UFW Firewall ---
setup_firewall() {
  ui_info "Setting up UFW firewall..."

  ui_info "Installing UFW..."
  install_packages_quietly "ufw" || { log_error "Failed to install UFW."; return 1; }

  ui_info "Enabling UFW firewall..."
  if [ "${DRY_RUN:-false}" = false ]; then
    # Reset to defaults to ensure a clean slate, then enable.
    sudo ufw --force reset >/dev/null 2>&1
    sudo ufw default deny incoming >/dev/null 2>&1
    sudo ufw default allow outgoing >/dev/null 2>&1
    if sudo ufw --force enable >> "$INSTALL_LOG" 2>&1; then
      ui_success "UFW firewall is now active."
    else
      log_error "Failed to enable UFW."
    fi
  else
    ui_info "[DRY-RUN] Would enable the UFW firewall."
  fi
}

# --- Function to enable essential system services ---
setup_essential_services() {
  ui_info "Checking and enabling essential system services..."
  declare -A services
  services=(
    ["fstrim.timer"]="SSD trimming for performance"
    ["systemd-timesyncd.service"]="Network time synchronization"
    ["sshd.service"]="SSH server (if installed)"
    ["bluetooth.service"]="Bluetooth support (if hardware exists)"
    ["cronie.service"]="Cron job scheduler (if installed)"
    ["tlp.service"]="Power management for laptops (if installed and applicable)"
  )

  for service in "${!services[@]}"; do
    local reason=${services[$service]}
    local should_enable=false
    local is_enabled=false
    [ "${DRY_RUN:-false}" = false ] && systemctl is-enabled "$service" >/dev/null 2>&1 && is_enabled=true

    case "$service" in
      "sshd.service")
        command_exists sshd && should_enable=true
        ;;
      "bluetooth.service")
        # Check for bluetooth hardware directory
        [ -d /sys/class/bluetooth ] && should_enable=true
        ;;
      "tlp.service")
        # IS_LAPTOP is exported from system_preparation.sh
        [ "${IS_LAPTOP:-false}" = true ] && pacman -Q tlp &>/dev/null && should_enable=true
        ;;
      "cronie.service")
        pacman -Q cronie &>/dev/null && should_enable=true
        ;;
      *)
        should_enable=true # For fstrim, timesync
        ;;
    esac

    if $should_enable && ! $is_enabled; then
      if [ "${DRY_RUN:-false}" = false ]; then
        if sudo systemctl enable --now "$service" >> "$INSTALL_LOG" 2>&1; then
          ui_info "  - Enabled: $service ($reason)"
        else
          log_error "Failed to enable $service"
        fi
      else
        ui_info "  - [DRY-RUN] Would enable: $service ($reason)"
      fi
    fi
  done
  ui_success "Essential services checked."
}

# --- Function to apply Desktop Environment Tweaks ---
apply_desktop_tweaks() {
    if [[ "${XDG_CURRENT_DESKTOP}" != "KDE" ]]; then
        # Currently, only KDE tweaks are implemented.
        return
    fi

    ui_info "Applying KDE-specific tweaks..."

    local kde_shortcut_file="$HOME/.config/kglobalshortcutsrc"
    local config_shortcut_file="$CONFIGS_DIR/kglobalshortcutsrc"

    if [ -f "$config_shortcut_file" ]; then
        ui_info "Applying default KDE global shortcuts if none exist..."
        if [ "${DRY_RUN:-false}" = false ]; then
            if [ ! -f "$kde_shortcut_file" ]; then
                cp "$config_shortcut_file" "$kde_shortcut_file"
                ui_info "  - Default KDE shortcuts applied. They will be active after you log out and back in."
            fi
        else
            ui_info "[DRY-RUN] Would copy default KDE shortcuts if they do not exist."
        fi
    else
        ui_warn "KDE shortcuts file not found in configs directory. Skipping."
    fi
}


# --- Main Execution ---
setup_firewall
setup_essential_services
apply_desktop_tweaks

return 0
