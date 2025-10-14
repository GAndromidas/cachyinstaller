#!/bin/bash
set -uo pipefail

# --- Constants ---
BACKUP_DIR="$HOME/.config/cachyinstaller/backups"
SPEED_VERY_SLOW=5
SPEED_SLOW=10
SPEED_MEDIUM=50
SPEED_FAST=100

# --- Initialize Directories ---
mkdir -p "$BACKUP_DIR"

# --- Function to measure download speed ---
measure_download_speed() {
    ui_info "Measuring network speed..." >&2
    local speed_mbps=0
    local test_file="https://archlinux.org/packages/core/x86_64/linux/download"

    if command_exists curl; then
        local speed_bytes
        speed_bytes=$(curl -L --max-time 10 --output /dev/null --silent --write-out "%{speed_download}" "$test_file" 2>/dev/null || echo "0")
        speed_mbps=$(( (${speed_bytes%.*} * 8) / 1000000 ))
    fi

    # Use a conservative default if the measurement fails or is too low
    if [ "$speed_mbps" -eq 0 ]; then
        speed_mbps=10 # Fallback to a safe 10 Mbps
        ui_warn "Could not accurately measure network speed. Using a conservative default of ${speed_mbps}Mbps." >&2
    else
        ui_success "Measured network speed: ${speed_mbps}Mbps" >&2
    fi

    echo "$speed_mbps"
}

# --- Function to optimize pacman configuration ---
optimize_pacman() {
    local speed="$1"
    local pacman_conf="/etc/pacman.conf"
    local parallel_downloads=5

    ui_info "Optimizing pacman configuration..."

    # Determine optimal parallel downloads based on speed
    if (( speed >= SPEED_FAST )); then
        parallel_downloads=15
    elif (( speed >= SPEED_MEDIUM )); then
        parallel_downloads=10
    elif (( speed >= SPEED_SLOW )); then
        parallel_downloads=5
    else
        parallel_downloads=3
    fi

    # Backup original pacman.conf
    if [ -f "$pacman_conf" ] && [ "${DRY_RUN:-false}" = false ]; then
        sudo cp "$pacman_conf" "${BACKUP_DIR}/pacman.conf.$(date +%Y%m%d_%H%M%S).bak"
    fi

    ui_info "Setting parallel downloads to: $parallel_downloads"
    if [ "${DRY_RUN:-false}" = false ]; then
        # Enable or set ParallelDownloads
        if grep -q "^#ParallelDownloads" "$pacman_conf"; then
            sudo sed -i "s/^#ParallelDownloads.*/ParallelDownloads = $parallel_downloads/" "$pacman_conf"
        elif ! grep -q "^ParallelDownloads" "$pacman_conf"; then
            echo "ParallelDownloads = $parallel_downloads" | sudo tee -a "$pacman_conf" >/dev/null
        fi

        # Enable other candy
        for option in "Color" "CheckSpace" "VerbosePkgLists" "ILoveCandy"; do
            sudo sed -i "s/^#$option/$option/" "$pacman_conf"
        done
    else
        ui_info "[DRY-RUN] Would have configured pacman with $parallel_downloads parallel downloads."
    fi

    ui_success "Pacman configuration optimized."
}




# --- Main Execution ---
NETWORK_SPEED=$(measure_download_speed)

ui_info "Updating package keyrings..."
install_packages_quietly archlinux-keyring cachyos-keyring || log_error "Failed to update essential keyrings."

ui_info "Synchronizing package databases..."
if [ "${DRY_RUN:-false}" = false ]; then
    sudo pacman -Sy || log_error "Failed to synchronize package databases."
else
    ui_info "[DRY-RUN] Would have run 'sudo pacman -Sy'"
fi

optimize_pacman "$NETWORK_SPEED"

return 0
