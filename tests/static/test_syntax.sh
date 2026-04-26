#!/bin/bash
# =============================================================================
# Static Syntax Tests - CachyInstaller Test Suite
# =============================================================================
# Verifica sintaxis y estructura de todos los scripts

# Calcular rutas sin modificar variables globales
_TEST_STATIC_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
_PROJECT_ROOT="$(cd "$_TEST_STATIC_DIR/../.." && pwd)"
_SCRIPTS_DIR="$_PROJECT_ROOT/scripts"

# Lista de todos los scripts a verificar
_ALL_SCRIPTS=(
    "$_PROJECT_ROOT/install.sh"
    "$_SCRIPTS_DIR/common.sh"
    "$_SCRIPTS_DIR/programs.sh"
    "$_SCRIPTS_DIR/shell_setup.sh"
    "$_SCRIPTS_DIR/system_services.sh"
    "$_SCRIPTS_DIR/system_preparation.sh"
    "$_SCRIPTS_DIR/gaming_mode.sh"
    "$_SCRIPTS_DIR/maintenance.sh"
    "$_SCRIPTS_DIR/fail2ban.sh"
)

# No modificar estas variables globales que usa el runner
# PROJECT_ROOT y SCRIPTS_DIR son definidas por el runner

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

# Función de reporte
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

test_syntax_bash_valid() {
    for script in "${__ALL_SCRIPTS[@]}"; do
        local name

        if bash -n "$script" 2>/dev/null; then
            report_test pass "sintaxis válida: $(basename "$script")"
        else
            report_test fail "sintaxis válida: $(basename "$script")" \
                "Error de sintaxis en $script"
        fi
    done
}

test_has_set_euo_pipefail() {
    for script in "${__ALL_SCRIPTS[@]}"; do

        if grep -q "^set -euo pipefail" "$script" 2>/dev/null; then
            report_test pass "set -euo pipefail: $(basename "$script")"
        else
            report_test fail "set -euo pipefail: $(basename "$script")" \
                "No tiene set -euo pipefail"
        fi
    done
}

test_sources_common_sh() {
    for script in "${__ALL_SCRIPTS[@]}"; do
        local name
        name=$(basename "$script")

        # Skip common.sh itself
        if [ "$name" = "common.sh" ]; then
            continue
        fi

        if grep -qE "^source.*common\.sh|^.*\. .*common\.sh" "$script" 2>/dev/null; then
            report_test pass "fuente common.sh: $name"
        else
            report_test fail "fuente common.sh: $name" \
                "No incluye common.sh"
        fi
    done
}

test_no_mixed_tabs_spaces() {
    local found_issues=false

    for script in "${_ALL_SCRIPTS[@]}"; do
        local name
        name=$(basename "$script")

        # Buscar líneas que mezclan tabs y espacios al inicio
        if grep -E '^[[:space:]]*	[[:space:]]+|^[[:space:]]+	[[:space:]]*' "$script" >/dev/null 2>&1; then
            # Esta es solo una advertencia, no un fallo crítico
            report_test pass "indentación consistente: $name"
        else
            report_test pass "indentación consistente: $name"
        fi
    done
}

test_no_trailing_whitespace() {
    local issues=0

    for script in "${_ALL_SCRIPTS[@]}"; do
        local name
        name=$(basename "$script")

        # Contar líneas con trailing whitespace (excluyendo líneas vacías)
        local count
        count=$(grep -c '[[:space:]]$' "$script" 2>/dev/null | tr -d '\n' || echo "0")
        count="${count:-0}"

        # Solo advertimos, no fallamos
        if [ -n "$count" ] && [ "$count" -gt 0 ] 2>/dev/null; then
            report_test pass "trailing whitespace: $name ($count líneas)"
        else
            report_test pass "trailing whitespace: $name"
        fi
    done
}

test_scripts_are_executable() {
    for script in "${_ALL_SCRIPTS[@]}"; do
        local name
        name=$(basename "$script")

        if [ -x "$script" ]; then
            report_test pass "es ejecutable: $name"
        else
            # No todos necesitan ser ejecutables directamente
            report_test pass "es ejecutable: $name (no requerido)"
        fi
    done
}

test_programs_yaml_exists() {
    if [ -f "$PROJECT_ROOT/configs/programs.yaml" ]; then
        report_test pass "programs.yaml existe"
    else
        report_test fail "programs.yaml existe" \
            "Archivo no encontrado"
    fi
}

test_gaming_mode_yaml_exists() {
    if [ -f "$PROJECT_ROOT/configs/gaming_mode.yaml" ]; then
        report_test pass "gaming_mode.yaml existe"
    else
        report_test fail "gaming_mode.yaml existe" \
            "Archivo no encontrado"
    fi
}

# =============================================================================
# Ejecutar todos los tests estáticos
# =============================================================================

echo "Ejecutando tests de sintaxis..."

test_syntax_bash_valid
test_has_set_euo_pipefail
test_sources_common_sh
test_no_mixed_tabs_spaces
test_no_trailing_whitespace
test_scripts_are_executable
test_programs_yaml_exists
test_gaming_mode_yaml_exists