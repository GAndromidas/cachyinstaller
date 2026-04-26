#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/constants.sh"
source "$SCRIPT_DIR/common.sh"
setup_error_trap

# --- Sanity Checks ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "$SCRIPT_DIR/constants.sh" ]]; then
  source "$SCRIPT_DIR/constants.sh"
fi
if ! command_exists fish; then
  log_error "Fish shell not found! This script is designed for CachyOS which includes Fish by default."
  return 1
fi

# --- Variables ---
CONFIGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs" && pwd)"
FISH_CONFIG_DIR="$HOME/.config/fish"
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"


# --- Create Directories ---
mkdir -p "$FISH_CONFIG_DIR/functions"
mkdir -p "$FISH_CONFIG_DIR/completions"
mkdir -p "$FASTFETCH_CONFIG_DIR"




# --- Install Fish & Starship Configuration ---
ui_info "Applying Fish and Starship configurations..."
if [ "${DRY_RUN:-false}" = false ]; then
  # Determine which config source to use (priority: cachyos-fish-config > user-fish-config > default)
  if [ -d "$CONFIGS_DIR/cachyos-fish-config" ]; then
    FISH_SOURCE="$CONFIGS_DIR/cachyos-fish-config"
    ui_info "  - Using CachyOS custom fish config."
  elif [ -d "$CONFIGS_DIR/user-fish-config" ]; then
    FISH_SOURCE="$CONFIGS_DIR/user-fish-config"
    ui_info "  - Using user-defined fish config."
  else
    FISH_SOURCE="$CONFIGS_DIR/fish"
    ui_info "  - Using default fish config."
  fi

  # Deploy config.fish
  if [ ! -f "$FISH_CONFIG_DIR/config.fish" ] || [ "$FISH_SOURCE" != "$CONFIGS_DIR/fish" ]; then
    if [ -f "$FISH_SOURCE/config.fish" ]; then
      cp "$FISH_SOURCE/config.fish" "$FISH_CONFIG_DIR/config.fish"
      ui_info "  - Fish config installed from $FISH_SOURCE."
    fi
  fi

  # Deploy starship.toml
  if [ ! -f "$FISH_CONFIG_DIR/starship.toml" ] || [ "$FISH_SOURCE" != "$CONFIGS_DIR/fish" ]; then
    if [ -f "$FISH_SOURCE/starship.toml" ]; then
      cp "$FISH_SOURCE/starship.toml" "$FISH_CONFIG_DIR/starship.toml"
      ui_info "  - Starship config installed from $FISH_SOURCE."
    elif [ -f "$CONFIGS_DIR/fish/starship.toml" ]; then
      cp "$CONFIGS_DIR/fish/starship.toml" "$FISH_CONFIG_DIR/starship.toml"
      ui_info "  - Default starship config installed."
    fi
  fi

  # Deploy conf.d files if they exist in the source
  if [ -d "$FISH_SOURCE/conf.d" ]; then
    mkdir -p "$FISH_CONFIG_DIR/conf.d"
    cp "$FISH_SOURCE/conf.d"/* "$FISH_CONFIG_DIR/conf.d/" 2>/dev/null && \
      ui_info "  - conf.d files installed from $FISH_SOURCE."
  fi
else
  ui_info "[DRY-RUN] Would copy Fish configs from priority source if needed."
fi

# --- Install Fastfetch Configuration ---
ui_info "Applying default Fastfetch configuration if none exists..."
if [ "${DRY_RUN:-false}" = false ]; then
  if [ ! -f "$FASTFETCH_CONFIG_DIR/config.jsonc" ]; then
    cp "$CONFIGS_DIR/fastfetch/config.jsonc" "$FASTFETCH_CONFIG_DIR/config.jsonc"
    ui_info "  - Default fastfetch config installed."
  fi
else
  ui_info "[DRY-RUN] Would copy default fastfetch config if it does not exist."
fi

# --- Install Fisher and Plugins ---
ui_info "Installing Fisher (Fish plugin manager) and plugins..."
if [ "${DRY_RUN:-false}" = false ]; then
  # Install Fisher itself with checksum verification
  # Download Fisher installer to temp file for checksum verification
  # (Never pipe curl directly into source — supply chain safety)
  curl -sL "$FISHER_URL" -o /tmp/fisher_install.fish
  actual_checksum=$(sha256sum /tmp/fisher_install.fish | awk '{print $1}')
  if [[ "$actual_checksum" != "$FISHER_CHECKSUM" ]]; then
      log_error "Fisher checksum mismatch. Expected: $FISHER_CHECKSUM Got: $actual_checksum"
      log_error "Possible supply chain compromise. Aborting Fisher installation."
      log_error "To update the checksum: curl -sL \"$FISHER_URL\" | sha256sum"
      rm -f /tmp/fisher_install.fish
  else
      fish -c "source /tmp/fisher_install.fish"
      rm -f /tmp/fisher_install.fish
  fi

  # Install plugins
  plugins=(
    "jorgebucaran/autopair.fish"
    "franciscolourenco/done"
    "PatrickF1/fzf.fish"
    "meaningful-ooo/sponge"
  )

  for plugin in "${plugins[@]}"; do
    if fish -c "fisher install $plugin" >> "$INSTALL_LOG" 2>&1; then
      ui_info "  - Installed plugin: $plugin"
    else
      log_error "Failed to install plugin: $plugin"
    fi
  done
  ui_success "Fisher plugins installed."
else
  ui_info "[DRY-RUN] Would have installed Fisher and plugins."
fi

# --- Set Fish as Default Shell ---
fish_path=$(command -v fish)
if [[ "$SHELL" != "$fish_path" ]]; then
  ui_info "Setting Fish as the default shell..."
  if [ "${DRY_RUN:-false}" = false ]; then
    # Add fish to /etc/shells if it's not already there
    if ! grep -q "^$fish_path$" /etc/shells; then
      ui_info "Adding '$fish_path' to /etc/shells"
      echo "$fish_path" | sudo tee -a /etc/shells >/dev/null
    fi

    # Change the shell
    if sudo chsh -s "$fish_path" "$USER"; then
      ui_success "Fish is now the default shell. Please log out and back in to see the change."
    else
      log_error "Failed to set Fish as the default shell. You can try manually with 'chsh -s $fish_path'."
    fi
  else
    ui_info "[DRY-RUN] Would have set Fish as the default shell."
  fi
else
  ui_info "Fish is already the default shell."
fi

# --- Configure Hyprland xdg-desktop-portal ---
configure_hyprland_portals() {
    # Configure xdg-desktop-portal for Hyprland + KDE apps
    # This is required for Dolphin and all Qt/KDE apps to open files correctly.
    # Without this config, "Open with", file associations, and PDF/image opening
    # will silently fail in Hyprland.
    #
    # Architecture:
    #   - hyprland portal → screen capture, Hyprland-specific features
    #   - kde portal      → file picker for Dolphin, Ark, Okular, Gwenview, Kate
    #   - gtk portal      → file picker fallback for GTK apps
    #
    # Reference: https://wiki.hyprland.org/Hypr-Ecosystem/xdg-desktop-portal-hyprland/

    local portal_config_dir="$HOME/.config/xdg-desktop-portal"
    local portal_config_file="$portal_config_dir/hyprland-portals.conf"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        ui_info "[DRY-RUN] Would create: $portal_config_file"
        return 0
    fi

    mkdir -p "$portal_config_dir"

    # Only write if the file does not already exist (idempotent)
    if [[ ! -f "$portal_config_file" ]]; then
        cat > "$portal_config_file" << 'EOF'
[preferred]
# hyprland handles: screencopy, globalshortcuts, inhibit_idle, remote_desktop
# kde handles: file picker for all Qt/KDE apps (Dolphin, Ark, Okular, Gwenview)
# gtk handles: file picker fallback for GTK apps
default=hyprland;kde;gtk
org.freedesktop.impl.portal.FileChooser=kde
org.freedesktop.impl.portal.Screenshot=hyprland
org.freedesktop.impl.portal.ScreenCast=hyprland
EOF
        ui_success "Created Hyprland portal configuration: $portal_config_file"
    else
        ui_info "Portal config already exists — skipping: $portal_config_file"
    fi

    # Remove stale portal configs from previous desktop environments
    # that can conflict with Hyprland portal resolution
    local stale_configs=(
        "$HOME/.config/xdg-desktop-portal/gnome-portals.conf"
        "$HOME/.config/xdg-desktop-portal/wlr-portals.conf"
    )
    for stale in "${stale_configs[@]}"; do
        if [[ -f "$stale" ]]; then
            rm -f "$stale"
            ui_info "Removed conflicting portal config: $stale"
        fi
    done

    INSTALLED_PACKAGES+=("xdg-portal-config (hyprland+kde+gtk)")
}

# Run portal configuration
configure_hyprland_portals

return 0
