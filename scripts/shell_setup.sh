#!/usr/bin/env bash
set -uo pipefail
trap 'exit_handler $?' EXIT

# CachyOS Shell Setup - Fish Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
source "$SCRIPT_DIR/common.sh"

# Handle script exit
exit_handler() {
    local exit_code=$1
    # Return to fish shell if we came from it
    if [[ -n "${FISH_VERSION:-}" ]] && [[ "$exit_code" -eq 0 ]]; then
        exec fish
    fi
    exit "$exit_code"
}

setup_fish() {
  step "Setting up enhanced Fish shell configuration"

  # Verify Fish shell is installed (should always be true on CachyOS)
  if ! command -v fish >/dev/null 2>&1; then
    log_error "Fish shell not found! This shouldn't happen on CachyOS."
    return 1
  fi

  # Create necessary directories
  mkdir -p "$HOME/.config/fish"
  mkdir -p "$HOME/.config/fish/functions"
  mkdir -p "$HOME/.config/fish/completions"
  mkdir -p "$HOME/.config/fastfetch"

  # Backup existing configurations with timestamp
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local configs_to_backup=(
    "$HOME/.config/fish/config.fish"
    "$HOME/.config/fish/starship.fish"
    "$HOME/.config/fish/starship.toml"
    "$HOME/.config/fastfetch/config.jsonc"
  )

  for config in "${configs_to_backup[@]}"; do
    if [[ -f "$config" ]]; then
      local backup_path="${config}.cachyos.backup.${timestamp}"
      log_info "Backing up ${config##*/} to ${backup_path##*/}"
      cp "$config" "$backup_path"
    fi
  done

  # Install Fish configuration
  log_info "Installing enhanced Fish configuration"
  if [[ -f "$CONFIGS_DIR/fish/config.fish" ]]; then
    cp "$CONFIGS_DIR/fish/config.fish" "$HOME/.config/fish/config.fish"
    chmod 644 "$HOME/.config/fish/config.fish"
    log_success "Installed Fish configuration"
  else
    log_error "Fish configuration not found at $CONFIGS_DIR/fish/config.fish"
    return 1
  fi

  # Install Starship configurations
  log_info "Installing Starship configurations"
  if [[ -f "$CONFIGS_DIR/fish/starship.fish" ]]; then
    cp "$CONFIGS_DIR/fish/starship.fish" "$HOME/.config/fish/starship.fish"
    chmod 644 "$HOME/.config/fish/starship.fish"
    log_success "Installed Starship Fish integration"
  fi

  if [[ -f "$CONFIGS_DIR/fish/starship.toml" ]]; then
    cp "$CONFIGS_DIR/fish/starship.toml" "$HOME/.config/fish/starship.toml"
    chmod 644 "$HOME/.config/fish/starship.toml"
    log_success "Installed Starship configuration"
  fi

  # Install Fastfetch configuration
  setup_fastfetch

  # Install Fisher (plugin manager) if not present
  if ! fish -c "functions -q fisher" 2>/dev/null; then
    log_info "Installing Fisher plugin manager"
    curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | fish -c "source && fisher install jorgebucaran/fisher" &>/dev/null
    if [ $? -eq 0 ]; then
        log_success "Installed Fisher plugin manager"
    else
        log_warning "Fisher installation failed, but continuing..."
    fi
  fi

  # Install essential Fish plugins
  log_info "Installing Fish plugins"
  fish -c "fisher install jorgebucaran/autopair.fish" &>/dev/null
  fish -c "fisher install franciscolourenco/done" &>/dev/null
  fish -c "fisher install PatrickF1/fzf.fish" &>/dev/null
  fish -c "fisher install meaningful-ooo/sponge" &>/dev/null
  log_success "Installed Fish plugins"

  # Verify configurations
  verify_installations

  # Final setup
  log_info "Setting Fish as default shell (if not already)"
  local fish_path=$(command -v fish)
  if [[ -n "$fish_path" ]]; then
    if [[ "$SHELL" != "$fish_path" ]]; then
      if grep -q "^$fish_path$" /etc/shells || sudo sh -c "echo $fish_path >> /etc/shells"; then
        if sudo chsh -s "$fish_path" "$USER" 2>/dev/null; then
          log_success "Fish is now your default shell"
        else
          log_error "Failed to set Fish as default shell"
          log_info "You can do it manually with: chsh -s $fish_path"
        fi
      else
        log_error "Could not add Fish shell to /etc/shells"
      fi
    else
      log_info "Fish is already your default shell"
    fi
  else
    log_error "Fish shell not found in system"
  fi

  log_success "Fish shell setup completed successfully"

  # Notify about shell restart
  log_warning "Please restart your shell or run 'exec fish' to apply all changes"
}

setup_fastfetch() {
  step "Setting up Fastfetch configuration"

  # Remove any existing fastfetch config and directory
  if [[ -d "$HOME/.config/fastfetch" ]]; then
    rm -rf "$HOME/.config/fastfetch"
  fi

  # Create fresh fastfetch directory
  mkdir -p "$HOME/.config/fastfetch"

  # Install new fastfetch configuration
  if [[ -f "$CONFIGS_DIR/fastfetch/config.jsonc" ]]; then
    log_info "Installing custom Fastfetch configuration"
    cp "$CONFIGS_DIR/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    chmod 644 "$HOME/.config/fastfetch/config.jsonc"

    # Test the new configuration
    if command -v fastfetch >/dev/null 2>&1; then
      if fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --dry-run >/dev/null 2>&1; then
        log_success "Fastfetch configuration installed and verified"
      else
        log_warning "Fastfetch configuration might have issues but was installed"
      fi
    else
      log_warning "Fastfetch not found - configuration installed but not tested"
    fi
  else
    log_error "Fastfetch configuration not found at $CONFIGS_DIR/fastfetch/config.jsonc"
    return 1
  fi
}

verify_installations() {
  local all_good=true

  # Test Fish config
  if ! fish -c "status --is-interactive; and source ~/.config/fish/config.fish" 2>/dev/null; then
    log_error "Fish configuration test failed"
    all_good=false
  fi

  # Test Starship
  if ! fish -c "starship init fish" &>/dev/null; then
    log_warning "Starship integration test failed"
    all_good=false
  fi

  # Test Fastfetch
  if command -v fastfetch >/dev/null 2>&1; then
    if ! fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --dry-run >/dev/null 2>&1; then
      log_warning "Fastfetch configuration test failed"
      all_good=false
    fi
  fi

  if [ "$all_good" = true ]; then
    log_success "All configurations verified successfully"
  else
    log_warning "Some configurations may need attention"
  fi
}

# Main execution
log_info "Starting CachyOS Fish shell enhancement..."
setup_fish
log_success "Shell enhancement completed"
