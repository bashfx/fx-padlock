#!/bin/bash

set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")"

source pilot.sh
setup_pilot

echo "=== Quick Performance Test ==="
echo "Testing complete cycle (create ignition + distro + unlock) for each approach"
echo

approaches=(layered_native double_wrapped ssh_delegation temporal_chain lattice_proxy)

for approach in "${approaches[@]}"; do
    echo -n "Testing $approach: "
    
    start=$(date +%s.%N)
    
    # Complete test cycle
    "${approach}_create_ignition" "perf-test" "test-pass" >/dev/null 2>&1 || true
    "${approach}_create_distro" "perf-test-distro" "test-pass" >/dev/null 2>&1 || true
    "${approach}_unlock" "perf-test-distro" "test-pass" >/dev/null 2>&1 || true
    
    end=$(date +%s.%N)
    duration=$(echo "$end - $start" | bc -l)
    
    printf "%.3fs\n" "$duration"
done

echo
echo "=== Results Summary ==="
echo "Note: Times include complete cycle (ignition + distro + unlock)"
echo "Lower times = better performance"