#!/bin/bash
# Extract and checksum duplicate functions to identify differences

set -euo pipefail

# Create extraction directory
mkdir -p ./.func/extracts

echo "=== EXTRACTING AND CHECKSUMMING DUPLICATE FUNCTIONS ==="
echo

# Files to check (prioritizing ignition as requested)
FILES=(
    "parts/07_ignition_api.sh:ignition"
    "parts/08_repo_api.sh:repo" 
    "parts/09_key_api.sh:key"
    "parts/06_master_api.sh:master"
    "parts/04_helpers.sh:helpers"
)

# Read duplicates list
mapfile -t DUPLICATES < all_duplicates.log

echo "Processing ${#DUPLICATES[@]} duplicate functions across ${#FILES[@]} files..."
echo

for dup_func in "${DUPLICATES[@]}"; do
    echo "--- Processing function: $dup_func ---"
    
    # Extract from each file that contains it
    for file_info in "${FILES[@]}"; do
        IFS=':' read -r filepath prefix <<< "$file_info"
        
        # Check if function exists in this file
        if func ls "$filepath" | grep -q "^$dup_func$"; then
            extract_name="${prefix}_${dup_func}"
            echo "  Extracting from $filepath as $extract_name"
            
            # Extract function with custom name
            func copy "$dup_func" "$filepath" --alias="$extract_name" -f 2>/dev/null || {
                echo "    ⚠️  Failed to extract $dup_func from $filepath"
                continue
            }
            
            # Move to extracts directory and calculate checksum
            if [[ -f ".func/${extract_name}.edit.sh" ]]; then
                mv ".func/${extract_name}.edit.sh" "./.func/extracts/${extract_name}.sh"
                mv ".func/${extract_name}.orig.sh" "./.func/extracts/${extract_name}.orig.sh" 2>/dev/null || true
                
                # Calculate checksum of function body only (skip metadata)
                checksum=$(grep -v "^#" "./.func/extracts/${extract_name}.sh" | grep -v "^$" | sha256sum | cut -d' ' -f1)
                echo "    ✅ $extract_name: $checksum"
                echo "$dup_func:$prefix:$checksum" >> "./.func/extracts/checksums.log"
            fi
        fi
    done
    echo
done

echo "=== CHECKSUM ANALYSIS ==="
echo

# Find identical implementations (same checksum)
echo "Functions with identical implementations:"
sort "./.func/extracts/checksums.log" | awk -F: '{print $3 " " $1 ":" $2}' | sort | uniq -d -f1 | while read -r checksum func_info; do
    echo "  Checksum $checksum:"
    grep ":$checksum$" "./.func/extracts/checksums.log" | while IFS=: read -r func prefix cs; do
        echo "    - $prefix/$func"
    done
    echo
done

# Find different implementations (different checksums for same function)
echo "Functions with different implementations:"
awk -F: '{print $1}' "./.func/extracts/checksums.log" | sort | uniq -d | while read -r func; do
    echo "  Function $func:"
    grep "^$func:" "./.func/extracts/checksums.log" | while IFS=: read -r f prefix checksum; do
        echo "    - $prefix: $checksum"
    done
    echo
done

echo "=== SUMMARY ==="
total_extracts=$(ls ./.func/extracts/*.sh | wc -l)
unique_checksums=$(awk -F: '{print $3}' "./.func/extracts/checksums.log" | sort -u | wc -l)
echo "Total extracts: $total_extracts"
echo "Unique implementations: $unique_checksums"
echo "True duplicates: $((total_extracts - unique_checksums))"
echo
echo "Results saved in ./.func/extracts/"
echo "Checksum log: ./.func/extracts/checksums.log"