#!/usr/bin/env bash
set -uo pipefail

# Configuration files
INSTALL_LOG="$HOME/.cachyinstaller.log"
STATE_FILE="$HOME/.cachyinstaller.state"
CONFIG_FILE="$HOME/.cachyinstaller.conf" # Retaining for potential future use if cachyinstaller needs its own config
TOTAL_STEPS=7 # Total installation steps for CachyOS

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

# Source common functions first for UI and logging utilities
source "$SCRIPTS_DIR/common.sh"

# Install helper utilities early (e.g., gum, figlet, flatpak)
install_helper_utils

# Initialize log file
{
  echo "==========================================
CachyInstaller Installation Log
Started: $(date)
==========================================

"
} > "$INSTALL_LOG"



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
      echo "Unknown option: $arg" | tee -a "$INSTALL_LOG"
      echo "Use --help for usage information" | tee -a "$INSTALL_LOG"
      exit 1
      ;;
  esac
done
export VERBOSE
export DRY_RUN
export INSTALL_LOG

# Define cachy_ascii function
show_cachy_banner() {
    if command -v figlet >/dev/null 2>&1; then
        echo -e "${BOLD}${GREEN}"
        figlet -c "CachyInstaller"
        echo -e "${RESET}"
    else
        echo -e "${BOLD}${CYAN}CachyInstaller - Post-Installation Enhancement${RESET}"
    fi
}

# Silently install gum and figlet for UI and banners before menu
# Ensure pacman syncs first to avoid 'package not found' issues
sudo pacman -Sy --noconfirm >/dev/null 2>&1 || log_error "Failed to synchronize pacman databases. This might affect the installation of UI helpers (gum, figlet). Please check your internet connection and try again."
if ! command -v gum >/dev/null 2>&1; then
  sudo pacman -S --noconfirm gum >/dev/null 2>&1 || log_error "Failed to install 'gum', a required UI helper. The installer will proceed with a basic interface. Please ensure your internet connection is stable and try installing 'gum' manually if issues persist."
fi
if ! command -v figlet >/dev/null 2>&1; then
  sudo pacman -S --noconfirm figlet >/dev/null 2>&1 || log_error "Failed to install 'figlet', a UI helper for banners. Reboot messages will be displayed in plain text. Please ensure your internet connection is stable and try installing 'figlet' manually if issues persist."
fi

# Clear screen and show banner
clear
show_cachy_banner

# Check system requirements for new users
check_system_requirements() {
  local requirements_failed=false

  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}Error: This script should NOT be run as root!${RESET}" | tee -a "$INSTALL_LOG"
    echo -e "${YELLOW}   Please run as a regular user with sudo privileges.${RESET}" | tee -a "$INSTALL_LOG"
    echo -e "${YELLOW}   Example: ./install.sh (not sudo ./install.sh)${RESET}" | tee -a "$INSTALL_LOG"
    exit 1
  fi

  # Check if we're on CachyOS
  if ! grep -q "CachyOS" /etc/os-release; then
    echo -e "${RED}Error: This script is designed for CachyOS only!${RESET}" | tee -a "$INSTALL_LOG"
    echo -e "${YELLOW}   Please run this on a CachyOS installation.${RESET}" | tee -a "$INSTALL_LOG"
    exit 1
  fi

  # Check internet connection
  if ! ping -c 1 cachyos.org &>/dev/null; then
    echo -e "${RED}Error: No internet connection detected!${RESET}" | tee -a "$INSTALL_LOG"
    echo -e "${YELLOW}   Please check your network connection and try again.${RESET}" | tee -a "$INSTALL_LOG"
    exit 1
  fi

  # Check available disk space (at least 2GB)
  local available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt 2097152 ]]; then
    echo -e "${RED}Error: Insufficient disk space!${RESET}" | tee -a "$INSTALL_LOG"
    echo -e "${YELLOW}   At least 2GB free space is required.${RESET}" | tee -a "$INSTALL_LOG"
    echo -e "${YELLOW}   Available: $((available_space / 1024 / 1024))GB${RESET}" | tee -a "$INSTALL_LOG"
    exit 1
  fi
}

check_system_requirements
show_menu # Assuming show_menu is in common.sh and sets INSTALL_MODE
export INSTALL_MODE

