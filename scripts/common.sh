#!/bin/bash
set -uo pipefail

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

# UI/Flow configuration
TOTAL_STEPS=7
: "${VERBOSE:=false}"   # Can be overridden/exported by caller

# Ensure critical variables are defined
: "${HOME:=/home/$USER}"
: "${USER:=$(whoami)}"
: "${INSTALL_LOG:=$HOME/.cachyinstaller.log}"

# ===== Logging Functions =====

# Function to save log on exit
save_log_on_exit() {
  {
    echo ""
    echo "=========================================="
    echo "Installation ended: $(date)"
    echo "=========================================="
  } >> "$INSTALL_LOG"
}

# ===== UI Helper Functions =====

supports_gum() {
  command -v gum >/dev/null 2>&1
}

ui_info() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 226 "$message"
  else
    echo -e "${YELLOW}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

ui_success() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 46 "$message"
  else
    echo -e "${GREEN}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

ui_warn() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 226 "$message"
  else
    echo -e "${YELLOW}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

ui_error() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 196 "$message"
  else
    echo -e "${RED}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

print_header() {
  local title="$1"; shift
  if supports_gum; then
    gum style --border double --margin "1 2" --padding "1 4" --foreground 51 --border-foreground 51 "$title"
    while (( "$#" )); do
      gum style --margin "1 0 0 0" --foreground 226 "$1"
      shift
    done
  else
    echo -e "${CYAN}----------------------------------------------------------------${RESET}"
    echo -e "${CYAN}$title${RESET}"
    echo -e "${CYAN}----------------------------------------------------------------${RESET}"
    while (( "$#" )); do
      echo -e "${YELLOW}$1${RESET}"
      shift
    done
  fi
}

print_step_header() {
  local step_num="$1"; local total="$2"; local title="$3"
  echo ""
  if supports_gum; then
    gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step ${step_num}/${total}: ${title}"
  else
    echo -e "${CYAN}Step ${step_num}/${total}: ${title}${RESET}"
  fi
}

cachy_ascii() {
  echo -e "${CYAN}"
  cat << "EOF"
   ____           _           ___           _        _ _
  / ___|__ _  ___| |__  _   _|_ _|_ __  ___| |_ __ _| | | ___ _ __
 | |   / _` |/ __| '_ \| | | || || '_ \/ __| __/ _` | | |/ _ \ '__|
 | |__| (_| | (__| | | | |_| || || | | \__ \ || (_| | | |  __/ |
  \____\__,_|\___|_| |_|\__, |___|_| |_|___/\__\__,_|_|_|\___|_|
                        |___/
EOF
  echo -e "${NC}"
}

show_menu() {
  if supports_gum; then
    show_gum_menu
  else
    show_traditional_menu
  fi
}

show_gum_menu() {
  gum style --margin "1 0" --foreground 226 "This script will enhance your CachyOS installation with additional"
  gum style --margin "0 0 1 0" --foreground 226 "tools, security, and performance optimizations."

  local choice
  choice=$(gum choose --cursor="-> " --selected.foreground 51 --cursor.foreground 51 \
    "Standard - Complete setup with all recommended packages" \
    "Minimal - Essential tools only for a lightweight system" \
    "Exit - Cancel installation")

  case "$choice" in
    "Standard"*)
      INSTALL_MODE="default"
      ui_success "Selected: Standard installation"
      ;;
    "Minimal"*)
      INSTALL_MODE="minimal"
      ui_success "Selected: Minimal installation"
      ;;

    "Exit"*)
      ui_info "Installation cancelled."
      exit 0
      ;;
  esac
}

show_traditional_menu() {
  echo -e "${CYAN}Choose your installation mode:${RESET}"
  echo "  1) Standard - Complete setup with all recommended packages"
  echo "  2) Minimal - Essential tools only for a lightweight system"
  echo "  3) Exit - Cancel installation"

  local menu_choice
  while true; do
    read -r -p "Enter your choice [1-3]: " menu_choice
    case "$menu_choice" in
      1) INSTALL_MODE="default"; ui_success "Selected: Standard"; break ;;
      2) INSTALL_MODE="minimal"; ui_success "Selected: Minimal"; break ;;
      3) ui_info "Installation cancelled."; exit 0 ;;
      *) ui_error "Invalid choice! Please enter 1, 2, or 3." ;;
    esac
  done
}

# ===== Step and Logging Functions =====

