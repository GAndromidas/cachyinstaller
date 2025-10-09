#!/bin/bash
set -uo pipefail

# CachyOS Programs Installation Script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"

source "$SCRIPT_DIR/common.sh"

# Global arrays for tracking
PROGRAMS_ERRORS=()
PROGRAMS_INSTALLED=()
PROGRAMS_REMOVED=()

# ===== YAML Parsing Functions =====
ensure_yq() {
  if ! command -v yq &>/dev/null; then
    log_info "Installing yq for YAML parsing..."
    sudo pacman -S --noconfirm yq
    if ! command -v yq &>/dev/null; then
      log_error "Failed to install yq. Please install manually: sudo pacman -S yq"
      return 1
    fi
  fi
  return 0
}

read_yaml_packages() {
  local yaml_file="$1"
  local yaml_path="$2"
  local -n packages_array="$3"
  local -n descriptions_array="$4"

  packages_array=()
  descriptions_array=()

  local yq_output
  yq_output=$(yq -r "$yaml_path[] | [.name, .description] | @tsv" "$yaml_file" 2>/dev/null)

  if [[ $? -eq 0 && -n "$yq_output" ]]; then
    while IFS=$'\t' read -r name description; do
      [[ -z "$name" ]] && continue
      packages_array+=("$name")
      descriptions_array+=("$description")
    done <<< "$yq_output"
  fi
}

read_yaml_simple_packages() {
  local yaml_file="$1"
  local yaml_path="$2"
  local -n packages_array="$3"

  packages_array=()

  local yq_output
  yq_output=$(yq -r "$yaml_path[]" "$yaml_file" 2>/dev/null)

  if [[ $? -eq 0 && -n "$yq_output" ]]; then
    while IFS= read -r package; do
      [[ -z "$package" ]] && continue
      packages_array+=("$package")
    done <<< "$yq_output"
  fi
}

# ===== Package Lists (Loaded from YAML) =====
PROGRAMS_YAML="$CONFIGS_DIR/programs.yaml"
if [[ ! -f "$PROGRAMS_YAML" ]]; then
  log_error "Programs configuration file not found: $PROGRAMS_YAML"
  return 1
fi

# Ensure yq is available
if ! ensure_yq; then
  return 1
fi

# Read package lists from YAML
read_yaml_packages "$PROGRAMS_YAML" ".pacman.packages" pacman_programs pacman_descriptions
read_yaml_packages "$PROGRAMS_YAML" ".essential.default" essential_programs_default essential_descriptions_default
read_yaml_packages "$PROGRAMS_YAML" ".essential.minimal" essential_programs_minimal essential_descriptions_minimal
read_yaml_packages "$PROGRAMS_YAML" ".aur.default" aur_programs_default aur_descriptions_default
read_yaml_packages "$PROGRAMS_YAML" ".aur.minimal" aur_programs_minimal aur_descriptions_minimal

# Read desktop environment specific packages
read_yaml_simple_packages "$PROGRAMS_YAML" ".desktop_environments.kde.install" kde_install_programs
read_yaml_simple_packages "$PROGRAMS_YAML" ".desktop_environments.kde.remove" kde_remove_programs
read_yaml_simple_packages "$PROGRAMS_YAML" ".desktop_environments.gnome.install" gnome_install_programs
read_yaml_simple_packages "$PROGRAMS_YAML" ".desktop_environments.gnome.remove" gnome_remove_programs
read_yaml_simple_packages "$PROGRAMS_YAML" ".desktop_environments.cosmic.install" cosmic_install_programs
read_yaml_simple_packages "$PROGRAMS_YAML" ".desktop_environments.cosmic.remove" cosmic_remove_programs

# ===== Helper Functions =====
check_paru() {
  if ! command -v paru &>/dev/null; then
    log_warning "paru (AUR helper) is not installed. AUR packages will be skipped."
    return 1
  fi
  return 0
}

check_flatpak() {
  if ! command -v flatpak &>/dev/null; then
    log_warning "flatpak is not installed. Flatpak packages will be skipped."
    return 1
  fi
  if ! flatpak remote-list | grep -q flathub; then
    log_info "Adding Flathub remote"
    flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
  fi
  log_info "Updating Flatpak remotes"
  flatpak update -y

  # Update desktop database for Flatpak integration
  if command -v update-desktop-database &>/dev/null; then
    sudo update-desktop-database /usr/share/applications/ 2>/dev/null || true
    if [[ -d "$HOME/.local/share/applications" ]]; then
      update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    fi
    if [[ -d "/var/lib/flatpak/exports/share/applications" ]]; then
      sudo update-desktop-database /var/lib/flatpak/exports/share/applications 2>/dev/null || true
    fi
    if [[ -d "$HOME/.local/share/flatpak/exports/share/applications" ]]; then
      update-desktop-database "$HOME/.local/share/flatpak/exports/share/applications" 2>/dev/null || true
    fi
    log_success "Desktop database updated for Flatpak integration"
  fi
  return 0
}

