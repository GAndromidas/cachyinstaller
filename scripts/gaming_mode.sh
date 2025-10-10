#!/bin/bash
set -uo pipefail

# Gaming setup for CachyOS - Always enabled as it's a gaming distro
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
# common.sh is sourced by install.sh, no need to source again here.

# CachyOS Gaming Mode - Always install gaming packages
step "Gaming Mode Setup"

log_info "=== CACHYOS GAMING MODE ==="
log_info "INSTALL_MODE: ${INSTALL_MODE:-default}"
log_info "Gaming packages: Always installed"
log_info "==========================="

# Show Gaming Mode banner
figlet_banner "Gaming Mode" || ui_info "Gaming Mode"

# Detect GPU type for proper driver installation
detect_graphics_card() {
  local graphics_card_vendor="unknown"

  # Check for NVIDIA GPU
  if lspci -k | grep -iqE \"VGA|3D|Display controller\" && lspci -k | grep -iq \"NVIDIA\"; then
    graphics_card_vendor=\"nvidia\"
  elif lspci -k | grep -iqE \"VGA|3D|Display controller\" && lspci -k | grep -iq \"AMD\"; then
    graphics_card_vendor=\"amd\"
  elif lspci -k | grep -iqE \"VGA|3D|Display controller\" && lspci -k | grep -iq \"Intel\"; then
    graphics_card_vendor=\"intel\"
  fi

  echo "$graphics_card_vendor"
}

# CachyOS is a gaming distro - always install gaming packages in both modes
if command -v gum >/dev/null 2>&1; then
  gum style --foreground 51 "CachyOS Gaming Mode (${INSTALL_MODE^} Installation)"
  gum style --foreground 226 "Installing: CachyOS Gaming Meta + GPU-specific drivers"
  gum style --foreground 33 "Includes: Steam, Wine, MangoHud, GameMode, Lutris, Gamescope, Goverlay"
else
  echo -e "${CYAN}CachyOS Gaming Mode (${INSTALL_MODE^} Installation)${RESET}"
  echo -e "${YELLOW}Installing: CachyOS Gaming Meta + GPU-specific drivers${RESET}"
  echo -e "${BLUE}Includes: Steam, Wine, MangoHud, GameMode, Lutris, Gamescope, Goverlay${RESET}"
fi

# Detect and install GPU-specific drivers
detect_and_install_gpu_drivers() {
  local graphics_card_vendor=$(detect_graphics_card)
  local skip_mesa_install=$1 # New parameter to skip mesa if cachyos-gaming-meta handles it
  log_info "Detected graphics card vendor: $graphics_card_vendor"

  case "$graphics_card_vendor" in
    nvidia)
      log_info "Installing NVIDIA gaming drivers..."
      local nvidia_packages=("lib32-nvidia-utils" "nvidia-utils")
      install_packages_quietly "${nvidia_packages[@]}"
      ;;
    amd)
      log_info "Installing AMD gaming drivers... (Mesa drivers)"
      local amd_packages=("lib32-vulkan-radeon" "vulkan-radeon")
      if [ "$skip_mesa_install" != "true" ]; then
        amd_packages+=("lib32-mesa" "mesa")
        # Try mesa-git packages first (CachyOS specific)
        if pacman -Ss lib32-mesa-git >/dev/null 2>&1; then
          local amd_git_packages=("lib32-mesa-git" "mesa-git")
          install_packages_quietly "${amd_git_packages[@]}" || install_packages_quietly "${amd_packages[@]}"
        else
          install_packages_quietly "${amd_packages[@]}"
        fi
      else
        install_packages_quietly "${amd_packages[@]}"
      fi
      ;;
    intel)
      log_info "Installing Intel gaming drivers..."
      local intel_packages=("lib32-vulkan-intel" "vulkan-intel")
      if [ "$skip_mesa_install" != "true" ]; then
        intel_packages+=("lib32-mesa" "mesa")
      fi
      install_packages_quietly "${intel_packages[@]}"
      ;;
    *)
      log_warning "Unknown GPU type, installing generic drivers..."
      if [ "$skip_mesa_install" != "true" ]; then
        local generic_packages=("lib32-mesa" "mesa")
        install_packages_quietly "${generic_packages[@]}"
      fi
      ;;
  esac
}

