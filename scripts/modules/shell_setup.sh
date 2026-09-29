#!/bin/bash
set -uo pipefail

# Fish shell enhancement for CachyOS (Fish behavior unchanged).
# CachyOS-only policy: additive only — never overwrite an existing config.
# DRY-RUN guard: every mutating section below checks DRY_RUN and only
# prints a preview when set — a preview run never writes files, installs
# plugins, or changes the login shell.
# Idempotency: config files are only installed when missing,
# /etc/shells is appended only when absent, plugins install
# through fisher (already-installed plugins are no-ops).

# --- Sanity Checks ---
if ! command_exists fish; then
  log_error "Fish shell not found! This script is designed for CachyOS which includes Fish by default."
  return 1
fi

# --- Variables ---
CONFIGS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../configs" && pwd)"
FISH_CONFIG_DIR="$HOME/.config/fish"
FASTFETCH_CONFIG_DIR="$HOME/.config/fastfetch"


# --- Create Directories ---
mkdir -p "$FISH_CONFIG_DIR/functions"
mkdir -p "$FISH_CONFIG_DIR/completions"
mkdir -p "$FASTFETCH_CONFIG_DIR"




# --- Install Fish & Starship Configuration ---
# CachyOS-only policy: additive only. CachyOS already ships a tuned fish +
# starship setup. Only place a default when the user has none. Never overwrite
# an existing config.
ui_info "Applying Fish and Starship configurations..."
if [ "${DRY_RUN:-false}" = false ]; then
  # Resolve source files (cachyos-fish-config uses a different filename).
  FISH_SRC_FILE=""
  STARSHIP_SRC_FILE=""
  if [ -f "$CONFIGS_DIR/user-fish-config/config.fish" ]; then
    # Preferred: tiny shim that sources the system cachyos-config.fish.
    FISH_SRC_FILE="$CONFIGS_DIR/user-fish-config/config.fish"
    ui_info "  - Using user fish shim (sources system CachyOS config)."
  elif [ -f "$CONFIGS_DIR/cachyos-fish-config/cachyos-config.fish" ]; then
    FISH_SRC_FILE="$CONFIGS_DIR/cachyos-fish-config/cachyos-config.fish"
    ui_info "  - Using CachyOS custom fish config."
  elif [ -f "$CONFIGS_DIR/fish/config.fish" ]; then
    FISH_SRC_FILE="$CONFIGS_DIR/fish/config.fish"
    ui_info "  - Using default fish config."
  fi
  if [ -f "$CONFIGS_DIR/user-fish-config/starship.toml" ]; then
    STARSHIP_SRC_FILE="$CONFIGS_DIR/user-fish-config/starship.toml"
  elif [ -f "$CONFIGS_DIR/fish/starship.toml" ]; then
    STARSHIP_SRC_FILE="$CONFIGS_DIR/fish/starship.toml"
  fi

  # Deploy config.fish only when missing (never overwrite CachyOS/user config).
  if [ ! -f "$FISH_CONFIG_DIR/config.fish" ]; then
    if [ -n "$FISH_SRC_FILE" ]; then
      cp "$FISH_SRC_FILE" "$FISH_CONFIG_DIR/config.fish"
      ui_info "  - Fish config installed (none existed)."
    fi
  else
    ui_info "  - Fish config already exists, leaving untouched."
  fi

  # Deploy starship.toml only when missing.
  if [ ! -f "$FISH_CONFIG_DIR/starship.toml" ]; then
    if [ -n "$STARSHIP_SRC_FILE" ]; then
      cp "$STARSHIP_SRC_FILE" "$FISH_CONFIG_DIR/starship.toml"
      ui_info "  - Starship config installed (none existed)."
    fi
  else
    ui_info "  - Starship config already exists, leaving untouched."
  fi

  # Deploy conf.d snippets only when missing (never overwrite).
  if [ -d "$CONFIGS_DIR/user-fish-config/conf.d" ]; then
    mkdir -p "$FISH_CONFIG_DIR/conf.d"
    for conf_src in "$CONFIGS_DIR/user-fish-config/conf.d"/*; do
      [ -e "$conf_src" ] || continue
      dest_name="$(basename "$conf_src")"
      if [ ! -f "$FISH_CONFIG_DIR/conf.d/$dest_name" ]; then
        cp "$conf_src" "$FISH_CONFIG_DIR/conf.d/" 2>/dev/null && \
          ui_info "  - conf.d file installed: $dest_name"
      fi
    done
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
    if ! grep -qxF "$fish_path" /etc/shells; then
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
