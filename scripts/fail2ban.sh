#!/bin/bash
set -uo pipefail

# CachyOS Fail2ban Setup - Security protection for SSH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

install_and_configure_fail2ban() {
  step "Installing and configuring Fail2ban"

  # Install fail2ban if not already installed
  if ! pacman -Q fail2ban &>/dev/null; then
    log_info "Installing fail2ban..."
    if sudo pacman -S --noconfirm fail2ban; then
      log_success "Fail2ban installed"
      INSTALLED_PACKAGES+=("fail2ban")
    else
      log_error "Failed to install fail2ban"
      return 1
    fi
  else
    log_info "Fail2ban already installed"
  fi

  # Configure jail.local if it doesn't exist
  local jail_local="/etc/fail2ban/jail.local"
  if [[ ! -f "$jail_local" ]]; then
    log_info "Creating fail2ban configuration..."

    # Copy default config and apply CachyOS optimizations
    sudo cp /etc/fail2ban/jail.conf "$jail_local"

    # Apply security-focused settings
    sudo sed -i 's/^backend = auto/backend = systemd/' "$jail_local"
    sudo sed -i 's/^bantime  = 10m/bantime = 1h/' "$jail_local"
    sudo sed -i 's/^maxretry = 5/maxretry = 3/' "$jail_local"
    sudo sed -i 's/^findtime  = 10m/findtime = 10m/' "$jail_local"

    log_success "Fail2ban configuration created"
  else
    log_info "Fail2ban already configured"
  fi

  # Enable and start fail2ban service
  if ! systemctl is-enabled fail2ban >/dev/null 2>&1; then
    log_info "Enabling fail2ban service..."
    if sudo systemctl enable --now fail2ban; then
      log_success "Fail2ban service enabled and started"
    else
      log_error "Failed to enable fail2ban service"
      return 1
    fi
  else
    log_info "Fail2ban service already enabled"
    # Ensure it's running
    sudo systemctl start fail2ban 2>/dev/null || true
  fi

  # Verify fail2ban is running
  if systemctl is-active fail2ban >/dev/null 2>&1; then
    log_success "Fail2ban is active and protecting your system"
  else
    log_warning "Fail2ban may not be running properly"
  fi
}

# Main execution
log_info "Starting Fail2ban security setup..."

install_and_configure_fail2ban

log_success "Fail2ban security setup completed - SSH brute force protection is active"
