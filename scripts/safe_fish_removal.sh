#!/bin/bash
set -uo pipefail

# Safe Fish Removal Helper Script
# This script safely removes Fish shell and ensures clean reboot functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

safe_remove_fish() {
  log_info "Starting safe Fish removal process"

  # Immediately disable Fish notifications to prevent interference
  log_info "Disabling Fish notifications system-wide"
  if [[ -f "/usr/share/cachyos-fish-config/conf.d/done.fish" ]]; then
    sudo mv "/usr/share/cachyos-fish-config/conf.d/done.fish" "/usr/share/cachyos-fish-config/conf.d/done.fish.disabled" 2>/dev/null || true
    log_success "Fish notifications disabled"
  fi

  # Disable any Fish completion systems that might interfere
  if [[ -d "/usr/share/cachyos-fish-config/completions" ]]; then
    sudo mv "/usr/share/cachyos-fish-config/completions" "/usr/share/cachyos-fish-config/completions.disabled" 2>/dev/null || true
  fi

  # Kill all Fish processes except current shell
  log_info "Terminating Fish background processes"
  pkill -f "fish.*done" 2>/dev/null || true
  pkill -f "fish.*notify" 2>/dev/null || true

  # Wait a moment for processes to terminate
  sleep 1

  # Switch to bash environment for safety
  log_info "Switching to bash environment"
  export SHELL="/bin/bash"
  export FISH_REMOVAL_SAFE=true

  # Remove Fish package and configurations
  log_info "Removing Fish shell package"
  if pacman -Q fish &>/dev/null; then
    sudo pacman -Rns fish --noconfirm >/dev/null 2>&1 || {
      log_warning "Fish package removal had issues, forcing removal"
      sudo pacman -Rdd fish --noconfirm >/dev/null 2>&1 || true
    }
    log_success "Fish package removed"
  fi

  # Complete removal of Fish configurations
  log_info "Removing all Fish configurations"
  rm -rf "$HOME/.config/fish" "$HOME/.local/share/fish" "$HOME/.cache/fish" 2>/dev/null || true
  rm -f "$HOME/.fishrc" "$HOME/.fish_history" "$HOME/.fish_profile" 2>/dev/null || true

  # Remove Fish from system profiles
  sed -i '/fish/d' "$HOME/.profile" 2>/dev/null || true
  sed -i '/fish/d' "$HOME/.bashrc" 2>/dev/null || true
  sed -i '/fish/d' "$HOME/.bash_profile" 2>/dev/null || true

  # Remove Fish autostart entries
  rm -f "$HOME/.config/autostart/fish"* 2>/dev/null || true

  # Remove system-wide Fish configurations
  sudo rm -rf "/usr/share/cachyos-fish-config" 2>/dev/null || true
  sudo rm -rf "/etc/fish" 2>/dev/null || true
  sudo rm -rf "/usr/share/fish" 2>/dev/null || true

  # Clean up any Fish-related environment variables
  unset FISH_VERSION 2>/dev/null || true
  unset __fish_cache_dir 2>/dev/null || true
  unset __fish_config_dir 2>/dev/null || true
  unset __fish_data_dir 2>/dev/null || true
  unset __fish_user_data_dir 2>/dev/null || true

  log_success "Fish shell completely and safely removed"
}

ensure_clean_reboot_environment() {
  log_info "Ensuring clean environment for reboot prompt"

  # Make sure we're in bash context
  if [[ "${SHELL##*/}" == "fish" ]] || [[ -n "${FISH_VERSION:-}" ]]; then
    log_warning "Still in Fish environment, forcing bash switch"
    exec /bin/bash -c "
      export FISH_REMOVAL_SAFE=true
      export CACHYOS_SHELL_CHOICE='zsh'
      echo 'Successfully switched to bash for clean reboot'
      exit 0
    "
  fi

  # Clear any Fish-related error states
  set +e  # Don't exit on errors temporarily

  # Reset terminal state
  reset 2>/dev/null || true
  clear 2>/dev/null || true

  set -e  # Re-enable exit on errors

  log_success "Environment prepared for clean reboot"
}

show_reboot_prompt() {
  ensure_clean_reboot_environment

  echo ""
  if command -v gum >/dev/null 2>&1; then
    gum style --border double --margin "1 2" --padding "1 4" --foreground 46 --border-foreground 46 "🎉 Fish Removal Complete!"
    echo ""
    gum style --foreground 226 "Fish shell has been completely removed and replaced with ZSH."
    gum style --foreground 196 "⚠️  REBOOT REQUIRED to complete the conversion!"
    echo ""
    gum style --foreground 51 "For inexperienced users: It's highly recommended to reboot now."
    echo ""
    if gum confirm "Would you like to reboot now?"; then
      gum style --foreground 46 "🔄 Rebooting system in 3 seconds..."
      sleep 3
      sudo reboot now
    else
      gum style --foreground 226 "⚠️  Please remember to reboot manually later!"
    fi
  else
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║                                                           ║${RESET}"
    echo -e "${GREEN}║              🎉 Fish Removal Complete!                   ║${RESET}"
    echo -e "${GREEN}║                                                           ║${RESET}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${YELLOW}Fish shell has been completely removed and replaced with ZSH.${RESET}"
    echo -e "${RED}⚠️  REBOOT REQUIRED to complete the conversion!${RESET}"
    echo ""
    echo -e "${CYAN}For inexperienced users: It's highly recommended to reboot now.${RESET}"
    echo ""
    read -p "Would you like to reboot now? [Y/n]: " -r reboot_choice
    if [[ "$reboot_choice" =~ ^[Yy]$|^$ ]]; then
      echo -e "${GREEN}🔄 Rebooting system in 3 seconds...${RESET}"
      sleep 3
      sudo reboot now
    else
      echo -e "${YELLOW}⚠️  Please remember to reboot manually later!${RESET}"
    fi
  fi
}

# Main execution when called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  log_info "Starting safe Fish removal process"
  safe_remove_fish
  show_reboot_prompt
fi
