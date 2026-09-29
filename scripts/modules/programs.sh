#!/bin/bash
set -uo pipefail

# --- Configuration & Dependencies ---
CONFIGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../configs" && pwd)"
PROGRAMS_YAML="$CONFIGS_DIR/programs.yaml"

# This script parses package lists from YAML. `yq` gives stricter parsing
# when present, but the built-in fallback parser handles everything here —
# so a missing/failed yq install is never fatal.
ensure_yq() {
  if command_exists yq; then
    return 0
  fi
  ui_info "Trying to install 'yq' for stricter YAML parsing (optional, fallback available)..."
  if [ "${DRY_RUN:-false}" = false ]; then
    install_packages_quietly yq >>"$INSTALL_LOG" 2>&1 || \
      log_warning "Could not install 'yq' — continuing with built-in parser."
  else
    ui_info "[DRY-RUN] Would try to install 'yq' (optional)."
  fi
  return 0
}

# --- YAML Parsing Helper ---
# Handles both shapes used in programs.yaml:
#   - lists of objects with a 'name' key  -> uses .name
#   - bare string lists (DE install/remove) -> uses the item itself
# Uses yq when available, otherwise the built-in fallback parser.
read_yaml_list() {
  local yaml_path="$1"
  if command_exists yq; then
    yq -r "${yaml_path}[] | .name // ." "$PROGRAMS_YAML" 2>/dev/null || true
    return 0
  fi
  if declare -f _yaml_fallback_packages_with_desc >/dev/null 2>&1; then
    local _fp=() _fd=()
    _yaml_fallback_packages_with_desc "$PROGRAMS_YAML" "$yaml_path" _fp _fd
    printf '%s\n' "${_fp[@]}"
    return 0
  fi
  log_warning "yq not found and no fallback parser — list $yaml_path will be empty"
  return 0
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



# --- UI Helper for this script (guarded: common.sh provides the same helper) ---
if ! declare -f print_package_summary >/dev/null 2>&1; then
print_package_summary() {
  local title="$1"
  shift
  local pkgs=("$@")

  if [ ${#pkgs[@]} -gt 0 ]; then
    echo ""
    ui_info "$title:"
    # Use column to format the list nicely.
    # The sed command removes empty lines that might result from filtering.
    printf '%s\n' "${pkgs[@]}" | sed '/^$/d' | column | sed 's/^/  /'
  fi
}
fi

# --- Main Logic ---

# 1. Verify YAML file and try to ensure 'yq' (optional, never fatal)
if [[ ! -f "$PROGRAMS_YAML" ]]; then
  log_error "Programs configuration file not found: $PROGRAMS_YAML"
  return 1
fi
ensure_yq || true

# 2. Load all package lists
ui_info "Loading package lists for '$INSTALL_MODE' mode..."
mapfile -t pacman_base_pkgs < <(read_yaml_list ".pacman.packages")
mapfile -t essential_pkgs < <(read_yaml_list ".essential.${INSTALL_MODE:-default}")
mapfile -t aur_pkgs < <(read_yaml_list ".aur.${INSTALL_MODE:-default}")

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

# 3. Consolidate Pacman packages (dedupe, drop empties)
dedupe_list() {
  # $1 = nameref of array to dedupe in place
  local -n _dl="$1"
  local _seen=() _out=() _item _s
  for _item in "${_dl[@]}"; do
    _item=$(echo "$_item" | xargs)
    [[ -z "$_item" ]] && continue
    _s=" ${_seen[*]} "
    [[ "$_s" == *" $_item "* ]] && continue
    _seen+=("$_item")
    _out+=("$_item")
  done
  _dl=("${_out[@]}")
}
pacman_pkgs_to_install=(
  "${pacman_base_pkgs[@]}"
  "${essential_pkgs[@]}"
  "${de_install_pkgs[@]}"
)
dedupe_list pacman_pkgs_to_install
dedupe_list aur_pkgs
dedupe_list flatpak_pkgs

# 4. Display a summary of what will be installed
print_header "Package Installation Summary"
print_package_summary "The following packages will be installed from Pacman" "${pacman_pkgs_to_install[@]}"
print_package_summary "The following packages will be installed from the AUR" "${aur_pkgs[@]}"
print_package_summary "The following packages will be installed from Flatpak" "${flatpak_pkgs[@]}"

if [ ${#pacman_pkgs_to_install[@]} -eq 0 ] && [ ${#aur_pkgs[@]} -eq 0 ] && [ ${#flatpak_pkgs[@]} -eq 0 ]; then
  ui_success "No new packages to install."
  return 0
fi

# 5. Remove conflicting packages first
remove_pacman_packages "${de_remove_pkgs[@]}"

# Batch install with individual fallback. Single-item helpers already record
# into INSTALLED_PACKAGES / FAILED_PACKAGES, so fallback loops must not
# re-append (avoids double counting).
install_pacman_packages() {
  if [[ ${#pacman_pkgs_to_install[@]} -eq 0 ]]; then
    ui_info "No pacman packages to install."
    return
  fi
  # Skip already-installed to shrink the batch
  local _to_install=() _p
  for _p in "${pacman_pkgs_to_install[@]}"; do
    pacman -Q "$_p" &>/dev/null || _to_install+=("$_p")
  done
  if [[ ${#_to_install[@]} -eq 0 ]]; then
    ui_info "All ${#pacman_pkgs_to_install[@]} pacman packages already installed."
    return
  fi
  ui_info "Installing ${#_to_install[@]}/${#pacman_pkgs_to_install[@]} pacman packages..."

  if [ "${DRY_RUN:-false}" = true ]; then
    ui_info "Dry-run: would install these packages via Pacman:"
    printf '  %s\n' "${_to_install[@]}"
    return
  fi

  printf "${CYAN}Attempting batch installation...${RESET}\n"
  if sudo pacman -S --noconfirm --needed "${_to_install[@]}" >>"$INSTALL_LOG" 2>&1; then
    printf "${GREEN} ✓ Batch installation successful${RESET}\n"
    INSTALLED_PACKAGES+=("${_to_install[@]}")
    return
  fi

  printf "${YELLOW} ! Batch installation failed. Falling back to individual installation...${RESET}\n"
  for _p in "${_to_install[@]}"; do
    pacman_install_single "$_p" true || true
  done
}

# Ensure an AUR helper exists before attempting AUR installs. CachyOS ships
# paru by default, but minimal profiles may lack it — without this, every
# AUR package (rustdesk, dropbox, ventoy) is silently skipped with only a
# warning in the log.
ensure_aur_helper() {
  if command_exists paru || command_exists yay; then
    return 0
  fi
  ui_info "No AUR helper found — installing 'paru' (required for AUR packages)..."
  if [ "${DRY_RUN:-false}" = false ]; then
    if install_packages_quietly paru; then
      ui_success "paru installed."
      return 0
    fi
    log_error "Failed to install paru — AUR packages will be skipped."
    return 1
  else
    ui_info "[DRY-RUN] Would install 'paru'."
  fi
  return 0
}

# AUR installation with batch and fallback (paru first, yay fallback)
install_aur_packages_enhanced() {
  if [[ ${#aur_pkgs[@]} -eq 0 ]]; then
    ui_info "No AUR packages to install."
    return
  fi
  local _helper=""
  if declare -f aur_helper >/dev/null 2>&1; then
    _helper=$(aur_helper)
  else
    _helper="paru"
  fi
  if ! command -v "$_helper" >/dev/null; then
    ui_warn "AUR helper '$_helper' is not installed. Skipping AUR packages."
    return
  fi
  ui_info "Installing ${#aur_pkgs[@]} AUR packages with $_helper..."

  if [ "${DRY_RUN:-false}" = true ]; then
    ui_info "Dry-run: would install these AUR packages with $_helper:"
    printf '  %s\n' "${aur_pkgs[@]}"
    return
  fi

  printf "${CYAN}Attempting batch installation...${RESET}\n"
  if "$_helper" -S --noconfirm --needed "${aur_pkgs[@]}" >>"$INSTALL_LOG" 2>&1; then
    printf "${GREEN} ✓ Batch installation successful${RESET}\n"
    for _p in "${aur_pkgs[@]}"; do
      INSTALLED_PACKAGES+=("$_p (AUR)")
    done
    return
  fi

  printf "${YELLOW} ! Batch installation failed. Falling back to individual installation...${RESET}\n"
  for _p in "${aur_pkgs[@]}"; do
    paru_install_single "$_p" true || true
  done
}

# Flatpak runs in parallel with pacman+AUR (no shared lock), so the caller
# starts it in the background. This helper is the synchronous fallback path.
install_flatpak_packages_sync() {
  if ! command -v flatpak >/dev/null; then
    ui_warn "flatpak is not installed. Skipping Flatpak packages."
    return
  fi
  if [[ ${#flatpak_pkgs[@]} -eq 0 ]]; then
    ui_info "No Flatpak applications to install."
    return
  fi
  if [ "${DRY_RUN:-false}" = true ]; then
    ui_info "Dry-run: would install these Flatpak applications:"
    printf '  %s\n' "${flatpak_pkgs[@]}"
    return
  fi
  if declare -f flatpak_install_batch >/dev/null 2>&1; then
    flatpak_install_batch "${flatpak_pkgs[@]}" || true
  else
    for _p in "${flatpak_pkgs[@]}"; do
      flatpak_install_single "$_p" true || true
    done
  fi
}

# 6-8. Install: Flatpak shares no lock with pacman/paru, so it runs in
# parallel in the background while pacman+AUR install. The background job
# can't touch parent arrays — its exit code travels via a file. All output
# stays in the install log.
_flatpak_rc_file=""
_flatpak_pid=""
if command -v flatpak &>/dev/null && [[ ${#flatpak_pkgs[@]} -gt 0 ]]; then
  if [ "${DRY_RUN:-false}" = true ]; then
    ui_info "Dry-run: would install ${#flatpak_pkgs[@]} Flatpak applications in parallel."
  elif declare -f flatpak_install_batch >/dev/null 2>&1; then
    _flatpak_rc_file=$(mktemp /tmp/cachyinstaller_flatpak.XXXXXX)
    ( flatpak_install_batch "${flatpak_pkgs[@]}" >>"$INSTALL_LOG" 2>&1; echo "$?" > "$_flatpak_rc_file" ) &
    _flatpak_pid=$!
  fi
fi

# 6. Install Pacman packages with batch/fallback
install_pacman_packages

# 7. Install AUR packages with batch/fallback (helper ensured first)
if [ ${#aur_pkgs[@]} -gt 0 ]; then
  if ensure_aur_helper && { command_exists paru || command_exists yay; }; then
    install_aur_packages_enhanced
  else
    ui_warn "No AUR helper available. Skipping AUR packages."
  fi
fi

# 8. Flatpak: join background job, or fall back to synchronous install
if [[ -n "$_flatpak_pid" ]]; then
  wait "$_flatpak_pid"
  _flatpak_rc=1
  _flatpak_rc=$(cat "$_flatpak_rc_file" 2>/dev/null || echo 1)
  rm -f "$_flatpak_rc_file"
  if [[ "$_flatpak_rc" -eq 0 ]]; then
    INSTALLED_PACKAGES+=("${flatpak_pkgs[@]}")
  else
    FAILED_PACKAGES+=("flatpak batch (see log for per-app results)")
  fi
elif [ ${#flatpak_pkgs[@]} -gt 0 ]; then
  if ! command -v flatpak &>/dev/null; then
    ui_info "Setting up Flatpak..."
    install_packages_quietly flatpak || { log_error "Failed to install Flatpak. Skipping Flatpak packages."; return 0; }
    if [ "${DRY_RUN:-false}" = false ]; then
      if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
        flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >> "$INSTALL_LOG" 2>&1
        ui_info "Flathub remote added."
      fi
    fi
  fi
  install_flatpak_packages_sync
fi

# Final roll-up so a partial failure is never silently invisible.
echo ""
if [[ ${#FAILED_PACKAGES[@]} -gt 0 ]]; then
  ui_warn "Programs installation completed with ${#FAILED_PACKAGES[@]} failure(s): ${FAILED_PACKAGES[*]}"
  ui_info "Everything else installed successfully (${#INSTALLED_PACKAGES[@]} package(s)). Check $INSTALL_LOG for details."
else
  ui_success "Programs installation complete — ${#INSTALLED_PACKAGES[@]} package(s) installed, 0 failures."
fi

return 0
