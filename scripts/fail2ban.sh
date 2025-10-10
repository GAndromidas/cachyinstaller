#!/bin/bash
set -uo pipefail

# CachyOS Fail2ban Setup - Security protection for SSH
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# common.sh is sourced by install.sh, no need to source again here.

install_and_configure_fail2ban() {
  step "Installing and configuring Fail2ban"

  # Install fail2ban if not already installed
  if ! pacman -Q fail2ban &>/dev/null; then
    log_info "Ensuring fail2ban is installed..."
    if install_package "fail2ban"; then
      log_success "Fail2ban installed."
    else
      log_error "Failed to install fail2ban. Fail2ban setup aborted."
      return 1
    fi
  else
    log_info "Fail2ban already installed"
  fi

  # Configure jail.local if it doesn't exist
  local jail_local="/etc/fail2ban/jail.local"
  if [[ ! -f "$jail_local" ]]; then
    log_info "Creating and configuring fail2ban jail.local..."

    {
      echo "[DEFAULT]"
      echo "backend = systemd"
      echo "bantime = 1h"
      echo "maxretry = 3"
      echo "findtime = 10m" # Keeping default for clarity, though it's the same
      echo ""
      echo "[sshd]"
      echo "enabled = true"
      echo "port    = ssh"
      echo "logpath = %(sshd_log)s"
      echo "backend = %(sshd_backend)s"
    } | sudo tee "$jail_local" >/dev/null

    log_success "Fail2ban configuration created: $jail_local"
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
