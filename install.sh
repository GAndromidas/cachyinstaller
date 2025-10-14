#!/bin/bash
set -uo pipefail

# Installation log file
INSTALL_LOG="$HOME/.cachyinstaller.log"

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
    CachyInstaller enhances a fresh CachyOS installation by adding useful tools,
    security features, and performance improvements, while preserving the core
    optimizations of CachyOS.

INSTALLATION MODES:
    Standard        Complete setup with all recommended packages.
    Minimal         Essential tools only for lightweight installations.
    Custom          Interactive selection of packages to install.

LOG FILE:
    Installation log saved to: $INSTALL_LOG
EOF
  exit 0
}

# Clear terminal for clean interface
clear

# Get the directory where this script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPTS_DIR="$SCRIPT_DIR/scripts"
CONFIGS_DIR="$SCRIPT_DIR/configs"

source "$SCRIPTS_DIR/common.sh"

# --- Function to setup system environment variables ---
# This is run on every invocation to ensure variables are set, even on resume.
setup_system_enhancements() {
    # Detect GPU vendor and export for other scripts
    if lspci | grep -i "VGA" | grep -i "NVIDIA" >/dev/null; then
        export GPU_VENDOR="nvidia"
    elif lspci | grep -i "VGA" | grep -i "AMD" >/dev/null; then
        export GPU_VENDOR="amd"
    elif lspci | grep -i "VGA" | grep -i "Intel" >/dev/null; then
        export GPU_VENDOR="intel"
    else
        # Default to empty if no specific GPU is found, to avoid unbound variable errors.
        export GPU_VENDOR=""
    fi

    # Detect if it's a laptop
    if [ -d "/sys/class/power_supply" ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        export IS_LAPTOP=true
    else
        export IS_LAPTOP=false
    fi
}
# Always run system detection
setup_system_enhancements

# --- Function to setup system environment variables ---
# This is run on every invocation to ensure variables are set, even on resume.
setup_system_enhancements() {
    # Detect GPU vendor and export for other scripts
    if lspci | grep -i "VGA" | grep -i "NVIDIA" >/dev/null; then
        export GPU_VENDOR="nvidia"
    elif lspci | grep -i "VGA" | grep -i "AMD" >/dev/null; then
        export GPU_VENDOR="amd"
    elif lspci | grep -i "VGA" | grep -i "Intel" >/dev/null; then
        export GPU_VENDOR="intel"
    else
        # Default to empty if no specific GPU is found, to avoid unbound variable errors.
        export GPU_VENDOR=""
    fi

    # Detect if it's a laptop
    if [ -d "/sys/class/power_supply" ] && ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        export IS_LAPTOP=true
    else
        export IS_LAPTOP=false
    fi
}
# Always run system detection
setup_system_enhancements

# Initialize log file
{
  echo "=========================================="
  echo "CachyInstaller Installation Log"
  echo "Started: $(date)"
  echo "=========================================="
  echo ""
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
      echo "Unknown option: $arg"
      echo "Use --help for usage information"
      exit 1
      ;;
  esac
done
export VERBOSE
export DRY_RUN
export INSTALL_LOG

cachy_ascii

# Silently install gum for beautiful UI before menu
if ! command -v gum >/dev/null 2>&1; then
  sudo pacman -S --noconfirm gum >/dev/null 2>&1 || true
fi

# Check system requirements
check_system_requirements() {
  # Check if running as root
  if [[ $EUID -eq 0 ]]; then
    ui_error "Error: This script should NOT be run as root!"
    ui_warn "Please run as a regular user with sudo privileges."
    exit 1
  fi

  # Check if we're on CachyOS
  if ! grep -q "CachyOS" /etc/os-release; then
    ui_error "Error: This script is designed for CachyOS only!"
    exit 1
  fi

  # Check internet connection
  if ! ping -c 1 cachyos.org &>/dev/null; then
    ui_error "Error: No internet connection detected!"
    ui_warn "Please check your network connection and try again."
    exit 1
  fi

  # Check available disk space (at least 2GB)
  local available_space
  available_space=$(df / | awk 'NR==2 {print $4}')
  if [[ $available_space -lt 2097152 ]]; then
    ui_error "Error: Insufficient disk space! At least 2GB is required."
    exit 1
  fi
}

check_system_requirements
show_menu
export INSTALL_MODE

# Dry-run mode banner
if [ "$DRY_RUN" = true ]; then
  echo ""
  ui_warn "========================================"
  ui_warn "         DRY-RUN MODE ENABLED"
  ui_warn "========================================"
  ui_info "Preview mode: No changes will be made."
  echo ""
  sleep 2
fi

# Prompt for sudo and keep it alive
if [ "$DRY_RUN" = false ]; then
  ui_info "Please enter your sudo password to begin:"
  sudo -v || { ui_error "Sudo required. Exiting."; exit 1; }
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
  SUDO_KEEPALIVE_PID=$!
  trap 'kill $SUDO_KEEPALIVE_PID 2>/dev/null; save_log_on_exit' EXIT INT TERM
else
  ui_info "Dry-run mode: Skipping sudo authentication."
  trap 'save_log_on_exit' EXIT INT TERM
fi

# Installation start header
print_header "Starting CachyOS Enhancement" \
  "This process will take 5-15 minutes depending on your internet speed." \
  "You can safely leave this running."

# Step 1: System Preparation
print_step_header 1 "$TOTAL_STEPS" "System Preparation"
ui_info "Updating package lists and installing system utilities..."
step "System Preparation" && source "$SCRIPTS_DIR/system_preparation.sh" || log_error "System preparation failed"
ui_success "Step 1 completed"

# Step 2: Fish Shell Enhancement
print_step_header 2 "$TOTAL_STEPS" "Fish Shell Enhancement"
ui_info "Enhancing the Fish shell with plugins and custom configurations..."
step "Shell Setup" && source "$SCRIPTS_DIR/shell_setup.sh" || log_error "Fish shell enhancement failed"
ui_success "Step 2 completed"

# Step 3: Programs Installation
print_step_header 3 "$TOTAL_STEPS" "Programs Installation"
ui_info "Installing applications based on your desktop environment..."
step "Programs Installation" && source "$SCRIPTS_DIR/programs.sh" || log_error "Programs installation failed"
ui_success "Step 3 completed"

# Step 4: Gaming Mode
print_step_header 4 "$TOTAL_STEPS" "Gaming Mode"
ui_info "Setting up gaming tools (optional)..."
step "Gaming Mode" && source "$SCRIPTS_DIR/gaming_mode.sh" || log_error "Gaming Mode setup failed"
ui_success "Step 4 completed"

# Step 5: Fail2ban Setup
print_step_header 5 "$TOTAL_STEPS" "Fail2ban Setup"
ui_info "Setting up security protection for SSH..."
step "Fail2ban Setup" && source "$SCRIPTS_DIR/fail2ban.sh" || log_error "Fail2ban setup failed"
ui_success "Step 5 completed"

# Step 6: System Services
print_step_header 6 "$TOTAL_STEPS" "System Services"
ui_info "Enabling and configuring system services..."
step "System Services" && source "$SCRIPTS_DIR/system_services.sh" || log_error "System services configuration failed"
ui_success "Step 6 completed"

# Step 7: Maintenance
print_step_header 7 "$TOTAL_STEPS" "Maintenance"
ui_info "Final cleanup and system optimization..."
step "Maintenance" && source "$SCRIPTS_DIR/maintenance.sh" || log_error "Maintenance failed"
ui_success "Step 7 completed"

if [ "$DRY_RUN" = true ]; then
  print_header "Dry-Run Preview Completed"
  echo ""
  ui_info "This was a preview run. No changes were made to your system."
  ui_info "To perform the actual installation, run: ./install.sh"
  echo ""
else
  print_header "CachyOS Enhancement Completed"
fi

echo ""
ui_warn "What's been set up for you:"
echo -e "  - Enhanced Fish shell with plugins and aliases"
echo -e "  - Desktop environment with essential applications"
echo -e "  - Security features (firewall, SSH protection)"
echo -e "  - Performance and gaming optimizations"
echo -e "  - Btrfs snapshots and dual-boot support (if applicable)"
echo ""

if declare -f print_programs_summary >/dev/null 2>&1; then
  print_programs_summary
fi
print_summary
log_performance "Total installation time"

# Save final log details
{
  echo ""
  echo "=========================================="
  echo "Installation Summary"
  echo "=========================================="

  if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "Errors encountered:"
    for error in "${ERRORS[@]}"; do
      echo "  - $error"
    done
  fi
  echo ""
  echo "Installation log saved to: $INSTALL_LOG"
} >> "$INSTALL_LOG"

# Handle installation results
if [ ${#ERRORS[@]} -eq 0 ]; then
  ui_success "All steps completed successfully."
  ui_info "Log saved to: $INSTALL_LOG"
else
  ui_warn "Some non-critical errors occurred during installation:"
  for error in "${ERRORS[@]}"; do
      ui_error "   - $error"
  done
  ui_info "Your system should still work correctly."
  ui_info "You can run the installer again to resume from the last successful step."
fi

prompt_reboot "$SCRIPT_DIR"
