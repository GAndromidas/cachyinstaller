#!/bin/bash
set -uo pipefail

# Gaming setup for CachyOS - Always enabled as it's a gaming distro
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
source "$SCRIPT_DIR/common.sh"

# CachyOS Gaming Mode - Always install gaming packages
step "Gaming Mode Setup"

log_info "=== CACHYOS GAMING MODE ==="
log_info "INSTALL_MODE: ${INSTALL_MODE:-default}"
log_info "Gaming packages: Always installed"
log_info "=========================="

# Show Gaming Mode banner
figlet_banner "Gaming Mode"

# Detect GPU type for proper driver installation
detect_gpu_type() {
  local gpu_type="unknown"

  # Check for NVIDIA GPU
  if lspci | grep -i nvidia >/dev/null 2>&1; then
    gpu_type="nvidia"
  # Check for AMD GPU
  elif lspci | grep -i "amd\|radeon" >/dev/null 2>&1; then
    gpu_type="amd"
  # Check for Intel GPU
  elif lspci | grep -i intel.*graphics >/dev/null 2>&1; then
    gpu_type="intel"
  fi

  echo "$gpu_type"
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
  local gpu_type=$(detect_gpu_type)
  log_info "Detected GPU type: $gpu_type"

  case "$gpu_type" in
    nvidia)
      log_info "Installing NVIDIA gaming drivers..."
      local nvidia_packages=("lib32-nvidia-utils" "nvidia-utils")
      install_packages_quietly "${nvidia_packages[@]}"
      ;;
    amd)
      log_info "Installing AMD gaming drivers..."
      local amd_packages=("lib32-mesa" "mesa" "lib32-vulkan-radeon" "vulkan-radeon")
      # Try mesa-git packages first (CachyOS specific)
      if pacman -Ss lib32-mesa-git >/dev/null 2>&1; then
        local amd_git_packages=("lib32-mesa-git" "mesa-git")
        install_packages_quietly "${amd_git_packages[@]}" || install_packages_quietly "${amd_packages[@]}"
      else
        install_packages_quietly "${amd_packages[@]}"
      fi
      ;;
    intel)
      log_info "Installing Intel gaming drivers..."
      local intel_packages=("lib32-mesa" "mesa" "lib32-vulkan-intel" "vulkan-intel")
      install_packages_quietly "${intel_packages[@]}"
      ;;
    *)
      log_warning "Unknown GPU type, installing generic drivers..."
      local generic_packages=("lib32-mesa" "mesa")
      install_packages_quietly "${generic_packages[@]}"
      ;;
  esac
}

# Install CachyOS gaming meta package (includes Steam, MangoHud, GameMode, etc.)
step "Installing CachyOS gaming meta package"
if sudo pacman -S --noconfirm --needed cachyos-gaming-meta 2>/dev/null; then
    log_success "CachyOS gaming meta package installed (includes Steam, Wine, MangoHud, GameMode, Lutris, Gamescope, Goverlay)"
    INSTALLED_PACKAGES+=("cachyos-gaming-meta")

    # Install GPU-specific drivers
    detect_and_install_gpu_drivers

    # Copy MangoHud configuration if available
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

else
    log_warning "cachyos-gaming-meta not available, falling back to individual packages"

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

    # Install GPU-specific drivers
    detect_and_install_gpu_drivers

    # Install essential gaming utilities (excluding Steam and Wine - handled separately)
    step "Installing gaming utilities"
    GAMING_PACKAGES=(
        "discord"
        "lutris"
        "obs-studio"
    )
    install_packages_quietly "${GAMING_PACKAGES[@]}"

    # Try steam-native-runtime first, then regular steam
    step "Installing Steam with Mesa-git compatibility"
    steam_installed=false

    # Try steam-native-runtime first, then regular steam
    if install_package "steam-native-runtime"; then
        log_success "Steam (native runtime) installed - compatible with Mesa-git"
        steam_installed=true
    elif install_package "steam"; then
        log_success "Steam installed"
        steam_installed=true
    else
        log_error "Steam installation failed - try manual installation"
        log_info "Manual options: sudo pacman -S steam-native-runtime or sudo pacman -S steam"
    fi
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
    log_info "cachyos-gaming-applications not available, checking for Heroic Games Launcher"

    # Check if Heroic Games Launcher is already installed (might be included in cachyos-gaming-meta)
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
    else
      log_info "Heroic Games Launcher already installed (included in cachyos-gaming-meta)"
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
    if ! flatpak list | grep -q "$pkg"; then
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
