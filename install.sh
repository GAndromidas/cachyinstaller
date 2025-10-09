```#!/usr/bin/env bash
set -uo pipefail

# Configuration files
INSTALL_LOG="$HOME/.cachyinstaller.log"
STATE_FILE="$HOME/.cachyinstaller.state"
CONFIG_FILE="$HOME/.cachyinstaller.conf"
TOTAL_STEPS=7  # Total installation steps

# Detect if we're running in Fish and re-execute in bash if needed
if [ -n "${FISH_VERSION:-}" ] || [ "$(ps -p $$ -o comm=)" = "fish" ]; then
    exec bash "$0" "$@"
fi

# Function to show help
show_help() {
  cat << EOF
CachyInstaller - CachyOS Post-Installation Enhancement Script

USAGE:
    ./install.sh [OPTIONS]

OPTIONS:
    -h, --help      Show this help message and exit
    -v, --verbose   Enable verbose output (show all package installation details)
    -q, --quiet     Quiet mode (minimal output)
    -d, --dry-run   Preview what will be installed without making changes

DESCRIPTION:
    CachyInstaller enhances a CachyOS installation with additional features
    and optimizations. It preserves CachyOS's core functionality while adding
    useful tools, security features, and performance improvements.

INSTALLATION MODES:
    Standard        Complete setup with all recommended packages
    Minimal         Essential tools only for lightweight installations
    Custom          Interactive selection of packages to install

FEATURES:
    - Desktop environment optimization (KDE, GNOME, Cosmic)
    - Security hardening (Fail2ban, Firewall)
    - Gaming mode with performance optimizations
    - Fish shell enhancements
    - Btrfs snapshot support
    - Windows dual-boot detection
    - Automatic GPU driver configuration

REQUIREMENTS:
    - Fresh CachyOS installation
    - Active internet connection
    - Regular user account with sudo privileges
    - Minimum 2GB free disk space

EXAMPLES:
    ./install.sh                Run installer with interactive prompts
    ./install.sh --verbose      Run with detailed package installation output
    ./install.sh --help         Show this help message

LOG FILE:
    Installation log saved to: ~/.cachyinstaller.log

MORE INFO:
    https://github.com/cachyos/cachyinstaller

EOF
  exit 0
}

# Clear terminal for clean interface
clear

# Get the directory where this script is located (cachyinstaller root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIGS_DIR="$SCRIPT_DIR/configs"

source "$SCRIPTS_DIR/common.sh"

# Initialize log file
{
  echo "=========================================="
  echo "CachyInstaller Installation Log"
  echo "Started: $(date)"
  echo "=========================================="
  echo ""
} > "$INSTALL_LOG"

# Function to log to both console and file
log_both() {
  echo "$1" | tee -a "$INSTALL_LOG"
}

START_TIME=$(date +%s)

# Parse flags
VERBOSE=false
DRY_RUN=false
for arg in "$@"; do
  case "$arg" in
    -h|--help)
      show_help
      ;;
    --verbose|-v)
      VERBOSE=true
      ;;
    --quiet|-q)
      VERBOSE=false
      ;;
    --dry-run|-d)
      DRY_RUN=true
      VERBOSE=true
      ;;
    *)
      echo "Unknown option: $arg"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done
export VERBOSE
export DRY_RUN
export INSTALL_LOG

# Define cachy_ascii function
show_cachy_banner() {
    echo ""
    echo -e "${BOLD}${CYAN}   ____            _            ___           _        _ _${RESET}"
    echo -e "${BOLD}${CYAN}  / ___|__ _  ___| |__  _   _ |_ _|_ __  ___| |_ __ _| | | ___ _ __${RESET}"
    echo -e "${BOLD}${CYAN} | |   / _\\\\` |/ __| \'_ \\\\| | | | | || \'_ \\\\/ __| __/ _\\\\` | | |/ _ \\\\ \'__|${RESET}"
    echo -e "${BOLD}${CYAN} | |__| (_| | (__| | | | |_| | | || | | \\\\__ \\\\ || (_| | | |  __/ |${RESET}"
    echo -e "${BOLD}${CYAN}  \\\\____\\\\\\\\__,_|\\\\___|_| |_|\\\\\\\\__, |___||_| |_|___/\\\\__\\\\\\\\__,_|_|_|\\\\\\\\___|_|${RESET}"
    echo -e "${BOLD}${CYAN}                        |___/${RESET}"
    echo ""
}