# ===== Installation Functions =====
install_pacman_quietly() {
  local pkgs=("$@")
  local to_install=()

  for pkg in "${pkgs[@]}"; do
    pacman -Q "$pkg" &>/dev/null || to_install+=("$pkg")
  done

  local total=${#to_install[@]}
  if [ $total -eq 0 ]; then
    log_info "All Pacman packages are already installed"
    return
  fi

  log_info "Installing ${total} packages via Pacman: ${to_install[*]}"
  if install_packages "${to_install[@]}"; then
    for pkg in "${to_install[@]}"; do
      # Add to PROGRAMS_INSTALLED only if successfully installed by common.sh
      package_installed "$pkg" && PROGRAMS_INSTALLED+=("$pkg")
    done
    log_success "Pacman batch installation completed"
  else
    log_error "Some Pacman packages failed to install. Check log for details."
    # The common.sh functions already add to ERRORS array, but we can also add to PROGRAMS_ERRORS for specific tracking
    for pkg in "${to_install[@]}"; do
      ! package_installed "$pkg" && PROGRAMS_ERRORS+=("Failed to install $pkg (Pacman)")
    done
  fi
}

install_flatpak_quietly() {
  local pkgs=("$@")
  local to_install=()

  for pkg in "${pkgs[@]}"; do
    flatpak list --app | grep -qw "$pkg" || to_install+=("$pkg")
  done

  local total=${#to_install[@]}
  if [ $total -eq 0 ]; then
    log_info "All Flatpak packages are already installed"
    return
  fi

  log_info "Installing ${total} packages via Flatpak: ${to_install[*]}"
    if flatpak install -y flathub "${to_install[@]}"; then
    for pkg in "${to_install[@]}"; do
      flatpak list --app | grep -qw "$pkg" && PROGRAMS_INSTALLED+=("$pkg (flatpak)")
    done
    log_success "Flatpak batch installation completed"
  else
    log_error "Some Flatpak packages failed to install"
    for pkg in "${to_install[@]}"; do
      if ! flatpak list --app | grep -qw "$pkg"; then
        PROGRAMS_ERRORS+=("Failed to install Flatpak $pkg")
      fi
    done
  fi
}

install_aur_quietly() {
  local pkgs=("$@")
  local to_install=()

  for pkg in "${pkgs[@]}"; do
    pacman -Q "$pkg" &>/dev/null || to_install+=("$pkg")
  done

  local total=${#to_install[@]}
  if [ $total -eq 0 ]; then
    log_info "All AUR packages are already installed"
    return
  fi

  log_info "Installing ${total} packages via AUR (paru): ${to_install[*]}"
  if paru -S --noconfirm --needed "${to_install[@]}"; then
    for pkg in "${to_install[@]}"; do
      pacman -Q "$pkg" &>/dev/null && PROGRAMS_INSTALLED+=("$pkg (AUR)")
    done
    log_success "AUR batch installation completed"
  else
    log_error "Some AUR packages failed to install. Check log for details."
    for pkg in "${to_install[@]}"; do
      if ! pacman -Q "$pkg" &>/dev/null; then
        PROGRAMS_ERRORS+=("Failed to install AUR $pkg")
      fi
    done
  fi
}

# ===== Desktop Environment Detection =====
detect_desktop_environment() {
  case "$XDG_CURRENT_DESKTOP" in
    KDE)
      log_success "KDE detected"
      specific_install_programs=("${kde_install_programs[@]}")
      specific_remove_programs=("${kde_remove_programs[@]}")
      flatpak_install_function="install_flatpak_programs_kde"
      flatpak_minimal_function="install_flatpak_minimal_kde"
      ;;
    GNOME)
      log_success "GNOME detected"
      specific_install_programs=("${gnome_install_programs[@]}")
      specific_remove_programs=("${gnome_remove_programs[@]}")
      flatpak_install_function="install_flatpak_programs_gnome"
      flatpak_minimal_function="install_flatpak_minimal_gnome"
      ;;
    COSMIC)
      log_success "Cosmic DE detected"
      specific_install_programs=("${cosmic_install_programs[@]}")
      specific_remove_programs=("${cosmic_remove_programs[@]}")
      flatpak_install_function="install_flatpak_programs_cosmic"
      flatpak_minimal_function="install_flatpak_minimal_cosmic"
      ;;
    *)
      log_warning "Unsupported or unknown desktop environment"
      specific_install_programs=()
      specific_remove_programs=()
      flatpak_install_function="install_flatpak_minimal_generic"
      flatpak_minimal_function="install_flatpak_minimal_generic"
      ;;
  esac
}

