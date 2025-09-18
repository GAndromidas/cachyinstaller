#!/bin/bash

# Color variables for output formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Terminal formatting helpers
TERM_WIDTH=$(tput cols 2>/dev/null || echo 80)

# Global arrays and variables
ERRORS=()                # Collects error messages for summary
CURRENT_STEP=1           # Tracks current step for progress display
INSTALLED_PACKAGES=()    # Tracks installed packages
REMOVED_PACKAGES=()      # Tracks removed packages

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # Script directory
CONFIGS_DIR="$SCRIPT_DIR/configs"                           # Config files directory
SCRIPTS_DIR="$SCRIPT_DIR/scripts"                           # Custom scripts directory

# Helper utilities to install - conditionally includes ZSH packages
get_helper_utils() {
  local utils=(base-devel bc bluez-utils cronie curl eza figlet flatpak fzf git openssh pacman-contrib rsync ufw)

  # Add ZSH-related utilities only if not keeping Fish on CachyOS
  if [[ "${CACHYOS_SHELL_CHOICE:-}" != "fish" ]]; then
    utils+=(zoxide)
  fi

  echo "${utils[@]}"
}

# Initialize HELPER_UTILS as empty - will be populated when needed
HELPER_UTILS=()

# Function to populate HELPER_UTILS based on current shell choice
populate_helper_utils() {
  HELPER_UTILS=($(get_helper_utils))
}

# Ensure critical variables are defined
: "${HOME:=/home/$USER}"
: "${USER:=$(whoami)}"
: "${XDG_CURRENT_DESKTOP:=}"



# Utility/Helper Functions
figlet_banner() {
  local title="$1"
  if command -v figlet >/dev/null 2>/dev/null; then
    echo -e "${CYAN}"
    figlet "$title"
    echo -e "${RESET}"
  else
    echo -e "${CYAN}========== $title ==========${RESET}"
  fi
}

cachy_ascii() {
  echo -e "${CYAN}"
  cat << "EOF"
   ____           _            ___           _        _ _
  / ___|__ _  ___| |__  _   _ |_ _|_ __  ___| |_ __ _| | | ___ _ __
 | |   / _` |/ __| '_ \| | | | | || '_ \/ __| __/ _` | | |/ _ \ '__|
 | |__| (_| | (__| | | | |_| | | || | | \__ \ || (_| | | |  __/ |
  \____\__,_|\___|_| |_|\__, ||___|_| |_|___/\__\__,_|_|_|\___|_|
                        |___/

EOF
  echo -e "${RESET}"
}

show_menu() {
  # Check if gum is available, fallback to traditional menu if not
  if command -v gum >/dev/null 2>&1; then
    show_gum_menu
  else
    show_traditional_menu
  fi
}

show_gum_menu() {
  echo ""
  gum style --border double --margin "1 2" --padding "1 4" --foreground 46 --border-foreground 46 "Welcome to CachyInstaller!"
  gum style --margin "1 0" --foreground 226 "Choose your installation mode:"
  echo ""

  # Installation mode selection using gum
  local choice=$(gum choose \
    "1) Default - Complete setup with essential packages and configurations" \
    "2) Minimal - Essential tools only, faster installation" \
    "3) Exit - Cancel installation" \
    --selected="1) Default - Complete setup with essential packages and configurations" \
    --cursor-prefix="▶ " \
    --selected-prefix="✓ " \
    --unselected-prefix="  ")

  case "$choice" in
    "1) Default"*)
      export INSTALL_MODE="default"
      gum style --foreground 51 "✓ Selected: Default installation"
      ;;
    "2) Minimal"*)
      export INSTALL_MODE="minimal"
      gum style --foreground 46 "✓ Selected: Minimal installation"
      ;;
    "3) Exit"*)
      gum style --foreground 196 "Installation cancelled by user"
      exit 0
      ;;
    *)
      gum style --foreground 196 "Invalid selection. Exiting."
      exit 1
      ;;
  esac
}

