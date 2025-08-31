#!/bin/bash
# Method 1: script command with different variations

echo "=== Method 1: script command variations ==="

passphrase="test123"

# Test 1a: Basic script with /dev/null
echo "Test 1a: script -qec with /dev/null"
mkfifo pipe1a
(printf '%s\n%s\n' "$passphrase" "$passphrase" > pipe1a &) 
timeout 5s script -qec "cat pipe1a | age -p -o output1a.age test_input.txt" /dev/null
echo "Exit code: $?"
rm -f pipe1a

# Test 1b: script with /dev/null and different flags
echo "Test 1b: script -qfec"
mkfifo pipe1b
(printf '%s\n%s\n' "$passphrase" "$passphrase" > pipe1b &)
timeout 5s script -qfec "cat pipe1b | age -p -o output1b.age test_input.txt" /dev/null
echo "Exit code: $?"
rm -f pipe1b

# Test 1c: script without /dev/null redirect
echo "Test 1c: script without /dev/null"
mkfifo pipe1c
(printf '%s\n%s\n' "$passphrase" "$passphrase" > pipe1c &)
timeout 5s script -qec "cat pipe1c | age -p -o output1c.age test_input.txt"
echo "Exit code: $?"
rm -f pipe1c

# Test 1d: Direct input to script
echo "Test 1d: Direct input to script"
timeout 5s script -qec "printf '%s\n%s\n' '$passphrase' '$passphrase' | age -p -o output1d.age test_input.txt" /dev/null
echo "Exit code: $?"

echo "Files created:"
ls -la output*.age 2>/dev/null || echo "No age files created"