# Silently install gum and figlet for UI and banners before menu
if ! command -v gum >/dev/null 2>&1 || ! command -v figlet >/dev/null 2>&1; then
    sudo pacman -Sy >/dev/null 2>&1
    sudo pacman -S --noconfirm gum figlet >/dev/null 2>&1
fi

# Clear screen and show banner
clear
source "$SCRIPTS_DIR/common.sh"

# Show banner
show_cachy_banner

# Check system requirements for new users
check_system_requirements() {
  local requirements_failed=false

  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should NOT be run as root!${RESET}"
    echo -e "${YELLOW}   Please run as a regular user with sudo privileges.${RESET}"
    echo -e "${YELLOW}   Example: ./install.sh (not sudo ./install.sh)${RESET}"
    exit 1
  fi

  # Check if we're on CachyOS
  if ! grep -q "CachyOS" /etc/os-release; then
    echo -e "${RED}Error: This script is designed for CachyOS only!${RESET}"
    echo -e "${YELLOW}   Please run this on a CachyOS installation.${RESET}"
    exit 1
  fi

  # Check internet connection
  if ! ping -c 1 cachyos.org &>/dev/null; then
    echo -e "${RED}Error: No internet connection detected!${RESET}"
    echo -e "${YELLOW}   Please check your network connection and try again.${RESET}"
    exit 1
  fi

  # Check available disk space (at least 2GB)
  local available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt 2097152 ]]; then
    echo -e "${RED}Error: Insufficient disk space!${RESET}"
    echo -e "${YELLOW}   At least 2GB free space is required.${RESET}"
    echo -e "${YELLOW}   Available: $((available_space / 1024 / 1024))GB${RESET}"
    exit 1
  fi
}

check_system_requirements
show_menu
export INSTALL_MODE

# Install helper utilities after menu selection
echo -e "\\n${BOLD}${BLUE}:: Installing helper utilities...${RESET}"
echo -e "${DIM}───────────────────────────────────────────────────${RESET}\\n"
install_helper_utils

# Dry-run mode banner
if [ "$DRY_RUN" = true ]; then
  print_header "Dry-Run Preview Completed"
  echo ""
  ui_info "${YELLOW}This was a preview run. No changes will be made to your system.${RESET}"
  echo ""
  ui_info "${CYAN}To perform the actual installation, run:${RESET}"
  ui_info "${GREEN}  ./install.sh${RESET}"
  echo ""
else
  print_header "CachyOS Enhancement Completed Successfully"
fi

# Prompt for sudo using UI helpers
if [ "$DRY_RUN" = false ]; then
  ui_info "Please enter your sudo password to begin the installation:"
  sudo -v || { ui_error "Sudo required. Exiting."; exit 1; }
else
  ui_info "Dry-run mode: Skipping sudo authentication"
fi

# Keep sudo alive
if [ "$DRY_RUN" = false ]; then
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null; save_log_on_exit' EXIT INT TERM
else
  trap 'save_log_on_exit' EXIT INT TERM
fi

# State tracking for error recovery
mkdir -p "$(dirname "$STATE_FILE")" "$(dirname "$CONFIG_FILE")"

# Save initial configuration
save_config() {
  {
    echo "INSTALL_MODE=$INSTALL_MODE"
    echo "VERBOSE=$VERBOSE"
    echo "START_TIME=$START_TIME"
    echo "CURRENT_SHELL=$SHELL"
  } > "$CONFIG_FILE"
}

# Load saved configuration if exists
load_config() {
  if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    return 0
  fi
  return 1
}

# Function to mark step as completed with timestamp
mark_step_complete() {
  local step_name="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "${step_name}|${timestamp}" >> "$STATE_FILE"
  sync "$STATE_FILE"  # Ensure state is written to disk
}

# Function to check if step was completed
is_step_complete() {
  local step_name="$1"
  if [ -f "$STATE_FILE" ]; then
    grep -q "^${step_name}|" "$STATE_FILE"
    return $?
  fi
  return 1
}

