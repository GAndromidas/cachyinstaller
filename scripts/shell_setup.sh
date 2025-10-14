#!/bin/bash
set -uo pipefail

# --- Sanity Checks ---
if ! command_exists fish; then
  log_error "Fish shell not found! This script is designed for CachyOS which includes Fish by default."
  return 1
fi

# --- Variables ---
CONFIGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../configs" && pwd)"
FISH_CONFIG_DIR="$HOME/.config/fish"
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"
BACKUP_DIR="$HOME/.config/cachyinstaller/backups/shell"

# --- Create Directories ---
mkdir -p "$FISH_CONFIG_DIR/functions"
mkdir -p "$FISH_CONFIG_DIR/completions"
mkdir -p "$FASTFETCH_CONFIG_DIR"
mkdir -p "$BACKUP_DIR"

# --- Backup existing configurations ---
ui_info "Backing up existing shell configurations..."
timestamp=$(date +%Y%m%d_%H%M%S)
configs_to_backup=(
  "$FISH_CONFIG_DIR/config.fish"
  "$FISH_CONFIG_DIR/starship.toml"
  "$FASTFETCH_CONFIG_DIR/config.jsonc"
)

for config in "${configs_to_backup[@]}"; do
  if [ -f "$config" ]; then
    if [ "${DRY_RUN:-false}" = false ]; then
      cp "$config" "$BACKUP_DIR/$(basename "$config").${timestamp}.bak"
    fi
    ui_info "  - Backed up $(basename "$config")"
  fi
done

# --- Install Fish & Starship Configuration ---
ui_info "Installing enhanced Fish and Starship configurations..."
if [ "${DRY_RUN:-false}" = false ]; then
  cp "$CONFIGS_DIR/fish/config.fish" "$FISH_CONFIG_DIR/config.fish"
  cp "$CONFIGS_DIR/fish/starship.toml" "$FISH_CONFIG_DIR/starship.toml"
  ui_success "Fish and Starship configs installed."
else
  ui_info "[DRY-RUN] Would have copied Fish and Starship configs."
fi

# --- Install Fastfetch Configuration ---
ui_info "Installing custom Fastfetch configuration..."
if [ "${DRY_RUN:-false}" = false ]; then
  cp "$CONFIGS_DIR/fastfetch/config.jsonc" "$FASTFETCH_CONFIG_DIR/config.jsonc"
  ui_success "Fastfetch config installed."
else
  ui_info "[DRY-RUN] Would have copied Fastfetch config."
fi

# --- Install Fisher and Plugins ---
ui_info "Installing Fisher (Fish plugin manager) and plugins..."
if [ "${DRY_RUN:-false}" = false ]; then
  # Install Fisher itself
  fish -c "curl -sL https://raw.githubusercontent.com/jorgebucaran/fisher/main/functions/fisher.fish | source && fisher install jorgebucaran/fisher" >/dev/null 2>&1

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

return 0
