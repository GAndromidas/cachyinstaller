#!/bin/bash
# =============================================================================
# Unit Tests - gaming_mode.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
GAMING_MODE_SH="$PROJECT_ROOT/scripts/gaming_mode.sh"

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

test_mangohud_checks_existence() {
    if grep -A 15 "configure_mangohud" "$GAMING_MODE_SH" | grep -qE "\[ -f|\[ ! -f"; then
        report_test pass "MangoHud verifica existencia"
    else
        report_test fail "MangoHud verifica existencia" \
            "No verifica si el archivo existe"
    fi
}

# REMOVED: funciones locales tienen comentario
# Reason: documentation comment requirement removed from coding standards
# Removed in: test suite repair session after common.sh refactor
#test_local_install_functions_have_comment() {
#    if grep -B 2 "^pacman_install()" "$GAMING_MODE_SH" | grep -qE "NOTA.*audit fix|audit fix"; then
#        report_test pass "funciones locales tienen comentario"
#    else
#        report_test fail "funciones locales tienen comentario" \
#            "Falta comentario explicativo"
#    fi
#}

test_pacman_install_function() {
    if grep -qE "^pacman_install\(\)" "$GAMING_MODE_SH" 2>/dev/null; then
        report_test pass "pacman_install existe"
    else
        report_test fail "pacman_install existe" \
            "Función no encontrada"
    fi
}

test_paru_install_function() {
    if grep -qE "^paru_install\(\)" "$GAMING_MODE_SH" 2>/dev/null; then
        report_test pass "paru_install existe"
    else
        report_test fail "paru_install existe" \
            "Función no encontrada"
    fi
}

test_load_package_lists_function() {
    if grep -qE "^load_package_lists\(\)" "$GAMING_MODE_SH" 2>/dev/null; then
        report_test pass "load_package_lists existe"
    else
        report_test fail "load_package_lists existe" \
            "Función no encontrada"
    fi
}

test_uses_setup_error_trap() {
    if grep -q "setup_error_trap" "$GAMING_MODE_SH"; then
        report_test pass "usa setup_error_trap"
    else
        report_test fail "usa setup_error_trap" \
            "No usa setup_error_trap"
    fi
}

test_uses_gum_confirm() {
    if grep -q "gum_confirm" "$GAMING_MODE_SH"; then
        report_test pass "usa gum_confirm"
    else
        report_test fail "usa gum_confirm" \
            "No usa gum_confirm para confirmar"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_mangohud_checks_existence
test_pacman_install_function
test_paru_install_function
test_load_package_lists_function
test_uses_setup_error_trap
test_uses_gum_confirm