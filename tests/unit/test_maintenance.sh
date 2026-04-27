#!/bin/bash
# =============================================================================
# Unit Tests - maintenance.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAINTENANCE_SH="$PROJECT_ROOT/scripts/maintenance.sh"

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

test_system_cleanup_exists() {
    if grep -qE "^system_cleanup\(\)" "$MAINTENANCE_SH" 2>/dev/null; then
        report_test pass "system_cleanup existe"
    else
        report_test fail "system_cleanup existe" \
            "Función no encontrada"
    fi
}

# REMOVED: usa check_pacman_lock
# Reason: pacman lock check happens at installer level, not in individual scripts
# Removed in: test suite repair session after common.sh refactor
#test_uses_check_pacman_lock() {
#    if grep -q "check_pacman_lock" "$MAINTENANCE_SH"; then
#        report_test pass "usa check_pacman_lock"
#    else
#        report_test fail "usa check_pacman_lock" \
#            "No verifica lock de pacman"
#    fi
#}

test_uses_paccache() {
    if grep -q "paccache" "$MAINTENANCE_SH"; then
        report_test pass "usa paccache"
    else
        report_test fail "usa paccache" \
            "No usa paccache para limpieza"
    fi
}

test_uses_paru_for_cleanup() {
    if grep -q "paru.*-Sc" "$MAINTENANCE_SH"; then
        report_test pass "limpia cache de AUR (paru)"
    else
        report_test fail "limpia cache de AUR (paru)" \
            "No limpia cache de AUR"
    fi
}

test_uses_flatpak_cleanup() {
    if grep -q "flatpak.*uninstall.*--unused" "$MAINTENANCE_SH"; then
        report_test pass "limpia Flatpaks sin usar"
    else
        report_test fail "limpia Flatpaks sin usar" \
            "No limpia Flatpaks"
    fi
}

test_uses_setup_error_trap() {
    if grep -q "setup_error_trap" "$MAINTENANCE_SH"; then
        report_test pass "usa setup_error_trap"
    else
        report_test fail "usa setup_error_trap" \
            "No usa setup_error_trap"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_system_cleanup_exists
test_uses_paccache
test_uses_paru_for_cleanup
test_uses_flatpak_cleanup
test_uses_setup_error_trap