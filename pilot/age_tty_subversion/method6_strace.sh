#!/bin/bash
# Method 6: Understanding age behavior with strace and alternative binaries

echo "=== Method 6: Deep analysis and alternatives ==="

passphrase="test123"

# Test 6a: Use strace to understand exactly what age is doing
echo "Test 6a: Analyze age behavior with strace"
if command -v strace >/dev/null 2>&1; then
    echo "Running strace on age to see system calls..."
    timeout 3s strace -e trace=openat,read,write -o age_trace.log age -p -o output6a.age test_input.txt 2>/dev/null &
    strace_pid=$!
    sleep 1
    kill $strace_pid 2>/dev/null
    wait $strace_pid 2>/dev/null
    
    if [[ -f age_trace.log ]]; then
        echo "Strace output (tty-related calls):"
        grep -i tty age_trace.log || echo "No tty calls found"
        grep -i "openat" age_trace.log | head -5
        rm -f age_trace.log
    fi
else
    echo "strace not available"
fi

# Test 6b: Check if there are alternative age implementations
echo "Test 6b: Check for alternative age implementations"
which -a age 2>/dev/null || echo "Only one age binary found"

# Test 6c: Check age source/build info
echo "Test 6c: Age version and build information"
age --version 2>&1

# Test 6d: Look for age configuration files or environment variables
echo "Test 6d: Age environment variables and config"
env | grep -i age || echo "No AGE environment variables"

# Test 6e: Try RAGE (Rust implementation of age) if available
echo "Test 6e: Check for RAGE (Rust age implementation)"
if command -v rage >/dev/null 2>&1; then
    echo "RAGE found, testing passphrase mode:"
    timeout 5s rage -p -o output6e.age test_input.txt < <(printf '%s\n%s\n' "$passphrase" "$passphrase") 2>/dev/null
    echo "RAGE exit code: $?"
else
    echo "RAGE not available"
fi

echo "Files created:"
ls -la output*.age 2>/dev/null || echo "No age files created"