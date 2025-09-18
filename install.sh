#!/bin/bash
set -uo pipefail

# Clear terminal for clean interface
clear

# Get the directory where this script is located (cachyinstaller root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIGS_DIR="$SCRIPT_DIR/configs"

source "$SCRIPTS_DIR/common.sh"

START_TIME=$(date +%s)

cachy_ascii

# Silently install gum for beautiful UI before menu
if ! command -v gum >/dev/null 2>&1; then
  sudo pacman -S --noconfirm gum >/dev/null 2>&1 || true
fi

# Check system requirements for CachyOS
check_system_requirements() {
  # Check if running as root
  check_root_user

  # Check if we're on CachyOS
  if ! grep -qi "cachyos" /etc/os-release 2>/dev/null; then
    echo -e "${RED}❌ Error: This script is designed specifically for CachyOS!${RESET}"
    echo -e "${YELLOW}   Please run this on a CachyOS installation.${RESET}"
    echo -e "${YELLOW}   For Arch Linux, use the archinstaller instead.${RESET}"
    exit 1
  fi

  # Check internet connection
  if ! ping -c 1 archlinux.org &>/dev/null; then
    echo -e "${RED}❌ Error: No internet connection detected!${RESET}"
    echo -e "${YELLOW}   Please check your network connection and try again.${RESET}"
    exit 1
  fi

  # Check available disk space (at least 2GB)
  local available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt 2097152 ]]; then
    echo -e "${RED}❌ Error: Insufficient disk space!${RESET}"
    echo -e "${YELLOW}   At least 2GB free space is required.${RESET}"
    echo -e "${YELLOW}   Available: $((available_space / 1024 / 1024))GB${RESET}"
    exit 1
  fi
}

check_system_requirements

# Show CachyOS information
show_cachyos_info

# Show shell choice menu for Fish users (must come before show_menu)
if is_fish_shell; then
  show_shell_choice_menu
fi

# Show installation mode menu
show_menu
export INSTALL_MODE

# Use gum for beautiful sudo prompt if available
if command -v gum >/dev/null 2>&1; then
  gum style --foreground 226 "Please enter your sudo password to begin the installation:"
  sudo -v || { gum style --foreground 196 "Sudo required. Exiting."; exit 1; }
else
  echo -e "${YELLOW}Please enter your sudo password to begin the installation:${RESET}"
  sudo -v || { echo -e "${RED}Sudo required. Exiting.${RESET}"; exit 1; }
fi

# Keep sudo alive
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
SUDO_KEEPALIVE_PID=$!
trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null' EXIT

# Use gum for beautiful installation start message
if command -v gum >/dev/null 2>&1; then
  echo ""
  gum style --border double --margin "1 2" --padding "1 4" --foreground 46 --border-foreground 46 "🚀 Starting CachyOS Installation"
  gum style --margin "1 0" --foreground 226 "⏱️  This process will take approximately 10-20 minutes depending on your internet speed."
  gum style --margin "0 0 1 0" --foreground 226 "💡 You can safely leave this running - it will handle everything automatically!"
else
  echo -e "\n${GREEN}🚀 Starting CachyOS installation...${RESET}"
  echo -e "${YELLOW}⏱️  This process will take approximately 10-20 minutes depending on your internet speed.${RESET}"
  echo -e "${YELLOW}💡 You can safely leave this running - it will handle everything automatically!${RESET}"
  echo ""
fi

# Run all installation steps with error handling
# Step 1: System Preparation
if command -v gum >/dev/null 2>&1; then
  gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step 1: System Preparation"
  gum style --foreground 226 "📦 Updating package lists and installing system utilities..."
else
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${CYAN}Step 1: System Preparation${RESET}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${YELLOW}📦 Updating package lists and installing system utilities...${RESET}"
fi
step "System Preparation" && source "$SCRIPTS_DIR/system_preparation.sh" || log_error "System preparation failed"

