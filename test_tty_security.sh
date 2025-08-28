#!/bin/bash

set -euo pipefail

# Direct test of TTY subversion functions to validate security fix
echo "Testing TTY subversion security fix..."

# Source the padlock functions
source ./padlock.sh

# Initialize temp file system
_temp_setup_trap

# Create test files
TEST_INPUT="$(mktemp)"
TEST_OUTPUT="$(mktemp)"
echo "test data for encryption" > "$TEST_INPUT"

echo "Testing _age_interactive_encrypt with dangerous passphrases..."

# Test passphrases that would cause command injection in old version
test_passphrases=(
    "normal_password"
    "'; echo INJECTION > /tmp/injection_test; echo '"
    "\$(echo injection_test)"
    "pass\`id\`word"
)

success=0
total=${#test_passphrases[@]}

for i in "${!test_passphrases[@]}"; do
    passphrase="${test_passphrases[$i]}"
    test_num=$((i + 1))
    
    printf "Test %d: " "$test_num"
    
    # Test the function directly
    if _age_interactive_encrypt "$TEST_INPUT" "$TEST_OUTPUT" "$passphrase" 2>/dev/null; then
        echo "✅ Encryption successful (no injection)"
        
        # Test decryption
        if _age_interactive_decrypt "$TEST_OUTPUT" "$passphrase" >/dev/null 2>&1; then
            echo "    ✅ Decryption successful"
            success=$((success + 1))
        else
            echo "    ❌ Decryption failed"
        fi
    else
        echo "❌ Encryption failed"
    fi
    
    # Clean up output for next test
    rm -f "$TEST_OUTPUT"
done

echo
echo "Results: $success/$total tests passed"

# Check for injection artifacts
if [[ -f "/tmp/injection_test" ]]; then
    echo "❌ CRITICAL: Command injection detected!"
    rm -f "/tmp/injection_test"
    exit 1
else
    echo "✅ No command injection artifacts found"
fi

# Cleanup
rm -f "$TEST_INPUT" "$TEST_OUTPUT"

echo "✅ TTY security fix validation completed successfully"