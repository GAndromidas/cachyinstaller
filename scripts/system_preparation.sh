#!/bin/bash
set -uo pipefail

# CachyOS System Preparation - Only what CachyOS doesn't manage
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

check_prerequisites() {
  step "Checking system prerequisites"
  check_root_user
  if ! command -v pacman >/dev/null; then
    log_error "This script is intended for CachyOS systems with pacman"
    return 1
  fi
  log_success "Prerequisites OK"
}

update_system() {
  step "Updating system packages"
  log_info "Updating system packages..."

  if sudo pacman -Syu --noconfirm; then
    log_success "System packages updated"
  else
    log_warning "Some packages may not have updated - continuing installation"
  fi
}

install_helper_packages() {
  step "Installing helper utilities"
  local helper_packages=("${HELPER_UTILS[@]}")

  log_info "Installing ${#helper_packages[@]} helper utilities..."
  install_packages_quietly "${helper_packages[@]}"
}

install_shell_packages() {
  step "Installing shell packages"

  if [[ "${CACHYOS_SHELL_CHOICE:-}" == "fish" ]]; then
    log_info "Keeping Fish shell - no additional shell packages needed"
    log_success "Fish shell configuration preserved"
    return 0
  fi

  # Install ZSH and related packages for shell conversion
  local shell_packages=(
    "zsh"
    "zsh-autosuggestions"
    "zsh-syntax-highlighting"
    "starship"
  )

  log_info "Installing ZSH shell packages for Fish conversion..."
  install_packages_quietly "${shell_packages[@]}"
}

set_sudo_pwfeedback() {
  step "Enabling sudo password feedback (asterisks)"

  if ! sudo grep -q '^Defaults.*pwfeedback' /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
    log_info "Enabling sudo password feedback (asterisks)"
    echo 'Defaults env_reset,pwfeedback' | sudo EDITOR='tee -a' visudo &>/dev/null
    log_success "Sudo password feedback enabled"
  else
    log_info "Sudo password feedback already enabled"
  fi
}

generate_locales() {
  step "Generating locales"
  log_info "Generating system locales..."
  if sudo sed -i 's/#el_GR.UTF-8 UTF-8/el_GR.UTF-8 UTF-8/' /etc/locale.gen && sudo locale-gen &>/dev/null; then
    log_success "Locales generated successfully"
  else
    log_warning "Locale generation had issues but continuing"
  fi
}

# Main execution
main() {
  log_info "Starting CachyOS system preparation..."

  check_prerequisites || { log_error "Prerequisites check failed"; return 1; }
  update_system || { log_error "System update failed"; return 1; }
  install_helper_packages || { log_error "Helper packages installation failed"; return 1; }
  install_shell_packages || { log_error "Shell packages installation failed"; return 1; }
  set_sudo_pwfeedback || { log_warning "Sudo feedback setup had issues"; }
  generate_locales || { log_warning "Locale generation had issues"; }

  log_success "CachyOS system preparation completed successfully"
}

# Run the main function
main
