#!/bin/bash
set -uo pipefail

# --- User Confirmation ---
local confirm_fail2ban=false
ui_info "Fail2ban provides protection against SSH brute-force attacks."
if [ "${DRY_RUN:-false}" = true ]; then
    ui_info "[DRY-RUN] Would ask to install Fail2ban."
    confirm_fail2ban=true # Assume yes for dry run to show what would happen
elif supports_gum; then
    if gum confirm "Install and configure Fail2ban for SSH?"; then
        confirm_fail2ban=true
    fi
else
    read -r -p "Install and configure Fail2ban for SSH? [y/N]: " response
    if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
        confirm_fail2ban=true
    fi
fi

if ! $confirm_fail2ban; then
    ui_warn "Skipping Fail2ban setup as requested."
    return 0
fi

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

return 0
