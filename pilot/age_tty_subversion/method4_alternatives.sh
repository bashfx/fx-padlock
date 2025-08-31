#!/bin/bash
# Method 4: Alternative age usage patterns and process substitution

echo "=== Method 4: Alternative approaches ==="

passphrase="test123"

# Test 4a: Process substitution
echo "Test 4a: Process substitution"
timeout 5s age -p -o output4a.age test_input.txt < <(printf '%s\n%s\n' "$passphrase" "$passphrase")
echo "Exit code: $?"

# Test 4b: Heredoc
echo "Test 4b: Heredoc"
timeout 5s age -p -o output4b.age test_input.txt << EOF
$passphrase
$passphrase
EOF
echo "Exit code: $?"

# Test 4c: File descriptor manipulation
echo "Test 4c: File descriptor manipulation"
exec 3< <(printf '%s\n%s\n' "$passphrase" "$passphrase")
timeout 5s age -p -o output4c.age test_input.txt <&3
echo "Exit code: $?"
exec 3<&-

# Test 4d: Using age-keygen instead
echo "Test 4d: Generate age key and use it instead"
if age-keygen -o temp.key 2>/dev/null; then
    echo "Generated age key, testing with key instead of passphrase"
    age -e -i temp.key -o output4d.age test_input.txt
    echo "Encryption exit code: $?"
    
    age -d -i temp.key output4d.age > decrypted4d.txt 2>/dev/null
    echo "Decryption exit code: $?"
    
    if cmp -s test_input.txt decrypted4d.txt; then
        echo "SUCCESS: Key-based encryption/decryption works"
    else
        echo "FAILED: Key-based approach failed"
    fi
    rm -f temp.key decrypted4d.txt
else
    echo "age-keygen failed"
fi

# Test 4e: Check age version and capabilities
echo "Test 4e: Age version and help"
age --version 2>&1 | head -1
echo "Age help on passphrase:"
age --help 2>&1 | grep -i pass || echo "No passphrase help found"

echo "Files created:"
ls -la output*.age 2>/dev/null || echo "No age files created"