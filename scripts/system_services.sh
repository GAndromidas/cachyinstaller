#!/bin/bash
set -uo pipefail

# CachyOS System Services Configuration - Simplified
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
# common.sh is sourced by install.sh, no need to source again here.

setup_firewall_and_services() {
  step "Setting up firewall and essential services"

  # UFW firewall setup
  if ! pacman -Q ufw &>/dev/null; then
    log_info "Ensuring UFW firewall is installed..."
    if install_package "ufw"; then
      log_success "UFW installed."
    else
      log_error "Failed to install UFW. Firewall setup aborted."
      return 1
    fi
  fi

  # Reset UFW rules only if not already active to avoid disrupting existing custom rules
  if ! sudo ufw status | grep -q "Status: active"; then
    log_info "Resetting UFW firewall rules to default."
    sudo ufw --force reset &>/dev/null
  else
    log_info "UFW is already active. Skipping forced reset to preserve existing rules."
  fi
  sudo ufw --force enable &>/dev/null
  log_success "UFW firewall enabled."

  # Collect services to enable
  local services=("ufw.service" "fstrim.timer" "systemd-timesyncd.service")

  # SSH service if openssh is installed
  if pacman -Q openssh &>/dev/null; then
    services+=(sshd.service)
  fi

  # Bluetooth service if hardware detected and bluez installed
  if [[ -d /sys/class/bluetooth ]] && [[ -n "$(ls -A /sys/class/bluetooth 2>/dev/null)" ]] && pacman -Q bluez &>/dev/null; then
    services+=(bluetooth.service)
  fi

  # Cronie service if installed
  if pacman -Q cronie &>/dev/null; then
    services+=(cronie.service)
  fi

  # TLP for laptops if installed
  if [[ -d /sys/class/power_supply ]] && ls /sys/class/power_supply/BAT* &>/dev/null 2>&1 && pacman -Q tlp &>/dev/null; then
    services+=(tlp.service)
  fi

  # Enable services that aren't already enabled
  local services_to_enable=()
  for svc in "${services[@]}"; do
    if ! systemctl is-enabled "$svc" >/dev/null 2>&1; then
      services_to_enable+=("$svc")
    fi
  done


  if [[ ${#services_to_enable[@]} -gt 0 ]]; then
    log_info "Enabling services: ${services_to_enable[*]}"
    for svc in "${services_to_enable[@]}"; do
      if sudo systemctl enable --now "$svc"; then
        log_success "Enabled and started service: $svc"
      else
        log_error "Failed to enable/start service: $svc"
      fi
    done
    log_success "Enabled ${#services_to_enable[@]} system services in total."
  else
    log_success "All necessary system services are already enabled."
  fi
}

setup_desktop_tweaks() {
  step "Setting up desktop environment tweaks"

  case "$XDG_CURRENT_DESKTOP" in
    KDE)
      log_info "Applying KDE Plasma configurations..."
      local kde_shortcut_file="$HOME/.config/kglobalshortcutsrc"
      # Backup existing global shortcuts if they exist
      if [[ -f "$kde_shortcut_file" ]]; then
        local timestamp=$(date +%Y%m%d_%H%M%S)
        log_info "Backing up existing KDE global shortcuts to ${kde_shortcut_file}.cachyos.backup.${timestamp}"
        cp "$kde_shortcut_file" "${kde_shortcut_file}.cachyos.backup.${timestamp}"
      fi

      # Copy KDE global shortcuts from config
      if [[ -f "$CONFIGS_DIR/kglobalshortcutsrc" ]]; then
        mkdir -p "$(dirname "$kde_shortcut_file")"
        cp "$CONFIGS_DIR/kglobalshortcutsrc" "$kde_shortcut_file"
        log_success "KDE global shortcuts applied (will be active after next login or Plasma restart)"
      else
        log_warning "KDE global shortcuts configuration file not found at $CONFIGS_DIR/kglobalshortcutsrc. Skipping."
      fi
      ;;
    GNOME)
      log_info "Applying GNOME configurations. No specific tweaks implemented yet."
      # GNOME specific tweaks can be added here in the future.
      ;;
    COSMIC)
      log_info "Applying COSMIC configurations. No specific tweaks implemented yet."
      # COSMIC specific tweaks can be added here in the future.
      ;;
    *)
      log_info "No specific desktop environment tweaks for '${XDG_CURRENT_DESKTOP:-unknown}'. Skipping."
      ;;
  esac

  log_success "Desktop environment tweaks completed"
}

# Main execution
log_info "Starting CachyOS system services configuration..."

setup_firewall_and_services
setup_desktop_tweaks

log_success "System services configuration completed"
