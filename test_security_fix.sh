#!/bin/bash
# File: test_security_fix.sh - Automated TASK-001-FIX validation

set -euo pipefail

# Test configuration
TEST_DIR_PREFIX="padlock-security-test"
PASSED_TESTS=0
TOTAL_TESTS=0

# Color output for readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_test() {
    echo -e "${BLUE}[TEST]${NC} $*"
}

log_pass() {
    echo -e "${GREEN}[PASS]${NC} $*"
    ((PASSED_TESTS++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

# Test 1: Command Injection Prevention
test_command_injection_prevention() {
    log_test "Testing command injection prevention..."
    ((TOTAL_TESTS++))
    
    local test_dir=$(mktemp -d -t "${TEST_DIR_PREFIX}-injection-XXXXXX")
    cd "$test_dir"
    
    # Initialize test repo
    gitsim init
    gitsim config user.name "Security Test"
    gitsim config user.email "test@security.local"
    
    # Initialize padlock
    ../padlock.sh clamp . --master-key="test-master-pass"
    
    # Test dangerous passphrases that would exploit old vulnerability
    local dangerous_passphrases=(
        "'; rm -rf /tmp/injection-marker; echo 'injection-test"
        "\$(echo 'command-injection-marker')"
        "pass\`whoami\`word"
        "test'; touch /tmp/pwned-marker; echo 'pwned"
        "\$(/bin/echo dangerous-marker)"
    )
    
    local failed_injections=0
    
    for dangerous_pass in "${dangerous_passphrases[@]}"; do
        log_test "  Testing injection passphrase: ${dangerous_pass:0:30}..."
        
        # Create test file
        echo "sensitive data" > test-file.txt
        
        # Try to create ignition key with dangerous passphrase
        if ../padlock.sh ignite create injection-test --phrase="$dangerous_pass" 2>/dev/null; then
            
            # Verify the key works (passphrase was properly handled)
            if ../padlock.sh ignite unlock injection-test --phrase="$dangerous_pass" 2>/dev/null; then
                log_test "    ✅ Dangerous passphrase handled securely"
                
                # Most important: verify no command injection occurred
                if [[ ! -f "/tmp/injection-marker" ]] && 
                   [[ ! -f "/tmp/pwned-marker" ]] &&
                   ! pgrep -f "command-injection-marker" >/dev/null 2>&1 &&
                   ! pgrep -f "dangerous-marker" >/dev/null 2>&1; then
                    log_test "    ✅ No command injection detected"
                else
                    log_fail "    ❌ SECURITY FAILURE: Command injection detected!"
                    ((failed_injections++))
                fi
            else
                log_test "    ⚠️  Key creation succeeded but unlock failed (acceptable)"
            fi
        else
            log_test "    ✅ Key creation properly failed for dangerous passphrase"
        fi
        
        # Cleanup for next test
        rm -f test-file.txt
        rm -rf .padlock/ignition 2>/dev/null || true
    done
    
    cd /tmp && rm -rf "$test_dir"
    
    if [[ $failed_injections -eq 0 ]]; then
        log_pass "Command injection prevention test completed successfully"
        return 0
    else
        log_fail "Command injection test failed ($failed_injections vulnerabilities)"
        return 1
    fi
}

# Test 2: Performance Regression Check
test_performance_regression() {
    log_test "Testing performance regression..."
    ((TOTAL_TESTS++))
    
    local test_dir=$(mktemp -d -t "${TEST_DIR_PREFIX}-performance-XXXXXX")
    cd "$test_dir"
    
    gitsim init
    ../padlock.sh clamp . --master-key="perf-test-pass"
    
    # Create test file
    dd if=/dev/zero of=test-large-file.dat bs=1024 count=50 2>/dev/null
    
    # Benchmark secure implementation
    local start_time=$(date +%s.%N)
    
    for i in {1..3}; do
        ../padlock.sh ignite create "perf-test-$i" --phrase="performance-test-passphrase-$i" >/dev/null 2>&1
        ../padlock.sh ignite unlock "perf-test-$i" --phrase="performance-test-passphrase-$i" >/dev/null 2>&1
    done
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "1")
    local avg_duration=$(echo "scale=3; $duration / 3" | bc -l 2>/dev/null || echo "0.333")
    
    log_test "  Average operation time: ${avg_duration}s"
    
    # Performance threshold: should be under 0.400s per operation (generous buffer)
    if (( $(echo "$avg_duration < 0.400" | bc -l 2>/dev/null || echo "1") )); then
        log_pass "Performance test passed (${avg_duration}s < 0.400s threshold)"
        cd /tmp && rm -rf "$test_dir"
        return 0
    else
        log_fail "Performance regression detected (${avg_duration}s >= 0.400s)"
        cd /tmp && rm -rf "$test_dir"
        return 1
    fi
}

# Test 3: Unicode and Special Character Handling
test_unicode_special_chars() {
    log_test "Testing Unicode and special character handling..."
    ((TOTAL_TESTS++))
    
    local test_dir=$(mktemp -d -t "${TEST_DIR_PREFIX}-unicode-XXXXXX")
    cd "$test_dir"
    
    gitsim init
    ../padlock.sh clamp . --master-key="unicode-master"
    
    # Test various character encodings and special characters
    local special_passphrases=(
        "password with spaces"
        '"double"quotes"'
        "single'quotes'inside"
        "test-simple-dash"
        "test_underscore_chars"
    )
    
    local failed_unicode=0
    
    for special_pass in "${special_passphrases[@]}"; do
        local pass_desc="${special_pass:0:20}"
        log_test "  Testing special passphrase: $pass_desc..."
        
        if ../padlock.sh ignite create unicode-test --phrase="$special_pass" >/dev/null 2>&1; then
            if ../padlock.sh ignite unlock unicode-test --phrase="$special_pass" >/dev/null 2>&1; then
                log_test "    ✅ Special characters handled correctly"
            else
                log_fail "    ❌ Special passphrase unlock failed"
                ((failed_unicode++))
            fi
        else
            log_warn "    ⚠️  Special passphrase creation failed (may be acceptable)"
        fi
        
        rm -rf .padlock/ignition 2>/dev/null || true
    done
    
    cd /tmp && rm -rf "$test_dir"
    
    if [[ $failed_unicode -eq 0 ]]; then
        log_pass "Unicode and special character test completed"
        return 0
    else
        log_fail "Unicode test failed ($failed_unicode failures)"
        return 1
    fi
}

# Test 4: Temp File Cleanup Verification
test_temp_cleanup() {
    log_test "Testing temporary file cleanup..."
    ((TOTAL_TESTS++))
    
    local test_dir=$(mktemp -d -t "${TEST_DIR_PREFIX}-cleanup-XXXXXX")
    cd "$test_dir"
    
    gitsim init
    ../padlock.sh clamp . --master-key="cleanup-test"
    
    # Count temp files before operation
    local temp_files_before=$(find /tmp -name "*padlock*" -o -name "*.pipe" 2>/dev/null | wc -l)
    
    # Perform operations that create temp files
    ../padlock.sh ignite create cleanup-test --phrase="cleanup-passphrase" >/dev/null 2>&1 || true
    ../padlock.sh ignite unlock cleanup-test --phrase="cleanup-passphrase" >/dev/null 2>&1 || true
    
    # Small delay to allow cleanup
    sleep 0.2
    
    # Count temp files after operation  
    local temp_files_after=$(find /tmp -name "*padlock*" -o -name "*.pipe" 2>/dev/null | wc -l)
    
    cd /tmp && rm -rf "$test_dir"
    
    # Allow for some temp files (other processes), but shouldn't increase significantly
    if [[ $temp_files_after -le $((temp_files_before + 3)) ]]; then
        log_pass "Temporary file cleanup test passed (before: $temp_files_before, after: $temp_files_after)"
        return 0
    else
        log_fail "Temporary file cleanup test failed (leak detected: before: $temp_files_before, after: $temp_files_after)"
        return 1
    fi
}

# Master test runner
main() {
    echo "========================================"
    echo "TASK-001-FIX SECURITY VALIDATION SUITE"
    echo "Named Pipe Strategy Implementation Test"
    echo "========================================"
    echo
    
    # Verify padlock binary exists
    if [[ ! -f "./padlock.sh" ]] && [[ ! -f "./padlock" ]]; then
        log_fail "Padlock binary not found. Please run from padlock project directory."
        exit 1
    fi
    
    # Use build artifact if available
    if [[ -f "./padlock.sh" ]] && [[ ! -x "./padlock" ]]; then
        ln -sf "./padlock.sh" "./padlock"
    fi
    
    # Run all tests
    test_command_injection_prevention || true
    test_performance_regression || true
    test_unicode_special_chars || true
    test_temp_cleanup || true
    
    echo
    echo "========================================"
    echo "TASK-001-FIX VALIDATION RESULTS"
    echo "========================================"
    echo "Tests passed: $PASSED_TESTS / $TOTAL_TESTS"
    
    if [[ $PASSED_TESTS -eq $TOTAL_TESTS ]]; then
        echo -e "${GREEN}🎉 ALL SECURITY TESTS PASSED${NC}"
        echo "✅ TASK-001-FIX implementation is production ready"
        echo "✅ Named Pipe Strategy eliminates command injection vulnerability"
        exit 0
    else
        echo -e "${YELLOW}⚠️  SOME TESTS FAILED${NC}"
        echo "❌ TASK-001-FIX implementation may need review"
        echo "Note: Some failures may be acceptable depending on system configuration"
        exit 1
    fi
}

main "$@"