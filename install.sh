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

# State tracking for error recovery
STATE_FILE="$HOME/.cachyinstaller.state"
mkdir -p "$(dirname "$STATE_FILE")"

# Function to mark step as completed with atomic write
mark_step_complete() {
  local step_name="$1"
  
  # Validate step name
  if [ -z "$step_name" ]; then
    log_error "mark_step_complete: step_name cannot be empty"
    return 1
  fi
  
  # Atomic write with file locking to prevent corruption
  local temp_state_file="$STATE_FILE.tmp.$$"
  (
    flock -x 200
    echo "COMPLETED: $step_name" >> "$temp_state_file"
  ) 200>"$temp_state_file" && mv "$temp_state_file" "$STATE_FILE" 2>/dev/null || {
    log_error "Failed to update state file for step: $step_name"
    return 1
  }
}

# Function to check if step was completed
is_step_complete() {
  [ -f "$STATE_FILE" ] && grep -q "COMPLETED: $1" "$STATE_FILE"
}

# Enhanced step completion with status tracking and error recovery
mark_step_complete_with_progress() {
  local step_name="$1"
  local status="${2:-completed}"

  # Validate step name
  if [ -z "$step_name" ]; then
    log_error "mark_step_complete_with_progress: step_name cannot be empty"
    return 1
  fi

  # Write status to state file with consistent format for parsing
  if [ "$status" = "completed" ]; then
    echo "COMPLETED: $step_name" >> "$STATE_FILE"
  else
    echo "FAILED: $step_name" >> "$STATE_FILE"
  fi
}

# Enhanced resume functionality with partial failure handling and error recovery
show_resume_menu() {
  if [ ! -f "$STATE_FILE" ] || [ ! -s "$STATE_FILE" ]; then
    return 0
  fi
  
  echo ""
  ui_info "Previous installation detected. Checking installation status..."

  local completed_steps=()
  local step_status=()
  local has_failures=false
  local last_completed_step=""

  # Read and parse state file
  while IFS= read -r step; do
    completed_steps+=("$step")
    # Check if step was marked as completed
    if [[ "$step" =~ ^COMPLETED: ]]; then
      step_status+=("completed")
      last_completed_step="${step#*: }"
    elif [[ "$step" =~ ^FAILED: ]]; then
      step_status+=("failed")
      has_failures=true
    else
      # Legacy format - assume completed
      step_status+=("completed")
      last_completed_step="$step"
    fi
  done < "$STATE_FILE"

  if [ ${#completed_steps[@]} -eq 0 ]; then
    ui_info "No completed steps found in state file"
    return 0
  fi

  echo ""
  if supports_gum; then
    gum style --foreground 220 "Installation Progress Summary"
    echo ""
    for i in "${!completed_steps[@]}"; do
      local step="${completed_steps[$i]}"
      local status="${step_status[$i]}"
      local display_step="${step#*: }"
      
      case "$status" in
        "completed")
          gum style --foreground 10 "  [COMPLETED] $display_step" >/dev/null
          ;;
        "failed")
          gum style --foreground 196 "  [FAILED] $display_step" >/dev/null
          ;;
      esac
    done
    echo ""
    
    if [ "$has_failures" = true ]; then
      if gum confirm --default=true "Found failed steps. Retry failed steps first?"; then
        ui_info "Will retry failed steps during installation"
        return 0
      elif gum confirm --default=false "Resume from last completed step?"; then
        ui_success "Resuming installation from last completed step..."
        return 0
      else
        if gum confirm --default=false "Start fresh installation (this will clear previous progress)?"; then
          rm -f "$STATE_FILE" 2>/dev/null || true
          ui_info "Starting fresh installation..."
          return 0
        else
          ui_info "Installation cancelled by user"
          exit 0
        fi
      fi
    else
      if gum confirm --default=true "Resume installation from where you left off?"; then
        ui_success "Resuming installation..."
        return 0
      else
        if gum confirm --default=false "Start fresh installation (this will clear previous progress)?"; then
          rm -f "$STATE_FILE" 2>/dev/null || true
          ui_info "Starting fresh installation..."
          return 0
        else
          ui_info "Installation cancelled by user"
          exit 0
        fi
      fi
    fi
  else
    # Fallback for systems without gum
    echo ""
    for i in "${!completed_steps[@]}"; do
      local step="${completed_steps[$i]}"
      local status="${step_status[$i]}"
      local display_step="${step#*: }"
      
      case "$status" in
        "completed")
          echo -e "${GREEN}[COMPLETED]${RESET} $display_step"
          ;;
        "failed")
          echo -e "${RED}[FAILED]${RESET} $display_step"
          ;;
      esac
    done
    echo ""
    
    if [ "$has_failures" = true ]; then
      echo "Found failed steps. Options:"
      echo "1. Retry failed steps first"
      echo "2. Resume from last completed step"
      echo "3. Start fresh installation"
      echo "4. Cancel"
      echo ""
      read -p "Choose an option (1-4): " choice
      
      case "$choice" in
        1)
          ui_info "Will retry failed steps during installation"
          return 0
          ;;
        2)
          ui_success "Resuming installation from last completed step..."
          return 0
          ;;
        3)
          rm -f "$STATE_FILE" 2>/dev/null || true
          ui_info "Starting fresh installation..."
          return 0
          ;;
        4)
          ui_info "Installation cancelled by user"
          exit 0
          ;;
        *)
          ui_warn "Invalid option. Resuming installation..."
          return 0
          ;;
      esac
    else
      echo "Resume installation from where you left off? (y/n)"
      read -r response
      if [[ "$response" =~ ^[Yy]$ ]]; then
        ui_success "Resuming installation..."
        return 0
      else
        echo "Start fresh installation? (y/n)"
        read -r fresh_response
        if [[ "$fresh_response" =~ ^[Yy]$ ]]; then
          rm -f "$STATE_FILE" 2>/dev/null || true
          ui_info "Starting fresh installation..."
          return 0
        else
          ui_info "Installation cancelled by user"
          exit 0
        fi
      fi
    fi
  fi
}

