#!/bin/bash
# =============================================================================
# Unit Tests - programs.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROGRAMS_SH="$PROJECT_ROOT/scripts/programs.sh"

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

# REMOVED: current_toolchain es local
# Reason: variable removed during Hyprland-only refactor
# Removed in: test suite repair session after common.sh refactor
#test_current_toolchain_is_local() {
#    if grep -A 5 "configure_development_tools()" "$PROGRAMS_SH" | \
#       grep -q "local current_toolchain"; then
#        report_test pass "current_toolchain es local"
#    else
#        report_test fail "current_toolchain es local" \
#            "Variable no declarada como local"
#    fi
#}

# REMOVED: Hyprland en detección XDG
# Reason: Hyprland is now assumed, not detected — installer is Hyprland-only
# Removed in: test suite repair session after common.sh refactor
#test_hyprland_detection_in_case() {
#    if grep -A 10 'case.*XDG_CURRENT_DESKTOP' "$PROGRAMS_SH" | \
#       grep -qi "Hyprland"; then
#        report_test pass "Hyprland en detección XDG"
#    else
#        report_test fail "Hyprland en detección XDG" \
#            "Hyprland no está en el case de detección"
#    fi
#}

# REMOVED: Hyprland fallback con hyprctl
# Reason: hyprctl fallback removed — Hyprland-only setup has no fallback needed
# Removed in: test suite repair session after common.sh refactor
#test_hyprland_detection_fallback() {
#    if grep -q "hyprctl" "$PROGRAMS_SH"; then
#        report_test pass "Hyprland fallback con hyprctl"
#    else
#        report_test fail "Hyprland fallback con hyprctl" \
#            "No hay verificación con hyprctl"
#    fi
#}

# REMOVED: detección de GPU dual
# Reason: GPU detection moved to hardware_setup.sh, not programs.sh
# Removed in: test suite repair session after common.sh refactor
#test_configure_wayland_env_detects_dual_gpu() {
#    if grep -q "has_dual_gpu" "$PROGRAMS_SH" || \
#       grep -q "lspci.*intel.*nvidia\|lspci.*nvidia.*intel" "$PROGRAMS_SH"; then
#        report_test pass "detección de GPU dual"
#    else
#        report_test fail "detección de GPU dual" \
#            "No detecta GPU dual"
#    fi
#}

# REMOVED: advertencia PRIME/dual GPU
# Reason: PRIME detection removed — single NVIDIA GPU assumed
# Removed in: test suite repair session after common.sh refactor
#test_configure_wayland_env_prime_warning() {
#    if grep -qi "envycontrol\|prime\|gpu dual" "$PROGRAMS_SH"; then
#        report_test pass "advertencia PRIME/dual GPU"
#    else
#        report_test fail "advertencia PRIME/dual GPU" \
#            "No hay advertencia para GPU dual"
#    fi
#}

test_ensure_yq_function_exists() {
    if grep -qE "^ensure_yq\(\)" "$PROGRAMS_SH" 2>/dev/null; then
        report_test pass "ensure_yq existe"
    else
        report_test fail "ensure_yq existe" \
            "Función no encontrada"
    fi
}

test_read_yaml_list_function_exists() {
    if grep -qE "^read_yaml_list\(\)" "$PROGRAMS_SH" 2>/dev/null; then
        report_test pass "read_yaml_list existe"
    else
        report_test fail "read_yaml_list existe" \
            "Función no encontrada"
    fi
}

# REMOVED: configure_docker existe
# Reason: function removed — Docker config handled inline in system_services.sh
# Removed in: test suite repair session after common.sh refactor
#test_configure_docker_function_exists() {
#    if grep -qE "^configure_docker\(\)" "$PROGRAMS_SH" 2>/dev/null; then
#        report_test pass "configure_docker existe"
#    else
#        report_test fail "configure_docker existe" \
#            "Función no encontrada"
#    fi
#}

# REMOVED: configure_virtualization existe
# Reason: function removed — virtualization config handled inline
# Removed in: test suite repair session after common.sh refactor
#test_configure_virtualization_function_exists() {
#    if grep -qE "^configure_virtualization\(\)" "$PROGRAMS_SH" 2>/dev/null; then
#        report_test pass "configure_virtualization existe"
#    else
#        report_test fail "configure_virtualization existe" \
#            "Función no encontrada"
#    fi
#}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_ensure_yq_function_exists
test_read_yaml_list_function_exists