#!/usr/bin/env bash
# test_ignition_storage.sh - Ignition Storage Architecture Tests (TASK-003)
# Tests: Key generation, storage system, metadata management, list functionality
# Architecture: gitsim virtualization + XDG+ temp compliance (BashFX Testing Alignment Protocol)
set -euo pipefail

# Get the project root directory (two levels up from test file)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/tests/lib/harness.sh"

# BashFX gitsim virtualization pattern with XDG+ temp compliance
setup_gitsim_test() {
    local test_name="$1"
    if command -v gitsim >/dev/null 2>&1 && gitsim home-init "$test_name" > /dev/null 2>&1; then
        local sim_home
        sim_home=$(gitsim home-path 2>/dev/null)
        export HOME="$sim_home" 
        export XDG_ETC_HOME="$sim_home/.local/etc"
        export XDG_CACHE_HOME="$sim_home/.cache"
        
        # BashFX XDG+ temp directory (preferred over /tmp)
        export TMPDIR="$sim_home/.cache/tmp"
        mkdir -p "$TMPDIR"
        
        cd "$sim_home"
        
        # Setup git environment for padlock
        git init > /dev/null 2>&1
        git config user.name "Test User" > /dev/null 2>&1
        git config user.email "test@example.com" > /dev/null 2>&1
        
        # Copy padlock for testing
        cp "$SCRIPT_DIR/padlock.sh" .
        
        echo "$sim_home"
        return 0
    else
        # Fallback still uses XDG+ temp
        export TMPDIR="${XDG_CACHE_HOME:-$HOME/.cache}/tmp"
        mkdir -p "$TMPDIR"
        
        local test_dir
        test_dir=$(mktemp -d -t ignition_storage_test.XXXXXX)
        cd "$test_dir"
        
        # Setup git environment
        git init > /dev/null 2>&1
        git config user.name "Test User" > /dev/null 2>&1
        git config user.email "test@example.com" > /dev/null 2>&1
        
        # Copy padlock for testing
        cp "$SCRIPT_DIR/padlock.sh" .
        
        echo "$test_dir"
        return 0
    fi
}

# BashFX Test Ceremony Template
run_ignition_storage_architecture_test() {
    local test_num="$1"
    
    # BashFX ceremony - Test header
    echo "🧪 TEST $test_num: Ignition Storage Architecture"
    echo "   Category: integration | Expected: 2-3 min"
    echo "   Testing: Key generation, storage system, metadata management"
    echo
    
    # Setup test environment with ceremony
    echo "   ∆ Setting up virtualized test environment..."
    local test_home
    test_home=$(setup_gitsim_test "ignition-storage-$test_num")
    if [[ -n "$test_home" ]]; then
        echo "   ✓ Test environment ready: $test_home"
    else
        echo "   ✗ INVALID - Environment setup failed"
        return 2
    fi
    
    echo "   ∆ Testing storage directory creation..."
    
    # Test initial state - no ignition system
    if ./padlock.sh ignite list 2>/dev/null | grep -q "No ignition system configured"; then
        echo "   ✓ Initial state: No ignition system configured"
    else
        echo "   ✗ FAIL - Unexpected initial state"
        return 1
    fi
    
    echo "   ∆ Creating ignition master key..."
    
    # Test master key creation with storage
    if ./padlock.sh ignite create test-master --phrase="test123" > /dev/null 2>&1; then
        echo "   ✓ Master key creation successful"
    else
        echo "   ✗ FAIL - Master key creation failed"
        return 1
    fi
    
    echo "   ∆ Validating storage architecture..."
    
    # Validate directory structure was created
    if [[ -d ".padlock/ignition/keys" ]] && [[ -d ".padlock/ignition/metadata" ]] && [[ -d ".padlock/ignition/.derived" ]]; then
        echo "   ✓ Directory structure created correctly"
    else
        echo "   ✗ FAIL - Missing storage directories"
        return 1
    fi
    
    # Validate key files were created
    if [[ -f ".padlock/ignition/keys/test-master.ikey" ]] && [[ -f ".padlock/ignition/metadata/test-master.json" ]]; then
        echo "   ✓ Key and metadata files created"
    else
        echo "   ✗ FAIL - Missing key or metadata files"
        return 1
    fi
    
    echo "   ∆ Testing key listing functionality..."
    
    # Test list functionality
    local list_output
    list_output=$(./padlock.sh ignite list 2>/dev/null)
    if echo "$list_output" | grep -q "test-master.*active" && echo "$list_output" | grep -q "2025-"; then
        echo "   ✓ Key listing shows created master key"
    else
        echo "   ✗ FAIL - Key listing not working correctly"
        return 1
    fi
    
    echo "   ∆ Creating distributed key..."
    
    # Test distributed key creation
    if ./padlock.sh ignite new --name=test-distro --phrase="distro123" > /dev/null 2>&1; then
        echo "   ✓ Distributed key creation successful"
    else
        echo "   ✗ FAIL - Distributed key creation failed"
        return 1
    fi
    
    echo "   ∆ Validating dual key system..."
    
    # Test both keys are listed
    local dual_output
    dual_output=$(./padlock.sh ignite list 2>/dev/null)
    if echo "$dual_output" | grep -q "test-master" && echo "$dual_output" | grep -q "test-distro"; then
        echo "   ✓ Both master and distributed keys listed"
    else
        echo "   ✗ FAIL - Dual key listing not working"
        return 1
    fi
    
    # Validate file extensions are correct
    if [[ -f ".padlock/ignition/keys/test-master.ikey" ]] && [[ -f ".padlock/ignition/keys/test-distro.dkey" ]]; then
        echo "   ✓ Correct file extensions: .ikey and .dkey"
    else
        echo "   ✗ FAIL - Incorrect file extensions"
        return 1
    fi
    
    echo "   ∆ Testing JSON metadata structure..."
    
    # Validate JSON metadata structure
    local metadata=".padlock/ignition/metadata/test-master.json"
    if [[ -f "$metadata" ]] && jq -e '.name and .type and .created and .fingerprint' "$metadata" > /dev/null 2>&1; then
        echo "   ✓ JSON metadata structure valid"
    else
        echo "   ✗ FAIL - Invalid JSON metadata structure"
        return 1
    fi
    
    echo "   ∆ Testing duplicate key prevention..."
    
    # Test duplicate prevention
    if ./padlock.sh ignite create test-master --phrase="test456" 2>&1 | grep -q "already exists"; then
        echo "   ✓ Duplicate key prevention working"
    else
        echo "   ✗ FAIL - Duplicate key prevention not working"
        return 1
    fi
    
    # BashFX ceremony - Summary
    echo
    echo "   📊 PASS - All ignition storage architecture tests passed"
    echo "   ✓ Directory structure: .padlock/ignition/{keys,metadata,.derived}"
    echo "   ✓ Key generation: Master (.ikey) and distributed (.dkey)"
    echo "   ✓ Metadata system: JSON with fingerprints and timestamps" 
    echo "   ✓ List functionality: Both key types displayed correctly"
    echo "   ✓ Safety features: Duplicate prevention working"
    echo "────────────────────────────────────────────────────────────"
    echo
    return 0
}

