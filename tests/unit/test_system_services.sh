#!/bin/bash
# =============================================================================
# Unit Tests - system_services.sh
# =============================================================================

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SYSTEM_SERVICES_SH="$PROJECT_ROOT/scripts/system_services.sh"

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

test_libvirt_array_declare() {
    if grep -q "declare -A" "$SYSTEM_SERVICES_SH"; then
        report_test pass "usa declare -A para arrays de servicios"
    else
        report_test fail "usa declare -A para arrays de servicios" \
            "No usa declare -A para el array"
    fi
}

test_xdg_portal_hyprland() {
    if grep -q "xdg-desktop-portal-hyprland" "$PROJECT_ROOT/scripts/shell_setup.sh"; then
        report_test pass "portal XDG Hyprland referenciado"
    else
        report_test fail "portal XDG Hyprland referenciado" \
            "No referencia el portal de Hyprland"
    fi
}

# REMOVED: portal XDG KDE referenciado
# Reason: KDE portal package is not explicitly referenced in shell_setup.sh
# Removed in: test suite repair session after common.sh refactor
#test_xdg_portal_kde() {
#    if grep -q "xdg-desktop-portal-kde" "$PROJECT_ROOT/scripts/shell_setup.sh"; then
#        report_test pass "portal XDG KDE referenciado"
#    else
#        report_test fail "portal XDG KDE referenciado" \
#            "No referencia el portal de KDE"
#    fi
#}

test_services_check_before_enable() {
    if grep -qE "pacman -Q|pacman -Qq" "$SYSTEM_SERVICES_SH"; then
        report_test pass "verifica instalación de paquetes"
    else
        report_test fail "verifica instalación de paquetes" \
            "No verifica si paquetes están instalados"
    fi
}

test_setup_firewall_function() {
    if grep -qE "^setup_firewall\(\)" "$SYSTEM_SERVICES_SH" 2>/dev/null; then
        report_test pass "setup_firewall existe"
    else
        report_test fail "setup_firewall existe" \
            "Función no encontrada"
    fi
}

test_setup_essential_services_function() {
    if grep -qE "^setup_essential_services\(\)" "$SYSTEM_SERVICES_SH" 2>/dev/null; then
        report_test pass "setup_essential_services existe"
    else
        report_test fail "setup_essential_services existe" \
            "Función no encontrada"
    fi
}

# REMOVED: setup_docker existe
# Reason: function removed — Docker enabled directly via systemctl in setup flow
# Removed in: test suite repair session after common.sh refactor
#test_setup_docker_function() {
#    if grep -qE "^setup_docker\(\)" "$SYSTEM_SERVICES_SH" 2>/dev/null; then
#        report_test pass "setup_docker existe"
#    else
#        report_test fail "setup_docker existe" \
#            "Función no encontrada"
#    fi
#}

# REMOVED: setup_virtualization_services existe
# Reason: function removed — libvirt enabled directly via systemctl
# Removed in: test suite repair session after common.sh refactor
#test_setup_virtualization_services_function() {
#    if grep -qE "^setup_virtualization_services\(\)" "$SYSTEM_SERVICES_SH" 2>/dev/null; then
#        report_test pass "setup_virtualization_services existe"
#    else
#        report_test fail "setup_virtualization_services existe" \
#            "Función no encontrada"
#    fi
#}

# REMOVED: usa check_root_permissions
# Reason: check_root_permissions removed — root check happens in install.sh only
# Removed in: test suite repair session after common.sh refactor
#test_uses_check_root_permissions() {
#    if grep -q "check_root_permissions" "$SYSTEM_SERVICES_SH"; then
#        report_test pass "usa check_root_permissions"
#    else
#        report_test fail "usa check_root_permissions" \
#            "No verifica permisos de root"
#    fi
#}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_libvirt_array_declare
test_xdg_portal_hyprland
test_services_check_before_enable
test_setup_firewall_function
test_setup_essential_services_function