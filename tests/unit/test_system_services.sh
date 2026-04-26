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
    if grep -A 5 "libvirt_services" "$SYSTEM_SERVICES_SH" | grep -q "declare -A"; then
        report_test pass "array libvirt con declare -A"
    else
        report_test fail "array libvirt con declare -A" \
            "No usa declare -A para el array"
    fi
}

test_xdg_portal_hyprland() {
    if grep -q "xdg-desktop-portal-hyprland" "$SYSTEM_SERVICES_SH"; then
        report_test pass "portal XDG Hyprland referenciado"
    else
        report_test fail "portal XDG Hyprland referenciado" \
            "No referencia el portal de Hyprland"
    fi
}

test_xdg_portal_kde() {
    if grep -q "xdg-desktop-portal-kde" "$SYSTEM_SERVICES_SH"; then
        report_test pass "portal XDG KDE referenciado"
    else
        report_test fail "portal XDG KDE referenciado" \
            "No referencia el portal de KDE"
    fi
}

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

test_setup_docker_function() {
    if grep -qE "^setup_docker\(\)" "$SYSTEM_SERVICES_SH" 2>/dev/null; then
        report_test pass "setup_docker existe"
    else
        report_test fail "setup_docker existe" \
            "Función no encontrada"
    fi
}

test_setup_virtualization_services_function() {
    if grep -qE "^setup_virtualization_services\(\)" "$SYSTEM_SERVICES_SH" 2>/dev/null; then
        report_test pass "setup_virtualization_services existe"
    else
        report_test fail "setup_virtualization_services existe" \
            "Función no encontrada"
    fi
}

test_uses_check_root_permissions() {
    if grep -q "check_root_permissions" "$SYSTEM_SERVICES_SH"; then
        report_test pass "usa check_root_permissions"
    else
        report_test fail "usa check_root_permissions" \
            "No verifica permisos de root"
    fi
}

# =============================================================================
# Ejecutar tests
# =============================================================================

test_libvirt_array_declare
test_xdg_portal_hyprland
test_xdg_portal_kde
test_services_check_before_enable
test_setup_firewall_function
test_setup_essential_services_function
test_setup_docker_function
test_setup_virtualization_services_function
test_uses_check_root_permissions