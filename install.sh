#!/bin/bash
set -euo pipefail

# Source common functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/constants.sh"
source "${SCRIPT_DIR}/scripts/common.sh"

# Installation log file
INSTALL_LOG="$HOME/.cachyinstaller.log"

# Setup error trap
setup_error_trap

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
    --keep         Keep the installer directory after completion (useful for re-running or reviewing logs)

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
KEEP_DIR=true
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
    --keep)
      KEEP_DIR=true
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
export KEEP_DIR

cachy_ascii

# Try to install gum for beautiful UI, but continue if it fails
if ! command -v gum >/dev/null 2>&1; then
  sudo pacman -S --noconfirm gum >/dev/null 2>&1 || true
fi

# Source UI wrapper for fallback support
source "$SCRIPTS_DIR/ui.sh"

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
  if [[ $available_space -lt $MIN_DISK_KB ]]; then
    ui_error "Error: Insufficient disk space! At least 2GB is required."
    exit 1
  fi
}

check_system_requirements

# Verify pacman is not locked before proceeding
ui_info "Checking package manager availability..."
check_pacman_lock || { ui_error "Cannot proceed with pacman locked."; exit 1; }
ui_success "Package manager is available."

# Completion flag para idempotencia (audit fix)
COMPLETION_FLAG="$HOME/.config/cachyinstaller/.completed"

if [ -f "$COMPLETION_FLAG" ]; then
  ui_warn "CachyInstaller ya fue ejecutado exitosamente."
  ui_warn "Fecha de ejecución: $(cat "$COMPLETION_FLAG")"
  ui_warn "Para forzar re-ejecución, elimina el archivo:"
  ui_warn "  $COMPLETION_FLAG"
  read -rp "¿Continuar de todas formas? [s/N]: " confirm
  [[ "${confirm,,}" != "s" ]] && exit 0
fi

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
keep_sudo_alive() {
  while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
}
kill_sudo_keepalive() {
  if [ -n "$SUDO_KEEPALIVE_PID" ]; then
    kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
  fi
}
if [ "$DRY_RUN" = false ]; then
  ui_info "Please enter your sudo password to begin:"
  sudo -v || { ui_error "Sudo required. Exiting."; exit 1; }
  keep_sudo_alive
  SUDO_KEEPALIVE_PID=$!
  trap 'kill_sudo_keepalive; save_log_on_exit' EXIT INT TERM
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

# Step 2: Hardware Compatibility (NVIDIA + Wayland)
CURRENT_STEP=2
print_step_header 2 "$TOTAL_STEPS" "Hardware compatibility (NVIDIA + Wayland)"
ui_info "Setting up NVIDIA + Wayland environment variables..."
step "Hardware Setup" && source "$SCRIPTS_DIR/hardware_setup.sh" || log_error "Hardware setup failed"
ui_success "Step 2 completed"

# Step 3: Fish Shell Enhancement
print_step_header 3 "$TOTAL_STEPS" "Fish Shell Enhancement"
ui_info "Enhancing the Fish shell with plugins and custom configurations..."
step "Shell Setup" && source "$SCRIPTS_DIR/shell_setup.sh" || log_error "Fish shell enhancement failed"
ui_success "Step 3 completed"

# Step 4: Programs Installation
print_step_header 4 "$TOTAL_STEPS" "Programs Installation"
ui_info "Installing applications based on your desktop environment..."
step "Programs Installation" && source "$SCRIPTS_DIR/programs.sh" || log_error "Programs installation failed"
ui_success "Step 4 completed"

# Step 5: Gaming Mode (optional)
print_step_header 5 "$TOTAL_STEPS" "Gaming Mode"
if gum_confirm "Install gaming packages? (Steam, MangoHud, GameMode, Proton tools)"; then
  ui_info "Setting up gaming packages..."
  source "$SCRIPTS_DIR/gaming_mode.sh"
  ui_success "Step 5 completed"
else
  ui_info "Gaming setup skipped."
  ui_success "Step 5 skipped"
