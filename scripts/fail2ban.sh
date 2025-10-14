#!/bin/bash
set -uo pipefail

setup_fail2ban() {
  ui_info "Setting up Fail2ban for SSH protection..."

# --- Installation ---
ui_info "Installing Fail2ban..."
if ! install_packages_quietly "fail2ban"; then
  log_error "Failed to install Fail2ban. Aborting setup."
  return 1
fi
ui_success "Fail2ban installed."

# --- Configuration ---
JAIL_LOCAL_PATH="/etc/fail2ban/jail.local"
if [ -f "$JAIL_LOCAL_PATH" ]; then
  ui_info "Fail2ban configuration ($JAIL_LOCAL_PATH) already exists. Skipping."
else
  ui_info "Creating default Fail2ban configuration for SSH..."
  if [ "${DRY_RUN:-false}" = false ]; then
    # Using a heredoc for the configuration file content
    sudo tee "$JAIL_LOCAL_PATH" > /dev/null <<EOF
[DEFAULT]
# Use systemd journal for backend
backend = systemd
# Ban for 1 hour
bantime = 1h
# Max 3 retries
maxretry = 3
# Within a 10 minute window
findtime = 10m

[sshd]
enabled = true
EOF
    ui_success "Fail2ban configuration created at $JAIL_LOCAL_PATH"
  else
    ui_info "[DRY-RUN] Would have created $JAIL_LOCAL_PATH with SSH protection rules."
  fi
fi

# --- Service Management ---
ui_info "Enabling and starting the Fail2ban service..."
if [ "${DRY_RUN:-false}" = false ]; then
  if sudo systemctl enable --now fail2ban >> "$INSTALL_LOG" 2>&1; then
    ui_success "Fail2ban service is now enabled and running."
  else
    log_error "Failed to enable or start the Fail2ban service."
    ui_warn "You can try to enable it manually with: sudo systemctl enable --now fail2ban"
    return 1
  fi
else
  ui_info "[DRY-RUN] Would have enabled and started the Fail2ban service."
fi

}

setup_fail2ban
return 0
