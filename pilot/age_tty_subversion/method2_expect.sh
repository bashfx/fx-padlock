#!/bin/bash
# Method 2: expect and unbuffer approaches

echo "=== Method 2: expect/unbuffer approaches ==="

passphrase="test123"

# Check if expect is available
if command -v expect >/dev/null 2>&1; then
    echo "Test 2a: expect script"
    
    cat > temp_expect.exp << 'EOF'
#!/usr/bin/expect -f
set timeout 10
set passphrase [lindex $argv 0]
spawn age -p -o output2a.age test_input.txt
expect "Enter passphrase*"
send "$passphrase\r"
expect "Confirm passphrase*"
send "$passphrase\r"
expect eof
EOF
    
    chmod +x temp_expect.exp
    timeout 10s ./temp_expect.exp "$passphrase"
    echo "Exit code: $?"
    rm -f temp_expect.exp
else
    echo "Test 2a: expect not available"
fi

# Check if unbuffer is available 
if command -v unbuffer >/dev/null 2>&1; then
    echo "Test 2b: unbuffer"
    timeout 5s unbuffer bash -c "printf '%s\n%s\n' '$passphrase' '$passphrase' | age -p -o output2b.age test_input.txt"
    echo "Exit code: $?"
else
    echo "Test 2b: unbuffer not available"
fi

# Check for other expect-like tools
if command -v autoexpect >/dev/null 2>&1; then
    echo "Test 2c: autoexpect available"
else
    echo "Test 2c: autoexpect not available"
fi

echo "Files created:"
ls -la output*.age 2>/dev/null || echo "No age files created"