#!/bin/bash
# CachyInstaller install helpers — package installation wrappers
set -uo pipefail

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
      # Always log, only print to stdout when verbose
      echo "[$current/$total] $pkg_name [SKIP] Already installed" >> "$INSTALL_LOG" 2>/dev/null || true
      [[ "$VERBOSE" == "true" ]] && ui_info "[$current/$total] $pkg_name [SKIP] Already installed"
      continue
    fi

    # Always log detailed progress, only print to stdout when verbose
    echo "[$current/$total] Installing $pkg_name..." >> "$INSTALL_LOG" 2>/dev/null || true
    [[ "$VERBOSE" == "true" ]] && ui_info "[$current/$total] Installing $pkg_name..."

    local install_cmd
    case "$pkg_manager" in
      pacman) install_cmd="sudo pacman -S --noconfirm --needed $pkg" ;;
      flatpak) install_cmd="flatpak install --noninteractive -y $pkg" ;;
    esac

    if [ "${DRY_RUN:-false}" = true ]; then
      ui_info "[DRY-RUN] Would install: $pkg_name"
      INSTALLED_PACKAGES+=("$pkg_name")
    else
      # Silently attempt to install the package.
      # Errors will be collected and shown in the final summary.
      if eval "$install_cmd" >> "$INSTALL_LOG" 2>&1; then
        INSTALLED_PACKAGES+=("$pkg_name")
      else
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