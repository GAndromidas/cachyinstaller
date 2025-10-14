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


# --- Create Directories ---
mkdir -p "$FISH_CONFIG_DIR/functions"
mkdir -p "$FISH_CONFIG_DIR/completions"
mkdir -p "$FASTFETCH_CONFIG_DIR"




# --- Install Fish & Starship Configuration ---
ui_info "Applying default Fish and Starship configurations if none exist..."
if [ "${DRY_RUN:-false}" = false ]; then
  if [ ! -f "$FISH_CONFIG_DIR/config.fish" ]; then
    cp "$CONFIGS_DIR/fish/config.fish" "$FISH_CONFIG_DIR/config.fish"
    ui_info "  - Default fish config installed."
  fi
  if [ ! -f "$FISH_CONFIG_DIR/starship.toml" ]; then
    cp "$CONFIGS_DIR/fish/starship.toml" "$FISH_CONFIG_DIR/starship.toml"
    ui_info "  - Default starship config installed."
  fi
else
  ui_info "[DRY-RUN] Would copy default configs if they do not exist."
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
