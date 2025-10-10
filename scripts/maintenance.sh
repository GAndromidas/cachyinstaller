#!/usr/bin/env bash

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
        log_info "Skipping /tmp cleanup as it is a mounted filesystem (normal operation)"
    fi
}

# System cleanup
cleanup_system() {
    step "Performing comprehensive system cleanup"

    # Clean package cache
    if command_exists paccache; then
        sudo paccache -rk1
        log_success "Cleaned package cache."
    else
        log_warning "paccache not available or failed. Pacman cache not cleaned."
    fi

    # Clean paru cache if installed
    if command_exists paru; then
        if paru -Sc --noconfirm &>/dev/null; then
            log_success "Cleaned paru cache."
        else
            log_warning "Failed to clean paru cache. Check if there are unmerged updates."
        fi
    else
        log_info "paru not installed, skipping AUR cache cleanup."
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
        log_info "Attempting to remove development helper package: gendesk"
        echo -e "${RESET}    Description: Provides .desktop file generation for AUR packages.${RESET}"
        echo -e "${RESET}    This package is typically not needed after installation.${RESET}"

        if sudo pacman -Rns gendesk --noconfirm >/dev/null 2>&1; then
            log_success "Removed gendesk helper package."
        else
            log_warning "Failed to remove gendesk. It might be a dependency for other packages or already removed."
        fi
    else
        log_info "gendesk not found, skipping removal."
    fi
}

# Update mirrorlist


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
    log_info "Enabling snapshot-related system services..."
    if [ -f /usr/lib/systemd/system/grub-btrfsd.service ]; then
        if sudo systemctl enable --now grub-btrfsd.service &>/dev/null; then
            log_success "Enabled and started grub-btrfsd.service"
        else
            log_error "Failed to enable/start grub-btrfsd.service. GRUB snapshots may not be updated."
        fi
    else
        log_info "grub-btrfsd.service not found. Skipping GRUB snapshot integration."
    fi

    if [ -f /usr/lib/systemd/system/btrfs-assistant-daemon.service ]; then
        if sudo systemctl enable --now btrfs-assistant-daemon.service &>/dev/null; then
            log_success "Enabled and started btrfs-assistant-daemon.service"
        else
            log_error "Failed to enable/start btrfs-assistant-daemon.service. Btrfs Assistant GUI may not function correctly."
        fi
    else
        log_info "btrfs-assistant-daemon.service not found. Skipping Btrfs Assistant daemon."
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

        # Configure Snapper
        log_info "Configuring Snapper for root filesystem..."

        # Create initial Snapper config
        if ! snapper list-configs 2>/dev/null | grep -q "root"; then
            sudo snapper create-config /
            sudo snapper set-config "NUMBER_CLEANUP=yes" "NUMBER_LIMIT=10" "TIMELINE_CLEANUP=yes" "TIMELINE_LIMIT_HOURLY=5" "TIMELINE_LIMIT_DAILY=7"
            log_success "Snapper root configuration created and set."
        else
            log_info "Snapper configuration for root already exists."
        fi

        # Set up bootloader configuration for snapshots
        log_info "Configuring bootloader for snapshot integration (Detected: $(detect_bootloader))..."
        configure_bootloader_snapshots

        log_info "Enabling Snapper automatic snapshot timers..."
        if sudo systemctl enable --now snapper-timeline.timer snapper-cleanup.timer &>/dev/null; then
            log_success "Snapper timers (timeline, cleanup) enabled and started."
        else
            log_error "Failed to enable Snapper timers. Automatic snapshots will not run."
        fi

        # Create initial snapshot
        log_info "Creating initial snapshot..."
        if sudo snapper create --type single --cleanup-algorithm number --description "Initial snapshot after setup"; then
            log_success "Initial snapshot created successfully."
        else
            log_error "Failed to create initial snapshot."
        fi

        # Verify setup
        step "Verifying Btrfs snapshot setup"
        if snapper list-configs &>/dev/null; then
            log_success "Snapper is working correctly."

            if systemctl is-active snapper-timeline.timer >/dev/null 2>&1 && \
               systemctl is-active snapper-cleanup.timer >/dev/null 2>&1; then
                log_success "Snapper timers are active."
            else
                log_warning "Snapper timers may not be active. Check systemctl status."
            fi

            log_info "Current snapshots:"
            snapper list

            log_success "Btrfs snapshot setup completed successfully!"

            echo -e "${RESET}"
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
            echo -e "${RESET}"
        else
            log_error "Snapper verification failed. Please check Snapper installation and configuration."
            return 1
        fi
    fi
}

# Configure Snapper


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
        log_warning "Maintenance completed with issues. Review the log for details."
        if [ $errors -gt 0 ]; then
            log_error "Some errors occurred during maintenance. Consider reviewing the log and re-running if critical."
        fi
        log_info "Non-critical issues might have occurred, but the system should still be functional."
    else
        log_success "Maintenance completed successfully!"
    fi
}

# Run maintenance if script is executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    main
fi