show_traditional_menu() {
  echo ""
  echo -e "${GREEN}===============================================${RESET}"
  echo -e "${GREEN}       Welcome to CachyInstaller!${RESET}"
  echo -e "${GREEN}===============================================${RESET}"
  echo ""
  echo -e "${YELLOW}Choose your installation mode:${RESET}"
  echo ""
  echo -e "  ${CYAN}1)${RESET} Default - Complete setup with essential packages and configurations"
  echo -e "     ${GREEN}Gaming packages always included${RESET}"
  echo ""
  echo -e "  ${CYAN}2)${RESET} Minimal - Essential tools only, faster installation"
  echo -e "     ${GREEN}Gaming packages always included${RESET}"
  echo ""
  echo -e "  ${CYAN}3)${RESET} Exit - Cancel installation"
  echo ""

  while true; do
    read -p "Enter your choice (1-3): " choice
    case $choice in
          1)
            export INSTALL_MODE="default"
            echo -e "\n${BLUE}✓ Selected: Default installation${RESET}"
            break
            ;;
          2)
            export INSTALL_MODE="minimal"
            echo -e "\n${GREEN}✓ Selected: Minimal installation${RESET}"
            break
            ;;
          3)
            echo -e "\n${RED}Installation cancelled by user${RESET}"
            exit 0
            ;;
          *)
            echo -e "${RED}Invalid option. Please choose 1, 2, or 3.${RESET}"
            ;;
    esac
  done
}

# Function to get current shell and detect if it's fish
get_current_shell() {
  local current_shell=""
  # Check user's shell from /etc/passwd
  current_shell=$(getent passwd "$USER" | cut -d: -f7)
  # Get just the shell name
  current_shell=$(basename "$current_shell")
  echo "$current_shell"
}

# Function to detect if fish is the default shell (common in CachyOS)
is_fish_shell() {
  local shell=$(get_current_shell)
  [[ "$shell" == "fish" ]]
}

# Function to show shell choice menu for Fish users
show_shell_choice_menu() {
  if ! is_fish_shell; then
    return 0  # Not a Fish user, no need to show menu
  fi

  echo ""
  if command -v gum >/dev/null 2>&1; then
    gum style --border double --margin "1 2" --padding "1 4" --foreground 226 --border-foreground 226 "🐠 Fish Shell Detected!"
    gum style --margin "1 0" --foreground 226 "CachyOS uses Fish shell by default. Choose how to proceed:"
    echo ""

    local choice=$(gum choose \
      "Keep Fish - Enhance with CachyInstaller features (preserves your Fish config)" \
      "Switch to ZSH - Replace Fish with ZSH + Oh-My-Zsh (REMOVES Fish completely!)" \
      --selected="Keep Fish - Enhance with CachyInstaller features (preserves your Fish config)" \
      --cursor-prefix="▶ " \
      --selected-prefix="✓ " \
      --unselected-prefix="  ")

    case "$choice" in
      "Keep Fish"*)
        export CACHYOS_SHELL_CHOICE="fish"
        gum style --foreground 46 "✓ Fish shell will be kept and enhanced"
        ;;
      "Switch to ZSH"*)
        gum style --foreground 196 --border normal --border-foreground 196 --margin "1 0" --padding "1 2" "⚠️  WARNING: This will PERMANENTLY DELETE Fish shell!"
        gum style --foreground 196 "All Fish configurations, history, and customizations will be LOST!"
        echo ""
        if gum confirm "Are you absolutely sure you want to remove Fish shell?"; then
          export CACHYOS_SHELL_CHOICE="zsh"
          gum style --foreground 226 "✓ Fish will be replaced with ZSH"
        else
          export CACHYOS_SHELL_CHOICE="fish"
          gum style --foreground 46 "✓ Keeping Fish shell (wise choice!)"
        fi
        ;;
    esac
  else
    echo -e "${YELLOW}===============================================${RESET}"
    echo -e "${YELLOW}       🐠 Fish Shell Detected!${RESET}"
    echo -e "${YELLOW}===============================================${RESET}"
    echo ""
    echo -e "${CYAN}CachyOS uses Fish shell by default. Choose how to proceed:${RESET}"
    echo ""
    echo -e "  ${GREEN}1)${RESET} Keep Fish - Enhance with CachyInstaller features"
    echo -e "     ${GREEN}Preserves your Fish configuration${RESET}"
    echo ""
    echo -e "  ${RED}2)${RESET} Switch to ZSH - Replace Fish with ZSH + Oh-My-Zsh"
    echo -e "     ${RED}⚠️  REMOVES Fish shell completely!${RESET}"
    echo ""

    while true; do
      read -p "Enter your choice (1-2): " choice
      case $choice in
        1)
          export CACHYOS_SHELL_CHOICE="fish"
          echo -e "\n${GREEN}✓ Fish shell will be kept and enhanced${RESET}"
          break
          ;;
        2)
          echo -e "\n${RED}⚠️  WARNING: This will PERMANENTLY DELETE Fish shell!${RESET}"
          echo -e "${RED}All Fish configurations, history, and customizations will be LOST!${RESET}"
          echo ""
          read -p "Are you absolutely sure you want to remove Fish shell? (y/N): " confirm
          if [[ "$confirm" =~ ^[Yy]$ ]]; then
            export CACHYOS_SHELL_CHOICE="zsh"
            echo -e "${YELLOW}✓ Fish will be replaced with ZSH${RESET}"
            break
          else
            export CACHYOS_SHELL_CHOICE="fish"
            echo -e "${GREEN}✓ Keeping Fish shell (wise choice!)${RESET}"
            break
          fi
          ;;
        *)
          echo -e "${RED}Invalid option. Please choose 1 or 2.${RESET}"
          ;;
      esac
    done
  fi
}

