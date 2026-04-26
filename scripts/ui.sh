#!/bin/bash
# CachyInstaller UI module — gum wrappers and ANSI output functions
set -uo pipefail

supports_gum() {
  command -v gum >/dev/null 2>&1
}

ui_info() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 226 "$message"
  else
    echo -e "${YELLOW}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

ui_success() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 46 "$message"
  else
    echo -e "${GREEN}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

ui_warn() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 226 "$message"
  else
    echo -e "${YELLOW}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

ui_error() {
  local message="$1"
  if supports_gum; then
    gum style --foreground 196 "$message"
  else
    echo -e "${RED}$message${RESET}"
  fi | tee -a "$INSTALL_LOG" >&2
}

print_header() {
  local title="$1"; shift
  if supports_gum; then
    gum style --border double --margin "1 2" --padding "1 4" --foreground 51 --border-foreground 51 "$title"
    while (( "$#" )); do
      gum style --margin "1 0 0 0" --foreground 226 "$1"
      shift
    done
  else
    echo -e "${CYAN}----------------------------------------------------------------${RESET}"
    echo -e "${CYAN}$title${RESET}"
    echo -e "${CYAN}----------------------------------------------------------------${RESET}"
    while (( "$#" )); do
      echo -e "${YELLOW}$1${RESET}"
      shift
    done
  fi
}

print_step_header() {
  local step_num="$1"; local total="$2"; local title="$3"
  echo ""
  if supports_gum; then
    gum style --border normal --margin "1 0" --padding "0 2" --foreground 51 --border-foreground 51 "Step ${step_num}/${total}: ${title}"
  else
    echo -e "${CYAN}Step ${step_num}/${total}: ${title}${RESET}"
  fi
}

print_package_summary() {
  local title="$1"
  shift
  local pkgs=("$@")

  if [ ${#pkgs[@]} -gt 0 ]; then
    echo ""
    ui_info "$title:"
    printf '%s\n' "${pkgs[@]}" | sed '/^$/d' | column | sed 's/^/  /'
  fi
}

ui_header() {
    local title="$1"
    if supports_gum; then
        gum style --border normal --margin "1 2" --padding "1 2" --align center "$title"
    else
        echo ""
        echo -e "${CYAN}### ${title} ###${RESET}"
        echo ""
    fi
}

gum_confirm() {
    local question="$1"
    local description="${2:-}"

    if supports_gum; then
        if [ -n "$description" ]; then
            gum style --foreground 226 "$description"
        fi

        if gum confirm --default=true "$question"; then
            return 0
        else
            return 1
        fi
    else
        echo ""
        if [ -n "$description" ]; then
            echo -e "${YELLOW}${description}${RESET}"
        fi

        local response
        while true; do
            read -r -p "$(echo -e "${CYAN}${question} [Y/n]: ${RESET}")" response
            response=${response,,}
            case "$response" in
                ""|y|yes)
                    return 0
                    ;;
                n|no)
                    return 1
                    ;;
                *)
                    echo -e "\n${RED}Please answer Y (yes) or N (no).${RESET}\n"
                    ;;
            esac
        done
    fi
}

cachy_ascii() {
  echo -e "${CYAN}"
  cat << "EOF"
   ____           _           ___           _        _ _
  / ___|__ _  ___| |__  _   _|_ _|_ __  ___| |_ __ _| | | ___ _ __
 | |   / _` |/ __| '_ \| | | || || '_ \/ __| __/ _` | | |/ _ \ '__|
 | |__| (_| | (__| | | | |_| || || | | \__ \ || (_| | | |  __/ |
  \____\__,_|\___|_| |_|\__, |___|_| |_|___/\__\__,_|_|_|\___|_|
                        |___/
EOF
  echo -e "${NC}"
}

show_menu() {
  if supports_gum; then
    show_gum_menu
  else
    show_traditional_menu
  fi
}

show_gum_menu() {
  gum style --margin "1 0" --foreground 226 "This script will enhance your CachyOS installation with additional"
  gum style --margin "0 0 1 0" --foreground 226 "tools, security, and performance optimizations."

  local choice
  choice=$(gum choose --cursor="-> " --selected.foreground 51 --cursor.foreground 51 \
    "Standard - Complete setup with all recommended packages" \
    "Minimal - Essential tools only for a lightweight system" \
    "Exit - Cancel installation")

  case "$choice" in
    "Standard"*)
      INSTALL_MODE="default"
      ui_success "Selected: Standard installation"
      ;;
    "Minimal"*)
      INSTALL_MODE="minimal"
      ui_success "Selected: Minimal installation"
      ;;

    "Exit"*)
      ui_info "Installation cancelled."
      exit 0
      ;;
  esac
}

show_traditional_menu() {
  echo -e "${CYAN}Choose your installation mode:${RESET}"
  echo "  1) Standard - Complete setup with all recommended packages"
  echo "  2) Minimal - Essential tools only for a lightweight system"
  echo "  3) Exit - Cancel installation"

  local menu_choice
  while true; do
    read -r -p "Enter your choice [1-3]: " menu_choice
    case "$menu_choice" in
      1) INSTALL_MODE="default"; ui_success "Selected: Standard"; break ;;
      2) INSTALL_MODE="minimal"; ui_success "Selected: Minimal"; break ;;
      3) ui_info "Installation cancelled."; exit 0 ;;
      *) ui_error "Invalid choice! Please enter 1, 2, or 3." ;;
    esac
  done
}

step() {
  echo -e "\n${CYAN}> $1${RESET}" | tee -a "$INSTALL_LOG"
}

setup_error_trap() {
  trap 'last_status=$?; if [ $last_status -ne 0 ]; then ui_error "Error occurred (exit code: $last_status)"; fi' ERR
}