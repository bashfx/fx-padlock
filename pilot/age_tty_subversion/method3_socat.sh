#!/bin/bash
# Method 3: socat and pty manipulation

echo "=== Method 3: socat/pty approaches ==="

passphrase="test123"

# Check if socat is available
if command -v socat >/dev/null 2>&1; then
    echo "Test 3a: socat with pty"
    
    # Create a pty pair and try to feed age through it
    timeout 10s socat -u EXEC:"printf '%s\n%s\n' '$passphrase' '$passphrase'" EXEC:"age -p -o output3a.age test_input.txt",pty,raw,echo=0
    echo "Exit code: $?"
    
    echo "Test 3b: socat different approach"
    timeout 10s socat PTY,link=/tmp/ttyage,raw,echo=0 EXEC:"age -p -o output3b.age test_input.txt" &
    socat_pid=$!
    sleep 1
    if [[ -e /tmp/ttyage ]]; then
        printf '%s\n%s\n' "$passphrase" "$passphrase" > /tmp/ttyage &
        wait $socat_pid
        echo "Exit code: $?"
        rm -f /tmp/ttyage
    else
        echo "PTY not created"
        kill $socat_pid 2>/dev/null
    fi
else
    echo "Test 3a-3b: socat not available"
fi

# Check if we have access to /dev/ptmx for manual pty creation
if [[ -e /dev/ptmx ]]; then
    echo "Test 3c: /dev/ptmx available for manual pty creation"
else
    echo "Test 3c: /dev/ptmx not available"
fi

echo "Files created:"
ls -la output*.age 2>/dev/null || echo "No age files created"