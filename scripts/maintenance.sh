#!/bin/bash
set -uo pipefail

# CachyOS System Maintenance - Final cleanup and optimization
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

perform_cleanup() {
  step "Performing system cleanup"

  # Clean pacman cache
  log_info "Cleaning pacman cache..."
  sudo pacman -Sc --noconfirm 2>/dev/null || log_warning "Failed to clean pacman cache"

  # Clean paru cache (CachyOS default AUR helper)
  if command -v paru >/dev/null 2>&1; then
    log_info "Cleaning paru cache..."
    paru -Sc --noconfirm 2>/dev/null || log_warning "Failed to clean paru cache"
  fi

  # Remove orphaned packages
  local orphans=$(pacman -Qtdq 2>/dev/null)
  if [[ -n "$orphans" ]]; then
    log_info "Removing orphaned packages..."
    sudo pacman -Rns $orphans --noconfirm 2>/dev/null || log_warning "Some orphaned packages couldn't be removed"
  else
    log_info "No orphaned packages found"
  fi

  # Clean flatpak unused packages
  if command -v flatpak >/dev/null 2>&1; then
    log_info "Cleaning unused Flatpak packages..."
    sudo flatpak uninstall --unused --noninteractive -y 2>/dev/null || log_warning "Failed to clean Flatpak packages"
  fi

  log_success "System cleanup completed"
}

optimize_system() {
  step "Optimizing system performance"

  # SSD optimization (TRIM)
  if command -v lsblk >/dev/null 2>&1; then
    if lsblk -d -o rota 2>/dev/null | grep -q '^0$'; then
      log_info "SSD detected - running TRIM optimization..."
      sudo fstrim -v / 2>/dev/null || log_warning "TRIM operation had issues"
      log_success "SSD optimization completed"
    else
      log_info "HDD detected - skipping TRIM optimization"
    fi
  fi

  # Clean temporary files
  log_info "Cleaning temporary files..."
  sudo rm -rf /tmp/* 2>/dev/null || true

  # Sync filesystem
  log_info "Syncing filesystem..."
  sync

  log_success "System optimization completed"
}

update_system_databases() {
  step "Updating system databases"

  # Update desktop database
  if command -v update-desktop-database >/dev/null 2>&1; then
    log_info "Updating desktop database..."
    update-desktop-database "$HOME/.local/share/applications" 2>/dev/null || true
    sudo update-desktop-database /usr/share/applications 2>/dev/null || true
  fi

  # Update font cache
  if command -v fc-cache >/dev/null 2>&1; then
    log_info "Updating font cache..."
    fc-cache -f 2>/dev/null || log_warning "Font cache update had issues"
  fi

  # Update mimeinfo cache
  if command -v update-mime-database >/dev/null 2>&1; then
    log_info "Updating MIME database..."
    update-mime-database "$HOME/.local/share/mime" 2>/dev/null || true
  fi

  log_success "System databases updated"
}

cleanup_installer_temp_files() {
  step "Cleaning installer temporary files"

  # Remove any temporary installer files that might be left
  local temp_files=(
    "/tmp/cachyinstaller*"
    "/tmp/paru*"
    "$HOME/.cache/cachyinstaller*"
  )

  for temp_pattern in "${temp_files[@]}"; do
    if ls $temp_pattern 1> /dev/null 2>&1; then
      log_info "Removing temporary files: $temp_pattern"
      rm -rf $temp_pattern 2>/dev/null || log_warning "Could not remove some temp files"
    fi
  done

  # Clean any leftover build files
  if [[ -d "/tmp/makepkg" ]]; then
    log_info "Cleaning makepkg temporary files"
    sudo rm -rf /tmp/makepkg/* 2>/dev/null || true
  fi

  log_success "Installer temporary files cleaned up"
}

# Main execution
log_info "Starting CachyOS system maintenance..."

perform_cleanup
optimize_system
update_system_databases
cleanup_installer_temp_files

log_success "CachyOS system maintenance completed - your system is optimized!"