run_ignition_key_security_test() {
    local test_num="$1"
    
    echo "🧪 TEST $test_num: Ignition Key Security Validation"
    echo "   Category: integration | Expected: 1-2 min"
    echo "   Testing: Key format validation, age compatibility, fingerprints"
    echo
    
    echo "   ∆ Setting up security test environment..."
    local test_home
    test_home=$(setup_gitsim_test "ignition-security-$test_num")
    if [[ -n "$test_home" ]]; then
        echo "   ✓ Security test environment ready"
    else
        echo "   ✗ INVALID - Environment setup failed"
        return 2
    fi
    
    # Create a key for testing
    echo "   ∆ Creating test key for security validation..."
    ./padlock.sh ignite create security-test --phrase="secure123" > /dev/null 2>&1
    
    echo "   ∆ Validating age key format..."
    
    # Test that generated key is valid age format
    local key_file=".padlock/ignition/keys/security-test.ikey"
    if [[ -f "$key_file" ]] && grep -q "AGE-SECRET-KEY" "$key_file"; then
        echo "   ✓ Key file contains valid age secret key format"
    else
        echo "   ✗ FAIL - Invalid age key format"
        return 1
    fi
    
    echo "   ∆ Testing public key extraction..."
    
    # Test that public key can be extracted
    if age-keygen -y < "$key_file" > /dev/null 2>&1; then
        echo "   ✓ Public key extraction successful"
    else
        echo "   ✗ FAIL - Cannot extract public key"
        return 1
    fi
    
    echo "   ∆ Validating metadata fingerprint..."
    
    # Test fingerprint consistency
    local metadata=".padlock/ignition/metadata/security-test.json"
    if [[ -f "$metadata" ]]; then
        local stored_fingerprint
        stored_fingerprint=$(jq -r '.fingerprint' "$metadata")
        if [[ ${#stored_fingerprint} -eq 16 ]] && [[ "$stored_fingerprint" =~ ^[a-f0-9]+$ ]]; then
            echo "   ✓ Metadata fingerprint format valid (16 hex chars)"
        else
            echo "   ✗ FAIL - Invalid fingerprint format"
            return 1
        fi
    fi
    
    echo
    echo "   📊 PASS - Key security validation tests passed"
    echo "   ✓ Age format: Keys use proper AGE-SECRET-KEY format"
    echo "   ✓ Public key: Successfully extractable with age-keygen -y"
    echo "   ✓ Fingerprints: 16-character hex format for identification"
    echo "────────────────────────────────────────────────────────────"
    echo
    return 0
}

# Main test execution following BashFX Test Ceremony
main() {
    echo "🚀 Ignition Storage Architecture Test Suite"
    echo "═══════════════════════════════════════════════════════════════"
    echo "📋 Category: Integration tests for TASK-003 implementation"
    echo "📁 Architecture: BashFX gitsim virtualization + XDG+ temp"
    echo "⏱️  Expected Duration: 3-5 minutes"
    echo
    
    local start_time=$(date +%s)
    local tests_run=0
    local tests_passed=0
    local tests_failed=0
    
    # Test 1: Storage Architecture
    ((tests_run++))
    if run_ignition_storage_architecture_test 1; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # Test 2: Key Security  
    ((tests_run++))
    if run_ignition_key_security_test 2; then
        ((tests_passed++))
    else
        ((tests_failed++))
    fi
    
    # BashFX ceremony - Final summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "📊 FINAL TEST SUMMARY"
    echo "═════════════════════════════════════════════════════════════════"
    echo "   Tests Run: $tests_run"
    echo "   ✓ Passed: $tests_passed"
    if [[ $tests_failed -gt 0 ]]; then
        echo "   ✗ Failed: $tests_failed"
    fi
    echo "   ⏱️  Duration: ${duration}s"
    echo "   📍 Environment: $(if command -v gitsim >/dev/null; then echo "gitsim+XDG"; else echo "XDG-temp"; fi)"
    echo
    
    if [[ $tests_failed -eq 0 ]]; then
        echo "🎉 ALL IGNITION STORAGE TESTS PASSED!"
        echo "✅ TASK-003 implementation validated successfully"
        return 0
    else
        echo "💥 IGNITION STORAGE TESTS FAILED"
        return 1
    fi
}

# Execute main function
main "$@"