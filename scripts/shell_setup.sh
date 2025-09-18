#!/bin/bash
set -uo pipefail

# CachyOS Shell Setup - Simplified for Fish/ZSH choice
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
source "$SCRIPT_DIR/common.sh"

setup_shell() {
  if [[ "${CACHYOS_SHELL_CHOICE:-}" == "fish" ]]; then
    log_info "Keeping Fish shell - enhancing with CachyInstaller features"
    setup_fish_enhancement
  elif [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
    log_info "Converting Fish to ZSH - complete replacement"
    convert_fish_to_zsh
  else
    # Default fallback for non-Fish users or unset choice
    if is_fish_shell; then
      log_info "Fish detected - defaulting to Fish enhancement"
      setup_fish_enhancement
    else
      log_info "Installing ZSH setup"
      install_zsh_setup
    fi
  fi
}

setup_fish_enhancement() {
  step "Enhancing Fish shell"

  log_info "Preserving CachyOS Fish configuration"
  setup_fastfetch_config

  log_success "Fish shell enhanced with CachyInstaller features"
}

convert_fish_to_zsh() {
  step "Converting Fish to ZSH"

  log_warning "This will PERMANENTLY remove Fish shell!"

  # Use safe Fish removal helper
  source "$SCRIPT_DIR/safe_fish_removal.sh"
  safe_remove_fish

  # Continue with ZSH installation
  install_zsh_setup
  change_shell_to_zsh
  setup_fastfetch_config

  log_success "Successfully converted from Fish to ZSH"

  # Set flag for main installer to show reboot prompt
  export REQUIRES_REBOOT=true
}

install_zsh_setup() {
  step "Installing ZSH with Oh-My-Zsh"

  # Install Oh-My-Zsh
  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    log_info "Installing Oh-My-Zsh framework"
    RUNZSH=no CHSH=no KEEP_ZSHRC=yes yes | \
      sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >/dev/null 2>&1 || true

    if [[ -d "$HOME/.oh-my-zsh" ]]; then
      log_success "Oh-My-Zsh installed"
    else
      log_error "Failed to install Oh-My-Zsh"
      return 1
    fi
  fi

  # Install essential plugins
  install_zsh_plugins
  copy_zsh_config
  setup_starship

  log_success "ZSH setup completed"
}

install_zsh_plugins() {
  log_info "Installing essential ZSH plugins"

  local plugins_dir="$HOME/.oh-my-zsh/custom/plugins"
  mkdir -p "$plugins_dir"

  # Install zsh-autosuggestions
  if [[ ! -d "$plugins_dir/zsh-autosuggestions" ]]; then
    log_info "Installing zsh-autosuggestions plugin"
    git clone https://github.com/zsh-users/zsh-autosuggestions "$plugins_dir/zsh-autosuggestions" &>/dev/null || {
      log_warning "Failed to install zsh-autosuggestions plugin"
    }
  else
    log_info "zsh-autosuggestions already installed"
  fi

  # Install zsh-syntax-highlighting
  if [[ ! -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
    log_info "Installing zsh-syntax-highlighting plugin"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$plugins_dir/zsh-syntax-highlighting" &>/dev/null || {
      log_warning "Failed to install zsh-syntax-highlighting plugin"
    }
  else
    log_info "zsh-syntax-highlighting already installed"
  fi

  # Verify plugin installations
  if [[ -d "$plugins_dir/zsh-autosuggestions" ]] && [[ -d "$plugins_dir/zsh-syntax-highlighting" ]]; then
    log_success "All ZSH plugins installed successfully"
  else
    log_warning "Some ZSH plugins may not have installed correctly"
  fi
}

copy_zsh_config() {
  log_info "Installing CachyInstaller ZSH configuration"

  # Backup existing .zshrc
  if [[ -f "$HOME/.zshrc" ]]; then
    log_info "Backing up existing .zshrc"
    cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
  fi

  # Install CachyInstaller .zshrc
  if [[ -f "$CONFIGS_DIR/.zshrc" ]]; then
    log_info "Installing CachyInstaller .zshrc configuration"
    cp "$CONFIGS_DIR/.zshrc" "$HOME/.zshrc"
    chmod 644 "$HOME/.zshrc"
    log_success "ZSH configuration installed at $HOME/.zshrc"

    # Source the new configuration for current session if in ZSH
    if [[ "${SHELL##*/}" == "zsh" ]] && [[ -n "${ZSH_VERSION:-}" ]]; then
      source "$HOME/.zshrc" 2>/dev/null || true
      log_info "ZSH configuration loaded for current session"
    fi
  else
    log_error "CachyInstaller .zshrc not found at $CONFIGS_DIR/.zshrc"
    log_warning "Creating basic .zshrc configuration"
    cat > "$HOME/.zshrc" << 'EOF'
# Basic ZSH configuration
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"
plugins=(git zsh-autosuggestions zsh-syntax-highlighting)
source $ZSH/oh-my-zsh.sh
eval "$(starship init zsh)"
EOF
  fi
}

setup_starship() {
  log_info "Setting up Starship prompt configuration"

  mkdir -p "$HOME/.config"

  # Backup existing starship config if it exists
  if [[ -f "$HOME/.config/starship.toml" ]]; then
    log_info "Backing up existing starship configuration"
    cp "$HOME/.config/starship.toml" "$HOME/.config/starship.toml.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
  fi

  # Install CachyInstaller starship config
  if [[ -f "$CONFIGS_DIR/starship.toml" ]]; then
    log_info "Installing CachyInstaller starship configuration"
    cp "$CONFIGS_DIR/starship.toml" "$HOME/.config/starship.toml"
    chmod 644 "$HOME/.config/starship.toml"
    log_success "Starship configuration installed at $HOME/.config/starship.toml"
  else
    log_warning "CachyInstaller starship config not found - using default"
  fi
}

change_shell_to_zsh() {
  log_info "Changing default shell to ZSH"

  local current_shell=$(getent passwd "$USER" | cut -d: -f7)
  local zsh_path=$(command -v zsh)

  if [[ "$current_shell" != "$zsh_path" ]]; then
    if sudo chsh -s "$zsh_path" "$USER" 2>/dev/null; then
      log_success "Default shell changed to ZSH"
      log_warning "Shell change complete - system reboot required"
      export REQUIRES_REBOOT=true
    else
      log_error "Failed to change shell - you can do it manually: chsh -s $(command -v zsh)"
      export REQUIRES_REBOOT=true
    fi
  else
    log_info "Default shell is already ZSH"
  fi
}

setup_fastfetch_config() {
  step "Replacing CachyOS fastfetch config with CachyInstaller version"

  mkdir -p "$HOME/.config/fastfetch"

  # Always backup existing CachyOS config
  if [[ -f "$HOME/.config/fastfetch/config.jsonc" ]]; then
    log_info "Backing up CachyOS fastfetch configuration"
    cp "$HOME/.config/fastfetch/config.jsonc" "$HOME/.config/fastfetch/config.jsonc.cachyos.backup.$(date +%Y%m%d_%H%M%S)"
  fi

  # Replace with CachyInstaller fastfetch configuration (force replacement)
  if [[ -f "$CONFIGS_DIR/config.jsonc" ]]; then
    log_info "Installing CachyInstaller fastfetch configuration (replacing CachyOS default)"
    cp "$CONFIGS_DIR/config.jsonc" "$HOME/.config/fastfetch/config.jsonc"
    chmod 644 "$HOME/.config/fastfetch/config.jsonc"
    log_success "Fastfetch configuration replaced successfully"

    # Test the new configuration
    if command -v fastfetch >/dev/null 2>&1; then
      if fastfetch --config "$HOME/.config/fastfetch/config.jsonc" --dry-run >/dev/null 2>&1; then
        log_success "CachyInstaller fastfetch configuration validated"
      else
        log_warning "Fastfetch configuration may have issues but was installed"
      fi
    fi
  else
    log_error "CachyInstaller fastfetch config not found at $CONFIGS_DIR/config.jsonc"
    log_warning "Keeping CachyOS default fastfetch configuration"
  fi
}

# Main execution
log_info "Starting CachyOS shell setup..."

setup_shell

log_success "CachyOS shell setup completed"