# ===== Package Installation Functions =====
remove_programs() {
  step "Removing DE-specific programs"
  if [ ${#specific_remove_programs[@]} -eq 0 ]; then
    log_success "No specific programs to remove"
    return
  fi

  log_info "Removing ${#specific_remove_programs[@]} DE-specific programs..."
  for program in "${specific_remove_programs[@]}"; do
    if pacman -Q "$program" &>/dev/null; then
      if sudo pacman -Rns --noconfirm "$program" >/dev/null 2>&1; then
        log_success "Removed $program"
        PROGRAMS_REMOVED+=("$program")
      else
        log_error "Failed to remove $program"
      fi
    else
      log_info "$program not installed, skipping"
    fi
  done
  log_success "Program removal completed"
}

install_pacman_programs() {
  step "Installing Pacman programs"
  local pkgs=("${pacman_programs[@]}" "${essential_programs[@]}")
  if [ "${#specific_install_programs[@]}" -gt 0 ]; then
    pkgs+=("${specific_install_programs[@]}")
  fi
  install_pacman_quietly "${pkgs[@]}"
}

install_aur_packages() {
  step "Installing AUR packages"
  if [ ${#aur_programs[@]} -eq 0 ]; then
    log_success "No AUR packages to install"
    return
  fi

  if ! check_paru; then
    log_warning "Skipping AUR package installation due to missing paru"
    return
  fi

  install_aur_quietly "${aur_programs[@]}"
}

# ===== Flatpak Functions =====
install_flatpak_programs_list() {
  local flatpaks=("$@")
  install_flatpak_quietly "${flatpaks[@]}"
}

get_flatpak_packages() {
  local de="$1"
  local mode="$2"
  local -n packages_array="$3"

  packages_array=()
  local yq_output
  yq_output=$(yq -r ".flatpak.$de.$mode[].name" "$PROGRAMS_YAML" 2>/dev/null)

  if [[ $? -eq 0 && -n "$yq_output" ]]; then
    while IFS= read -r package; do
      [[ -z "$package" ]] && continue
      packages_array+=("$package")
    done <<< "$yq_output"
  fi
}

install_flatpak_programs_kde() {
  step "Installing Flatpak programs for KDE"
  local flatpaks
  get_flatpak_packages "kde" "default" flatpaks
  install_flatpak_programs_list "${flatpaks[@]}"
}

install_flatpak_programs_gnome() {
  step "Installing Flatpak programs for GNOME"
  local flatpaks
  get_flatpak_packages "gnome" "default" flatpaks
  install_flatpak_programs_list "${flatpaks[@]}"
}

install_flatpak_programs_cosmic() {
  step "Installing Flatpak programs for Cosmic"
  local flatpaks
  get_flatpak_packages "cosmic" "default" flatpaks
  install_flatpak_programs_list "${flatpaks[@]}"
}

install_flatpak_minimal_kde() {
  step "Installing minimal Flatpak programs for KDE"
  local flatpaks
  get_flatpak_packages "kde" "minimal" flatpaks
  install_flatpak_programs_list "${flatpaks[@]}"
}

install_flatpak_minimal_gnome() {
  step "Installing minimal Flatpak programs for GNOME"
  local flatpaks
  get_flatpak_packages "gnome" "minimal" flatpaks
  install_flatpak_programs_list "${flatpaks[@]}"
}

install_flatpak_minimal_cosmic() {
  step "Installing minimal Flatpak programs for Cosmic"
  local flatpaks
  get_flatpak_packages "cosmic" "minimal" flatpaks
  install_flatpak_programs_list "${flatpaks[@]}"
}

install_flatpak_minimal_generic() {
  step "Installing minimal Flatpak programs (generic DE/WM)"
  local flatpaks
  get_flatpak_packages "generic" "minimal" flatpaks
  install_flatpak_programs_list "${flatpaks[@]}"
}

# ===== CachyOS Package Filtering =====
filter_packages_for_cachyos() {
  log_info "Filtering packages for CachyOS native compatibility"

  # Packages that CachyOS already has or manages differently
  local cachyos_skip_packages=(
    "paru"
    "fish"
    "plymouth"
    "plymouth-theme-archlinux"
    "grub-theme-vimix"
    "kernel-modules-hook"
  )

  # Filter essential programs
  local filtered_essential=()
  for package in "${essential_programs[@]}"; do
    local should_skip=false
    for skip_package in "${cachyos_skip_packages[@]}"; do
      if [[ "$package" == "$skip_package" ]]; then
        log_info "Skipping $package - already provided by CachyOS"
        should_skip=true
        break
      fi
    done

    if ! $should_skip && pacman -Q "$package" &>/dev/null; then
      log_info "Skipping $package - already configured by CachyOS"
      should_skip=true
    fi

    if ! $should_skip; then
      filtered_essential+=("$package")
    fi
  done
  essential_programs=("${filtered_essential[@]}")

  # Filter AUR programs
  local filtered_aur=()
  for package in "${aur_programs[@]}"; do
    local should_skip=false
    for skip_package in "${cachyos_skip_packages[@]}"; do
      if [[ "$package" == "$skip_package" ]]; then
        log_info "Skipping AUR package $package - already provided by CachyOS"
        should_skip=true
        break
      fi
    done

    if ! $should_skip && pacman -Q "$package" &>/dev/null; then
      log_info "Skipping AUR package $package - already configured by CachyOS"
      should_skip=true
    fi

    if ! $should_skip; then
      filtered_aur+=("$package")
    fi
  done
  aur_programs=("${filtered_aur[@]}")

  log_success "Package filtering completed for CachyOS"
}

print_total_packages() {
  step "Calculating total packages to install"
  local pacman_total=$((${#pacman_programs[@]} + ${#essential_programs[@]} + ${#specific_install_programs[@]}))
  local aur_total=${#aur_programs[@]}
  local flatpak_total=0

  if [[ "$INSTALL_MODE" == "default" ]]; then
    case "$XDG_CURRENT_DESKTOP" in
      KDE) flatpak_total=3 ;;
      GNOME) flatpak_total=4 ;;
      COSMIC) flatpak_total=4 ;;
      *) flatpak_total=1 ;;
    esac
  else
    case "$XDG_CURRENT_DESKTOP" in
      KDE) flatpak_total=1 ;;
      GNOME) flatpak_total=2 ;;
      COSMIC) flatpak_total=2 ;;
      *) flatpak_total=1 ;;
    esac
  fi

  local total_packages=$((pacman_total + aur_total + flatpak_total))
  log_info "Total packages to install: $total_packages (Pacman: $pacman_total, AUR: $aur_total, Flatpak: $flatpak_total)"
}

