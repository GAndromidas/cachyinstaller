#!/bin/bash
# =============================================================================
# Test Helpers Library - CachyInstaller Test Suite
# =============================================================================
# Funciones compartidas para escribir tests

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RESET='\033[0m'

# Variables de test
TEST_TMPDIR=""
TEST_HOME=""
MOCKED_COMMANDS=()

# =============================================================================
# Funciones de aserción
# =============================================================================

assert_equals() {
    local expected="$1"
    local actual="$2"
    local description="$3"

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "         esperado: $expected"
        echo "         actual:   $actual"
        return 1
    fi
}

assert_not_empty() {
    local value="$1"
    local description="$2"

    if [ -n "$value" ]; then
        return 0
    else
        echo "         valor está vacío"
        return 1
    fi
}

assert_file_exists() {
    local filepath="$1"
    local description="$2"

    if [ -f "$filepath" ]; then
        return 0
    else
        echo "         archivo no encontrado: $filepath"
        return 1
    fi
}

assert_file_not_exists() {
    local filepath="$1"
    local description="$2"

    if [ ! -f "$filepath" ]; then
        return 0
    else
        echo "         archivo existe: $filepath"
        return 1
    fi
}

assert_contains() {
    local text="$1"
    local substring="$2"
    local description="$3"

    if echo "$text" | grep -q "$substring"; then
        return 0
    else
        echo "         texto no contiene: $substring"
        return 1
    fi
}

assert_exit_code() {
    local expected_code="$1"
    local command="$2"
    local description="$3"

    eval "$command" >/dev/null 2>&1
    local actual_code=$?

    if [ "$actual_code" -eq "$expected_code" ]; then
        return 0
    else
        echo "         código esperado: $expected_code"
        echo "         código actual:   $actual_code"
        return 1
    fi
}

assert_function_exists() {
    local func_name="$1"
    local filepath="$2"
    local description="$3"

    if grep -q "^${func_name}()" "$filepath" 2>/dev/null; then
        return 0
    else
        echo "         función no encontrada: $func_name"
        return 1
    fi
}

assert_variable_is_local() {
    local variable="$1"
    local function_name="$2"
    local filepath="$3"

    local line
    line=$(sed -n "/^${function_name}()/,/^}/p" "$filepath" 2>/dev/null | grep -E "local[[:space:]]+${variable}=" || true)

    if [ -n "$line" ]; then
        return 0
    else
        echo "         variable '$variable' no es local en $function_name"
        return 1
    fi
}

assert_command_has_flag() {
    local command="$1"
    local flag="$2"
    local filepath="$3"

    if grep -q "$flag" "$filepath" 2>/dev/null; then
        return 0
    else
        echo "         comando '$command' no tiene flag: $flag"
        return 1
    fi
}

# =============================================================================
# Control de tests
# =============================================================================

skip_test() {
    local reason="$1"
    echo -e "${YELLOW}⏭  SKIP${RESET} — $reason"
    return 2
}

# =============================================================================
# Mocks de comandos
# =============================================================================

mock_command() {
    local name="$1"
    local mock_output="${2:-}"
    local mock_exit_code="${3:-0}"

    local mock_dir="$TEST_TMPDIR/mocks"
    mkdir -p "$mock_dir"

    cat > "$mock_dir/$name" << EOF
#!/bin/bash
echo "$mock_output"
exit $mock_exit_code
EOF
    chmod +x "$mock_dir/$mock_dir/$name" 2>/dev/null || true
    chmod +x "$mock_dir/$name"

    # Agregar al PATH temporal
    export PATH="$mock_dir:$PATH"
    MOCKED_COMMANDS+=("$name")
}

unmock_command() {
    local name="$1"
    local mock_dir="$TEST_TMPDIR/mocks"

    if [ -f "$mock_dir/$name" ]; then
        rm -f "$mock_dir/$name"
    fi
}

unmock_all() {
    local mock_dir="$TEST_TMPDIR/mocks"

    for cmd in "${MOCKED_COMMANDS[@]}"; do
        rm -f "$mock_dir/$cmd" 2>/dev/null || true
    done
    MOCKED_COMMANDS=()
}

# =============================================================================
# Entorno de test
# =============================================================================

setup_test_env() {
    TEST_TMPDIR=$(mktemp -d)
    TEST_HOME="$TEST_TMPDIR/test_home"
    mkdir -p "$TEST_HOME"
    mkdir -p "$TEST_HOME/.config"

    # Exportar para que los scripts usen el entorno de test
    export TEST_TMPDIR
    export TEST_HOME
    export HOME="$TEST_HOME"

    # Variables por defecto
    export DRY_RUN="${DRY_RUN:-true}"
    export VERBOSE="${VERBOSE:-false}"
    export INSTALL_LOG="$TEST_TMPDIR/install.log"

    # Crear estructura de directorios que el script espera
    mkdir -p "$TEST_HOME/.config/cachyinstaller"
    mkdir -p "$TEST_HOME/.config/fish"
    mkdir -p "$TEST_HOME/.config/fastfetch"
    mkdir -p "$TEST_HOME/.config/environment.d"
    mkdir -p "$TEST_HOME/.config/MangoHud"
}

teardown_test_env() {
    if [ -n "$TEST_TMPDIR" ] && [ -d "$TEST_TMPDIR" ]; then
        unmock_all
        rm -rf "$TEST_TMPDIR"
    fi

    TEST_TMPDIR=""
    TEST_HOME=""
}

# =============================================================================
# Ejecutor de tests
# =============================================================================

run_test() {
    local test_name="$1"
    local test_function="$2"

    # Crear entorno
    setup_test_env

    # Ejecutar el test
    local result=0
    $test_function || result=$?

    # Cleanup
    teardown_test_env

    return $result
}

# =============================================================================
# Funciones auxiliares
# =============================================================================

get_project_root() {
    # Asumiendo que estamos en tests/lib/, subir dos niveles
    local this_dir
    this_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    echo "$(cd "$this_dir/../.." && pwd)"
}

get_script_path() {
    local script_name="$1"
    echo "$(get_project_root)/scripts/$script_name"
}

get_config_path() {
    local config_name="$1"
    echo "$(get_project_root)/configs/$config_name"
}