# Function to get step completion time
get_step_completion_time() {
  local step_name="$1"
  if [ -f "$STATE_FILE" ]; then
    grep "^${step_name}|" "$STATE_FILE" | cut -d'|' -f2
  fi
}

# Function to save log on exit (this now gets called by trap, if no reboot occurs)
save_log_on_exit() {
  {
    echo ""
    echo "=========================================="
    echo "Installation ended: $(date)"
    echo "=========================================="
  } >> "$INSTALL_LOG"
}


# Installation start header
echo -e "\\n${BOLD}${BLUE}:: Starting CachyOS Enhancement Installation...${RESET}"
echo -e "${DIM}───────────────────────────────────────────────────${RESET}\\n"

# Step 1: System Preparation
if ! is_step_complete "system_preparation"; then
  print_step_header 1 "$TOTAL_STEPS" "System Preparation"
  ui_info "Optimizing system and preparing for installation..."
  if step "System Preparation" && source "$SCRIPTS_DIR/system_preparation.sh"; then
    mark_step_complete "system_preparation"
    save_config
    ui_success "Step 1 completed successfully"
  else
    log_error "System preparation failed"
    exit 1
  fi
else
  completion_time=$(get_step_completion_time "system_preparation")
  ui_info "Step 1 (System Preparation) completed on $completion_time - skipping"
fi

# Step 2: Fish Shell Enhancement
if ! is_step_complete "shell_setup"; then
  print_step_header 2 "$TOTAL_STEPS" "Fish Shell Enhancement"
  ui_info "Enhancing Fish shell with custom configurations..."
  if step "Shell Setup" && source "$SCRIPTS_DIR/shell_setup.sh"; then
    mark_step_complete "shell_setup"
    ui_success "Step 2 completed"
  else
    log_error "Shell setup failed"
    # Do not exit here, allow other steps to try and complete
  fi
else
  ui_info "Step 2 (Shell Setup) already completed - skipping"
fi

# Step 3: Programs Installation
if ! is_step_complete "programs_installation"; then
  print_step_header 3 "$TOTAL_STEPS" "Programs Installation"
  ui_info "Installing additional applications..."
  if step "Programs Installation" && source "$SCRIPTS_DIR/programs.sh"; then
    mark_step_complete "programs_installation"
    ui_success "Step 3 completed"
  else
    log_error "Programs installation failed"
    # Do not exit here, allow other steps to try and complete
  fi
else
  ui_info "Step 3 (Programs Installation) already completed - skipping"
fi

# Step 4: Gaming Mode
if ! is_step_complete "gaming_mode"; then
  print_step_header 4 "$TOTAL_STEPS" "Gaming Mode"
  ui_info "Setting up gaming optimizations..."
  if step "Gaming Mode" && source "$SCRIPTS_DIR/gaming_mode.sh"; then
    mark_step_complete "gaming_mode"
    ui_success "Step 4 completed"
  else
    log_error "Gaming Mode failed"
    # Do not exit here, allow other steps to try and complete
  fi
else
  ui_info "Step 4 (Gaming Mode) already completed - skipping"
fi

# Step 5: Fail2ban Setup
if ! is_step_complete "fail2ban_setup"; then
  print_step_header 5 "$TOTAL_STEPS" "Fail2ban Setup"
  ui_info "Setting up security protection..."
  if step "Fail2ban Setup" && source "$SCRIPTS_DIR/fail2ban.sh"; then
    mark_step_complete "fail2ban_setup"
    ui_success "Step 5 completed"
  else
    log_error "Fail2ban setup failed"
    # Do not exit here, allow other steps to try and complete
  fi
else
  ui_info "Step 5 (Fail2ban Setup) already completed - skipping"
fi

# Step 6: System Services
if ! is_step_complete "system_services"; then
  print_step_header 6 "$TOTAL_STEPS" "System Services"
  ui_info "Configuring system services..."
  if step "System Services" && source "$SCRIPTS_DIR/system_services.sh"; then
    mark_step_complete "system_services"
    ui_success "Step 6 completed"
  else
    log_error "System services failed"
    # Do not exit here, allow other steps to try and complete
  fi
