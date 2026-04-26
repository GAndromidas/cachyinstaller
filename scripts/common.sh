#!/bin/bash
# CachyInstaller — common entry point
# This is the single entry point. All other scripts should source this file.
set -euo pipefail

# Source constants — must be loaded first
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPTS_DIR/constants.sh" ]]; then
  source "$SCRIPTS_DIR/constants.sh"
fi

# Source modules in dependency order
source "$SCRIPTS_DIR/ui.sh"
source "$SCRIPTS_DIR/logging.sh"
source "$SCRIPTS_DIR/install_helpers.sh"

# Color variables for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'
NC='\033[0m'

# Global arrays and variables
ERRORS=()                   # Collects error messages for summary
INSTALLED_PACKAGES=()       # Tracks installed packages
FAILED_PACKAGES=()          # Tracks packages that failed to install
FAILED_SERVICES=()          # Tracks services that failed to enable

# UI/Flow configuration (defaults, may be overridden by constants.sh)
: "${TOTAL_STEPS:=7}"
: "${VERBOSE:=false}"

# Ensure critical variables are defined
: "${HOME:=/home/$USER}"
: "${USER:=$(whoami)}"
: "${INSTALL_LOG:=$HOME/.cachyinstaller.log}"

# ===== Summary and Cleanup =====

print_summary() {
  echo ""
  ui_warn "=== INSTALL SUMMARY ==="
  [ "${#INSTALLED_PACKAGES[@]}" -gt 0 ] && echo -e "${GREEN}Installed: ${#INSTALLED_PACKAGES[@]} packages${RESET}"
  [ "${#FAILED_PACKAGES[@]}" -gt 0 ] && echo -e "${RED}Failed: ${#FAILED_PACKAGES[@]} packages${RESET}"
  [ "${#ERRORS[@]}" -gt 0 ] && echo -e "${RED}Errors: ${#ERRORS[@]} occurred${RESET}"
  ui_warn "======================="
  echo ""
}

prompt_reboot() {
  local cleanup_dir="$1"
  echo ""
  ui_warn "It is strongly recommended to reboot now to apply all changes."

  local reboot_ans
  if supports_gum; then
    gum confirm "Reboot now?" && reboot_ans="y" || reboot_ans="n"
  else
    read -r -p "Reboot now? [Y/n]: " reboot_ans
  fi

  # On successful installation, perform a self-cleanup.
  if [ ${#ERRORS[@]} -eq 0 ]; then
    ui_info "Performing self-cleanup..."
    sudo pacman -Rns --noconfirm gum >/dev/null 2>&1 || true
    rm -f "$INSTALL_LOG" 2>/dev/null || true
    rm -f "$HOME/.cachyinstaller.state" 2>/dev/null || true
    # CAUTION: This removes the directory the script is in. This must be the last step.
    if [ -n "$cleanup_dir" ] && [ -d "$cleanup_dir" ]; then
      if [[ "${KEEP_DIR:-false}" == "false" ]]; then
        rm -rf "$cleanup_dir"
      else
        ui_info "Installer directory kept at: $cleanup_dir"
      fi
    fi
  fi

  reboot_ans=${reboot_ans,,}
  case "$reboot_ans" in
    ""|y|yes)
      ui_info "Rebooting your system..."
      sudo reboot
      ;;
    *)
      ui_info "Reboot skipped. Please reboot manually."
      ;;
  esac
}

# ===== System validation functions (stay in common.sh) =====

check_system_requirements() {
  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    ui_error "Error: This script should NOT be run as root!"
    ui_warn "Please run as a regular user with sudo privileges."
    exit 1
  fi

  # Check if we're on CachyOS
  if ! grep -q "CachyOS" /etc/os-release; then
    ui_error "Error: This script is designed for CachyOS only!"
    exit 1
  fi

  # Check internet connection
  if ! ping -c 1 cachyos.org &>/dev/null; then
    ui_error "Error: No internet connection detected!"
    ui_warn "Please check your network connection and try again."
    exit 1
  fi

  # Check available disk space
  local available_space
  available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt $MIN_DISK_KB ]]; then
    ui_error "Error: Insufficient disk space! At least 2GB is required."
    exit 1
  fi
}

setup_system_enhancements() {
    # Detect GPU vendor
    if lspci | grep -i "VGA" | grep -i "NVIDIA" >/dev/null; then
        export GPU_VENDOR="nvidia"
    elif lspci | grep -i "VGA" | grep -i "AMD" >/dev/null; then
        export GPU_VENDOR="amd"
    elif lspci | grep -i "VGA" | grep -i "Intel" >/dev/null; then
        export GPU_VENDOR="intel"
    else
        export GPU_VENDOR=""
    fi

    # Detect if it's a laptop
    if [ -d "/sys/class/power_supply" ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        export IS_LAPTOP=true
    else
        export IS_LAPTOP=false
    fi
}

check_pacman_lock() {
    while fuser /var/lib/pacman/db.lck >/dev/null 2>&1; do
        ui_warn "Pacman is locked. Waiting..."
        sleep 5
    done
    return 0
}