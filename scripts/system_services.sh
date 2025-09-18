#!/bin/bash
set -uo pipefail

# CachyOS System Services Configuration - Simplified
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
source "$SCRIPT_DIR/common.sh"

setup_firewall_and_services() {
  step "Setting up firewall and essential services"

  # UFW firewall setup
  if ! pacman -Q ufw &>/dev/null; then
    log_info "Installing UFW firewall..."
    sudo pacman -S --noconfirm ufw
    INSTALLED_PACKAGES+=("ufw")
  fi

  sudo ufw --force reset &>/dev/null
  sudo ufw --force enable &>/dev/null
  log_success "UFW firewall configured and enabled"

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
    sudo systemctl enable --now "${services_to_enable[@]}" 2>/dev/null || true
    log_success "Enabled ${#services_to_enable[@]} system services"
  else
    log_success "All services already enabled"
  fi
}

setup_desktop_tweaks() {
  step "Setting up desktop environment tweaks"

  case "$XDG_CURRENT_DESKTOP" in
    KDE)
      log_info "Applying KDE Plasma configurations"
      # Copy KDE global shortcuts if available
      if [[ -f "$CONFIGS_DIR/kglobalshortcutsrc" ]]; then
        mkdir -p "$HOME/.config"
        cp "$CONFIGS_DIR/kglobalshortcutsrc" "$HOME/.config/kglobalshortcutsrc"
        log_success "KDE global shortcuts applied (active after next login)"
      fi
      ;;
    GNOME)
      log_info "Applying GNOME configurations"
      # GNOME specific tweaks can be added here
      ;;
    COSMIC)
      log_info "Applying COSMIC configurations"
      # COSMIC specific tweaks can be added here
      ;;
    *)
      log_info "Generic desktop environment detected"
      ;;
  esac

  log_success "Desktop environment tweaks completed"
}

# Main execution
log_info "Starting CachyOS system services configuration..."

setup_firewall_and_services
setup_desktop_tweaks

log_success "System services configuration completed"