# Show resume menu if previous installation detected
if [ -f "$STATE_FILE" ] && [ -s "$STATE_FILE" ]; then
  show_resume_menu
fi

# Installation start header
print_header "Starting CachyOS Enhancement" \
  "This process will take 5-15 minutes depending on your internet speed." \
  "You can safely leave this running."

# Step 1: System Preparation
if is_step_complete "system_preparation"; then
  ui_info "Step 1 (System Preparation) already completed - skipping"
else
  print_step_header 1 "$TOTAL_STEPS" "System Preparation"
  ui_info "Updating package lists and installing system utilities..."
  if step "System Preparation" && source "$SCRIPTS_DIR/system_preparation.sh"; then
    mark_step_complete_with_progress "system_preparation" "completed"
    ui_success "Step 1 completed"
  else
    mark_step_complete_with_progress "system_preparation" "failed"
    log_error "System preparation failed"
    # For critical steps, ask user if they want to continue
    if supports_gum; then
      if gum confirm "System preparation failed. Continue with installation?" "This may cause issues with subsequent steps."; then
        ui_warn "Continuing installation despite system preparation failure"
      else
        ui_error "Installation stopped due to system preparation failure"
        exit 1
      fi
    else
      ui_warn "System preparation failed but continuing installation"
    fi
  fi
fi

# Step 2: Fish Shell Enhancement
if is_step_complete "shell_setup"; then
  ui_info "Step 2 (Shell Setup) already completed - skipping"
else
  print_step_header 2 "$TOTAL_STEPS" "Fish Shell Enhancement"
  ui_info "Enhancing the Fish shell with plugins and custom configurations..."
  if step "Shell Setup" && source "$SCRIPTS_DIR/shell_setup.sh"; then
    mark_step_complete_with_progress "shell_setup" "completed"
    ui_success "Step 2 completed"
  else
    mark_step_complete_with_progress "shell_setup" "failed"
    log_error "Shell setup failed"
    # Shell setup is important but not critical for system functionality
    ui_warn "Shell setup failed but continuing installation"
  fi
fi

# Step 3: Programs Installation
if is_step_complete "programs_installation"; then
  ui_info "Step 3 (Programs Installation) already completed - skipping"
else
  print_step_header 3 "$TOTAL_STEPS" "Programs Installation"
  ui_info "Installing applications based on your desktop environment..."
  if step "Programs Installation" && source "$SCRIPTS_DIR/programs.sh"; then
    mark_step_complete_with_progress "programs_installation" "completed"
    ui_success "Step 3 completed"
  else
    mark_step_complete_with_progress "programs_installation" "failed"
    log_error "Programs installation failed"
    # Programs are optional for system functionality
    ui_warn "Programs installation failed but continuing installation"
  fi
fi

# Step 4: Gaming Mode
if is_step_complete "gaming_mode"; then
  ui_info "Step 4 (Gaming Mode) already completed - skipping"
else
  print_step_header 4 "$TOTAL_STEPS" "Gaming Mode"
  ui_info "Setting up gaming tools (optional)..."
  if step "Gaming Mode" && source "$SCRIPTS_DIR/gaming_mode.sh"; then
    mark_step_complete_with_progress "gaming_mode" "completed"
    ui_success "Step 4 completed"
  else
    mark_step_complete_with_progress "gaming_mode" "failed"
    log_error "Gaming Mode failed"
    ui_warn "Gaming Mode failed but continuing installation (gaming optimizations not applied)"
  fi
fi

# Step 5: Fail2ban Setup
if is_step_complete "fail2ban_setup"; then
  ui_info "Step 5 (Fail2ban Setup) already completed - skipping"
else
  print_step_header 5 "$TOTAL_STEPS" "Fail2ban Setup"
  ui_info "Setting up security protection for SSH..."
  if step "Fail2ban Setup" && source "$SCRIPTS_DIR/fail2ban.sh"; then
    mark_step_complete_with_progress "fail2ban_setup" "completed"
    ui_success "Step 5 completed"
  else
    mark_step_complete_with_progress "fail2ban_setup" "failed"
    log_error "Fail2ban setup failed"
    ui_warn "Fail2ban setup failed but continuing installation (SSH security protection not applied)"
  fi
fi

# Step 6: System Services
if is_step_complete "system_services"; then
  ui_info "Step 6 (System Services) already completed - skipping"
else
  print_step_header 6 "$TOTAL_STEPS" "System Services"
  ui_info "Enabling and configuring system services..."
  if step "System Services" && source "$SCRIPTS_DIR/system_services.sh"; then
    mark_step_complete_with_progress "system_services" "completed"
    ui_success "Step 6 completed"
  else
    mark_step_complete_with_progress "system_services" "failed"
    log_error "System services failed"
    # System services are important but not always critical
    ui_warn "System services failed but continuing installation"
  fi
fi

# Step 7: Maintenance
if is_step_complete "maintenance"; then
  ui_info "Step 7 (Maintenance) already completed - skipping"
else
  print_step_header 7 "$TOTAL_STEPS" "Maintenance"
  ui_info "Final cleanup and system optimization..."
  if step "Maintenance" && source "$SCRIPTS_DIR/maintenance.sh"; then
    mark_step_complete_with_progress "maintenance" "completed"
    ui_success "Step 7 completed"
  else
    mark_step_complete_with_progress "maintenance" "failed"
    log_error "Maintenance failed"
    ui_warn "Maintenance failed but installation completed"
  fi
fi

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
