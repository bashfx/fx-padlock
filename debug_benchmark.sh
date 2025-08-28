#!/bin/bash

# Debug benchmark script 
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR"

# Source the pilot.sh functions
source pilot.sh

echo "=== Debug Benchmark Test ==="
echo

# Setup pilot directory
setup_pilot

echo "1. Testing timer functions..."
timer_start
sleep 0.1
time_result=$(timer_stop)
echo "   Timer test: $time_result (should be ~0.100s)"

echo
echo "2. Testing single key creation..."
layered_native_create_ignition "debug-test-1" "test-pass"
echo "   Single key creation: OK"

echo
echo "3. Testing benchmark function with 1 operation..."
benchmark_approach "layered_native" 1

echo
echo "Debug complete!"