# Function to install individual gaming packages as a fallback when cachyos-gaming-meta is not available
_install_fallback_gaming_apps() {
    # Install individual gaming utilities (discord, lutris, obs-studio)
    step "Installing individual gaming utilities"
    local individual_gaming_packages=()

    if ! pacman -Q discord &>/dev/null; then
        individual_gaming_packages+=("discord")
    else
        log_info "Discord already installed, skipping individual installation."
    fi
    if ! pacman -Q lutris &>/dev/null; then
        individual_gaming_packages+=("lutris")
    else
        log_info "Lutris already installed, skipping individual installation."
    fi
    if ! pacman -Q obs-studio &>/dev/null; then
        individual_gaming_packages+=("obs-studio")
    else
        log_info "OBS Studio already installed, skipping individual installation."
    fi

    if [ ${#individual_gaming_packages[@]} -gt 0 ]; then
        install_packages_quietly "${individual_gaming_packages[@]}"
    else
        log_info "All individual gaming utilities already installed or not needed."
    fi
}

# Install CachyOS gaming meta package (includes Steam, MangoHud, GameMode, etc.)
step "Installing CachyOS gaming meta package"
META_GAMING_INSTALLED=false
if install_package "cachyos-gaming-meta"; then
    log_success "CachyOS gaming meta package installed (includes Steam, Wine, MangoHud, GameMode, Lutris, Gamescope, Goverlay)"

    META_GAMING_INSTALLED=true

    # Install GPU-specific drivers (Mesa is assumed to be handled by cachyos-gaming-meta)
    detect_and_install_gpu_drivers "true"

    # If cachyos-gaming-meta is installed, assume it handles MangoHud and GameMode configuration.
    # We can skip explicit MangoHud/GameMode installation and configuration here.
    log_info "MangoHud and GameMode are assumed to be handled by cachyos-gaming-meta."

else
    log_warning "cachyos-gaming-meta not available, falling back to individual packages"

    # Install GPU-specific drivers (Mesa is needed if meta-package isn't installed)
    detect_and_install_gpu_drivers "false"

    # Install MangoHud for performance monitoring
    step "Installing MangoHud"
    MANGO_PACKAGES=("mangohud" "lib32-mangohud")
    install_packages_quietly "${MANGO_PACKAGES[@]}"

    # Configure MangoHud
    step "Configuring MangoHud"
    MANGOHUD_CONFIG_DIR="$HOME/.config/MangoHud"
    MANGOHUD_CONFIG_SOURCE="$CONFIGS_DIR/MangoHud.conf"

    mkdir -p "$MANGOHUD_CONFIG_DIR"

    if [[ -f "$MANGOHUD_CONFIG_SOURCE" ]]; then
        cp "$MANGOHUD_CONFIG_SOURCE" "$MANGOHUD_CONFIG_DIR/MangoHud.conf"
        log_success "MangoHud configuration applied"
    else
        log_info "Using default MangoHud configuration"
    fi

    # Install GameMode for performance optimization
    step "Installing GameMode"
    GAMEMODE_PACKAGES=("gamemode" "lib32-gamemode")
    install_packages_quietly "${GAMEMODE_PACKAGES[@]}"

    # Call the fallback function if cachyos-gaming-meta is not available
    _install_fallback_gaming_apps
fi

# Install ProtonCachyOS for enhanced Steam compatibility
step "Installing ProtonCachyOS"
if command -v paru &>/dev/null; then
  if ! pacman -Q proton-cachyos &>/dev/null; then
    log_info "Installing ProtonCachyOS (enhanced Proton with CachyOS optimizations)"
    if paru -S --noconfirm --needed proton-cachyos; then
      log_success "ProtonCachyOS installed successfully"
      INSTALLED_PACKAGES+=("proton-cachyos (AUR)")
    else
      log_warning "ProtonCachyOS installation failed, Steam will use default Proton"
    fi
  else
    log_info "ProtonCachyOS already installed"
  fi
else
  log_warning "paru not available, skipping ProtonCachyOS"
fi

# Install CachyOS gaming applications package
step "Installing CachyOS gaming applications"
if sudo pacman -S --noconfirm --needed cachyos-gaming-applications 2>/dev/null; then
    log_success "CachyOS gaming applications installed"
    INSTALLED_PACKAGES+=("cachyos-gaming-applications")
else
    # Only try to install Heroic if cachyos-gaming-meta was NOT installed (as it might include it)
    if [ "$META_GAMING_INSTALLED" = "false" ]; then
        log_info "cachyos-gaming-applications not available, checking for Heroic Games Launcher"

        # Check if Heroic Games Launcher is already installed
        if ! pacman -Q heroic-games-launcher &>/dev/null && ! pacman -Q heroic-games-launcher-bin &>/dev/null; then
          log_info "Heroic Games Launcher not found, installing via AUR"

          if command -v paru &>/dev/null; then
            if paru -S --noconfirm --needed heroic-games-launcher-bin; then
              log_success "Heroic Games Launcher installed successfully"
              INSTALLED_PACKAGES+=("heroic-games-launcher-bin (AUR)")
            else
              log_error "Failed to install Heroic Games Launcher"
            fi
          else
            log_error "paru not found. Skipping Heroic Games Launcher installation."
          fi
         fi
    else
      log_info "cachyos-gaming-applications not available. Heroic Games Launcher skipped because cachyos-gaming-meta was installed."
    fi
fi

# Install gaming-related Flatpaks
step "Installing gaming Flatpaks"
GAMING_FLATPAKS=(
    "com.vysp3r.ProtonPlus"
)

if command -v flatpak >/dev/null 2>&1; then
  # Ensure flathub is added
  if ! flatpak remote-list | grep -q flathub; then
    log_info "Adding Flathub repository"
    sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
  fi

  for pkg in "${GAMING_FLATPAKS[@]}"; do
    if ! flatpak list --columns=application | grep -q "^$pkg\$"; then # More precise check for flatpak ID
      log_info "Installing Flatpak: $pkg"
      if sudo flatpak install -y flathub "$pkg"; then
        log_success "Installed $pkg"
        INSTALLED_PACKAGES+=("$pkg (Flatpak)")
      else
        log_error "Failed to install $pkg"
      fi
    else
      log_info "$pkg already installed"
    fi
  done
else
  log_warning "Flatpak not available. Skipping Flatpak gaming packages."
fi

log_success "CachyOS Gaming Mode setup completed - your gaming system is ready!"
