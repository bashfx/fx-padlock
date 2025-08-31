#!/bin/bash
# Run all TTY subversion methods and compare results

echo "🔬 Age TTY Subversion Research - Testing All Methods"
echo "=================================================="
echo

cd "$(dirname "$0")"

# Clean up any previous test files
rm -f output*.age decrypted*.txt

# Run each method
echo "🧪 Testing Method 1: script command variations"
bash method1_script.sh
echo

echo "🧪 Testing Method 2: expect/unbuffer approaches" 
bash method2_expect.sh
echo

echo "🧪 Testing Method 3: socat/pty manipulation"
bash method3_socat.sh
echo

echo "🧪 Testing Method 4: alternative approaches"
bash method4_alternatives.sh
echo

# Summary of results
echo "📊 RESULTS SUMMARY"
echo "=================="

passphrase="test123"
success_count=0
total_count=0

echo "Testing decryption of all generated .age files:"
for age_file in output*.age; do
    if [[ -f "$age_file" ]]; then
        total_count=$((total_count + 1))
        echo -n "Testing $age_file: "
        
        # Try to decrypt with our test passphrase
        if printf '%s\n' "$passphrase" | age -d "$age_file" 2>/dev/null | cmp -s - test_input.txt; then
            echo "✅ SUCCESS - correctly encrypted/decrypted"
            success_count=$((success_count + 1))
        else
            echo "❌ FAILED - incorrect encryption or can't decrypt"
        fi
    fi
done

if [[ $total_count -eq 0 ]]; then
    echo "❌ NO .age files were created - all methods failed"
else
    echo
    echo "Success rate: $success_count/$total_count methods worked"
    
    if [[ $success_count -gt 0 ]]; then
        echo "🎉 Found working method(s) for age -p TTY subversion!"
    else
        echo "😞 No methods successfully created valid age files"
    fi
fi

# Clean up
echo
echo "🧹 Cleaning up test files..."
rm -f output*.age decrypted*.txt temp*
echo "Done."