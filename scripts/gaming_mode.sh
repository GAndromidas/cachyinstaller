#!/bin/bash
set -uo pipefail

# Gaming and performance tweaks installation for CachyOS
# Get the directory where this script is located, resolving symlinks
SCRIPT_PATH="$(readlink -f "${BASH_SOURCE[0]}")"
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
CACHYINSTALLER_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
CONFIGS_DIR="$CACHYINSTALLER_ROOT/configs"
GAMING_YAML="$CONFIGS_DIR/gaming_mode.yaml"

source "$SCRIPT_DIR/common.sh"

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
	if sudo pacman -S --noconfirm --needed "$pkg" >/dev/null 2>&1; then
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
	if paru -S --noconfirm --needed "$pkg" >/dev/null 2>&1; then
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
	if flatpak install -y --noninteractive flathub "$pkg" >/dev/null 2>&1; then
		printf "${GREEN} ✓ Success${RESET}\n"
		return 0
	else
		printf "${RED} ✗ Failed${RESET}\n"
		return 1
	fi
}

# ===== YAML Parsing Functions =====

ensure_yq() {
	if ! command -v yq &>/dev/null; then
		ui_info "yq is required for YAML parsing. Installing..."
		if ! pacman_install "yq"; then
			log_error "Failed to install yq. Please install it manually: sudo pacman -S yq"
			return 1
		fi
	fi
	return 0
}

read_yaml_packages() {
	local yaml_file="$1"
	local yaml_path="$2"
	local -n packages_array="$3"

	packages_array=()
	local yq_output
	yq_output=$(yq -r "$yaml_path[].name" "$yaml_file" 2>/dev/null)

	if [[ $? -eq 0 && -n "$yq_output" ]]; then
		while IFS= read -r name; do
			[[ -z "$name" ]] && continue
			packages_array+=("$name")
		done <<<"$yq_output"
	fi
}

# ===== Mesa-Git Replacement Function =====
install_mesa_git_for_steam() {
	ui_info "Preparing mesa-git packages for Steam installation..."
	
	# Try different mesa-git package strategies
	local mesa_packages_success=0
	local mesa_packages_failed=0
	
	# Strategy 1: Try mesa-git packages from official repositories
	ui_info "Attempting to install mesa-git packages from repositories..."
	local mesa_git_packages=("mesa-git" "lib32-mesa-git")
	
	for pkg in "${mesa_git_packages[@]}"; do
		ui_info "Installing $pkg to replace standard mesa..."
		if sudo pacman -S --noconfirm --needed --overwrite "*" "$pkg" >/dev/null 2>&1; then 
			GAMING_INSTALLED+=("$pkg")
			((mesa_packages_success++))
		else 
			((mesa_packages_failed++))
			ui_warn "Failed to install $pkg from repositories"
		fi
	done
	
	# Strategy 2: If repository failed, try AUR packages
	if [ $mesa_packages_failed -gt 0 ] && command -v paru >/dev/null; then
		ui_info "Repository packages failed, trying AUR packages..."
		local aur_mesa_packages=("amdonly-gaming-mesa-git" "lib32-amdonly-gaming-mesa-git")
		
		for pkg in "${aur_mesa_packages[@]}"; do
			ui_info "Installing $pkg from AUR..."
			if paru_install "$pkg"; then 
				GAMING_INSTALLED+=("$pkg (AUR)")
				((mesa_packages_success++))
			else 
				((mesa_packages_failed++))
				ui_warn "Failed to install $pkg from AUR"
			fi
		done
	fi
	
	# Strategy 3: If all mesa-git failed, try forcing Steam installation
	if [ $mesa_packages_success -eq 0 ]; then
		ui_warn "All mesa-git packages failed to install"
		ui_info "Attempting to install Steam with standard mesa packages..."
		
		# Try installing Steam directly to see if it works
		if sudo pacman -S --noconfirm --needed steam >/dev/null 2>&1; then
			GAMING_INSTALLED+=("steam (with standard mesa)")
			ui_success "Steam installed with standard mesa packages"
			return 0
		else
			ui_error "Steam installation failed even with standard mesa"
			return 1
		fi
	fi
	
	if [ $mesa_packages_success -gt 0 ]; then
		ui_success "Mesa-git packages installed successfully ($mesa_packages_success/$((mesa_packages_success + mesa_packages_failed)))"
		return 0
	else
		ui_error "All mesa-git installation attempts failed"
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
		return 1
	fi

	read_yaml_packages "$GAMING_YAML" ".pacman.packages" pacman_gaming_programs
	read_yaml_packages "$GAMING_YAML" ".aur.packages" aur_gaming_programs
	read_yaml_packages "$GAMING_YAML" ".flatpak.apps" flatpak_gaming_programs
	return 0
}

# ===== Enhanced Installation Functions with Batch Support =====
install_pacman_packages() {
	if [[ ${#pacman_gaming_programs[@]} -eq 0 ]]; then
		ui_info "No pacman packages for gaming mode to install."
		return
	fi
	
	# Filter out Steam if it was already installed during mesa-git process
	local filtered_packages=()
	local steam_already_installed=false
	
	# Check if Steam was already installed
	for pkg in "${pacman_gaming_programs[@]}"; do
		if [[ "$pkg" == "steam" ]] && pacman -Q "$pkg" &>/dev/null; then
			steam_already_installed=true
			ui_info "Steam already installed during mesa-git process, skipping..."
		else
			filtered_packages+=("$pkg")
		fi
	done
	
	if [[ ${#filtered_packages[@]} -eq 0 ]]; then
		ui_info "All pacman packages already installed."
		return
	fi
	
	ui_info "Installing ${#filtered_packages[@]} pacman packages for gaming..."

	# Try batch install first for speed
	printf "${CYAN}Attempting batch installation...${RESET}\n"
	if sudo pacman -S --noconfirm --needed "${filtered_packages[@]}" >/dev/null 2>&1; then
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
	if paru -S --noconfirm --needed "${aur_gaming_programs[@]}" >/dev/null 2>&1; then
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
	if ! flatpak remote-list | grep -q flathub; then
		step "Adding Flathub remote"
		flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
	fi
	if [[ ${#flatpak_gaming_programs[@]} -eq 0 ]]; then
		ui_info "No Flatpak applications for gaming mode to install."
		return
	fi
	ui_info "Installing ${#flatpak_gaming_programs[@]} Flatpak applications for gaming..."

	# Try batch install first
	printf "${CYAN}Attempting batch installation...${RESET}\n"
	if flatpak install -y --noninteractive flathub "${flatpak_gaming_programs[@]}" >/dev/null 2>&1; then
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

	if [ -f "$mangohud_config_source" ]; then
		cp "$mangohud_config_source" "$mangohud_config_dir/MangoHud.conf"
		log_success "MangoHud configuration copied successfully."
	else
		log_warning "MangoHud configuration file not found at $mangohud_config_source"
	fi
}

# ===== Summary =====
print_summary() {
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

	local description="This includes popular tools like Steam, Wine, GameMode, MangoHud, Heroic Games Launcher, Faugus Launcher and more."
	if ! gum_confirm "Enable Gaming Mode?" "$description"; then
		ui_info "Gaming Mode skipped."
		return 0
	fi

	if ! load_package_lists; then
		return 1
	fi

	# Install mesa-git packages first to enable Steam installation
	install_mesa_git_for_steam
	
	install_pacman_packages
	install_aur_packages
	install_flatpak_packages
	configure_mangohud
	print_summary
	ui_success "Gaming Mode setup completed."
}

main
