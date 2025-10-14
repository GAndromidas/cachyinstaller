#!/bin/bash
set -uo pipefail

setup_gaming_mode() {
# --- User Confirmation ---
# For minimal installs, ask the user if they want gaming components.
if [ "${INSTALL_MODE}" = "minimal" ]; then
    ui_info "The 'Gaming Setup' will install Steam, Lutris, and other performance tools."

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

# Verify Lutris is installed
if ! command_exists lutris; then
  ui_warn "Lutris was not installed with the meta-package, installing it now..."
  install_packages_quietly "lutris"
fi

# 2. Configure MangoHud
ui_info "Configuring MangoHud..."
MANGOHUD_CONFIG_DIR="$HOME/.config/MangoHud"
MANGOHUD_CONFIG_SOURCE="$CONFIGS_DIR/MangoHud.conf"
if [ "${DRY_RUN:-false}" = false ]; then
    mkdir -p "$MANGOHUD_CONFIG_DIR"
    if [ -f "$MANGOHUD_CONFIG_SOURCE" ] && [ ! -f "$MANGOHUD_CONFIG_DIR/MangoHud.conf" ]; then
        cp "$MANGOHUD_CONFIG_SOURCE" "$MANGOHUD_CONFIG_DIR/MangoHud.conf"
        ui_info "  - Default MangoHud configuration applied."
    fi
else
    ui_info "[DRY-RUN] Would copy default MangoHud config if it does not exist."
fi

# 3. Install AUR & Flatpak Packages
install_aur_packages "${aur_pkgs[@]}"

if [ ${#flatpak_pkgs[@]} -gt 0 ]; then
  if ! command_exists flatpak; then
    ui_info "Installing Flatpak..."
    install_packages_quietly flatpak || { log_error "Failed to install Flatpak, skipping packages."; return; }
  fi
  install_flatpak_quietly "${flatpak_pkgs[@]}"
fi

}



setup_gaming_mode
return 0
