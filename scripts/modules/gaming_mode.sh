#!/bin/bash
set -uo pipefail

# Gaming and performance tweaks installation for CachyOS
# Get the directory where this script is located, resolving symlinks
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
GAMING_YAML="$CONFIGS_DIR/gaming_mode.yaml"

if ! declare -f ui_info >/dev/null 2>&1; then
  # shellcheck disable=SC1091
  source "$SCRIPT_DIR/../common.sh"
fi

# ===== Globals =====
GAMING_ERRORS=()
GAMING_INSTALLED=()
pacman_gaming_programs=()
aur_gaming_programs=()
flatpak_gaming_programs=()

# ===== Local Helper Functions =====

pacman_install() {
	local pkg="$1"
	printf "${CYAN}Installing Pacman package:${RESET} %-30s" "$pkg"
	if sudo pacman -S --noconfirm --needed "$pkg" >>"$INSTALL_LOG" 2>&1; then
		printf "${GREEN} ✓ Success${RESET}\n"
		return 0
	else
		printf "${RED} ✗ Failed${RESET}\n"
		return 1
	fi
}

paru_install() {
	local pkg="$1"
	printf "${CYAN}Installing AUR package:${RESET} %-30s" "$pkg"
	if paru -S --noconfirm --needed "$pkg" >>"$INSTALL_LOG" 2>&1; then
		printf "${GREEN} ✓ Success${RESET}\n"
		return 0
	else
		printf "${RED} ✗ Failed${RESET}\n"
		return 1
	fi
}

flatpak_install() {
	local pkg="$1"
	printf "${CYAN}Installing Flatpak app:${RESET} %-30s" "$pkg"
	if flatpak install -y --noninteractive flathub "$pkg" >>"$INSTALL_LOG" 2>&1; then
		printf "${GREEN} ✓ Success${RESET}\n"
		return 0
	else
		printf "${RED} ✗ Failed${RESET}\n"
		return 1
	fi
}

# ===== YAML Parsing Functions =====
# yq gives stricter parsing when present, but the built-in fallback parser
# handles gaming_mode.yaml — so a missing yq is never fatal.
ensure_yq() {
	if command -v yq &>/dev/null; then
		return 0
	fi
	ui_info "Trying to install 'yq' for stricter YAML parsing (optional, fallback available)..."
	if [[ "${DRY_RUN:-false}" == false ]]; then
		if ! pacman_install "yq"; then
			log_warning "Could not install yq — continuing with built-in parser."
		fi
	else
		ui_info "[DRY-RUN] Would try to install 'yq' (optional)."
	fi
	return 0
}

read_gaming_yaml_packages() {
	local yaml_file="$1"
	local yaml_path="$2"
	local -n packages_array="$3"

	packages_array=()
	if command -v yq &>/dev/null; then
		local yq_output
		yq_output=$(yq -r "$yaml_path[].name" "$yaml_file" 2>/dev/null || true)

		if [[ -n "$yq_output" ]]; then
			while IFS= read -r name; do
				[[ -z "$name" ]] && continue
				packages_array+=("$name")
			done <<<"$yq_output"
		fi
		return 0
	fi
	if declare -f _yaml_fallback_packages_with_desc >/dev/null 2>&1; then
		local _fp=() _fd=()
		_yaml_fallback_packages_with_desc "$yaml_file" "$yaml_path" _fp _fd
		packages_array=("${_fp[@]}")
		return 0
	fi
	log_warning "yq not found and no fallback parser — list $yaml_path will be empty"
	return 0
}

# ===== Steam Installation for CachyOS =====
# Non-interactive by design: this module runs with stdout/stderr redirected
# to the install log (dashboard_run), so every message stays hidden behind
# the dashboard and only the log shows progress. Nothing here may touch
# /dev/tty except the sanctioned gum_confirm prompt in main().
install_steam() {
	ui_info "Installing Steam..."

	# Check if Steam is already installed
	if pacman -Q steam &>/dev/null; then
		ui_info "Steam is already installed, skipping..."
		GAMING_INSTALLED+=("steam (already installed)")
		return 0
	fi

	# CachyOS already sets up the GPU/Vulkan stack, so the driver provider
	# is normally satisfied with no prompt. --noconfirm resolves any
	# remaining choice with the default instead of blocking forever on
	# unseen stdin (which looked like a hang with an empty log).
	if sudo pacman -S --noconfirm --needed steam >>"$INSTALL_LOG" 2>&1; then
		GAMING_INSTALLED+=("steam")
		ui_success "Steam installed successfully"
		return 0
	else
		ui_error "Steam installation failed"
		return 1
	fi
}