# Show CachyOS specific information
show_cachyos_info() {
  echo -e "\n${CYAN}═══ CachyOS Gaming Installation (${INSTALL_MODE^} Mode) ═══${RESET}"
  echo -e "${GREEN}What will be installed:${RESET}"

  if [[ "${INSTALL_MODE}" == "minimal" ]]; then
    echo -e "  • ${CYAN}Essential tools only (faster installation)${RESET}"
  else
    echo -e "  • ${CYAN}Complete setup with essential packages${RESET}"
  fi

  echo -e "  • ${CYAN}Gaming packages (Steam, Lutris, Wine, etc.) - Always included${RESET}"
  echo -e "  • ${CYAN}Security setup (Fail2ban, UFW)${RESET}"
  echo -e "  • ${CYAN}System services and optimizations${RESET}"

  if [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
    echo -e "  • ${RED}Fish→ZSH conversion${RESET} - Fish will be COMPLETELY REMOVED!"
  elif [[ "${CACHYOS_SHELL_CHOICE:-}" == "fish" ]]; then
    echo -e "  • ${GREEN}Fish shell enhancement${RESET} - Configuration preserved"
  else
    echo -e "  • ${YELLOW}Shell setup and optimization${RESET}"
  fi

  echo -e ""
  echo -e "${GREEN}CachyOS optimizations preserved:${RESET}"
  echo -e "  • ${CYAN}Performance tweaks and repositories${RESET}"
  echo -e "  • ${CYAN}System optimizations and configurations${RESET}"
  echo -e "${CYAN}══════════════════════════════════════${RESET}\n"
}

# Log functions
log_info() {
  echo -e "${CYAN}[INFO]${RESET} $1" | tee -a "$HOME/cachyinstaller.log"
}

log_error() {
  local error_msg="$1"
  ERRORS+=("$error_msg")
  echo -e "${RED}[ERROR]${RESET} $error_msg" | tee -a "$HOME/cachyinstaller.log"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${RESET} $1" | tee -a "$HOME/cachyinstaller.log"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${RESET} $1" | tee -a "$HOME/cachyinstaller.log"
}

# Step function with progress tracking
step() {
  local description="$1"
  log_info "Starting step $CURRENT_STEP: $description"
  CURRENT_STEP=$((CURRENT_STEP + 1))
}

# System checks
check_root_user() {
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}❌ This script should NOT be run as root!${RESET}"
    echo -e "${YELLOW}   Please run as a regular user with sudo privileges.${RESET}"
    echo -e "${YELLOW}   The script will request sudo access when needed.${RESET}"
    exit 1
  fi
}

# Package management helpers
package_installed() {
  pacman -Qi "$1" &>/dev/null
}

aur_package_installed() {
  pacman -Qi "$1" &>/dev/null
}

install_package() {
  local package="$1"
  if ! package_installed "$package"; then
    log_info "Installing $package..."
    if sudo pacman -S --noconfirm "$package"; then
      INSTALLED_PACKAGES+=("$package")
      log_success "Successfully installed $package"
    else
      log_error "Failed to install $package"
      return 1
    fi
  else
    log_info "Package $package already installed, skipping"
  fi
}

