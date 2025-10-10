#!/usr/bin/env bash

# Colors for terminal output
RED='\033[38;5;196m'      # Bright red
GREEN='\033[38;5;46m'     # Bright green
YELLOW='\033[38;5;226m'   # Bright yellow
BLUE='\033[38;5;39m'      # Bright blue
CYAN='\033[38;5;51m'      # Bright cyan
WHITE='\033[38;5;255m'    # Bright white
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

# Global arrays for tracking
declare -a INSTALLED_PACKAGES
declare -a ERRORS
declare -a WARNINGS

# Utility functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_step() {
    local description="$1"
    shift
    echo -e "\n>> $description..."
    if "$@"; then
        return 0
    else
        log_error "Failed to execute: $description"
        return 1
    fi
}

install_packages_quietly() {
    local failed=0
    for pkg in "$@"; do
        if ! install_package "$pkg"; then
            ((failed++))
        fi
        # Add small delay for readability
        sleep 0.1
    done
    return $failed
}

show_installation_summary() {
    echo -e "\n${CYAN}Installation Summary:${RESET}"
    echo -e "Packages installed: ${#INSTALLED_PACKAGES[@]}"
    echo -e "Warnings: ${#WARNINGS[@]}"
    echo -e "Errors: ${#ERRORS[@]}"

    if [ ${#INSTALLED_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n${GREEN}Successfully installed packages:${RESET}"
        printf '%s\n' "${INSTALLED_PACKAGES[@]}" | sort
    fi

    if [ ${#ERRORS[@]} -gt 0 ]; then
        echo -e "\n${RED}Errors encountered:${RESET}"
        printf '%s\n' "${ERRORS[@]}"
    fi
}

# Helper utilities that should be installed first
HELPER_UTILS=(\
    "base-devel"\
    "flatpak"\
    "git"\
    "curl"\
    "wget"\
    "rsync"\
    "gum"\
    "ufw"\
    "cronie"\
    "fzf"\
    "zoxide"\
    "starship"\
)

# Logging functions
log_error() {
    ERRORS+=("$1")
    echo -e "${BOLD}${RED}==> ERROR:${RESET} $1" | tee -a "$INSTALL_LOG"
}

log_warning() {
    WARNINGS+=("$1")
    echo -e "${BOLD}${YELLOW}==> WARNING:${RESET} $1" | tee -a "$INSTALL_LOG"
}

log_success() {
    echo -e "${BOLD}${GREEN}==> SUCCESS:${RESET} $1" | tee -a "$INSTALL_LOG"
}

log_info() {
    echo -e "${BOLD}${BLUE}==>${RESET} $1" | tee -a "$INSTALL_LOG"
}

# UI helper functions
ui_info() {
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 39 "ℹ $1"${RESET}
    else
        echo -e "${BLUE}ℹ $1${RESET}"
    fi
}

ui_success() {
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 82 "✓ $1"${RESET}
    else
        echo -e "${GREEN}✓ $1${RESET}"
    fi
}

ui_error() {
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 196 "✗ $1"${RESET}
    else
        echo -e "${RED}✗ $1${RESET}"
    fi
}

ui_warn() {
    if command -v gum >/dev/null 2>&1; then
        gum style --foreground 178 "⚠ $1"${RESET}
    else
        echo -e "${YELLOW}⚠ $1${RESET}"
    fi
}

# Progress tracking
START_TIME=$(date +%s)

log_performance() {
    local end_time=$(date +%s)
    local duration=$((end_time - START_TIME))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))
    echo -e "\n${CYAN}$1: ${minutes}m ${seconds}s${RESET}" | tee -a "$INSTALL_LOG"
}

print_step_header() {
    local current_step="$1"
    local total_steps="$2"
    local description="$3"
    echo -e "\n${BOLD}${BLUE}:: ${WHITE}Step ${current_step}/${total_steps}: ${description}${RESET}"
    echo -e "${DIM}───────────────────────────────────────────────────${RESET}"
}

print_header() {
    local title="$1"
    shift
    echo -e "\n${BOLD}${WHITE}╭───────────────────────────────────────────────────╮${RESET}"
    echo -e "${BOLD}${WHITE}│${RESET} ${CYAN}${title}${RESET}"
    for line in "$@"; do
        echo -e "${BOLD}${WHITE}│${RESET} ${DIM}${line}${RESET}"
    done
    echo -e "${BOLD}${WHITE}╰───────────────────────────────────────────────────╯${RESET}\n"
}

step() {
    local step_name="$1"
    echo -e "\\n${BOLD}${BLUE}==> ${WHITE}${step_name}...${RESET}"
}

figlet_banner() {
    local text="$1"
    if command -v figlet >/dev/null 2>&1; then
        echo -e "\\n${CYAN}"
        figlet -c -t "$text"
        echo -e "${RESET}"
    fi
}

# Package management functions
package_installed() {
    pacman -Qi "$1" &>/dev/null
}

install_package() {
    local package="$1"
    local retries=3
    local retry_delay=5
    local i=1

    # Check if it's a helper utility
    for util in "${HELPER_UTILS[@]}"; do
        if [[ "$package" == "$util" ]]; then
            log_info "Installing helper utility: $package..."
            if sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1; then
                INSTALLED_PACKAGES+=("$package")
                log_success "Successfully installed helper utility: $package"
                return 0
            fi
        fi
    done

    if ! package_installed "$package"; then
        log_info "Installing $package..."

        while [ $i -le $retries ]; do
            if sudo pacman -S --noconfirm --needed "$package" >/dev/null 2>&1; then
                if pacman -Q "$package" >/dev/null 2>&1; then
                    INSTALLED_PACKAGES+=("$package")
                    log_success "Successfully installed $package"
                    return 0
                else
                    log_warning "Package $package install succeeded but verification failed"
                fi
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
            ((i++))
        done
    else
        log_info "Package $package is already installed"
        return 0
    fi
}

install_packages() {
    local success=true
    for package in "$@"; do
        if ! install_package "$package"; then
            success=false
        fi
    done
    $success
}

# Function to update mirrorlist using rate-mirrors or reflector
update_mirrors() {\n    step "Updating mirrorlist"\n\n    if command_exists rate-mirrors; then
        sudo rate-mirrors --allow-root arch --save /etc/pacman.d/mirrorlist
        sudo pacman -Sy --noconfirm >/dev/null 2>&1 # Suppress output of pacman -Syy
        log_success "Mirrorlist updated successfully with rate-mirrors"\n    else
        log_warning "rate-mirrors not found, using reflector instead"\n        if command_exists reflector; then
            sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
            sudo pacman -Sy --noconfirm >/dev/null 2>&1 # Suppress output of pacman -Syy
            log_success "Mirrorlist updated successfully with reflector"\n        else
            log_error "Neither rate-mirrors nor reflector found for mirrorlist update"\n            return 1
        fi\n    fi
    return 0
}

# DE detection
detect_desktop_environment() {
    if [ -n "$XDG_CURRENT_DESKTOP" ]; then
        echo "$XDG_CURRENT_DESKTOP"
    elif [ -n "$DESKTOP_SESSION" ]; then
        echo "$DESKTOP_SESSION"\n    elif command_exists loginctl && loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type | grep -q "x11"; then
        echo "X11" # Fallback for unknown X11 DEs
    elif command_exists loginctl && loginctl show-session $(loginctl | grep $(whoami) | awk '{print $1}') -p Type | grep -q "wayland"; then
        echo "WAYLAND" # Fallback for unknown Wayland DEs
    else
        echo "UNKNOWN"
    fi
}

# Install helper utilities first
install_helper_utils() {
    local all_success=true
    log_info "Installing core helper utilities..."
    for util in "${HELPER_UTILS[@]}"; do
        if ! install_package "$util"; then
            all_success=false
        fi
        # A small delay for better console output readability, even for helpers
        sleep 0.1
    done
    if [ "$all_success" = true ]; then
        log_success "All core helper utilities installed."
        return 0
    else
        log_error "Some core helper utilities failed to install. Check log for details."
        return 1
    fi
}

# Menu functions
show_menu() {
    if command -v gum >/dev/null 2>&1; then
        # Show styled header with gum
        gum style --border double --margin "1 2" --padding "1 4" --foreground 51 "CachyOS Post-Installation Enhancement"${RESET}
        gum style --margin "1 0" --foreground 226 "Choose your installation mode:"${RESET}

        # Installation mode selection using gum
        choice=$(gum choose \
            "Default - Complete gaming setup with all optimizations" \
            "Minimal - Essential gaming setup with core features" \
            "Exit - Cancel installation" \
            --cursor.foreground="99" \
            --selected.foreground="99" \
            --cursor-prefix="▶ " \
            --selected-prefix="✓ " \
            --unselected-prefix="  ")

        case "$choice" in
            "Default"*)
                export INSTALL_MODE="default"
                gum style --foreground 51 "✓ Selected: Default installation"${RESET}
                ;;
            "Minimal"*)
                export INSTALL_MODE="minimal"
                gum style --foreground 46 "✓ Selected: Minimal installation"${RESET}
                ;;
            "Exit"*)
                gum style --foreground 196 "Installation cancelled by user"${RESET}
                exit 0
                ;;
        esac
    else
        # Fallback to traditional menu
        echo -e "╔══════════════════════════════════╗"
        echo -e "║     CachyOS Gaming Installer     ║"
        echo -e "╚══════════════════════════════════╝\n"

        echo "1) Default    - Complete gaming setup with all optimizations"
        echo "2) Minimal    - Essential gaming setup with core features"
        echo "3) Exit       - Cancel installation"
        echo

        while true; do
            read -p "Choose installation mode (1-3): " choice
            case $choice in
                1)
                    INSTALL_MODE="default"
                    break
                    ;;
                2)
                    INSTALL_MODE="minimal"
                    break
                    ;;
                3)
                    echo -e "\n${YELLOW}Installation cancelled.${RESET}"
                    exit 0
                    ;;
                *)
                    echo -e "${RED}Invalid choice. Please select 1-3${RESET}"
                    ;;
            esac
        done
    fi
}

