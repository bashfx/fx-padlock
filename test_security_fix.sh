#!/bin/bash
################################################################################
# Security Test Suite for Age TTY Subversion Functions
# Tests for command injection vulnerability fixes in TASK-001-FIX
################################################################################

set -euo pipefail

# Test configuration
TEST_DIR="$(mktemp -d)"
TEMP_FILES=()
TESTS_PASSED=0
TESTS_FAILED=0

# Cleanup function
cleanup() {
    echo "🧹 Cleaning up test files..."
    rm -rf "$TEST_DIR" 2>/dev/null || true
    for file in "${TEMP_FILES[@]}"; do
        rm -f "$file" 2>/dev/null || true
    done
}
trap cleanup EXIT

# Load the required parts in order
source parts/02_config.sh
source parts/03_stderr.sh  
source parts/04_helpers.sh

# Initialize options for the loaded functions
opt_trace=1    # Enable tracing for debugging
opt_quiet=0
opt_debug=0

# Set up temp file cleanup
_temp_setup_trap

# Test helper functions
ok() { 
    echo "✅ $1"
    ((TESTS_PASSED++))
}

fail() { 
    echo "❌ $1"
    ((TESTS_FAILED++))
}

info() {
    echo "🔍 $1"
}

# Create test files
TEST_INPUT="$TEST_DIR/test.txt"
TEST_OUTPUT="$TEST_DIR/test.age"
echo "Hello, secure world!" > "$TEST_INPUT"

# Test 1: Normal passphrase operation
info "Test 1: Normal passphrase operation"
normal_pass="simple123password"
if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT" "$normal_pass" 2>/dev/null; then
    # Verify decryption works
    decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT" "$normal_pass" 2>/dev/null)"
    if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
        ok "Normal passphrase encrypt/decrypt works"
    else
        fail "Normal passphrase decryption failed"
    fi
else
    fail "Normal passphrase encryption failed"
fi

# Test 2: Passphrase with single quotes
info "Test 2: Passphrase with single quotes"
quote_pass="pass'with'quotes"
TEST_OUTPUT2="$TEST_DIR/test2.age"
if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT2" "$quote_pass" 2>/dev/null; then
    decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT2" "$quote_pass" 2>/dev/null)"
    if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
        ok "Single quotes in passphrase handled safely"
    else
        fail "Single quotes passphrase decryption failed"
    fi
else
    fail "Single quotes passphrase encryption failed"
fi

# Test 3: Passphrase with double quotes  
info "Test 3: Passphrase with double quotes"
dquote_pass='pass"with"double"quotes'
TEST_OUTPUT3="$TEST_DIR/test3.age"
if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT3" "$dquote_pass" 2>/dev/null; then
    decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT3" "$dquote_pass" 2>/dev/null)"
    if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
        ok "Double quotes in passphrase handled safely"
    else
        fail "Double quotes passphrase decryption failed"
    fi
else
    fail "Double quotes passphrase encryption failed"
fi

# Test 4: Passphrase with shell variables ($USER)
info "Test 4: Passphrase with shell variables (\$USER)"
var_pass="password\$USER\$HOME"
TEST_OUTPUT4="$TEST_DIR/test4.age"
if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT4" "$var_pass" 2>/dev/null; then
    # Verify the literal string was used, not variable expansion
    decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT4" "$var_pass" 2>/dev/null)"
    if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
        ok "Shell variables in passphrase handled as literals (not expanded)"
    else
        fail "Shell variables passphrase test failed"
    fi
else
    fail "Shell variables passphrase encryption failed"
fi

# Test 5: Passphrase with command substitution $(whoami)
info "Test 5: Passphrase with command substitution \$(whoami)"
cmd_pass="pass\$(whoami)word"
TEST_OUTPUT5="$TEST_DIR/test5.age"
if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT5" "$cmd_pass" 2>/dev/null; then
    # Verify the literal string was used, not command substitution
    decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT5" "$cmd_pass" 2>/dev/null)"
    if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
        ok "Command substitution in passphrase handled as literal (not executed)"
    else
        fail "Command substitution passphrase test failed"  
    fi
else
    fail "Command substitution passphrase encryption failed"
fi

# Test 6: Passphrase with command injection attempt
info "Test 6: Passphrase with command injection attempt"
injection_pass="'; rm -rf /tmp/security_test_marker; echo '"
TEST_OUTPUT6="$TEST_DIR/test6.age"

# Create marker file to test if command injection occurs
MARKER_FILE="/tmp/security_test_marker_$$"
touch "$MARKER_FILE"
TEMP_FILES+=("$MARKER_FILE")

