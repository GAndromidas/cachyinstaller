#!/bin/bash
# =============================================================================
# Test Runner Principal - CachyInstaller Test Suite
# =============================================================================
# Ejecuta toda la suite de tests: estáticos, unitarios e integración

# No usar set -e para que los tests puedan ejecutarse completamente
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colores para output
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

# Categoría a ejecutar (default: todas)
CATEGORY="${1:-all}"

# Cargar helpers
source "$SCRIPT_DIR/lib/test_helpers.sh"

# Función para reportar resultado (disponible globalmente)
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

# Ejecutar categoría de tests
run_static_tests() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}  TESTS ESTÁTICOS - Verificación de sintaxis y estructura${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo ""

    source "$SCRIPT_DIR/static/test_syntax.sh"
}

run_unit_tests() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}  TESTS UNITARIOS - Funciones individuales${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo ""

    source "$SCRIPT_DIR/unit/test_common.sh"
    source "$SCRIPT_DIR/unit/test_programs.sh"
    source "$SCRIPT_DIR/unit/test_shell_setup.sh"
    source "$SCRIPT_DIR/unit/test_system_services.sh"
    source "$SCRIPT_DIR/unit/test_system_preparation.sh"
    source "$SCRIPT_DIR/unit/test_gaming_mode.sh"
    source "$SCRIPT_DIR/unit/test_fail2ban.sh"
    source "$SCRIPT_DIR/unit/test_maintenance.sh"
}

run_integration_tests() {
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}  TESTS DE INTEGRACIÓN - Flujos completos${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo ""

    source "$SCRIPT_DIR/integration/test_dry_run.sh"
}

# Imprimir resumen
print_summary() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo -e "${CYAN}  RESUMEN DE TESTS${RESET}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${RESET}"
    echo ""
    echo -e "  Tests ejecutados: ${TOTAL_TESTS}"
    echo -e "  Tests pasados:   ${GREEN}${PASSED_TESTS}${RESET}"
    echo -e "  Tests fallados:  ${RED}${FAILED_TESTS}${RESET}"
    echo -e "  Tests saltados:  ${YELLOW}${SKIPPED_TESTS}${RESET}"
    echo ""

    if [ "$FAILED_TESTS" -eq 0 ]; then
        echo -e "${GREEN}✅ Todos los tests pasaron${RESET}"
        return 0
    else
        echo -e "${RED}❌ Algunos tests fallaron${RESET}"
        return 1
    fi
}

# Main
case "$CATEGORY" in
    static)
        run_static_tests
        print_summary
        ;;
    unit)
        run_unit_tests
        print_summary
        ;;
    integration)
        run_integration_tests
        print_summary
        ;;
    all)
        local tot_static=0 pass_static=0 fail_static=0 skip_static=0
        local tot_unit=0 pass_unit=0 fail_unit=0 skip_unit=0
        local tot_int=0 pass_int=0 fail_int=0 skip_int=0

        # Static
        run_static_tests
        tot_static=$TOTAL_TESTS pass_static=$PASSED_TESTS fail_static=$FAILED_TESTS skip_static=$SKIPPED_TESTS

        # Reset for unit
        TOTAL_TESTS=0 PASSED_TESTS=0 FAILED_TESTS=0 SKIPPED_TESTS=0
        run_unit_tests
        tot_unit=$TOTAL_TESTS pass_unit=$PASSED_TESTS fail_unit=$FAILED_TESTS skip_unit=$SKIPPED_TESTS

        # Reset for integration
        TOTAL_TESTS=0 PASSED_TESTS=0 FAILED_TESTS=0 SKIPPED_TESTS=0
        run_integration_tests
        tot_int=$TOTAL_TESTS pass_int=$PASSED_TESTS fail_int=$FAILED_TESTS skip_int=$SKIPPED_TESTS

        # Combined summary
        TOTAL_TESTS=$((tot_static + tot_unit + tot_int))
        PASSED_TESTS=$((pass_static + pass_unit + pass_int))
        FAILED_TESTS=$((fail_static + fail_unit + fail_int))
        SKIPPED_TESTS=$((skip_static + skip_unit + skip_int))

        print_summary
        ;;
    *)
        echo "Uso: $0 [static|unit|integration|all]"
        exit 1
        ;;
esac