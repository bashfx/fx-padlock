#!/usr/bin/env bash
# test_runner_modular.sh - Modular Test Suite Orchestrator
# BashFX 2.1 Compliant Testing Framework

set -e

# Global variables
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PADLOCK_KEYS="${XDG_ETC_HOME:-$HOME/.local/etc}/padlock/keys"

# Source all test modules
source "$SCRIPT_DIR/tests/test_harness.sh"
source "$SCRIPT_DIR/tests/test_core.sh"
source "$SCRIPT_DIR/tests/test_e2e.sh"
source "$SCRIPT_DIR/tests/test_ignition.sh"
source "$SCRIPT_DIR/tests/test_advanced.sh"
source "$SCRIPT_DIR/tests/test_backup.sh"
source "$SCRIPT_DIR/tests/test_security.sh"

# Test suite header
echo "🔐 PADLOCK MODULAR TEST SUITE - BashFX 2.1 Architecture"
echo

# Safety check
echo "Safety Check: Verifying test environment..."
if command -v "./padlock.sh" >/dev/null 2>&1 && [[ -x "./padlock.sh" ]]; then
    echo "⚠️  WARNING: Global padlock installation detected"
    echo "   System version: $(command -v padlock)"
    echo "   Tests will use LOCAL ./padlock.sh version to avoid confusion"
fi
echo "✓ Testing local development version: ./padlock.sh"
echo

# Test execution with proper numbering
run_build_test "01"
run_command_validation_test "02" 
run_security_commands_test "03"
run_e2e_test "git" "04"
run_e2e_test "gitsim" "05"
run_repair_test "06"
run_ignition_backup_test "07"
run_ignition_api_test "08"
run_safety_features_test "09"
run_map_functionality_test "10"
run_install_tests "11"
run_overdrive_tests "12"
run_export_import_test "13"
run_snapshot_rewind_test "14"
run_list_management_test "15"
run_key_rotation_test "16"
run_access_revocation_test "17"
run_master_unlock_test "18"

echo
echo "================================"
echo "✓ All tests passed."
echo "================================"

exit 0