if command -v gum >/dev/null 2>&1; then
  gum style --foreground 46 "✓ Step 1 completed"
  echo ""
  gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step 2: Shell Setup"
  if [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
    gum style --foreground 226 "🐚 Converting Fish to ZSH with Oh-My-Zsh..."
  elif [[ "${CACHYOS_SHELL_CHOICE:-}" == "fish" ]]; then
    gum style --foreground 226 "🐠 Enhancing Fish shell with CachyInstaller features..."
  else
    gum style --foreground 226 "🐚 Setting up shell configuration..."
  fi
else
  echo -e "${GREEN}✓ Step 1 completed${RESET}"
  echo -e "${CYAN}Step 2: Shell Setup${RESET}"
  if [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
    echo -e "${YELLOW}🐚 Converting Fish to ZSH with Oh-My-Zsh...${RESET}"
  elif [[ "${CACHYOS_SHELL_CHOICE:-}" == "fish" ]]; then
    echo -e "${YELLOW}🐠 Enhancing Fish shell with CachyInstaller features...${RESET}"
  else
    echo -e "${YELLOW}🐚 Setting up shell configuration...${RESET}"
  fi
fi
step "Shell Setup" && source "$SCRIPTS_DIR/shell_setup.sh" || log_error "Shell setup failed"

if command -v gum >/dev/null 2>&1; then
  gum style --foreground 46 "✓ Step 2 completed"
  echo ""
  gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step 3: Programs Installation"
  gum style --foreground 226 "🖥️  Installing applications using paru AUR helper..."
else
  echo -e "${GREEN}✓ Step 2 completed${RESET}"
  echo -e "${CYAN}Step 3: Programs Installation${RESET}"
  echo -e "${YELLOW}🖥️  Installing applications using paru AUR helper...${RESET}"
fi
step "Programs Installation" && source "$SCRIPTS_DIR/programs.sh" || log_error "Programs installation failed"

if command -v gum >/dev/null 2>&1; then
  gum style --foreground 46 "✓ Step 3 completed"
  echo ""
  gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step 4: Gaming Mode"
  gum style --foreground 226 "🎮 Setting up gaming tools..."
else
  echo -e "${GREEN}✓ Step 3 completed${RESET}"
  echo -e "${CYAN}Step 4: Gaming Mode${RESET}"
  echo -e "${YELLOW}🎮 Setting up gaming tools...${RESET}"
fi
step "Gaming Mode" && source "$SCRIPTS_DIR/gaming_mode.sh" || log_error "Gaming Mode failed"

if command -v gum >/dev/null 2>&1; then
  gum style --foreground 46 "✓ Step 4 completed"
  echo ""
  gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step 5: Fail2ban Setup"
  gum style --foreground 226 "🛡️  Setting up security protection for SSH..."
else
  echo -e "${GREEN}✓ Step 4 completed${RESET}"
  echo -e "${CYAN}Step 5: Fail2ban Setup${RESET}"
  echo -e "${YELLOW}🛡️  Setting up security protection for SSH...${RESET}"
fi
step "Fail2ban Setup" && source "$SCRIPTS_DIR/fail2ban.sh" || log_error "Fail2ban setup failed"

if command -v gum >/dev/null 2>&1; then
  gum style --foreground 46 "✓ Step 5 completed"
  echo ""
  gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step 6: System Services"
  gum style --foreground 226 "⚙️  Configuring system services and desktop environment..."
else
  echo -e "${GREEN}✓ Step 5 completed${RESET}"
  echo -e "${CYAN}Step 6: System Services${RESET}"
  echo -e "${YELLOW}⚙️  Configuring system services and desktop environment...${RESET}"
fi
step "System Services" && source "$SCRIPTS_DIR/system_services.sh" || log_error "System services failed"

if command -v gum >/dev/null 2>&1; then
  gum style --foreground 46 "✓ Step 6 completed"
  echo ""
  gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step 7: Maintenance"
  gum style --foreground 226 "🧹 Setting up system maintenance..."
else
  echo -e "${GREEN}✓ Step 6 completed${RESET}"
  echo -e "${CYAN}Step 7: Maintenance${RESET}"
  echo -e "${YELLOW}🧹 Setting up system maintenance...${RESET}"
fi
step "Maintenance" && source "$SCRIPTS_DIR/maintenance.sh" || log_error "Maintenance setup failed"

if command -v gum >/dev/null 2>&1; then
  gum style --foreground 46 "✓ Step 7 completed"
  echo ""
else
  echo -e "${GREEN}✓ Step 7 completed${RESET}"
  echo -e "\n${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
  echo -e "${GREEN}🎉 INSTALLATION COMPLETED SUCCESSFULLY! 🎉${RESET}"
  echo -e "${CYAN}═══════════════════════════════════════════════════════════════${RESET}"
fi

echo ""
echo -e "${YELLOW}🎯 What's been set up for you:${RESET}"
echo -e "  • 🖥️  Desktop environment with essential applications"
echo -e "  • 🎮 Complete gaming setup (Steam, Lutris, Wine, MangoHud)"
echo -e "  • 🛡️  Security features (UFW firewall, Fail2ban, SSH protection)"
if [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
  echo -e "  • 🐚 ZSH shell with Oh-My-Zsh (converted from Fish)"
elif [[ "${CACHYOS_SHELL_CHOICE:-}" == "fish" ]]; then
  echo -e "  • 🐠 Enhanced Fish shell (CachyOS configuration preserved)"
else
  echo -e "  • 🐚 Optimized shell configuration"
fi
echo -e "  • 🔧 System services and desktop tweaks"
echo -e "  • 📦 AUR packages using CachyOS default paru"
echo -e "  • ⚡ All CachyOS optimizations preserved"
echo ""

# Show installation summary
show_installation_summary

# Handle installation results with gum styling
if [ ${#ERRORS[@]} -eq 0 ]; then
  if command -v gum >/dev/null 2>&1; then
    echo ""
    gum style --foreground 46 "✅ All steps completed successfully!"
    gum style --foreground 226 "🧹 Cleaning up installer files..."
  else
    echo -e "\n${GREEN}✅ All steps completed successfully!${RESET}"
    echo -e "${YELLOW}🧹 Cleaning up installer files...${RESET}"
  fi

  # Clean up installer files completely
  local installer_path="$SCRIPT_DIR"
  local installer_name="$(basename "$SCRIPT_DIR")"

  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 226 "🗑️  Removing CachyInstaller files from system..."
  else
    echo -e "${YELLOW}🗑️  Removing CachyInstaller files from system...${RESET}"
  fi

  cd "$SCRIPT_DIR/.."
  if rm -rf "$installer_name" 2>/dev/null; then
    if command -v gum >/dev/null 2>&1; then
      gum style --foreground 46 "✓ CachyInstaller completely removed from system"
    else
      echo -e "${GREEN}✓ CachyInstaller completely removed from system${RESET}"
    fi
  else
    if command -v gum >/dev/null 2>&1; then
      gum style --foreground 196 "⚠️  Could not remove installer files - please delete manually: $installer_path"
    else
      echo -e "${YELLOW}⚠️  Could not remove installer files - please delete manually: $installer_path${RESET}"
    fi
  fi

  echo ""
  if command -v gum >/dev/null 2>&1; then
    gum style --border double --margin "1 2" --padding "1 4" --foreground 46 --border-foreground 46 "🎉 CachyInstaller Complete!"
    gum style --margin "1 0" --foreground 226 "Your CachyOS gaming system is now ready!"
    echo ""
    gum style --margin "1 0" --foreground 51 "📝 Installation log saved to: ~/cachyinstaller.log"
    if [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
      gum style --margin "0 0 1 0" --foreground 196 "⚠️  Please reboot to complete shell changes!"
    else
      gum style --margin "0 0 1 0" --foreground 46 "🔄 Restart your terminal to see all changes."
    fi
  else
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${RESET}"
    echo -e "${GREEN}║                  🎉 CACHYINSTALLER COMPLETE! 🎉              ║${RESET}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${RESET}"
    echo ""
    echo -e "${YELLOW}Your CachyOS gaming system is now ready!${RESET}"
    echo -e "${CYAN}📝 Installation log saved to: ~/cachyinstaller.log${RESET}"
    echo ""
    if [[ "${CACHYOS_SHELL_CHOICE:-}" == "zsh" ]]; then
      echo -e "${RED}⚠️  Please reboot to complete shell changes!${RESET}"
    else
      echo -e "${GREEN}🔄 Restart your terminal to see all changes.${RESET}"
    fi
  fi
else
  if command -v gum >/dev/null 2>&1; then
    gum style --foreground 196 "⚠️  Installation completed with some errors."
    gum style --foreground 226 "Check the log file for details: $HOME/cachyinstaller.log"
  else
    echo -e "${YELLOW}⚠️  Installation completed with some errors.${RESET}"
    echo -e "${YELLOW}Check the log file for details: $HOME/cachyinstaller.log${RESET}"
  fi
fi

# Keep sudo alive killer
trap - EXIT
kill $SUDO_KEEPALIVE_PID 2>/dev/null || true

exit 0
