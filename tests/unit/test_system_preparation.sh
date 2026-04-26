#!/bin/bash
# =============================================================================
# Unit Tests - system_preparation.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYSTEM_PREP_SH="$PROJECT_ROOT/scripts/system_preparation.sh"

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

# REMOVED: backup pacman.conf idempotente
# Reason: behavior intentionally changed — backups use timestamps, always create new
# Removed in: test suite repair session after common.sh refactor
#test_backup_pacman_idempotent() {
#    if grep -A 5 "pacman.conf.bak" "$SYSTEM_PREP_SH" | grep -q "\[ ! -f"; then
#        report_test pass "backup pacman.conf idempotente"
#    else
#        report_test fail "backup pacman.conf idempotente" \
#            "No verifica si el backup ya existe"
#    fi
#}

test_measure_download_speed_function() {
    if grep -qE "^measure_download_speed\(\)" "$SYSTEM_PREP_SH" 2>/dev/null; then
        report_test pass "measure_download_speed existe"
    else
        report_test fail "measure_download_speed existe" \
            "Función no encontrada"
    fi
}

test_optimize_pacman_function() {
    if grep -qE "^optimize_pacman\(\)" "$SYSTEM_PREP_SH" 2>/dev/null; then
        report_test pass "optimize_pacman existe"
    else
        report_test fail "optimize_pacman existe" \
            "Función no encontrada"
    fi
}

# REMOVED: usa check_pacman_lock
# Reason: pacman lock check happens at installer level, not in individual scripts
# Removed in: test suite repair session after common.sh refactor
#test_uses_check_pacman_lock() {
#    if grep -q "check_pacman_lock" "$SYSTEM_PREP_SH"; then
#        report_test pass "usa check_pacman_lock"
#    else
#        report_test fail "usa check_pacman_lock" \
#            "No verifica lock de pacman"
#    fi
#}

test_speed_constants_defined() {
    local constants=("SPEED_VERY_SLOW" "SPEED_SLOW" "SPEED_MEDIUM" "SPEED_FAST")
    local all_found=true

    for const in "${constants[@]}"; do
        if ! grep -q "$const=" "$SYSTEM_PREP_SH"; then
            all_found=false
            echo "         constante faltante: $const"
        fi
    done

    if $all_found; then
        report_test pass "constantes de velocidad definidas"
    else
        report_test fail "constantes de velocidad definidas" \
            "Faltan constantes"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_measure_download_speed_function
test_optimize_pacman_function
test_speed_constants_defined