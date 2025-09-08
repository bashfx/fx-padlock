#!/bin/bash
# Simple script to extract and checksum a few key duplicate functions

set -euo pipefail

echo "=== TESTING DUPLICATE FUNCTION CHECKSUMS ==="

# Test a few critical functions
TEST_FUNCTIONS=(
    "do_setup"
    "_create_ignition_master_with_tty_magic" 
    "do_import"
    "do_export"
    "do_revoke"
)

# Files that contain duplicates
FILES=(
    "parts/07_ignition_api.sh:ignition"
    "parts/08_repo_api.sh:repo" 
    "parts/09_key_api.sh:key"
    "parts/06_master_api.sh:master"
    "parts/04_helpers.sh:helpers"
)

for func in "${TEST_FUNCTIONS[@]}"; do
    echo "--- Testing function: $func ---"
    
    # Extract from each file that contains it
    for file_info in "${FILES[@]}"; do
        IFS=':' read -r filepath prefix <<< "$file_info"
        
        # Check if function exists in this file
        if func ls "$filepath" | grep -q "^$func$"; then
            extract_name="${prefix}_${func}"
            echo "  Found in $filepath, extracting as $extract_name"
            
            # Clean up any existing extracts
            rm -f "./func/${extract_name}.edit.sh" "./func/${func}.orig.sh" 2>/dev/null || true
            
            # Extract function
            if func copy "$func" "$filepath" --alias="$extract_name" -f >/dev/null 2>&1; then
                # Calculate checksum of function body (skip comments/empty lines)
                if [[ -f "./func/${extract_name}.edit.sh" ]]; then
                    checksum=$(grep -v '^#' "./func/${extract_name}.edit.sh" | grep -v '^[[:space:]]*$' | sha256sum | cut -d' ' -f1)
                    echo "    Checksum: $checksum"
                    echo "$func:$prefix:$checksum" >> checksums_simple.log
                else
                    echo "    ⚠️  Extract file not found"
                fi
            else
                echo "    ⚠️  Failed to extract"
            fi
        fi
    done
    echo
done

echo "=== ANALYSIS ==="
if [[ -f checksums_simple.log ]]; then
    echo "Functions with identical checksums (true duplicates):"
    sort checksums_simple.log | awk -F: '{print $3 " " $0}' | sort | uniq -d -f1 | cut -d' ' -f2- | while IFS=: read -r func prefix checksum; do
        echo "  $func in $prefix: $checksum"
    done
    
    echo
    echo "Functions with different checksums (different implementations):"
    awk -F: '{print $1}' checksums_simple.log | sort | uniq -d | while read -r func; do
        echo "  Function $func has different implementations:"
        grep "^$func:" checksums_simple.log | while IFS=: read -r f prefix checksum; do
            echo "    - $prefix: $checksum"
        done
    done
else
    echo "No checksums generated"
fi