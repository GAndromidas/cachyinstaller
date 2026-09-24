#!/bin/bash
set -uo pipefail

# Compatibility facade: sources the modular libraries so existing modules
# keep working, and keeps the CachyOS-specific UI helpers (banner, menu,
# reboot prompt, summary) in one place.

COMMON_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIGS_DIR="$COMMON_DIR/../configs"
SCRIPTS_DIR="$COMMON_DIR"

TOTAL_STEPS=9
export TOTAL_STEPS

: "${USER:=$(whoami)}"
: "${HOME:=/home/${USER}}"
: "${XDG_CURRENT_DESKTOP:=}"
: "${VERBOSE:=false}"

for __lib_module in core ui system package config state; do
  # shellcheck disable=SC1091
  source "$COMMON_DIR/lib/$__lib_module.sh"
done
unset __lib_module

export INSTALL_LOG="${INSTALL_LOG:-/var/tmp/cachyinstaller.log}"
STATE_FILE="${STATE_FILE:-/var/tmp/cachyinstaller.state}"
export STATE_FILE

cachy_ascii() {
  echo -e "${THEME_PRIMARY:-}"
  cat << "EOF"
   ____           _           ___           _        _ _
  / ___|__ _  ___| |__  _   _|_ _|_ __  ___| |_ __ _| | | ___ _ __
 | |   / _` |/ __| '_ \| | | || || '_ \/ __| __/ _` | | |/ _ \ '__|
 | |__| (_| | (__| | | | |_| || || | | \__ \ || (_| | | |  __/ |
  \____\__,_|\___|_| |_|\__, |___|_| |_|___/\__\__,_|_|_|\___|_|
                        |___/
EOF
  echo -e "${RESET:-}"
}

validate_install_mode() {
  local mode="$1"
  case "$mode" in
    "default"|"minimal") return 0 ;;
    *)
      log_error "Invalid INSTALL_MODE: '$mode'. Valid modes are: default, minimal"
      return 1
      ;;
  esac
}

show_menu() {
  if supports_gum; then
    show_gum_menu
  else
    show_traditional_menu
  fi
}

show_gum_menu() {
  gum style --margin "1 0" --foreground "$GUM_WARN" "This script will enhance your CachyOS installation with additional"
  gum style --margin "0 0 1 0" --foreground "$GUM_WARN" "tools, security, and performance optimizations."
  local choice=""
  choice=$(gum choose --cursor="-> " --selected.foreground "$GUM_PRIMARY" --cursor.foreground "$GUM_PRIMARY" \
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
    "Exit"*|"")
      ui_info "Installation cancelled."
      exit 0
      ;;
  esac
}

show_traditional_menu() {
  echo -e "${THEME_HEADER:-}Choose your installation mode:${RESET:-}"
  echo "  1) Standard - Complete setup with all recommended packages"
  echo "  2) Minimal - Essential tools only for a lightweight system"
  echo "  3) Exit - Cancel installation"
  local menu_choice=""
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

check_system_compatibility() {
  local issues=()
  if [[ $EUID -eq 0 ]]; then
    issues+=("Script should not be run as root")
  fi
  if ! grep -q "CachyOS" /etc/os-release 2>/dev/null; then
    issues+=("Not running on CachyOS")
  fi
  local available_space=0
  available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt 2097152 ]]; then
    issues+=("Insufficient disk space (need 2GB)")
  fi
  if ! ping -c 1 -W 5 cachyos.org &>/dev/null && ! ping -c 1 -W 5 8.8.8.8 &>/dev/null && ! getent hosts cachyos.org &>/dev/null; then
    issues+=("No internet connection (check cable/Wi-Fi and DNS - try: ping 8.8.8.8)")
  fi
  if ! command -v yq &>/dev/null; then
    log_warning "yq not found — using built-in fallback YAML parser (install yq for stricter parsing)"
  fi
  if [ ${#issues[@]} -gt 0 ]; then
    log_error "System compatibility issues found:"
    for issue in "${issues[@]}"; do
      log_error "  - $issue"
    done
    return 1
  fi
  return 0
}

print_header() {
  local title="$1"; shift
  if supports_gum; then
    gum style --border double --margin "1 2" --padding "1 4" --foreground "$GUM_HEADER" --border-foreground "$GUM_BORDER" "$title"
    while (( "$#" )); do
      gum style --margin "1 0 0 0" --foreground "$GUM_WARN" "$1"
      shift
    done
  else
    echo -e "${THEME_HEADER:-}$title${RESET:-}"
    echo "----------------------------------------"
    while (( "$#" )); do
      echo -e "${THEME_TEXT:-}$1${RESET:-}"
      shift
    done
  fi
}

print_step_header() {
  local step_num="$1"; local total="$2"; local title="$3"
  echo ""
  if supports_gum; then
    gum style --border normal --margin "1 0" --padding "0 2" --foreground "$GUM_PRIMARY" --border-foreground "$GUM_BORDER" "Step ${step_num}/${total}: ${title}"
  else
    echo -e "${THEME_SECONDARY:-}Step ${step_num}/${total}: ${title}${RESET:-}"
  fi
}

print_package_summary() {
  local title="$1"
  shift
  local pkgs=("$@")
  if [ ${#pkgs[@]} -gt 0 ]; then
    echo ""
    ui_info "$title:"
    printf '%s\n' "${pkgs[@]}" | sed '/^$/d' | column | sed 's/^/  /'
  fi
}

gum_confirm() {
  local question="$1"
  local description="${2:-}"
  ui_confirm "$question" "$description" true
}

format_time() {
  local seconds=$1
  if [ "$seconds" -le 0 ]; then
    echo "<1s"
  elif [ "$seconds" -lt 60 ]; then
    echo "${seconds}s"
  elif [ "$seconds" -lt 3600 ]; then
    echo "$((seconds / 60))m $((seconds % 60))s"
  else
    echo "$((seconds / 3600))h $(((seconds % 3600) / 60))m"
  fi
}

log_performance() {
  local step_name="$1"
  local elapsed=$((SECONDS - ${START_TIME_SEC:-$SECONDS}))
  ((elapsed < 0)) && elapsed=0
  ui_info "$step_name completed in $(format_time "$elapsed")."
}

print_summary() {
  echo ""
  ui_warn "=== INSTALL SUMMARY ==="
  [ "${#INSTALLED_PACKAGES[@]}" -gt 0 ] && echo -e "${THEME_SUCCESS:-}Installed: ${#INSTALLED_PACKAGES[@]} packages${RESET:-}"
  [ "${#FAILED_PACKAGES[@]}" -gt 0 ] && echo -e "${THEME_ERROR:-}Failed: ${#FAILED_PACKAGES[@]} packages${RESET:-}"
  [ "${#ERRORS[@]}" -gt 0 ] && echo -e "${THEME_ERROR:-}Errors: ${#ERRORS[@]} occurred${RESET:-}"
  ui_warn "======================="
  echo ""
}

install_packages_quietly() {
  install_package_generic "pacman" "$@"
}

install_aur_quietly() {
  local helper=""
  helper=$(aur_helper)
  if ! command -v "$helper" &>/dev/null; then
    log_error "AUR helper not found (looked for paru, yay)."
    return 1
  fi
  install_package_generic "aur" "$@"
}

install_aur_packages() {
  local pkgs_to_install=("$@")
  if [ ${#pkgs_to_install[@]} -eq 0 ]; then
    return 0
  fi
  local helper=""
  helper=$(aur_helper)
  if ! command -v "$helper" &>/dev/null; then
    ui_warn "AUR helper '$helper' not found. Skipping AUR packages: ${pkgs_to_install[*]}"
    return 1
  fi
  ui_info "Installing ${#pkgs_to_install[@]} AUR packages..."
  if [ "${DRY_RUN:-false}" = true ]; then
    for pkg in "${pkgs_to_install[@]}"; do
      ui_info "  - [DRY-RUN] Would install AUR package: $pkg"
      INSTALLED_PACKAGES+=("$pkg (AUR)")
    done
    return 0
  fi
  if "$helper" -S --noconfirm --needed "${pkgs_to_install[@]}" >> "$INSTALL_LOG" 2>&1; then
    ui_success "AUR packages installed successfully."
    for pkg in "${pkgs_to_install[@]}"; do INSTALLED_PACKAGES+=("$pkg (AUR)"); done
  else
    log_error "Failed to install some AUR packages."
  fi
}

install_flatpak_quietly() {
  if ! command -v flatpak &>/dev/null; then
    log_error "Flatpak not found. Cannot install Flatpak packages."
    return 1
  fi
  install_package_generic "flatpak" "$@"
}

prompt_reboot() {
  if [[ "${DRY_RUN:-false}" == true ]]; then
    log_debug "Dry-run: skipping reboot prompt"
    return 0
  fi
  simple_banner "Installation Complete"
  echo ""
  ui_success "Your CachyOS system is now enhanced and ready to use!"
  echo ""
  local mode="Standard"
  [ "${INSTALL_MODE:-default}" = "minimal" ] && mode="Minimal"
  echo -e "  Mode:     $mode"
  if command -v pacman &>/dev/null; then
    echo -e "  Packages: $(pacman -Q 2>/dev/null | wc -l) installed"
  fi
  echo -e "  Log:      ${INSTALL_LOG:-/var/tmp/cachyinstaller.log}"
  echo -e "  Verify:   bash scripts/verify.sh (or ./install.sh --check)"
  echo ""
  ui_warn "It is strongly recommended to reboot now to apply all changes."
  echo ""
  if supports_gum; then
    if gum confirm --default=true --prompt.foreground "$GUM_PRIMARY" --selected.background "$GUM_PRIMARY" "Reboot now?"; then
      ui_info "Rebooting your system..."
      sudo reboot
      exit 0
    else
      ui_info "Reboot skipped. You can reboot manually with: sudo reboot"
    fi
  else
    local reboot_ans=""
    read -r -p "Reboot now? [Y/n]: " reboot_ans
    reboot_ans=${reboot_ans,,}
    case "$reboot_ans" in
      ""|y|yes)
        ui_info "Rebooting your system..."
        sudo reboot
        exit 0
        ;;
      *)
        ui_info "Reboot skipped. You can reboot manually with: sudo reboot"
        ;;
    esac
  fi
}
