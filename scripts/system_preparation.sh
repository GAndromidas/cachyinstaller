#!/usr/bin/env bash
set -uo pipefail

# Get script directory and source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# Constants
BACKUP_DIR="$HOME/.cache/cachyinstaller/backups"
PERF_LOG="$HOME/.cache/cachyinstaller/performance.log"
NETWORK_LOG="$HOME/.cache/cachyinstaller/network.log"

# Constants for network speed thresholds (in Mbps)
SPEED_VERY_SLOW=5
SPEED_SLOW=10
SPEED_MEDIUM=50
SPEED_FAST=100

# Initialize directories
mkdir -p "$BACKUP_DIR"
mkdir -p "$(dirname "$PERF_LOG")"
mkdir -p "$(dirname "$NETWORK_LOG")"

# Function to measure download speed
measure_download_speed() {
    step "Measuring network speed"
    local speed=0
    local attempts=0
    local max_attempts=3
    local test_file="https://archlinux.org/packages/core/x86_64/linux/download"
    local fallback_file="https://github.com/archlinux/archinstall/archive/refs/heads/master.zip"

    # Try multiple speed test attempts
    while [ $attempts -lt $max_attempts ] && [ $speed -eq 0 ]; do
        attempts=$((attempts + 1))
        log_info "Testing network speed (attempt $attempts/$max_attempts)..."

        # Try curl first
        if command -v curl >/dev/null 2>&1; then
            speed=$(curl -L --max-time 10 --output /dev/null --silent --write-out "%{speed_download}" "$test_file" 2>/dev/null)
            speed=$((${speed%.*} / 131072)) # Convert to Mbps
        fi

        # If curl failed or speed is 0, try wget
        if [ "$speed" -eq 0 ] && command -v wget >/dev/null 2>&1; then
            local start_time=$(date +%s)
            if wget -O /dev/null "$fallback_file" 2>&1 | grep -q "MB/s"; then
                local end_time=$(date +%s)
                local duration=$((end_time - start_time))
                # Avoid division by zero
                if [ "$duration" -eq 0 ]; then
                    speed=0
                else
                    speed=$((5 / duration * 8)) # Assuming ~5MB file size
                fi
            fi
        fi

        # If still no valid speed, try ping
        if [ "$speed" -eq 0 ]; then
            local ping_time=$(ping -c 1 archlinux.org 2>/dev/null | grep "time=" | cut -d "=" -f 4 | cut -d " " -f 1)
            if [ -n "$ping_time" ]; then
                if [ "${ping_time%.*}" -lt 50 ]; then
                    speed=50
                elif [ "${ping_time%.*}" -lt 100 ]; then
                    speed=20
                else
                    speed=5
                fi
            fi
        fi

        [ "$speed" -gt 0 ] && break
        sleep 1
    done

    # Use conservative default if all attempts failed
    if [ "$speed" -eq 0 ]; then
        speed=10
        log_warning "Could not measure network speed, using conservative default of ${speed}Mbps"
    else
        log_success "Measured network speed: ${speed}Mbps"
    fi

    echo "$speed"
}

# Function to update mirrorlist using rate-mirrors
update_mirrors() {
    step "Updating mirrorlist with rate-mirrors"

    log_info "Running rate-mirrors to find fastest mirrors silently..."
    if sudo rate-mirrors --allow-root --save /etc/pacman.d/mirrorlist arch &>/dev/null; then
        sudo pacman -Syy &>/dev/null # Suppress output of pacman -Syy
        log_success "Mirrorlist updated successfully"
    else
        log_error "Failed to update mirrorlist with rate-mirrors"
        return 1
    fi
}

# Function to optimize pacman configuration
optimize_pacman() {
    local speed=$1
    local pacman_conf="/etc/pacman.conf"
    local parallel_downloads=5

    step "Optimizing pacman configuration"

    # Determine optimal parallel downloads based on speed
    if [ "$speed" -ge "$SPEED_FAST" ]; then
        parallel_downloads=15
    elif [ "$speed" -ge "$SPEED_MEDIUM" ]; then
        parallel_downloads=10
    elif [ "$speed" -ge "$SPEED_SLOW" ]; then
        parallel_downloads=5
    else
        parallel_downloads=3
    fi

    # Backup original pacman.conf
    if [ -f "$pacman_conf" ]; then
        sudo cp "$pacman_conf" "${BACKUP_DIR}/pacman.conf.$(date +%Y%m%d_%H%M%S).bak"
    fi

    # Update pacman configuration
    log_info "Configuring pacman with parallel downloads: $parallel_downloads"

    # Enable parallel downloads
    if grep -q "^#ParallelDownloads" "$pacman_conf"; then
        sudo sed -i "s/^#ParallelDownloads.*/ParallelDownloads = $parallel_downloads/" "$pacman_conf"
    elif ! grep -q "^ParallelDownloads" "$pacman_conf"; then
        echo "ParallelDownloads = $parallel_downloads" | sudo tee -a "$pacman_conf" >/dev/null
    fi

    # Enable other optimizations
    for option in "Color" "CheckSpace" "VerbosePkgLists" "ILoveCandy"; do
        if grep -q "^#$option" "$pacman_conf"; then
            sudo sed -i "s/^#$option$/$option/" "$pacman_conf"
        elif ! grep -q "^$option" "$pacman_conf"; then
            echo "$option" | sudo tee -a "$pacman_conf" >/dev/null
        fi
    done

    log_success "Pacman configuration optimized"
}

