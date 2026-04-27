#!/bin/bash
# CachyInstaller logging module — log file management and error reporting
set -uo pipefail

save_log_on_exit() {
  {
    echo ""
    echo "=========================================="
    echo "Installation ended: $(date)"
    echo "=========================================="
  } >> "$INSTALL_LOG"
}

log_error() {
  echo -e "${RED}Error: $1${RESET}" | tee -a "$INSTALL_LOG"
  ERRORS+=("$1")
}

log_success() {
  echo -e "${GREEN}Success: $1${RESET}" | tee -a "$INSTALL_LOG"
}

log_warning() {
  echo -e "${YELLOW}Warning: $1${RESET}" | tee -a "$INSTALL_LOG"
}

log_info() {
  echo -e "${CYAN}Info: $1${RESET}" | tee -a "$INSTALL_LOG"
}

log_performance() {
  local step_name="$1"
  local current_time
  current_time=$(date +%s)
  local elapsed=$((current_time - START_TIME))
  local minutes=$((elapsed / 60))
  local seconds=$((elapsed % 60))
  ui_info "$step_name completed in ${minutes}m ${seconds}s."
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}