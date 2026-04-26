#!/bin/bash
# =============================================================================
# Unit Tests - fail2ban.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FAIL2BAN_SH="$PROJECT_ROOT/scripts/fail2ban.sh"

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

test_setup_fail2ban_exists() {
    if grep -qE "^setup_fail2ban\(\)" "$FAIL2BAN_SH" 2>/dev/null; then
        report_test pass "setup_fail2ban existe"
    else
        report_test fail "setup_fail2ban existe" \
            "Función no encontrada"
    fi
}

test_checks_config_before_create() {
    if grep -A 10 "jail.local" "$FAIL2BAN_SH" | grep -q "\[ -f"; then
        report_test pass "verifica config antes de crear"
    else
        report_test fail "verifica config antes de crear" \
            "No verifica si config existe"
    fi
}

test_uses_check_root_permissions() {
    if grep -q "check_root_permissions" "$FAIL2BAN_SH"; then
        report_test pass "usa check_root_permissions"
    else
        report_test fail "usa check_root_permissions" \
            "No verifica permisos de root"
    fi
}

test_creates_sshd_jail() {
    if grep -q "sshd" "$FAIL2BAN_SH" && grep -q "enabled = true" "$FAIL2BAN_SH"; then
        report_test pass "configura jail sshd"
    else
        report_test fail "configura jail sshd" \
            "No configura jail para sshd"
    fi
}

test_uses_systemctl_enable() {
    if grep -q "systemctl enable" "$FAIL2BAN_SH"; then
        report_test pass "usa systemctl enable"
    else
        report_test fail "usa systemctl enable" \
            "No habilita servicio con systemctl"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_setup_fail2ban_exists
test_checks_config_before_create
test_uses_check_root_permissions
test_creates_sshd_jail
test_uses_systemctl_enable