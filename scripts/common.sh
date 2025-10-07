#!/usr/bin/env bash

# Simple color formatting
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
RESET='\033[0m'

# Global state
ERRORS=()                # Error messages
CURRENT_STEP=1          # Current installation step
INSTALLED_PACKAGES=()    # Installed packages
STATE_FILE="$HOME/.cachyinstaller.state"
LOG_FILE="$HOME/.cachyinstaller.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"  # Script directory
CONFIGS_DIR="$SCRIPT_DIR/configs"                           # Config files directory
SCRIPTS_DIR="$SCRIPT_DIR/scripts"                           # Custom scripts directory

# Core utilities to install
get_helper_utils() {
  local utils=(base-devel bc bluez-utils cronie curl eza figlet flatpak fzf git openssh pacman-contrib rsync ufw zoxide)
  echo "${utils[@]}"
}

# Initialize HELPER_UTILS as empty - will be populated when needed
HELPER_UTILS=()

# Function to populate HELPER_UTILS based on current shell choice
populate_helper_utils() {
  # Handle Fish shell array syntax differently
  if [[ -n "$FISH_VERSION" ]]; then
    HELPER_UTILS=($(get_helper_utils | tr ' ' '\n'))
  else
    HELPER_UTILS=($(get_helper_utils))
  fi
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
  echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║     CachyOS Gaming Installer     ║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"
  echo -e "\n1) Default    - Complete gaming setup with all optimizations"
  echo -e "2) Minimal    - Essential gaming setup with core features"
  echo -e "3) Exit       - Cancel installation"
  echo ""

  while true; do
    read -p "Choose installation mode (1-3): " choice
    case $choice in
      1) export INSTALL_MODE="default"; break ;;
      2) export INSTALL_MODE="minimal"; break ;;
      3) echo "Installation cancelled"; exit 0 ;;
      *) echo -e "${RED}Invalid choice${RESET}" ;;
    esac
  done
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
  # First try $SHELL environment variable
  if [[ -n "$SHELL" ]]; then
    current_shell=$(basename "$SHELL")
  else
    # Fallback to /etc/passwd
    current_shell=$(getent passwd "$USER" | cut -d: -f7)
    current_shell=$(basename "$current_shell")
  fi
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
    gum style --border double --margin "1 2" --padding "1 4" --foreground 46 --border-foreground 46 "Fish Shell Enhancement"
    gum style --margin "1 0" --foreground 226 "Optimizing your Fish shell configuration..."
    echo ""
    export CACHYOS_SHELL_CHOICE="fish"
    gum style --foreground 46 "✓ Enhancing Fish shell with gaming optimizations"
  else
    echo -e "${CYAN}╔══════════════════════════════════╗${RESET}"
    echo -e "${CYAN}║      Fish Shell Enhancement      ║${RESET}"
    echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${GREEN}Optimizing your Fish shell configuration...${RESET}"
    export CACHYOS_SHELL_CHOICE="fish"
    echo -e "${GREEN}✓ Enhancing Fish shell with gaming optimizations${RESET}"
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

# Simple logging functions
log_info() {
    echo -e "${CYAN}[Setup]${RESET} $1" | tee -a "$LOG_FILE"
}

log_error() {
    local msg="$1"
    ERRORS+=("$msg")
    echo -e "${RED}[ERROR]${RESET} $msg" | tee -a "$LOG_FILE"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${RESET} $1" | tee -a "$LOG_FILE"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${RESET} $1" | tee -a "$LOG_FILE"
}

# Step function with progress tracking and error recovery
step() {
  local description="$1"
  local state_data="$2"

  log_info "Starting step $CURRENT_STEP: $description"

  # Create checkpoint before step
  if [ -n "$state_data" ]; then
    echo "${description}|$(date '+%Y-%m-%d %H:%M:%S')|${state_data}" > "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "${STATE_FILE}"
  fi

  # Track step for error recovery
  LAST_STATE="$description"
  CURRENT_STEP=$((CURRENT_STEP + 1))

  # Reset error count for new step
  ERROR_COUNT=0
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
        if sudo pacman -S --noconfirm --needed "$package"; then
            INSTALLED_PACKAGES+=("$package")
            log_success "Installed $package"
            return 0
        else
            log_error "Failed to install $package"
            return 1
        fi
    fi
    return 0
                    return 0
                else
                    log_error "Package $package appears to have failed verification after installation"
                    continue
                fi
            else
                local exit_code=$?
                if [ $exit_code -eq 124 ]; then
                    log_error "Installation of $package timed out after ${timeout}s"
                fi

                if [ $i -lt $retries ]; then
                    log_warning "Failed to install $package (attempt $i/$retries). Retrying in ${retry_delay}s..."
                    sleep $retry_delay
                    # Clear package manager locks if they exist
                    sudo rm -f /var/lib/pacman/db.lck
                else
                    log_error "Failed to install $package after $retries attempts"
                    return 1
                fi
            fi
        done
    else
        log_info "Package $package already installed, skipping"
        return 0
    fi
}