step() {
  echo -e "\n${CYAN}> $1${RESET}" | tee -a "$INSTALL_LOG"
}

log_error() {
  echo -e "${RED}Error: $1${RESET}" | tee -a "$INSTALL_LOG"
  ERRORS+=("$1")
}

# ===== Package Management =====

install_package_generic() {
  local pkg_manager="$1"
  shift
  local pkgs=("$@")
  local total=${#pkgs[@]}
  local current=0
  local failed=0

  if [ $total -eq 0 ]; then
    return 0
  fi

  ui_info "Installing ${total} packages via ${pkg_manager}..."

  for pkg in "${pkgs[@]}"; do
    ((current++))
    local pkg_name
    pkg_name=$(echo "$pkg" | awk '{print $1}')

    local already_installed=false
    case "$pkg_manager" in
      pacman) pacman -Q "$pkg_name" &>/dev/null && already_installed=true ;;
      flatpak) flatpak list | grep -q "$pkg_name" &>/dev/null && already_installed=true ;;
    esac

    if [ "$already_installed" = true ]; then
      $VERBOSE && ui_info "[$current/$total] $pkg_name [SKIP] Already installed"
      continue
    fi

    $VERBOSE && ui_info "[$current/$total] Installing $pkg_name..."

    local install_cmd
    case "$pkg_manager" in
      pacman) install_cmd="sudo pacman -S --noconfirm --needed $pkg" ;;
      flatpak) install_cmd="flatpak install --noninteractive -y $pkg" ;;
    esac

    if [ "${DRY_RUN:-false}" = true ]; then
      ui_info "[$current/$total] $pkg_name [DRY-RUN] Would execute: $install_cmd"
      INSTALLED_PACKAGES+=("$pkg_name")
    else
      if eval "$install_cmd" >> "$INSTALL_LOG" 2>&1; then
        $VERBOSE && ui_success "[$current/$total] $pkg_name [OK]"
        INSTALLED_PACKAGES+=("$pkg_name")
      else
        ui_error "[$current/$total] $pkg_name [FAIL]"
        FAILED_PACKAGES+=("$pkg_name")
        log_error "Failed to install $pkg_name via $pkg_manager"
        ((failed++))
      fi
    fi
  done

  if [ $failed -eq 0 ]; then
    return 0
  else
    return 1
  fi
}

install_packages_quietly() {
  install_package_generic "pacman" "$@"
}

install_flatpak_quietly() {
  if ! command -v flatpak &>/dev/null; then
    log_error "Flatpak not found. Cannot install Flatpak packages."
    return 1
  fi
  install_package_generic "flatpak" "$@"
}

# --- Helper for AUR packages (using paru) ---
install_aur_packages() {
    local pkgs_to_install=("$@")
    if [ ${#pkgs_to_install[@]} -eq 0 ]; then
        return
    fi

    if ! command_exists paru; then
        ui_warn "AUR helper 'paru' not found. Skipping AUR packages: ${pkgs_to_install[*]}"
        return 1
    fi

    ui_info "Installing ${#pkgs_to_install[@]} AUR packages..."
    if [ "${DRY_RUN:-false}" = true ]; then
        for pkg in "${pkgs_to_install[@]}"; do
            ui_info "  - [DRY-RUN] Would install AUR package: $pkg"
            INSTALLED_PACKAGES+=("$pkg (AUR)")
        done
        return
    fi

    if paru -S --noconfirm --needed "${pkgs_to_install[@]}" >> "$INSTALL_LOG" 2>&1; then
        ui_success "AUR packages installed successfully."
        for pkg in "${pkgs_to_install[@]}"; do INSTALLED_PACKAGES+=("$pkg (AUR)"); done
    else
        log_error "Failed to install some AUR packages."
    fi
}


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
    rm -f "$HOME/.cachyinstaller.state" 2>/dev/null || true # Cleanup old state files if they exist
    # CAUTION: This removes the directory the script is in. This must be the last step.
    if [ -n "$cleanup_dir" ] && [ -d "$cleanup_dir" ]; then
      rm -rf "$cleanup_dir"
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


# ===== Performance and Utility =====

log_performance() {
  local step_name="$1"
  local current_time
  current_time=$(date +%s)
  local elapsed=$((current_time - START_TIME))
  local minutes=$((elapsed / 60))
  local seconds=$((elapsed % 60))
  ui_info "$step_name completed in ${minutes}m ${seconds}s."
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}