# ===== MAIN LOGIC =====
log_info "=== CACHYOS PROGRAMS INSTALLATION ==="
log_info "INSTALL_MODE: ${INSTALL_MODE:-NOT_SET}"
log_info "CachyOS: Native installation"
log_info "Shell choice: ${CACHYOS_SHELL_CHOICE:-NOT_SET}"
log_info "======================================"

# Load packages based on install mode
if [[ "$INSTALL_MODE" == "default" ]]; then
  log_info "Loading DEFAULT installation packages"
  essential_programs=("${essential_programs_default[@]}")
  aur_programs=("${aur_programs_default[@]}")
elif [[ "$INSTALL_MODE" == "minimal" ]]; then
  log_info "Loading MINIMAL installation packages"
  essential_programs=("${essential_programs_minimal[@]}")
  aur_programs=("${aur_programs_minimal[@]}")
else
  log_error "INSTALL_MODE not set or invalid: '${INSTALL_MODE:-NOT_SET}'. Using default mode"
  essential_programs=("${essential_programs_default[@]}")
  aur_programs=("${aur_programs_default[@]}")
fi

log_info "Before CachyOS filtering - Essential: ${#essential_programs[@]}, AUR: ${#aur_programs[@]}"

check_flatpak || log_warning "Flatpak packages will be skipped"

detect_desktop_environment
print_total_packages

# Apply CachyOS package filtering
filter_packages_for_cachyos
log_info "After CachyOS filtering - Essential: ${#essential_programs[@]}, AUR: ${#aur_programs[@]}"

# Execute installation steps
remove_programs
install_pacman_programs
install_aur_packages

# Install Flatpak packages based on mode
if [[ "$INSTALL_MODE" == "default" ]]; then
  if [ -n "$flatpak_install_function" ]; then
    $flatpak_install_function
  else
    log_warning "No Flatpak install function for your DE"
  fi
elif [[ "$INSTALL_MODE" == "minimal" ]]; then
  if [ -n "$flatpak_minimal_function" ]; then
    $flatpak_minimal_function
  else
    install_flatpak_minimal_generic
  fi
fi

# Print summary
log_info "=== PROGRAMS INSTALLATION SUMMARY ==="
if [ ${#PROGRAMS_INSTALLED[@]} -gt 0 ]; then
  log_success "Installed: ${#PROGRAMS_INSTALLED[@]} packages"
else
  log_info "No new packages were installed"
fi

if [ ${#PROGRAMS_REMOVED[@]} -gt 0 ]; then
  log_info "Removed: ${#PROGRAMS_REMOVED[@]} packages"
fi

if [ ${#PROGRAMS_ERRORS[@]} -gt 0 ]; then
  log_warning "Errors: ${#PROGRAMS_ERRORS[@]} issues encountered"
  for err in "${PROGRAMS_ERRORS[@]}"; do
    log_error "$err"
  done
else
  log_success "All program installation steps completed successfully!"
fi

log_success "CachyOS programs installation completed"
