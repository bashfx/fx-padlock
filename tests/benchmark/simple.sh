#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
cd "$SCRIPT_DIR"

# Source the pilot.sh functions
source ../../pilot.sh

echo "=== Performance Benchmark Results ==="
echo

# Setup
setup_pilot

approaches=(layered_native double_wrapped ssh_delegation temporal_chain lattice_proxy)
operations=${1:-100}

echo "Testing $operations operations per approach"
echo

# Function to time a single operation
time_operation() {
    local start=$(date +%s.%N)
    "$@" >/dev/null 2>&1 || true
    local end=$(date +%s.%N)
    echo "$end - $start" | bc -l
}

# Results storage
declare -A generation_times
declare -A unlock_times

for approach in "${approaches[@]}"; do
    echo "Benchmarking: $approach"
    
    # Test key generation speed (average of first 10 operations)
    total_gen_time=0
    for ((i=1; i<=10; i++)); do
        op_time=$(time_operation "${approach}_create_ignition" "bench-$i" "test-pass-$i")
        total_gen_time=$(echo "$total_gen_time + $op_time" | bc -l)
    done
    avg_gen_time=$(echo "scale=3; $total_gen_time / 10" | bc -l)
    generation_times[$approach]=$avg_gen_time
    
    # Test unlock speed (create one key, test unlocking it multiple times)
    "${approach}_create_distro" "unlock-test-$approach" "test-pass" >/dev/null 2>&1 || true
    
    total_unlock_time=0
    successful_unlocks=0
    for ((i=1; i<=10; i++)); do
        start=$(date +%s.%N)
        if "${approach}_unlock" "unlock-test-$approach" "test-pass" >/dev/null 2>&1; then
            end=$(date +%s.%N)
            op_time=$(echo "$end - $start" | bc -l)
            total_unlock_time=$(echo "$total_unlock_time + $op_time" | bc -l)
            ((successful_unlocks++))
        fi
    done
    
    if [[ $successful_unlocks -gt 0 ]]; then
        avg_unlock_time=$(echo "scale=3; $total_unlock_time / $successful_unlocks" | bc -l)
        unlock_times[$approach]=$avg_unlock_time
    else
        unlock_times[$approach]="FAILED"
    fi
    
    echo "  Gen: ${generation_times[$approach]}s avg, Unlock: ${unlock_times[$approach]}s avg"
done

echo
echo "=== Summary Table ==="
printf "%-15s %-12s %-12s %-12s\n" "Approach" "Generation" "Unlock" "Total"
echo "--------------------------------------------------------"

for approach in "${approaches[@]}"; do
    gen_time="${generation_times[$approach]}"
    unlock_time="${unlock_times[$approach]}"
    
    if [[ "$unlock_time" == "FAILED" ]]; then
        total_time="FAILED"
    else
        total_time=$(echo "scale=3; $gen_time + $unlock_time" | bc -l)
    fi
    
    printf "%-15s %-12s %-12s %-12s\n" "$approach" "${gen_time}s" "${unlock_time}s" "${total_time}s"
done

echo
echo "=== Recommendations ==="

# Find fastest approach
fastest_approach=""
fastest_time=999999
for approach in "${approaches[@]}"; do
    unlock_time="${unlock_times[$approach]}"
    if [[ "$unlock_time" != "FAILED" ]]; then
        gen_time="${generation_times[$approach]}"
        total_time=$(echo "$gen_time + $unlock_time" | bc -l)
        
        if (( $(echo "$total_time < $fastest_time" | bc -l) )); then
            fastest_time=$total_time
            fastest_approach=$approach
        fi
    fi
done

echo "Fastest approach: $fastest_approach (${fastest_time}s total)"