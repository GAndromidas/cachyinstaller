#!/bin/bash
# =============================================================================
# Unit Tests - shell_setup.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SHELL_SETUP_SH="$PROJECT_ROOT/scripts/shell_setup.sh"

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

test_fisher_hash_verification_present() {
    if grep -qiE "sha256sum|VERIFY_FISHER_HASH|FISHER_KNOWN_HASH" "$SHELL_SETUP_SH"; then
        report_test pass "verificación de hash Fisher"
    else
        report_test fail "verificación de hash Fisher" \
            "No hay verificación de hash para Fisher"
    fi
}

test_fisher_uses_temp_file() {
    if grep -qE "mktemp|FISHER_TMP" "$SHELL_SETUP_SH"; then
        report_test pass "Fisher usa archivo temporal"
    else
        report_test fail "Fisher usa archivo temporal" \
            "No usa mktemp o variable temporal"
    fi
}

test_fish_config_not_overwritten() {
    if grep -A 10 "Deploy config.fish" "$SHELL_SETUP_SH" | grep -q "\[ ! -f"; then
        report_test pass "Fish config verifica existencia"
    else
        report_test fail "Fish config verifica existencia" \
            "No verifica antes de copiar"
    fi
}

test_starship_config_not_overwritten() {
    if grep -A 10 "Deploy starship.toml" "$SHELL_SETUP_SH" | grep -q "\[ ! -f"; then
        report_test pass "Starship config verifica existencia"
    else
        report_test fail "Starship config verifica existencia" \
            "No verifica antes de copiar"
    fi
}

test_fastfetch_config_not_overwritten() {
    if grep -A 10 "Install Fastfetch" "$SHELL_SETUP_SH" | grep -q "\[ ! -f"; then
        report_test pass "Fastfetch config verifica existencia"
    else
        report_test fail "Fastfetch config verifica existencia" \
            "No verifica antes de copiar"
    fi
}

test_fisher_plugins_list() {
    local plugins=("autopair.fish" "done" "fzf.fish" "sponge")
    local found=0

    for plugin in "${plugins[@]}"; do
        if grep -q "$plugin" "$SHELL_SETUP_SH"; then
            ((found++))
        fi
    done

    if [ "$found" -ge 3 ]; then
        report_test pass "lista de plugins Fisher completa"
    else
        report_test fail "lista de plugins Fisher completa" \
            "Faltan plugins (encontrados: $found/4)"
    fi
}

test_uses_command_exists() {
    if grep -q "command_exists fish" "$SHELL_SETUP_SH"; then
        report_test pass "usa command_exists para validación"
    else
        report_test fail "usa command_exists para validación" \
            "No valida presencia de fish"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_fisher_hash_verification_present
test_fisher_uses_temp_file
test_fish_config_not_overwritten
test_starship_config_not_overwritten
test_fastfetch_config_not_overwritten
test_fisher_plugins_list
test_uses_command_exists