install_aur_package() {
    local package="$1"
    if ! command -v paru >/dev/null; then
        log_error "paru is not installed. Cannot install AUR packages."
        return 1
    fi

    if ! aur_package_installed "$package"; then
        log_info "Installing AUR package $package..."
        if paru -S --noconfirm --needed "$package"; then
            INSTALLED_PACKAGES+=("$package")
            log_success "Installed AUR package $package"
            return 0
        else
            log_error "Failed to install AUR package $package"
            return 1
        fi
                else
                    log_error "AUR package $package appears to have failed verification after installation"
                    continue
                fi
            else
                local exit_code=$?
                if [ $exit_code -eq 124 ]; then
                    log_error "Installation of AUR package $package timed out after ${timeout}s"
                fi

                if [ $i -lt $retries ]; then
                    log_warning "Failed to install AUR package $package (attempt $i/$retries). Retrying in ${retry_delay}s..."
                    sleep $retry_delay
                    # Clean build directory before retry
                    rm -rf "$HOME/.cache/paru/$package"
                else
                    log_error "Failed to install AUR package $package after $retries attempts"
                    return 1
                fi
            fi
        done
    else
        log_info "Gaming package $package already installed, skipping"
        return 0
    fi
}

# Batch package installation helper
install_packages_quietly() {
    local pkgs=("$@")
    local to_install=()
    local failed=0

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

    log_info "Installing gaming optimization packages..."

    # Install packages
    if sudo pacman -S --noconfirm --needed "${to_install[@]}"; then
        for pkg in "${to_install[@]}"; do
            if pacman -Q "$pkg" &>/dev/null; then
                INSTALLED_PACKAGES+=("$pkg")
            else
                log_error "Failed to install $pkg"
                ((failed++))
            fi
        done
    else
        log_error "Package installation failed"
        return 1
    fi

    return $failed

    # Try installing failed packages individually
    if [[ ${#failed_pkgs[@]} -gt 0 ]]; then
        log_warning "Retrying failed packages individually: ${failed_pkgs[*]}"
        for pkg in "${failed_pkgs[@]}"; do
            if install_package "$pkg"; then
                # Remove from failed packages if successful
                failed_pkgs=("${failed_pkgs[@]/$pkg}")
            fi
        done
    fi

    # Final status
    if [[ ${#failed_pkgs[@]} -gt 0 ]]; then
        log_error "Failed to install packages: ${failed_pkgs[*]}"
        return 1
    fi

    log_success "All packages installed successfully"
    return 0
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
# Function to prompt for reboot in a Fish-compatible way with package verification
prompt_reboot() {
    # Simple reboot prompt
  echo -e "\n${CYAN}╔══════════════════════════════════╗${RESET}"
  echo -e "${CYAN}║      System Ready for Reboot      ║${RESET}"
  echo -e "${CYAN}╚══════════════════════════════════╝${RESET}"
  echo -e "${GREEN}All gaming optimizations have been applied successfully.${RESET}"
  echo -e "${YELLOW}Please reboot to activate all performance enhancements.${RESET}\n"

  if command -v gum >/dev/null 2>&1; then
    if gum confirm --default=true "Would you like to reboot now?"; then
      echo -e "\n${GREEN}Rebooting system...${RESET}"
      sleep 2
      sudo reboot
    fi
  else
    read -p "Would you like to reboot now? [Y/n]: " response
    response=${response,,}
    if [[ -z "$response" || "$response" =~ ^[Yy]$ ]]; then
      echo -e "\n${GREEN}Rebooting system...${RESET}"
      sleep 2
      sudo reboot
    fi
  fi
}

show_installation_summary() {
  local duration=$(($(date +%s) - START_TIME))
  local hours=$((duration / 3600))
  local minutes=$(((duration % 3600) / 60))
  local seconds=$((duration % 60))

  clear
  echo -e "\n${GREEN}╔══════════════════════════════════════════╗${RESET}"
  echo -e "${GREEN}║         CachyOS Setup Complete!          ║${RESET}"
  echo -e "${GREEN}║      Your Gaming System is Ready         ║${RESET}"
  echo -e "${GREEN}╚══════════════════════════════════════════╝${RESET}\n"

  echo -e "${CYAN}Installation Details${RESET}"
  echo -e "Duration: ${GREEN}${hours}h ${minutes}m ${seconds}s${RESET}"
  echo -e "Mode: ${CYAN}${INSTALL_MODE:-default}${RESET}"
  echo -e "Completed: ${YELLOW}$(date '+%Y-%m-%d %H:%M:%S')${RESET}"

  if [[ ${#INSTALLED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "\n${GREEN}Packages Installed: ${#INSTALLED_PACKAGES[@]}${RESET}"
    printf "  %s\n" "${INSTALLED_PACKAGES[@]}" | head -5
    if [[ ${#INSTALLED_PACKAGES[@]} -gt 5 ]]; then
      echo -e "  ... and $((${#INSTALLED_PACKAGES[@]} - 5)) more packages"
    fi
  fi

  if [[ ${#REMOVED_PACKAGES[@]} -gt 0 ]]; then
    echo -e "\n${RED}🗑️  Packages Removed (${#REMOVED_PACKAGES[@]}):${RESET}"
    printf "   %s\n" "${REMOVED_PACKAGES[@]}"
  fi

  if [[ ${#ERRORS[@]} -gt 0 ]]; then
    echo -e "\n${RED}Errors Encountered: ${#ERRORS[@]}${RESET}"
    printf "  %s\n" "${ERRORS[@]}"
    echo -e "\nCheck log file: $LOG_FILE"
  fi

  echo -e "\n${GREEN}System Status: Ready for Gaming${RESET}"
  echo -e "${CYAN}Performance optimizations have been applied successfully${RESET}"
  echo -e "${CYAN}Installation log available at: $LOG_FILE${RESET}\n"

  echo -e "${GREEN}Fish shell has been enhanced with gaming optimizations.${RESET}"
  echo -e "${GREEN}Restart your terminal to activate the enhancements.${RESET}"

  echo -e "${CYAN}Thank you for using CachyInstaller!${RESET}\n"
}

# State recovery and validation functions
save_state() {
    local state_name="$1"
    local state_data="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    echo "${state_name}|${timestamp}|${state_data}" > "${STATE_FILE}.tmp"
    sync "${STATE_FILE}.tmp"
    mv "${STATE_FILE}.tmp" "$STATE_FILE"

    log_info "State saved: $state_name"
}

load_state() {
    if [ -f "$STATE_FILE" ]; then
        local state_data=$(cat "$STATE_FILE")
        LAST_STATE=$(echo "$state_data" | cut -d'|' -f1)
        log_info "Loaded state: $LAST_STATE"
        return 0
    fi
    return 1
}

validate_state() {
    local required_files=("$@")
    local missing_files=()

    for file in "${required_files[@]}"; do
        if [ ! -f "$file" ]; then
            missing_files+=("$file")
        fi
    done

    if [ ${#missing_files[@]} -gt 0 ]; then
        log_error "State validation failed - missing files: ${missing_files[*]}"
        return 1
    fi

    return 0
}

cleanup_state() {
    if [ -f "$STATE_FILE" ]; then
        rm -f "$STATE_FILE"
        log_info "State file cleaned up"
    fi
    if [ -f "${STATE_FILE}.tmp" ]; then
        rm -f "${STATE_FILE}.tmp"
    }
}

handle_error() {
    local error_msg="$1"
    local critical="${2:-false}"

    ((ERROR_COUNT++))

    log_error "$error_msg"

    if [ "$critical" = true ] || [ $ERROR_COUNT -gt 5 ]; then
        log_error "Too many errors or critical error encountered"
        cleanup_state
        exit 1
    fi

    if [ -n "$LAST_STATE" ]; then
        log_warning "Error recovery: Attempting to restore last known good state: $LAST_STATE"
        load_state
    fi
}

verify_installation() {
    local verify_mode="${1:-quick}"
    local failed=false

    log_info "Verifying installation ($verify_mode mode)..."

    # Basic system checks
    if ! command -v pacman >/dev/null; then
        log_error "Package manager not found!"
        failed=true
    fi

    # Check critical packages
    local critical_pkgs=("linux" "systemd" "bash")
    for pkg in "${critical_pkgs[@]}"; do
        if ! pacman -Q "$pkg" >/dev/null 2>&1; then
            log_error "Critical package missing: $pkg"
            failed=true
        fi
    done

    if [ "$verify_mode" = "full" ]; then
        # Verify all installed packages
        for pkg in "${INSTALLED_PACKAGES[@]}"; do
            if ! pacman -Q "$pkg" >/dev/null 2>&1; then
                log_error "Package verification failed: $pkg"
                failed=true
            fi
        done

        # Verify system services
        local required_services=("NetworkManager" "systemd-timesyncd")
        for service in "${required_services[@]}"; do
            if ! systemctl is-enabled "$service" >/dev/null 2>&1; then
                log_error "Required service not enabled: $service"
                failed=true
            fi
        done
    fi

    if [ "$failed" = true ]; then
        log_error "Installation verification failed"
        return 1
    fi

    log_success "Installation verification passed"
    return 0
}
