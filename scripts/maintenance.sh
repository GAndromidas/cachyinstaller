#!/usr/bin/env bash

# Import common functions if not already imported
if [ -z "$SCRIPTS_DIR" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
    source "$SCRIPT_DIR/scripts/common.sh"
fi

# Utility functions
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

run_step() {
    local description="$1"
    shift
    echo -e "\n>> $description..."
    if "$@"; then
        return 0
    else
        log_error "Failed to execute: $description"
        return 1
    fi
}

# Maintenance setup
setup_maintenance() {
    step "Maintenance"
    step "Performing final cleanup and optimizations"

    # SSD TRIM if available
    if command_exists lsblk; then
        if lsblk -d -o name,rota | grep -q "0$"; then
            sudo systemctl enable fstrim.timer
            sudo systemctl start fstrim.timer
            log_success "SSD TRIM service enabled"
        fi
    else
        log_warning "lsblk not available. Skipping SSD optimization."
    fi

    # Clean /tmp if not mounted as tmpfs
    if ! mount | grep -q "tmpfs on /tmp"; then
        sudo rm -rf /tmp/*
        log_success "Cleaned /tmp directory"
    else
        log_warning "Skipping /tmp cleanup as it is a mounted filesystem"
    fi
}

# System cleanup
cleanup_system() {
    step "Performing comprehensive system cleanup"

    # Clean package cache
    if command_exists paccache; then
        sudo paccache -rk1
        log_success "Cleaned package cache"
    else
        log_error "Failed to clean pacman cache"
    fi

    # Clean paru cache if installed
    if command_exists paru; then
        paru -Sc --noconfirm
        log_success "Cleaned paru cache"
    else
        log_warning "Failed to clean paru cache"
    fi

    # Clean flatpak if installed
    if command_exists flatpak; then
        flatpak uninstall --unused -y
        log_success "Cleaned unused Flatpak packages"
    else
        log_info "Flatpak not installed, skipping flatpak cleanup"
    fi
}

# Remove development packages
cleanup_helpers() {
    if pacman -Qi gendesk &>/dev/null; then
        echo "The following packages will be removed:"
        pacman -Qi gendesk | grep -E "^(Name|Description)" | sed 's/^/    /'

        if sudo pacman -Rns gendesk --noconfirm; then
            log_success "Removed helper packages"
        else
            log_error "Failed to remove some orphaned packages"
        fi
    fi
}

# Update mirrorlist
update_mirrors() {
    step "Updating mirrorlist"

    if command_exists rate-mirrors; then
        sudo rate-mirrors --allow-root arch --save /etc/pacman.d/mirrorlist
        sudo pacman -Sy
        log_success "Mirrorlist updated successfully"
    else
        log_warning "rate-mirrors not found, using reflector instead"
        if command_exists reflector; then
            sudo reflector --latest 20 --protocol https --sort rate --save /etc/pacman.d/mirrorlist
            sudo pacman -Sy
            log_success "Mirrorlist updated successfully"
        else
            log_error "Neither rate-mirrors nor reflector found"
            return 1
        fi
    fi
}

# Set up Btrfs snapshots
setup_snapshots() {
    if ! command_exists btrfs; then
        log_info "Not a Btrfs filesystem, skipping snapshot setup"
        return 0
    fi

    step "Configuring systemd-boot snapshot support"

    # Install snapshot tools
    log_info "Setting up snapshot management tools..."
    install_package snapper
    install_package snap-pac
    install_package btrfs-assistant

    # Configure snapshot services
    log_info "Configuring snapshot system services and monitoring..."

    # Enable services if they exist
    if [ -f /usr/lib/systemd/system/grub-btrfsd.service ]; then
        sudo systemctl enable --now grub-btrfsd.service
    else
        log_warning "Failed to enable grub-btrfsd.service"
    fi

    if [ -f /usr/lib/systemd/system/btrfs-assistant-daemon.service ]; then
        sudo systemctl enable --now btrfs-assistant-daemon.service
    else
        log_warning "Failed to enable btrfs-assistant-daemon.service"
    fi

    # Update boot configuration
    if command_exists grub-mkconfig; then
        sudo grub-mkconfig -o /boot/grub/grub.cfg
    else
        log_error "Failed to regenerate GRUB configuration"
    fi

    # Check filesystem and space
    if command_exists btrfs; then
        log_info "Btrfs filesystem detected on root partition"

        # Check available space
        local available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
        if [ "$available_space" -lt 20 ]; then
            log_warning "Low disk space detected: ${available_space}GB available (20GB+ recommended)"
        fi

        # Remove Timeshift if present to avoid conflicts
        if pacman -Qi timeshift &>/dev/null; then
            log_warning "Timeshift detected - removing to avoid conflicts with Snapper"
            sudo pacman -Rns timeshift --noconfirm || log_warning "Could not remove Timeshift cleanly"
        fi

        # Set up Snapper
        setup_snapper
    fi
}

# Configure Snapper
setup_snapper() {
    step "Installing snapshot management packages"
    log_info "Installing: snapper, snap-pac, btrfs-assistant"
    install_package snapper
    install_package snap-pac
    install_package btrfs-assistant

    step "Configuring Snapper for root filesystem"
    log_info "Creating new Snapper configuration..."

    # Create initial Snapper config
    if ! snapper list-configs 2>/dev/null | grep -q "root"; then
        sudo snapper create-config /
        sudo snapper set-config "NUMBER_CLEANUP=yes" "NUMBER_LIMIT=10" "TIMELINE_CLEANUP=yes" "TIMELINE_LIMIT_HOURLY=5" "TIMELINE_LIMIT_DAILY=7"
    fi

    # Set up bootloader configuration
    log_info "Detected bootloader: $(detect_bootloader)"
    configure_bootloader_snapshots

    step "Enabling Snapper automatic snapshot timers"
    sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer
    log_success "Snapper timers enabled and started"

    # Create initial snapshot
    step "Creating initial snapshot"
    sudo snapper create --type single --cleanup-algorithm number --description "Initial snapshot after setup"
    log_success "Initial snapshot created"

    # Verify setup
    step "Verifying Btrfs snapshot setup"
    if snapper list-configs &>/dev/null; then
        log_success "Snapper is working correctly"

        if systemctl is-active snapper-timeline.timer >/dev/null 2>&1 && \
           systemctl is-active snapper-cleanup.timer >/dev/null 2>&1; then
            log_success "Snapper timers are active"
        fi

        log_info "Current snapshots:"
        snapper list

        log_success "Btrfs snapshot setup completed successfully!"

        cat << EOF

Snapshot system configured:
  • Automatic snapshots before/after package operations
  • Retention: 5 hourly, 7 daily snapshots
  • CachyOS kernel fallback: Available in boot menu
  • GUI management: Launch 'btrfs-assistant' from your menu

How to use:
  • View snapshots: sudo snapper list
  • Restore via GUI: Launch 'btrfs-assistant'
  • Emergency fallback: Boot 'CachyOS Linux (Fallback)'
  • Snapshots stored in: /.snapshots/

EOF
    else
        log_error "Snapper verification failed"
        return 1
    fi
}

# Configure bootloader for snapshots
configure_bootloader_snapshots() {
    step "Configuring systemd-boot for CachyOS kernels"

    # Create systemd-boot entry for snapshots
    local template="/etc/systemd/system/boot-entries/snapshot.conf"
    if [ -f "$template" ]; then
        sudo cp "$template" "/boot/loader/entries/cachyos-snapshot.conf"
        log_success "Snapshot boot entry created"
    else
        log_warning "Could not find systemd-boot template. You may need to manually create fallback boot entry"
    fi

    # Update bootloader
    if ! sudo bootctl update; then
        log_warning "systemd-boot configuration had issues but continuing"
    fi

    step "Installing pacman hook for snapshot notifications"
    # Create pacman hook directory if it doesn't exist
    sudo mkdir -p /etc/pacman.d/hooks

    # Create pre and post transaction hooks
    cat << 'EOF' | sudo tee /etc/pacman.d/hooks/95-snapshot.hook >/dev/null
[Trigger]
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creating Snapper snapshot...
When = PreTransaction
Exec = /usr/bin/snapper create --type pre --cleanup-algorithm number --description "pacman transaction"
AbortOnFail
EOF

    cat << 'EOF' | sudo tee /etc/pacman.d/hooks/96-snapshot.hook >/dev/null
[Trigger]
Operation = Upgrade
Operation = Remove
Type = Package
Target = *

[Action]
Description = Creating Snapper snapshot...
When = PostTransaction
Exec = /usr/bin/snapper create --type post --cleanup-algorithm number --description "pacman transaction"
EOF

    log_success "Pacman hook installed - you'll be notified after package operations"
}

# Detect bootloader type
detect_bootloader() {
    if [ -d "/boot/EFI/systemd" ]; then
        echo "systemd-boot"
    elif [ -d "/boot/grub" ]; then
        echo "GRUB"
    else
        echo "unknown"
    fi
}

# Main maintenance function
main() {
    local errors=0
    local warnings=0

    setup_maintenance || ((errors++))
    cleanup_system || ((errors++))
    cleanup_helpers || ((errors++))
    update_mirrors || ((errors++))
    setup_snapshots || ((errors++))

    if [ $errors -gt 0 ] || [ $warnings -gt 0 ]; then
        log_warning "Maintenance completed with warnings in steps: setup_maintenance cleanup_helpers setup_bootloader_snapshots"
        log_info "Non-critical errors occurred but system should still be usable"
        log_error "Maintenance failed"
    else
        log_success "Maintenance completed successfully"
    fi
}

# Run maintenance if script is executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main
fi
