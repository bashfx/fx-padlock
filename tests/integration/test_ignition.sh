#!/usr/bin/env bash
# test_ignition.sh - Ignition Key Management System Tests
# Tests: Key generation, storage architecture, metadata management (TASK-003)

# Get the project root directory (two levels up from test file)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/tests/lib/harness.sh"

run_ignition_storage_test() {
    local test_num="$1"
    
    test_box "Ignition Storage Architecture" "$test_num"
    echo "│ Testing key generation, storage system, and metadata..."
    echo "│"
    
    # Set up isolated test environment
    local test_dir
    test_dir=$(setup_test_environment)
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/padlock.sh" .
    git init > /dev/null 2>&1
    git config user.name "Test User" > /dev/null 2>&1
    git config user.email "test@example.com" > /dev/null 2>&1
    
    echo "│ → Testing initial state (no ignition system)..."
    if ./padlock.sh ignite list 2>/dev/null | grep -q "No ignition system configured"; then
        echo "│ ✓ Initial state: No ignition system configured"
    else
        echo "│ ✗ Unexpected initial state"
        return 1
    fi
    
    echo "│ → Testing master key creation..."
    if ./padlock.sh ignite create test-master --phrase="test123" > /dev/null 2>&1; then
        echo "│ ✓ Master key creation successful"
    else
        echo "│ ✗ Master key creation failed"
        return 1
    fi
    
    echo "│ → Validating storage directory structure..."
    if [[ -d ".padlock/ignition/keys" ]] && [[ -d ".padlock/ignition/metadata" ]]; then
        echo "│ ✓ Storage directories created"
    else
        echo "│ ✗ Missing storage directories"
        return 1
    fi
    
    echo "│ → Validating key files..."
    if [[ -f ".padlock/ignition/keys/test-master.ikey" ]] && [[ -f ".padlock/ignition/metadata/test-master.json" ]]; then
        echo "│ ✓ Key and metadata files created"
    else
        echo "│ ✗ Missing key or metadata files"
        return 1
    fi
    
    echo "│ → Testing key listing functionality..."
    if ./padlock.sh ignite list 2>/dev/null | grep -q "test-master.*active"; then
        echo "│ ✓ Key listing shows created master key"
    else
        echo "│ ✗ Key listing not working correctly"
        return 1
    fi
    
    echo "│ → Testing distributed key creation..."
    if ./padlock.sh ignite new --name=test-distro --phrase="distro123" > /dev/null 2>&1; then
        echo "│ ✓ Distributed key creation successful"
    else
        echo "│ ✗ Distributed key creation failed"
        return 1
    fi
    
    echo "│ → Validating dual key system..."
    local list_output
    list_output=$(./padlock.sh ignite list 2>/dev/null)
    if echo "$list_output" | grep -q "test-master" && echo "$list_output" | grep -q "test-distro"; then
        echo "│ ✓ Both master and distributed keys listed"
    else
        echo "│ ✗ Dual key listing not working"
        return 1
    fi
    
    test_end
}

run_ignition_api_test() {
    local test_num="$1"
    
    test_box "Ignition API Commands" "$test_num"
    echo "│ Testing enhanced ignition command API functionality..."
    echo "│"
    
    # Set up isolated test environment
    local test_dir
    test_dir=$(setup_test_environment)
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/padlock.sh" .
    git init > /dev/null 2>&1
    git config user.name "Test User" > /dev/null 2>&1
    git config user.email "test@example.com" > /dev/null 2>&1
    
    echo "│ → Testing ignition command routing..."
    
    # Test ignition status command works
    if ./padlock.sh ignite status > /dev/null 2>&1; then
        echo "│ ✓ Ignition status command accessible"
    else
        echo "│ ✗ Ignition status command failed"
        return 1
    fi
    
    echo "│ → Testing ignition help availability..."
    if ./padlock.sh ignite help 2>&1 | grep -q "create\|new\|unlock"; then
        echo "│ ✓ Ignition help shows enhanced commands"
    else
        echo "│ ✗ Ignition help not showing enhanced commands"
        return 1
    fi
    
    echo "│ → Testing command validation..."
    if ./padlock.sh ignite invalid-command 2>&1 | grep -q "Unknown ignite action"; then
        echo "│ ✓ Command validation working"
    else
        echo "│ ✗ Command validation not working"
        return 1
    fi
    
    test_end
}

run_ignition_security_test() {
    local test_num="$1"
    
    test_box "Ignition Key Security" "$test_num"
    echo "│ Testing key security, age format, and duplicate prevention..."
    echo "│"
    
    # Set up isolated test environment  
    local test_dir
    test_dir=$(setup_test_environment)
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/padlock.sh" .
    git init > /dev/null 2>&1
    git config user.name "Test User" > /dev/null 2>&1
    git config user.email "test@example.com" > /dev/null 2>&1
    
    echo "│ → Creating test key for security validation..."
    if ! ./padlock.sh ignite create security-test --phrase="secure123" > /dev/null 2>&1; then
        echo "│ ✗ Test key creation failed"
        return 1
    fi
    
    echo "│ → Testing age key format validation..."
    local key_file=".padlock/ignition/keys/security-test.ikey"
    if [[ -f "$key_file" ]] && grep -q "AGE-SECRET-KEY" "$key_file"; then
        echo "│ ✓ Key file contains valid age secret key format"
    else
        echo "│ ✗ Invalid age key format"
        return 1
    fi
    
    echo "│ → Testing public key extraction..."
    if age-keygen -y < "$key_file" > /dev/null 2>&1; then
        echo "│ ✓ Public key extraction successful"
    else
        echo "│ ✗ Cannot extract public key"
        return 1
    fi
    
    echo "│ → Testing duplicate key prevention..."
    if ./padlock.sh ignite create security-test --phrase="different456" 2>&1 | grep -q "already exists"; then
        echo "│ ✓ Duplicate key prevention working"
    else
        echo "│ ✗ Duplicate key prevention not working"
        return 1
    fi
    
    echo "│ → Testing metadata fingerprint..."
    local metadata=".padlock/ignition/metadata/security-test.json"
    if [[ -f "$metadata" ]]; then
        if grep -q '"fingerprint"' "$metadata"; then
            echo "│ ✓ Metadata contains fingerprint"
        else
            echo "│ ✗ Missing fingerprint in metadata"
            return 1
        fi
    else
        echo "│ ✗ Metadata file not found"
        return 1
    fi
    
    test_end
}

# Run all tests using standard test runner pattern from harness
test_runner() {
    echo "Enhanced Ignition Testing Suite - TASK-003 Implementation"
    echo "Testing key storage architecture and enhanced API functionality"
    
    run_ignition_storage_test 1
    run_ignition_api_test 2
    run_ignition_security_test 3
}

# Execute tests
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    test_runner
fi