print_summary() {
    echo -e "\n${CYAN}Installation Summary:${RESET}"
    echo -e "${BLUE}Packages installed:${RESET} ${#INSTALLED_PACKAGES[@]}"
    echo -e "${YELLOW}Warnings:${RESET} ${#WARNINGS[@]}"
    echo -e "${RED}Errors:${RESET} ${#ERRORS[@]}"
}

save_log_on_exit() {
    log_performance "Total runtime"
    {
        echo -e "\nFinal Status:"
        echo "Packages installed: ${#INSTALLED_PACKAGES[@]}"
        echo "Warnings: ${#WARNINGS[@]}"
        echo "Errors: ${#ERRORS[@]}"
        echo -e "\nInstallation ended: $(date)"
    } >> "$INSTALL_LOG"
}

# Function to prompt for reboot
prompt_reboot() {
  if [ "$DRY_RUN" = true ]; then
    log_info "Dry-run mode: Skipping reboot prompt."
    return 0
  fi

  ui_info "Installation complete. A reboot is recommended to apply all changes."
  if command -v gum >/dev/null 2>&1; then
    choice=$(gum choose "Reboot Now" "Reboot Later")
    if [[ "$choice" == "Reboot Now" ]]; then
      log_info "Rebooting system now..."
      sudo reboot
    else
      log_info "Reboot postponed. Please reboot manually when convenient."
    fi
  else
    read -p "$(echo -e "${CYAN}Installation complete. Reboot now? (y/N): ${RESET}")" -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
      log_info "Rebooting system now..."
      sudo reboot
    else
      log_info "Reboot postponed. Please reboot manually when convenient."
    fi
  fi
}

# Export functions and variables
export -f log_error log_warning log_success log_info figlet_banner
export -f ui_info ui_success ui_error ui_warn
export -f install_package install_packages package_installed install_helper_utils
export -f print_step_header print_header step
export -f detect_desktop_environment show_menu print_summary update_mirrors save_log_on_exit prompt_reboot
export INSTALLED_PACKAGES ERRORS WARNINGS
export RED GREEN YELLOW BLUE CYAN RESET