# Dry-run mode banner (aligned with archinstaller)
if [ "$DRY_RUN" = true ]; then
  echo ""
  echo -e "${YELLOW}========================================${RESET}" | tee -a "$INSTALL_LOG"
  echo -e "${YELLOW}         DRY-RUN MODE ENABLED${RESET}" | tee -a "$INSTALL_LOG"
  echo -e "${YELLOW}========================================${RESET}" | tee -a "$INSTALL_LOG"
  echo -e "${CYAN}Preview mode: No changes will be made${RESET}" | tee -a "$INSTALL_LOG"
  echo -e "${CYAN}Package installations will be simulated${RESET}" | tee -a "$INSTALL_LOG"
  echo -e "${CYAN}System configurations will be previewed${RESET}" | tee -a "$INSTALL_LOG"
  echo "" | tee -a "$INSTALL_LOG"
  sleep 2
fi

# Prompt for sudo using UI helpers
if [ "$DRY_RUN" = false ]; then
  ui_info "Please enter your sudo password to begin the installation:"
  sudo -v || { ui_error "Sudo authentication failed. Exiting."; exit 1; }
else
  ui_info "Dry-run mode: Skipping sudo authentication."
fi

# Keep sudo timestamp alive (skip in dry-run mode)
if [ "$DRY_RUN" = false ]; then
  ui_info "Keeping sudo session alive..."
  # In a subshell, periodically update the sudo timestamp.
  # `sudo -v` extends the sudo timeout without running a command.
  (while true; do sudo -v; sleep 60; done) &
  SUDO_KEEPALIVE_PID=$!
  # Ensure the background sudo keep-alive process is killed on script exit.
  trap 'kill "$SUDO_KEEPALIVE_PID" 2>/dev/null; save_log_on_exit' EXIT INT TERM
else
  # In dry-run mode, we still need the exit trap for logging.
  trap 'save_log_on_exit' EXIT INT TERM
fi

# State tracking for error recovery
mkdir -p "$(dirname "$STATE_FILE")"

# Save initial configuration (kept as is, as it's CachyOS specific)
save_config() {
  {
    echo "INSTALL_MODE=$INSTALL_MODE"
    echo "VERBOSE=$VERBOSE"
    echo "START_TIME=$START_TIME"
    echo "CURRENT_SHELL=$SHELL"
  } > "$CONFIG_FILE"
}

# Load saved configuration if exists (kept as is, as it's CachyOS specific)
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

# Installation start header
print_header "Starting CachyOS Enhancement Installation" \
  "This process will customize your CachyOS system with selected features." \
  "You can safely leave this running - it will handle everything automatically!"

# Step 1: System Preparation
if ! is_step_complete "system_preparation"; then
  print_step_header 1 "$TOTAL_STEPS" "System Preparation"
  ui_info "Optimizing system and preparing for installation..."
  if step "System Preparation" && source "$SCRIPTS_DIR/system_preparation.sh"; then
    mark_step_complete "system_preparation"
    save_config # Keep CachyOS specific config save here
    ui_success "Step 1 completed"
  else
    log_error "System preparation failed"
    # Do not exit here to match archinstaller's robustness, allowing other steps to attempt.
    # Critical failures would have exited in check_system_requirements.
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
    log_error "Fish shell enhancement failed"
  fi
else
  completion_time=$(get_step_completion_time "shell_setup")
  ui_info "Step 2 (Fish Shell Enhancement) completed on $completion_time - skipping"
fi

# Step 3: Programs Installation
if ! is_step_complete "programs_installation"; then
  print_step_header 3 "$TOTAL_STEPS" "Programs Installation"
  ui_info "Installing additional applications and tools..."
  if step "Programs Installation" && source "$SCRIPTS_DIR/programs.sh"; then
    mark_step_complete "programs_installation"
    ui_success "Step 3 completed"
  else
    log_error "Programs installation failed"
  fi
else
  completion_time=$(get_step_completion_time "programs_installation")
  ui_info "Step 3 (Programs Installation) completed on $completion_time - skipping"
fi

# Step 4: Gaming Mode
if ! is_step_complete "gaming_mode"; then
  print_step_header 4 "$TOTAL_STEPS" "Gaming Mode"
  ui_info "Setting up gaming optimizations..."
  if step "Gaming Mode" && source "$SCRIPTS_DIR/gaming_mode.sh"; then
    mark_step_complete "gaming_mode"
    ui_success "Step 4 completed"
  else
    log_error "Gaming Mode setup failed"
  fi