# Function to optimize paru configuration
optimize_paru() {
    local speed=$1
    local paru_conf="/etc/paru.conf"
    local max_parallel=5

    if ! command -v paru >/dev/null 2>&1; then
        return 0
    fi

    step "Optimizing paru configuration"

    # Set parallel downloads based on speed
    if [ "$speed" -ge "$SPEED_FAST" ]; then
        max_parallel=10
    elif [ "$speed" -ge "$SPEED_MEDIUM" ]; then
        max_parallel=8
    elif [ "$speed" -ge "$SPEED_SLOW" ]; then
        max_parallel=5
    else
        max_parallel=3
    fi

    # Create or update paru configuration
    if [ ! -f "$paru_conf" ]; then
        sudo touch "$paru_conf"
    else
        sudo cp "$paru_conf" "${BACKUP_DIR}/paru.conf.$(date +%Y%m%d_%H%M%S).bak"
    fi

    # Update paru settings
    if grep -q "^MaxParallel" "$paru_conf"; then
        sudo sed -i "s/^MaxParallel = .*/MaxParallel = $max_parallel/" "$paru_conf"
    else
        echo "MaxParallel = $max_parallel" | sudo tee -a "$paru_conf" >/dev/null
    fi

    log_success "Paru configuration optimized"
}

# Function to setup system enhancements
setup_system_enhancements() {
    step "Setting up system enhancements"

    # Detect CachyOS features
    if pacman -Q linux-cachyos >/dev/null 2>&1; then
        export HAS_CACHYOS_KERNEL=true
        log_info "CachyOS kernel detected"
    fi

    # Check for gaming optimizations
    if pacman -Q gamemode >/dev/null 2>&1; then
        export HAS_GAMING_MODE=true
        log_info "GameMode detected"
    fi

    # Detect GPU vendor
    if lspci | grep -i "VGA" | grep -i "NVIDIA" >/dev/null; then
        export GPU_VENDOR="nvidia"
        log_info "NVIDIA GPU detected"
    elif lspci | grep -i "VGA" | grep -i "AMD" >/dev/null; then
        export GPU_VENDOR="amd"
        log_info "AMD GPU detected"
    elif lspci | grep -i "VGA" | grep -i "Intel" >/dev/null; then
        export GPU_VENDOR="intel"
        log_info "Intel GPU detected"
    fi

    # Detect laptop
    if [ -d "/sys/class/power_supply" ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        export IS_LAPTOP=true
        log_info "Laptop system detected"
    fi

    # Setup desktop environment specific configurations
    case "$XDG_CURRENT_DESKTOP" in
        "KDE")
            export DE_CONFIG_DIR="$HOME/.config/kde"
            export DE_SHORTCUT_FILE="$HOME/.config/kglobalshortcutsrc"
            if [ -f "$DE_SHORTCUT_FILE" ]; then
                cp "$DE_SHORTCUT_FILE" "$BACKUP_DIR/kglobalshortcutsrc.$(date +%Y%m%d_%H%M%S).bak"
            fi
            ;;
        "GNOME")
            export DE_CONFIG_DIR="$HOME/.config/gnome-session"
            dconf dump / > "$BACKUP_DIR/gnome-settings.$(date +%Y%m%d_%H%M%S).bak"
            ;;
        *)
            export DE_CONFIG_DIR="$HOME/.config"
            ;;
    esac

    log_success "System enhancements configured"
}

# Main preparation function
main() {
    local start_time=$(date +%s)

    # Display header
    figlet_banner "System Preparation" || log_info "=== System Preparation ==="

    # Check network speed and optimize package managers
    local network_speed=$(measure_download_speed)

    # Update mirrors using rate-mirrors
    update_mirrors

    # Optimize package managers based on network speed
    optimize_pacman "$network_speed"
    optimize_paru "$network_speed"

    # Setup system enhancements
    setup_system_enhancements

    # Calculate and log execution time
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_success "System preparation completed in ${duration} seconds"

    return 0
}

# Execute main function
main