if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT6" "$injection_pass" 2>/dev/null; then
    # Check if marker file still exists (command injection would have deleted it)
    if [[ -f "$MARKER_FILE" ]]; then
        ok "Command injection attempt blocked - marker file still exists"
        
        # Verify decryption with exact malicious string
        decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT6" "$injection_pass" 2>/dev/null)"
        if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
            ok "Command injection passphrase handled as literal string"
        else
            fail "Command injection passphrase decryption failed"
        fi
    else
        fail "CRITICAL SECURITY ISSUE: Command injection vulnerability still exists!"
    fi
else
    # If encryption fails, that's also acceptable (secure failure)
    if [[ -f "$MARKER_FILE" ]]; then
        ok "Command injection attempt blocked - encryption failed safely"
    else
        fail "CRITICAL: Command injection executed during failed encryption!"
    fi
fi

# Test 7: Complex mixed dangerous passphrase
info "Test 7: Complex mixed dangerous passphrase"
complex_pass='evil"; rm -rf /tmp/*; $(echo "pwned"); $USER'\''more evil'
TEST_OUTPUT7="$TEST_DIR/test7.age"

# Create another marker to test
MARKER_FILE2="/tmp/security_test_marker2_$$"
touch "$MARKER_FILE2"
TEMP_FILES+=("$MARKER_FILE2")

if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT7" "$complex_pass" 2>/dev/null; then
    if [[ -f "$MARKER_FILE2" ]]; then
        ok "Complex dangerous passphrase handled safely"
        
        # Test decryption
        decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT7" "$complex_pass" 2>/dev/null)"
        if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
            ok "Complex dangerous passphrase decryption works"
        else
            fail "Complex dangerous passphrase decryption failed"
        fi
    else
        fail "CRITICAL: Complex command injection succeeded!"
    fi
else
    # Acceptable failure mode
    if [[ -f "$MARKER_FILE2" ]]; then
        ok "Complex dangerous passphrase rejected safely"  
    else
        fail "CRITICAL: Command injection during complex passphrase failure!"
    fi
fi

# Test 8: Unicode and special characters
info "Test 8: Unicode and special characters"
unicode_pass="påss🔒wørd-测试"
TEST_OUTPUT8="$TEST_DIR/test8.age"
if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT8" "$unicode_pass" 2>/dev/null; then
    decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT8" "$unicode_pass" 2>/dev/null)"
    if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
        ok "Unicode characters in passphrase work correctly"
    else
        fail "Unicode passphrase decryption failed"
    fi
else
    fail "Unicode passphrase encryption failed"
fi

# Test 9: Very long passphrase (DoS protection)  
info "Test 9: Very long passphrase (DoS protection)"
long_pass=$(printf 'a%.0s' {1..1000})  # 1000 character passphrase
TEST_OUTPUT9="$TEST_DIR/test9.age"
if timeout 30s _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT9" "$long_pass" 2>/dev/null; then
    if timeout 30s bash -c "decrypted_output=\$(_age_interactive_decrypt '$TEST_OUTPUT9' '$long_pass' 2>/dev/null); [[ \"\$decrypted_output\" == \"Hello, secure world!\" ]]"; then
        ok "Very long passphrase handled within timeout"
    else
        fail "Very long passphrase decryption failed"
    fi
else
    fail "Very long passphrase encryption timed out (potential DoS vulnerability)"
fi

# Test 10: Empty passphrase edge case
info "Test 10: Empty passphrase edge case"
empty_pass=""
TEST_OUTPUT10="$TEST_DIR/test10.age"
if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT10" "$empty_pass" 2>/dev/null; then
    decrypted_output="$(_age_interactive_decrypt "$TEST_OUTPUT10" "$empty_pass" 2>/dev/null)"
    if [[ "$decrypted_output" == "Hello, secure world!" ]]; then
        ok "Empty passphrase handled correctly"
    else
        fail "Empty passphrase decryption failed"
    fi  
else
    ok "Empty passphrase rejected (acceptable security behavior)"
fi

# Results summary
echo ""
echo "=================================="
echo "🔒 SECURITY TEST RESULTS"
echo "=================================="
echo "✅ Tests passed: $TESTS_PASSED"
echo "❌ Tests failed: $TESTS_FAILED"
echo "📊 Total tests:  $((TESTS_PASSED + TESTS_FAILED))"

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo ""
    echo "🎉 ALL SECURITY TESTS PASSED!"
    echo "✓ Command injection vulnerability has been successfully patched"
    echo "✓ Age TTY subversion functions are secure"
    exit 0
else
    echo ""
    echo "🚨 SECURITY ISSUES DETECTED!"
    echo "❌ $TESTS_FAILED test(s) failed - security vulnerabilities may remain"
    echo "🔧 Please review and fix the failing test cases"
    exit 1
fi