install_aur_package() {
  local package="$1"
  if ! aur_package_installed "$package"; then
    log_info "Installing AUR package $package..."
    if paru -S --noconfirm "$package"; then
      INSTALLED_PACKAGES+=("$package")
      log_success "Successfully installed AUR package $package"
    else
      log_error "Failed to install AUR package $package"
      return 1
    fi
  else
    log_info "AUR package $package already installed, skipping"
  fi
}

# Batch package installation helper
install_packages_quietly() {
  local pkgs=("$@")
  local to_install=()

  # Filter out already installed packages
  for pkg in "${pkgs[@]}"; do
    if ! pacman -Q "$pkg" &>/dev/null; then
      to_install+=("$pkg")
    fi
  done

  if [[ ${#to_install[@]} -eq 0 ]]; then
    log_info "All packages already installed"
    return 0
  fi

  log_info "Installing ${#to_install[@]} packages: ${to_install[*]}"

  if sudo pacman -S --noconfirm --needed "${to_install[@]}"; then
    for pkg in "${to_install[@]}"; do
      INSTALLED_PACKAGES+=("$pkg")
    done
    log_success "Successfully installed packages"
  else
    log_error "Some packages failed to install"
    return 1
  fi
}

# Utility functions
get_locale_date() {
  date '+%Y-%m-%d %H:%M:%S'
}

get_desktop_environment() {
  if [[ -n "$XDG_CURRENT_DESKTOP" ]]; then
    echo "$XDG_CURRENT_DESKTOP"
  elif [[ -n "$DESKTOP_SESSION" ]]; then
    echo "$DESKTOP_SESSION"
  else
    echo "Unknown"
  fi
}

# Installation summary
show_installation_summary() {
  local end_time=$(date +%s)
  local duration=$((end_time - START_TIME))
  local hours=$((duration / 3600))
  local minutes=$(((duration % 3600) / 60))
  local seconds=$((duration % 60))

  echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║                    INSTALLATION COMPLETE                     ║${RESET}"
  echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}\n"

  echo -e "${CYAN}📊 Installation Summary:${RESET}"
  echo -e "   Duration: ${hours}h ${minutes}m ${seconds}s"
  echo -e "   Install Mode: ${INSTALL_MODE:-default}"
  echo -e "   Date: $(get_locale_date)"

  if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "\n${GREEN}📦 Packages Installed (${#INSTALLED_PACKAGES[@]}):${RESET}"
    printf "   %s\n" "${INSTALLED_PACKAGES[@]}" | head -10
    if [[ ${#INSTALLED_PACKAGES[@]} -gt 10 ]]; then
      echo -e "   ... and $((${#INSTALLED_PACKAGES[@]} - 10)) more packages"
    fi
  fi

  if [[ ${#REMOVED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "\n${RED}🗑️  Packages Removed (${#REMOVED_PACKAGES[@]}):${RESET}"
    printf "   %s\n" "${REMOVED_PACKAGES[@]}"
  fi

  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo -e "\n${RED}⚠️  Errors Encountered (${#ERRORS[@]}):${RESET}"
    printf "   %s\n" "${ERRORS[@]}"
    echo -e "\n${YELLOW}💡 Check the log file for more details: $HOME/cachyinstaller.log${RESET}"
  fi

  echo -e "\n${GREEN}🎉 CachyInstaller has finished setting up your gaming system!${RESET}"
  echo -e "${CYAN}📝 Log file saved to: $HOME/cachyinstaller.log${RESET}\n"

  if [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
    echo -e "${RED}⚠  REBOOT REQUIRED to complete shell changes!${RESET}"
    echo -e "${YELLOW}   Fish has been completely removed and replaced with ZSH.${RESET}"
    echo -e "${YELLOW}   For inexperienced users: Reboot now to avoid any issues!${RESET}"
  elif [[ "${CACHYOS_SHELL_CHOICE:-}" == "fish" ]]; then
    echo -e "${GREEN}🐠 Your Fish shell has been enhanced with new features.${RESET}"
    echo -e "${GREEN}   Restart your terminal to see the changes.${RESET}"
  else
    echo -e "${YELLOW}🔄 A reboot is recommended to apply all changes.${RESET}"
  fi

  echo -e "${CYAN}Thank you for using CachyInstaller! 🚀${RESET}\n"
}
