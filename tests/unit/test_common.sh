#!/bin/bash
# =============================================================================
# Unit Tests - common.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COMMON_SH="$PROJECT_ROOT/scripts/common.sh"

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
RESET='\033[0m'

# Contadores
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0

report_test() {
    local status="$1"
    local name="$2"
    local reason="${3:-}"

    TOTAL_TESTS=$((TOTAL_TESTS + 1))

    case "$status" in
        pass)
            PASSED_TESTS=$((PASSED_TESTS + 1))
            echo -e "${GREEN}✅ PASS${RESET}  $name"
            ;;
        fail)
            FAILED_TESTS=$((FAILED_TESTS + 1))
            echo -e "${RED}❌ FAIL${RESET}  $name"
            if [ -n "$reason" ]; then
                echo -e "         ${YELLOW}$reason${RESET}"
            fi
            ;;
        skip)
            SKIPPED_TESTS=$((SKIPPED_TESTS + 1))
            echo -e "${YELLOW}⏭  SKIP${RESET}  $name — $reason"
            ;;
    esac
}

# =============================================================================
# Tests
# =============================================================================

test_log_error_defined_once() {
    # Contar ocurrencias de la definición de log_error (solo la definición, no llamadas)
    local count
    count=$(grep -cE "^log_error\(\)" "$COMMON_SH" 2>/dev/null || echo "0")

    if [ "$count" -eq 1 ]; then
        report_test pass "log_error definida una vez"
    else
        report_test fail "log_error definida una vez" \
            "Encontrada $count veces (esperado: 1)"
    fi
}

test_all_log_functions_exist() {
    local funcs=("log_info" "log_success" "log_warning" "log_error"
                 "ui_info" "ui_success" "ui_warn" "ui_error")
    local all_exist=true

    for func in "${funcs[@]}"; do
        if ! grep -qE "^${func}\(\)" "$COMMON_SH" 2>/dev/null; then
            all_exist=false
            echo "         función faltante: $func"
        fi
    done

    if $all_exist; then
        report_test pass "funciones de log existen"
    else
        report_test fail "funciones de log existen" \
            "Algunas funciones no fueron encontradas"
    fi
}

test_handle_error_exists() {
    if grep -qE "^handle_error\(\)" "$COMMON_SH" 2>/dev/null; then
        report_test pass "handle_error existe"
    else
        report_test fail "handle_error existe" \
            "Función no encontrada"
    fi
}

test_check_pacman_lock_exists() {
    if grep -qE "^check_pacman_lock\(\)" "$COMMON_SH" 2>/dev/null; then
        report_test pass "check_pacman_lock existe"
    else
        report_test fail "check_pacman_lock existe" \
            "Función no encontrada"
    fi
}

test_backup_file_exists() {
    if grep -qE "^backup_file\(\)" "$COMMON_SH" 2>/dev/null; then
        report_test pass "backup_file existe"
    else
        report_test fail "backup_file existe" \
            "Función no encontrada"
    fi
}

test_setup_error_trap_exists() {
    if grep -qE "^setup_error_trap\(\)" "$COMMON_SH" 2>/dev/null; then
        report_test pass "setup_error_trap existe"
    else
        report_test fail "setup_error_trap existe" \
            "Función no encontrada"
    fi
}

test_install_package_functions_exist() {
    local funcs=("install_package_generic" "install_packages_quietly"
                 "install_aur_packages")
    local all_exist=true

    for func in "${funcs[@]}"; do
        if ! grep -qE "^${func}\(\)" "$COMMON_SH" 2>/dev/null; then
            all_exist=false
            echo "         función faltante: $func"
        fi
    done

    if $all_exist; then
        report_test pass "funciones de instalación existen"
    else
        report_test fail "funciones de instalación existen" \
            "Algunas funciones no fueron encontradas"
    fi
}

test_log_error_no_duplicate_definition() {
    # Verificar que la definición duplicada fue eliminada (audit fix)
    local count
    count=$(grep -c "^log_error()" "$COMMON_SH" 2>/dev/null || echo "0")

    if [ "$count" -eq 1 ]; then
        report_test pass "log_error sin duplicados (audit fix)"
    else
        report_test fail "log_error sin duplicados (audit fix)" \
            "Still has duplicates"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_log_error_defined_once
test_all_log_functions_exist
test_handle_error_exists
test_check_pacman_lock_exists
test_backup_file_exists
test_setup_error_trap_exists
test_install_package_functions_exist
test_log_error_no_duplicate_definition