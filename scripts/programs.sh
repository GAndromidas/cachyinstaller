#!/bin/bash
set -uo pipefail

# --- Configuration & Dependencies ---
CONFIGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs" && pwd)"
PROGRAMS_YAML="$CONFIGS_DIR/programs.yaml"

# This script depends on 'yq' for parsing the YAML file.
# This function ensures it's installed before proceeding.
ensure_yq() {
  if ! command_exists yq; then
    ui_info "YAML processor 'yq' is not installed. Installing it now..."
    install_packages_quietly go-yq || {
      log_error "Failed to install 'go-yq'. This is a critical dependency for package management."
      return 1
    }
  fi
  return 0
}

# --- YAML Parsing Helper ---
# Reads a simple list of packages from a given path in the YAML file.
# Reads a list of packages from a given path in the YAML file.
# It correctly handles simple lists of strings and lists of objects with a 'name' key.
read_yaml_list() {
  local yaml_path="$1"
  # For each item in the array, get its '.name' property. If it's null (e.g., a simple string), return the item itself.
  yq -r "${yaml_path}[] | .name // ." "$PROGRAMS_YAML" 2>/dev/null || echo ""
}

# --- Package Manager Helpers ---
# Custom helper for removing packages, respecting DRY_RUN.
remove_pacman_packages() {
  local pkgs_to_remove=("$@")
  if [ ${#pkgs_to_remove[@]} -eq 0 ]; then
    return
  fi

  ui_info "Removing conflicting or unnecessary packages..."
  for pkg in "${pkgs_to_remove[@]}"; do
    if pacman -Q "$pkg" &>/dev/null; then
      if [ "${DRY_RUN:-false}" = false ]; then
        sudo pacman -Rns --noconfirm "$pkg" >> "$INSTALL_LOG" 2>&1 && ui_info "  - Removed $pkg" || log_error "Failed to remove $pkg"
      else
        ui_info "  - [DRY-RUN] Would remove $pkg"
      fi
    fi
  done
}



# --- Main Logic ---

# 1. Verify YAML file and 'yq' dependency
if [[ ! -f "$PROGRAMS_YAML" ]]; then
  log_error "Programs configuration file not found: $PROGRAMS_YAML"
  return 1
fi
ensure_yq || return 1

# 2. Load package lists based on installation mode
ui_info "Loading package lists for '$INSTALL_MODE' mode..."
mapfile -t pacman_base_pkgs < <(read_yaml_list ".pacman.packages")
mapfile -t essential_pkgs < <(read_yaml_list ".essential.${INSTALL_MODE:-default}")
mapfile -t aur_pkgs < <(read_yaml_list ".aur.${INSTALL_MODE:-default}")

# 3. Detect Desktop Environment and load DE-specific packages
de_lower="generic"
case "${XDG_CURRENT_DESKTOP:-}" in
  KDE) de_lower="kde" ;;
  GNOME) de_lower="gnome" ;;
  COSMIC) de_lower="cosmic" ;;
esac
ui_info "Detected Desktop Environment: ${de_lower^}"

mapfile -t de_install_pkgs < <(read_yaml_list ".desktop_environments.${de_lower}.install")
mapfile -t de_remove_pkgs < <(read_yaml_list ".desktop_environments.${de_lower}.remove")
mapfile -t flatpak_pkgs < <(read_yaml_list ".flatpak.${de_lower}.${INSTALL_MODE:-default}")

# 4. Remove conflicting packages
remove_pacman_packages "${de_remove_pkgs[@]}"

# 5. Install Pacman packages
pacman_pkgs_to_install=(
  "${pacman_base_pkgs[@]}"
  "${essential_pkgs[@]}"
  "${de_install_pkgs[@]}"
)
# Filter out empty array elements
pacman_pkgs_to_install=(${pacman_pkgs_to_install[@]})
if [ ${#pacman_pkgs_to_install[@]} -gt 0 ]; then
    install_packages_quietly "${pacman_pkgs_to_install[@]}"
else
    ui_info "No new Pacman packages to install."
fi

# 6. Install AUR packages
if command_exists paru; then
  install_aur_packages "${aur_pkgs[@]}"
else
  ui_warn "AUR helper 'paru' not found. Skipping AUR packages."
fi

# 7. Install Flatpak packages
if [ ${#flatpak_pkgs[@]} -gt 0 ]; then
    ui_info "Setting up Flatpak..."
    if ! command_exists flatpak; then
        ui_info "Installing Flatpak..."
        install_packages_quietly flatpak || { log_error "Failed to install Flatpak. Skipping Flatpak packages."; return 0; }
    fi

    if [ "${DRY_RUN:-false}" = false ]; then
        # Ensure flathub remote exists
        if ! flatpak remote-list | grep -q flathub; then
            flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$INSTALL_LOG" 2>&1
            ui_info "Flathub remote added."
        fi
    else
        ui_info "[DRY-RUN] Would ensure Flathub remote exists."
    fi
    install_flatpak_quietly "${flatpak_pkgs[@]}"
else
    ui_info "No Flatpak packages selected for installation."
fi

return 0