else
  completion_time=$(get_step_completion_time "gaming_mode")
  ui_info "Step 4 (Gaming Mode) completed on $completion_time - skipping"
fi

# Step 5: Fail2ban Setup
if ! is_step_complete "fail2ban_setup"; then
  print_step_header 5 "$TOTAL_STEPS" "Fail2ban Setup"
  ui_info "Setting up security protection with Fail2ban..."
  if step "Fail2ban Setup" && source "$SCRIPTS_DIR/fail2ban.sh"; then
    mark_step_complete "fail2ban_setup"
    ui_success "Step 5 completed"
  else
    log_error "Fail2ban setup failed"
  fi
else
  completion_time=$(get_step_completion_time "fail2ban_setup")
  ui_info "Step 5 (Fail2ban Setup) completed on $completion_time - skipping"
fi

# Step 6: System Services
if ! is_step_complete "system_services"; then
  print_step_header 6 "$TOTAL_STEPS" "System Services"
  ui_info "Configuring essential system services..."
  if step "System Services" && source "$SCRIPTS_DIR/system_services.sh"; then
    mark_step_complete "system_services"
    ui_success "Step 6 completed"
  else
    log_error "System services configuration failed"
  fi
else
  completion_time=$(get_step_completion_time "system_services")
  ui_info "Step 6 (System Services) completed on $completion_time - skipping"
fi

# Step 7: Maintenance
if ! is_step_complete "maintenance"; then
  print_step_header 7 "$TOTAL_STEPS" "Maintenance"
  ui_info "Performing final cleanup and system optimization..."
  if step "Maintenance" && source "$SCRIPTS_DIR/maintenance.sh"; then
    mark_step_complete "maintenance"
    ui_success "Step 7 completed"
  else
    log_error "Maintenance steps failed"
  fi
else
  completion_time=$(get_step_completion_time "maintenance")
  ui_info "Step 7 (Maintenance) completed on $completion_time - skipping"
fi

# Final summary based on DRY_RUN status (aligned with archinstaller)
if [ "$DRY_RUN" = true ]; then
  print_header "Dry-Run Preview Completed"
  echo ""
  echo -e "${YELLOW}This was a preview run. No changes will be made to your system.${RESET}"
  echo ""
  echo -e "${CYAN}To perform the actual installation, run:${RESET}"
  echo -e "${GREEN}  ./install.sh${RESET}"
  echo ""
else
  print_header "CachyOS Enhancement Completed Successfully"
fi

echo ""
echo -e "${YELLOW}What's been set up for you:${RESET}"
echo -e "  - Enhanced Fish shell configuration"
echo -e "  - Additional applications and tools"
echo -e "  - Security features (firewall, SSH protection)"
echo -e "  - Gaming optimizations"
echo -e "  - Laptop optimizations (if laptop detected)"
echo -e "  - Btrfs snapshots (if Btrfs filesystem detected)"
echo -e "  - Dual-boot with Windows (if detected)"
echo ""

if declare -f print_programs_summary >/dev/null 2>&1; then
  print_programs_summary
fi

print_summary # Assuming this is in common.sh
log_performance "Total installation time"

# Save final log (now handled by common.sh's save_log_on_exit via trap)
# The trap is set earlier in the script, ensuring this is called.

# Handle installation results with unified styling
if [ ${#ERRORS[@]} -eq 0 ]; then
  ui_success "All steps completed successfully"
  ui_info "Installation log saved to: $INSTALL_LOG"
  ui_info "State file saved to: $STATE_FILE"
  ui_info "The installer directory has been preserved so you can review what happened."
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
  ui_info "State file saved to: $STATE_FILE"
  ui_info "You can run the installer again to resume from the last successful step."
  ui_info "The installer directory has been preserved so you can review what happened."
fi

# Prompt for reboot using the common function
prompt_reboot # Assuming this is in common.sh and handles the interactive prompt and reboot logic

# This block is after potential reboot, so it will only run if no reboot occurred,
# or if the script was re-executed from fish and we need to return to fish.
if [ -n "${FISH_VERSION:-}" ] && [ "$SHELL" = "$(command -v fish)" ]; then
    exec fish
fi