else
  ui_info "Step 6 (System Services) already completed - skipping"
fi

# Step 7: Maintenance
if ! is_step_complete "maintenance"; then
  print_step_header 7 "$TOTAL_STEPS" "Maintenance"
  ui_info "Setting up system maintenance..."
  if step "Maintenance" && source "$SCRIPTS_DIR/maintenance.sh"; then
    mark_step_complete "maintenance"
    ui_success "Step 7 completed"
  else
    log_error "Maintenance failed"
    # Do not exit here, allow other steps to try and complete
  fi
else
  completion_time=$(get_step_completion_time "maintenance")
  ui_info "Step 7 (Maintenance) already completed on $completion_time - skipping"
fi

if [ "$DRY_RUN" = true ]; then
  print_header "Dry-Run Preview Completed"
  ui_info "" # Added for spacing
  ui_info "${YELLOW}This was a preview run. No changes will be made to your system.${RESET}"
  ui_info "" # Added for spacing
  ui_info "${CYAN}To perform the actual installation, run:${RESET}"
  ui_info "${GREEN}  ./install.sh${RESET}"
  ui_info "" # Added for spacing
else
  print_header "CachyOS Enhancement Completed Successfully"
fi

ui_info "" # Added for spacing
ui_info "${YELLOW}What's been set up for you:${RESET}"
ui_info "  - Enhanced Fish shell configuration"
ui_info "  - Additional applications and tools"
ui_info "  - Security features (firewall, SSH protection)"
ui_info "  - Gaming optimizations"
ui_info "  - Laptop optimizations (if laptop detected)"
ui_info "  - Btrfs snapshots (if Btrfs filesystem detected)"
ui_info "  - Dual-boot with Windows (if detected)"
ui_info "" # Added for spacing

if declare -f print_programs_summary >/dev/null 2>&1; then
  print_programs_summary
fi

print_summary
log_performance "Total installation time"

# Save final log (this will be handled by save_log_on_exit which is trapped)

# Handle installation results with unified styling
if [ ${#ERRORS[@]} -eq 0 ]; then
  ui_success "All steps completed successfully"
  # Clean up everything if installation was successful
  cleanup_on_exit # This will remove .log and .conf, and gum/figlet packages. It will NOT remove .state

  # Delete the cachyinstaller folder itself
  log_info "Deleting cachyinstaller directory: $SCRIPT_DIR"
  sudo rm -rf "$SCRIPT_DIR" &>/dev/null || log_error "Failed to delete installer directory: $SCRIPT_DIR"
  log_success "Removed installation directory: $SCRIPT_DIR"

  # Ensure figlet is installed for the banner (should already be there from initial check)
  if ! command -v figlet >/dev/null 2>&1; then
    sudo pacman -S --noconfirm figlet >/dev/null 2>&1 || true
  fi

  # Display reboot banner and prompt
  ui_info "\n${CYAN}$(figlet \"Reboot System\")${RESET}"

  read -p "Would you like to reboot now? [Y/n]: " response
  response=${response:-Y} # Default to Y if response is empty
  response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

  if [[ "$response" == "y" || "$response" == "yes" ]]; then
      ui_info "\n${GREEN}Rebooting system...${RESET}"
      sleep 2
      sudo reboot
  else
      log_info "Reboot skipped by user."
  fi

else
  ui_warn "Some errors occurred during installation:"
  if command -v gum >/dev/null 2>&1; then
    for error in "${ERRORS[@]}"; do
      echo "   - $error" | gum style --foreground 196
    done
  else
    for error in "${ERRORS[@]}"; do
      echo -e "${RED}   - $error${RESET}"
    done
  fi
  ui_info "Most errors are non-critical and your system should still work."
  ui_info "Installation log saved to: $INSTALL_LOG"
  ui_info "State file saved to: $STATE_FILE" # Ensure this message remains even if state file is not deleted by cleanup
  ui_info "You can run the installer again to resume from the last successful step."
fi

# This block is after potential reboot, so it will only run if no reboot occurred,
# or if the script was re-executed from fish and we need to return to fish.
if [ -n "${FISH_VERSION:-}" ] && [ "$SHELL" = "$(command -v fish)" ]; then
    exec fish
fi