fi

# Step 6: Fail2ban Setup
print_step_header 6 "$TOTAL_STEPS" "Fail2ban Setup"
ui_info "Setting up security protection for SSH..."
step "Fail2ban Setup" && source "$SCRIPTS_DIR/fail2ban.sh" || log_error "Fail2ban setup failed"
ui_success "Step 6 completed"

# Step 7: System Services
print_step_header 7 "$TOTAL_STEPS" "System Services"
ui_info "Enabling and configuring system services..."
step "System Services" && source "$SCRIPTS_DIR/system_services.sh" || log_error "System services configuration failed"
ui_success "Step 7 completed"

# Step 8: Maintenance
print_step_header 8 "$TOTAL_STEPS" "Maintenance"
ui_info "Final cleanup and system optimization..."
step "Maintenance" && source "$SCRIPTS_DIR/maintenance.sh" || log_error "Maintenance failed"
ui_success "Step 8 completed"

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

# Save final log details and summary
{
  echo ""
  echo "=========================================="
  echo "Installation Summary"
  echo "=========================================="
  echo "Completed at: $(date)"

  if [ ${#INSTALLED_PACKAGES[@]} -gt 0 ]; then
    echo "Packages installed: ${#INSTALLED_PACKAGES[@]}"
  fi

  if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
    echo "Packages that failed to install:"
    for pkg in "${FAILED_PACKAGES[@]}"; do
      echo "  - $pkg"
    done
  fi

  if [ ${#FAILED_SERVICES[@]} -gt 0 ]; then
    echo "Services that failed to enable:"
    for svc in "${FAILED_SERVICES[@]}"; do
      echo "  - $svc"
    done
  fi

  if [ ${#ERRORS[@]} -gt 0 ]; then
    echo "Errors encountered:"
    for error in "${ERRORS[@]}"; do
      echo "  - $error"
    done
  fi
  echo ""
  echo "Full log saved to: $INSTALL_LOG"
} >> "$INSTALL_LOG"

# Handle installation results
if [ ${#ERRORS[@]} -eq 0 ]; then
  # Completion flag para idempotencia (audit fix)
  mkdir -p "$HOME/.config/cachyinstaller"
  date '+%Y-%m-%d %H:%M:%S' > "$COMPLETION_FLAG"

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

print_post_install_notes() {
  print_header "COMANDOS POST-INSTALACIÓN RECOMENDADOS"

  echo ""
  ui_warn "CUDA (optional — manual install):"
  echo "  CUDA was not installed automatically (~5GB download)."
  echo "  Install only after verifying your Hyprland session is stable:"
  echo ""
  echo "    nvidia-smi                    # verify GPU is detected"
  echo "    sudo pacman -S cuda           # install CUDA (~5GB)"
  echo ""
  echo "  Required for: Blender GPU rendering, Ollama GPU inference,"
  echo "  and ML/AI workflows with GPU acceleration."
  echo ""

  ui_info "── Render GPU en Blender (NVIDIA OptiX/CUDA) ──"
  ui_info "Instala el toolkit de CUDA para habilitar render por GPU."
  ui_info "Descarga: ~512MB | Espacio en disco: ~5GB"
  echo ""
  ui_info "  sudo pacman -S cuda"
  echo ""
  ui_info "Después de instalar: abre Blender →"
  ui_info "  Edit → Preferences → System → Cycles Render Devices"
  ui_info "  Selecciona OptiX (recomendado para GPUs RTX)"
  echo ""

  ui_info "── Activar toolchain de Rust ──"
  ui_info "  rustup default stable"
  echo ""

  ui_info "── Levantar relay de RustDesk (escritorio remoto) ──"
  ui_info "  cd ~/rustdesk-relay && docker compose up -d"
  echo ""

  ui_info "── Verificar soporte Vulkan ──"
  ui_info "  vulkaninfo --summary"
  echo ""
}

print_post_install_notes

prompt_reboot "$SCRIPT_DIR"
