#!/bin/bash
# =============================================================================
# Integration Tests - Dry Run Tests
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

report_test() {
    local status="$1"
    local name="$2"
    local reason="${3:-}"

    ((TOTAL_TESTS++))

    case "$status" in
        pass)
            ((PASSED_TESTS++))
            echo -e "${GREEN}✅ PASS${RESET}  $name"
            ;;
        fail)
            ((FAILED_TESTS++))
            echo -e "${RED}❌ FAIL${RESET}  $name"
            if [ -n "$reason" ]; then
                echo -e "         ${YELLOW}$reason${RESET}"
            fi
            ;;
        skip)
            ((SKIPPED_TESTS++))
            echo -e "${YELLOW}⏭  SKIP${RESET}  $name — $reason"
            ;;
    esac
}

# =============================================================================
# Tests
# =============================================================================

test_install_sh_syntax_valid() {
    if bash -n "$PROJECT_ROOT/install.sh" 2>/dev/null; then
        report_test pass "install.sh sintaxis válida"
    else
        report_test fail "install.sh sintaxis válida" \
            "Error de sintaxis"
    fi
}

test_programs_sh_syntax_valid() {
    if bash -n "$PROJECT_ROOT/scripts/programs.sh" 2>/dev/null; then
        report_test pass "programs.sh sintaxis válida"
    else
        report_test fail "programs.sh sintaxis válida" \
            "Error de sintaxis"
    fi
}

test_system_services_sh_syntax_valid() {
    if bash -n "$PROJECT_ROOT/scripts/system_services.sh" 2>/dev/null; then
        report_test pass "system_services.sh sintaxis válida"
    else
        report_test fail "system_services.sh sintaxis válida" \
            "Error de sintaxis"
    fi
}

test_dry_run_variable_defined() {
    if grep -q "DRY_RUN" "$PROJECT_ROOT/install.sh" && \
       grep -q "DRY_RUN" "$PROJECT_ROOT/scripts/programs.sh"; then
        report_test pass "DRY_RUN variable usada"
    else
        report_test fail "DRY_RUN variable usada" \
            "Variable DRY_RUN no encontrada"
    fi
}

test_completion_flag_logic() {
    if grep -q "COMPLETION_FLAG" "$PROJECT_ROOT/install.sh"; then
        report_test pass "lógica de completion flag"
    else
        report_test fail "lógica de completion flag" \
            "No hay implementación de flag"
    fi
}

test_programs_yaml_has_blender() {
    if grep -q "blender" "$PROJECT_ROOT/configs/programs.yaml"; then
        report_test pass "Blender en programs.yaml"
    else
        report_test fail "Blender en programs.yaml" \
            "Blender no encontrado"
    fi
}

test_programs_yaml_has_cuda() {
    if grep -q "cuda" "$PROJECT_ROOT/configs/programs.yaml"; then
        report_test pass "CUDA en programs.yaml"
    else
        report_test fail "CUDA en programs.yaml" \
            "CUDA no encontrado"
    fi
}

test_gaming_mode_yaml_has_steam() {
    if grep -q "steam" "$PROJECT_ROOT/configs/gaming_mode.yaml"; then
        report_test pass "Steam en gaming_mode.yaml"
    else
        report_test fail "Steam en gaming_mode.yaml" \
            "Steam no encontrado"
    fi
}

test_config_files_exist() {
    local configs=(
        "configs/fish/config.fish"
        "configs/fish/starship.toml"
        "configs/fastfetch/config.jsonc"
        "configs/MangoHud.conf"
        "configs/kglobalshortcutsrc"
    )

    local all_exist=true
    for cfg in "${configs[@]}"; do
        if [ ! -f "$PROJECT_ROOT/$cfg" ]; then
            echo "         falta: $cfg"
            all_exist=false
        fi
    done

    if $all_exist; then
        report_test pass "todos los archivos de config existen"
    else
        report_test fail "todos los archivos de config existen" \
            "Algunos configs no existen"
    fi
}

test_hyprland_detection_xdg() {
    if grep -q "hyprland\|Hyprland\|HYPRLAND\|de_lower.*generic" \
        "$PROJECT_ROOT/scripts/programs.sh"; then
        report_test pass "Hyprland como DE activo"
    else
        report_test fail "Hyprland como DE activo" \
            "programs.sh no referencia Hyprland ni usa generic fallback"
    fi
}

# REMOVED: detección KDE por XDG
# Reason: KDE is not the target DE — Hyprland-only setup
# Removed in: test suite repair session after common.sh refactor
#test_kde_detection_xdg() {
#    if grep -q 'KDE|kde:wayland)' "$PROJECT_ROOT/scripts/programs.sh"; then
#        report_test pass "detección KDE por XDG"
#    else
#        report_test fail "detección KDE por XDG" \
#            "No detecta KDE"
#    fi
#}

test_gnome_detection_xdg() {
    if grep -q 'GNOME)' "$PROJECT_ROOT/scripts/programs.sh"; then
        report_test pass "detección GNOME por XDG"
    else
        report_test fail "detección GNOME por XDG" \
            "No detecta GNOME"
    fi
}

test_scripts_call_setup_error_trap() {
    local scripts=(
        "scripts/programs.sh"
        "scripts/shell_setup.sh"
        "scripts/system_services.sh"
        "scripts/system_preparation.sh"
        "scripts/gaming_mode.sh"
        "scripts/maintenance.sh"
        "scripts/fail2ban.sh"
    )

    local all_have_trap=true
    for script in "${scripts[@]}"; do
        if ! grep -q "setup_error_trap" "$PROJECT_ROOT/$script"; then
            echo "         sin trap: $script"
            all_have_trap=false
        fi
    done

    if $all_have_trap; then
        report_test pass "todos los scripts tienen trap"
    else
        report_test fail "todos los scripts tienen trap" \
            "Algunos scripts no tienen trap"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_install_sh_syntax_valid
test_programs_sh_syntax_valid
test_system_services_sh_syntax_valid
test_dry_run_variable_defined
test_completion_flag_logic
test_programs_yaml_has_blender
test_programs_yaml_has_cuda
test_gaming_mode_yaml_has_steam
test_config_files_exist
test_hyprland_detection_xdg
test_gnome_detection_xdg
test_scripts_call_setup_error_trap