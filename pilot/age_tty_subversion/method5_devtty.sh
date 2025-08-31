#!/bin/bash
# Method 5: /dev/tty manipulation and creative approaches

echo "=== Method 5: /dev/tty manipulation ==="

passphrase="test123"

# Test 5a: Create a fake /dev/tty
echo "Test 5a: Create fake /dev/tty with named pipe"
mkdir -p fakedev
mkfifo fakedev/tty
(printf '%s\n%s\n' "$passphrase" "$passphrase" > fakedev/tty &)

# Run age with modified PATH to find our fake /dev/tty  
timeout 5s env PATH="$(pwd)/fakedev:$PATH" age -p -o output5a.age test_input.txt < fakedev/tty 2>/dev/null
echo "Exit code: $?"
rm -rf fakedev

# Test 5b: Use script with a pty and redirect /dev/tty
echo "Test 5b: script with pty redirection"
if command -v script >/dev/null; then
    # Create script that redirects /dev/tty to our input
    cat > temp_script.sh << 'EOF'
#!/bin/bash
exec 1>/dev/null 2>/dev/null
printf '%s\n%s\n' "$1" "$1" | age -p -o output5b.age test_input.txt
EOF
    chmod +x temp_script.sh
    
    timeout 10s script -qec "./temp_script.sh '$passphrase'" /dev/null 2>/dev/null
    echo "Exit code: $?"
    rm -f temp_script.sh
fi

# Test 5c: Mount bind a pipe to /dev/tty (requires root, probably won't work)
echo "Test 5c: Check if we can manipulate /dev/tty"
if [[ -w /dev ]]; then
    echo "/dev is writable - could potentially create /dev/tty"
else
    echo "/dev is not writable - cannot create /dev/tty"
fi

# Test 5d: Use chroot/namespace to create our own /dev/tty
echo "Test 5d: Check for namespace/container capabilities"
if command -v unshare >/dev/null 2>&1; then
    echo "unshare available - could try namespace approach"
    # This would need root privileges typically
else
    echo "unshare not available"
fi

echo "Files created:"
ls -la output*.age 2>/dev/null || echo "No age files created"