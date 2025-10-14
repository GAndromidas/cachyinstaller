#!/bin/bash
set -uo pipefail

setup_gaming_mode() {
# --- User Confirmation ---
# CachyOS is gaming-focused, but we should still ask, especially for minimal installs.
if [ "${INSTALL_MODE}" = "minimal" ]; then
    ui_info "The 'Gaming Setup' will install Steam, Lutris, graphics drivers, and other performance tools."

    local confirm_gaming=false
    if [ "${DRY_RUN:-false}" = true ]; then
        ui_info "[DRY-RUN] Would ask to install gaming components."
        confirm_gaming=true # Assume yes for dry run to show what would be installed
    elif supports_gum; then
        if gum confirm "Install gaming components?"; then
            confirm_gaming=true
        fi
    else
        read -r -p "Install gaming components? [y/N]: " response
        if [[ "$response" =~ ^([yY][eE][sS]|[yY])$ ]]; then
            confirm_gaming=true
        fi
    fi

    if ! $confirm_gaming; then
        ui_warn "Skipping gaming setup as requested."
        return 0
    fi
fi

# --- Package Definitions ---
local cachyos_meta_pkg="cachyos-gaming-meta"
local fallback_pkgs=(
    "steam" "lutris" "gamemode" "lib32-gamemode" "mangohud"
    "lib32-mangohud" "goverlay" "gamescope" "wine"
)
local nvidia_pkgs=("lib32-nvidia-utils" "nvidia-utils")
local amd_pkgs=("lib32-vulkan-radeon" "vulkan-radeon" "lib32-mesa" "mesa")
local intel_pkgs=("lib32-vulkan-intel" "vulkan-intel" "lib32-mesa" "mesa")
local aur_pkgs=("proton-cachyos" "heroic-games-launcher-bin")
local flatpak_pkgs=("com.vysp3r.ProtonPlus")



# --- Main Installation Logic ---

# 1. Install Base Gaming Packages
ui_info "Installing core gaming packages..."
# Try the CachyOS meta package first for a cohesive experience.
if ! install_packages_quietly "$cachyos_meta_pkg"; then
    ui_warn "CachyOS meta-package failed or was not found. Installing individual fallback packages..."
    install_packages_quietly "${fallback_pkgs[@]}"
fi

# 2. Install Graphics Drivers
# The GPU_VENDOR variable is exported by system_preparation.sh
if [ -n "${GPU_VENDOR}" ]; then
    ui_info "Installing graphics drivers for ${GPU_VENDOR^^}..."
    case "$GPU_VENDOR" in
        nvidia) install_packages_quietly "${nvidia_pkgs[@]}" ;;
        amd)    install_packages_quietly "${amd_pkgs[@]}" ;;
        intel)  install_packages_quietly "${intel_pkgs[@]}" ;;
    esac
else
    ui_warn "GPU vendor could not be determined. Skipping automatic driver installation."
    ui_warn "Please install the appropriate drivers for your hardware manually."
fi

# 3. Configure MangoHud
ui_info "Configuring MangoHud..."
MANGOHUD_CONFIG_DIR="$HOME/.config/MangoHud"
MANGOHUD_CONFIG_SOURCE="$CONFIGS_DIR/MangoHud.conf"
if [ "${DRY_RUN:-false}" = false ]; then
    mkdir -p "$MANGOHUD_CONFIG_DIR"
    if [ -f "$MANGOHUD_CONFIG_SOURCE" ]; then
        cp "$MANGOHUD_CONFIG_SOURCE" "$MANGOHUD_CONFIG_DIR/MangoHud.conf"
        ui_success "MangoHud configuration applied."
    else
        ui_warn "MangoHud config file not found, default settings will be used."
    fi
else
    ui_info "[DRY-RUN] Would have copied MangoHud configuration."
fi

# 4. Install AUR & Flatpak Packages
install_aur_packages "${aur_pkgs[@]}"

if [ ${#flatpak_pkgs[@]} -gt 0 ]; then
  if ! command_exists flatpak; then
    ui_info "Installing Flatpak..."
    install_packages_quietly flatpak || { log_error "Failed to install Flatpak, skipping packages."; return; }
  fi
  install_flatpak_quietly "${flatpak_pkgs[@]}"
fi

}

# --- Helper for AUR packages (using paru) ---
install_aur_packages() {
    local pkgs_to_install=("$@")
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

setup_gaming_mode
return 0