# ===== Load All Package Lists from YAML =====
load_package_lists() {
	if [[ ! -f "$GAMING_YAML" ]]; then
		log_error "Gaming mode configuration file not found: $GAMING_YAML"
		return 1
	fi

	if ! ensure_yq; then
		log_warning "yq setup had issues — continuing with built-in parser."
	fi

	read_gaming_yaml_packages "$GAMING_YAML" ".pacman.packages" pacman_gaming_programs
	read_gaming_yaml_packages "$GAMING_YAML" ".aur.packages" aur_gaming_programs
	read_gaming_yaml_packages "$GAMING_YAML" ".flatpak.apps" flatpak_gaming_programs
	return 0
}

# ===== Enhanced Installation Functions with Batch Support =====
install_pacman_packages() {
	if [[ ${#pacman_gaming_programs[@]} -eq 0 ]]; then
		ui_info "No pacman packages for gaming mode to install."
		return
	fi
	
	# Filter out Steam if it was already installed during mesa-git process,
	# plus anything else already on the system to shrink the batch.
	local filtered_packages=()
	local steam_already_installed=false

	# Check if Steam was already installed
	for pkg in "${pacman_gaming_programs[@]}"; do
		if [[ "$pkg" == "steam" ]] && pacman -Q "$pkg" &>/dev/null; then
			steam_already_installed=true
			ui_info "Steam already installed during mesa-git process, skipping..."
		elif pacman -Q "$pkg" &>/dev/null; then
			ui_info "$pkg already installed, skipping..."
		else
			filtered_packages+=("$pkg")
		fi
	done

	if [[ ${#filtered_packages[@]} -eq 0 ]]; then
		ui_info "All pacman packages already installed."
		return
	fi

	ui_info "Installing ${#filtered_packages[@]} pacman packages for gaming..."

	# Log to INSTALL_LOG (not /dev/null): these are large downloads and the
	# dashboard hides step output, so `tail -f` on the log is the only
	# progress signal. Swallowing output looks like a hang.
	printf "${CYAN}Attempting batch installation...${RESET}\n"
	if sudo pacman -S --noconfirm --needed "${filtered_packages[@]}" >>"$INSTALL_LOG" 2>&1; then
		printf "${GREEN} ✓ Batch installation successful${RESET}\n"
		for pkg in "${filtered_packages[@]}"; do
			GAMING_INSTALLED+=("$pkg")
		done
		return
	fi

	printf "${YELLOW} ! Batch installation failed. Falling back to individual installation...${RESET}\n"
	for pkg in "${filtered_packages[@]}"; do
		if pacman_install "$pkg"; then GAMING_INSTALLED+=("$pkg"); else GAMING_ERRORS+=("$pkg (pacman)"); fi
	done
}

install_aur_packages() {
	if ! command -v paru >/dev/null; then ui_warn "paru is not installed. Skipping AUR packages."; return; fi
	if [[ ${#aur_gaming_programs[@]} -eq 0 ]]; then ui_info "No AUR packages to install."; return; fi
	ui_info "Installing ${#aur_gaming_programs[@]} AUR packages with paru..."

	# Try batch install first
	printf "${CYAN}Attempting batch installation...${RESET}\n"
	if paru -S --noconfirm --needed "${aur_gaming_programs[@]}" >>"$INSTALL_LOG" 2>&1; then
		printf "${GREEN} ✓ Batch installation successful${RESET}\n"
		for pkg in "${aur_gaming_programs[@]}"; do
			GAMING_INSTALLED+=("$pkg (AUR)")
		done
		return
	fi

	printf "${YELLOW} ! Batch installation failed. Falling back to individual installation...${RESET}\n"
	for pkg in "${aur_gaming_programs[@]}"; do
		if paru_install "$pkg"; then GAMING_INSTALLED+=("$pkg (AUR)"); else GAMING_ERRORS+=("$pkg (AUR)"); fi
	done
}

	install_flatpak_packages() {
	if ! command -v flatpak >/dev/null; then ui_warn "flatpak is not installed. Skipping gaming Flatpaks."; return; fi
	if ! flatpak remote-list 2>/dev/null | grep -q flathub; then
		step "Adding Flathub remote"
		flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo >>"$INSTALL_LOG" 2>&1
	fi
	if [[ ${#flatpak_gaming_programs[@]} -eq 0 ]]; then
		ui_info "No Flatpak applications for gaming mode to install."
		return
	fi
	ui_info "Installing ${#flatpak_gaming_programs[@]} Flatpak applications for gaming..."

	# Try batch install first (logged: Flatpak runtimes are GB-sized,
	# silent downloads look like a hang)
	printf "${CYAN}Attempting batch installation...${RESET}\n"
	if flatpak install -y --noninteractive flathub "${flatpak_gaming_programs[@]}" >>"$INSTALL_LOG" 2>&1; then
		printf "${GREEN} ✓ Batch installation successful${RESET}\n"
		for pkg in "${flatpak_gaming_programs[@]}"; do
			GAMING_INSTALLED+=("$pkg (Flatpak)")
		done
		return
	fi

	printf "${YELLOW} ! Batch installation failed. Falling back to individual installation...${RESET}\n"
	for pkg in "${flatpak_gaming_programs[@]}"; do
		if flatpak_install "$pkg"; then GAMING_INSTALLED+=("$pkg (Flatpak)"); else GAMING_ERRORS+=("$pkg (Flatpak)"); fi
	done
}

# ===== Configuration Functions =====
configure_mangohud() {
	step "Configuring MangoHud"
	local mangohud_config_dir="$HOME/.config/MangoHud"
	local mangohud_config_source="$CONFIGS_DIR/MangoHud.conf"

	mkdir -p "$mangohud_config_dir"

	if [ -f "$mangohud_config_dir/MangoHud.conf" ]; then
		ui_info "MangoHud configuration already exists, skipping."
		return 0
	fi

	if [ -f "$mangohud_config_source" ]; then
		cp "$mangohud_config_source" "$mangohud_config_dir/MangoHud.conf"
		log_success "MangoHud configuration copied successfully."
	else
		log_warning "MangoHud configuration file not found at $mangohud_config_source"
	fi
}

# ===== Summary =====
print_gaming_summary() {
	echo ""
	ui_header "Gaming Mode Setup Summary"
	if [[ ${#GAMING_INSTALLED[@]} -gt 0 ]]; then
		echo -e "${GREEN}Installed:${RESET}"
		printf "  - %s\n" "${GAMING_INSTALLED[@]}"
	fi
	if [[ ${#GAMING_ERRORS[@]} -gt 0 ]]; then
		echo -e "${RED}Errors:${RESET}"
		printf "  - %s\n" "${GAMING_ERRORS[@]}"
	fi
	echo ""
}

# ===== Main Execution =====
main() {
	step "Gaming Mode Setup"
	ui_header "Gaming Mode"

	local description="This includes popular tools like Steam, Wine, MangoHud, Heroic Games Launcher, Faugus Launcher and more."
	if ! gum_confirm "Enable Gaming Mode?" "$description"; then
		ui_info "Gaming Mode skipped."
		return 2
	fi

	if [[ "${DRY_RUN:-false}" == true ]]; then
		ui_info "Dry-run: Gaming Mode packages would be evaluated here."
		return 0
	fi

	if ! load_package_lists; then
		return 1
	fi

	# Install Steam (non-interactive, output hidden behind the dashboard)
	install_steam
	
	install_pacman_packages
	install_aur_packages
	install_flatpak_packages
	configure_mangohud
	print_gaming_summary
	ui_success "Gaming Mode setup completed."
}

main
