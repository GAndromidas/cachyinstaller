#!/bin/bash
set -uo pipefail

# --- Constants ---
BACKUP_DIR="$HOME/.config/cachyinstaller/backups"

# --- Initialize Directories ---
mkdir -p "$BACKUP_DIR"

# --- Function to optimize pacman configuration ---
# CachyOS-only policy: respect CachyOS defaults. CachyOS already ships an
# optimized pacman.conf (ParallelDownloads, mirrors, repos). Only ensure
# cosmetic/display options are enabled (Color, ILoveCandy, VerbosePkgLists).
# Never override ParallelDownloads or touch repos/mirrors here.
optimize_pacman() {
    local pacman_conf="/etc/pacman.conf"

    ui_info "Ensuring pacman display options (CachyOS defaults kept)..."

    # Backup original pacman.conf
    if [ -f "$pacman_conf" ] && [ "${DRY_RUN:-false}" = false ]; then
        sudo cp "$pacman_conf" "${BACKUP_DIR}/pacman.conf.$(date +%Y%m%d_%H%M%S).bak"
    fi

    if [ "${DRY_RUN:-false}" = false ]; then
        if grep -q "^#Color" "$pacman_conf"; then
            sudo sed -i "s/^#Color/Color/" "$pacman_conf"
        fi
        if grep -q "^#VerbosePkgLists" "$pacman_conf"; then
            sudo sed -i "s/^#VerbosePkgLists/VerbosePkgLists/" "$pacman_conf"
        fi
        # ILoveCandy: uncomment if commented, add if entirely missing
        if grep -q "^#ILoveCandy" "$pacman_conf"; then
            sudo sed -i "s/^#ILoveCandy/ILoveCandy/" "$pacman_conf"
        elif ! grep -q "^ILoveCandy" "$pacman_conf"; then
            if grep -q "^Color" "$pacman_conf"; then
                sudo sed -i "/^Color/a ILoveCandy" "$pacman_conf"
            else
                sudo sed -i "/^\[options\]/a ILoveCandy" "$pacman_conf"
            fi
        fi
    else
        ui_info "[DRY-RUN] Would ensure Color, ILoveCandy, VerbosePkgLists in $pacman_conf."
    fi

    ui_success "Pacman display options ensured."
}

# --- Enable sudo password feedback (asterisks) ---
# Additive only: drops a visudo-validated snippet, never edits sudoers directly.
set_sudo_pwfeedback() {
    # Globs must expand as root (sudo sh -c): /etc/sudoers.d is 750, so a
    # user-expanded glob never matches and pwfeedback would be appended again
    # on every run.
    if ! sudo sh -c 'grep -q "^Defaults.*pwfeedback" /etc/sudoers /etc/sudoers.d/* 2>/dev/null'; then
        ui_info "Enabling sudo password feedback (pwfeedback)..."
        if [ "${DRY_RUN:-false}" = false ]; then
            echo 'Defaults env_reset,pwfeedback' | sudo EDITOR='tee -a' visudo >/dev/null
        else
            ui_info "[DRY-RUN] Would enable sudo pwfeedback via visudo."
        fi
    else
        ui_info "sudo pwfeedback already enabled. Skipping."
    fi
}

# --- Main Execution ---
keyring_pkgs=("archlinux-keyring" "cachyos-keyring")
print_package_summary "Updating essential keyrings" "${keyring_pkgs[@]}"
install_packages_quietly "${keyring_pkgs[@]}" || log_error "Failed to update essential keyrings."

ui_info "Synchronizing package databases..."
if [ "${DRY_RUN:-false}" = false ]; then
    sudo pacman -Sy || log_error "Failed to synchronize package databases."
else
    ui_info "[DRY-RUN] Would have run 'sudo pacman -Sy'"
fi

optimize_pacman
set_sudo_pwfeedback

return 0
