#!/bin/bash

echo "Debugging colored line alignment:"
echo ""

CARD_WIDTH=74
CONTENT_WIDTH=$((CARD_WIDTH - 4))

# Test regular line
echo "Regular line:"
regular_line=$(printf "│ %-${CONTENT_WIDTH}s │" "State: PASS")
echo "$regular_line"
echo "Length: ${#regular_line}"
echo ""

# Test colored line (simulating the issue)
echo "Colored line (with ANSI codes):"
colored_text="State: \033[0;32mPASS\033[0m (✨ PASS)"
colored_line=$(printf "│ %-${CONTENT_WIDTH}s │" "$colored_text")
echo -e "$colored_line"
echo "Length: ${#colored_line}"
echo ""

# Calculate visible length (excluding ANSI codes)
echo "Analyzing the colored text:"
echo "Raw text: '$colored_text'"
echo "Raw length: ${#colored_text}"

# Remove ANSI codes for length calculation
clean_text=$(echo -e "$colored_text" | sed 's/\x1b\[[0-9;]*m//g')
echo "Clean text: '$clean_text'"
echo "Clean length: ${#clean_text}"
echo ""

# Proper way to handle colored content
echo "Corrected approach:"
visible_length=${#clean_text}
padding_needed=$((CONTENT_WIDTH - visible_length))
if [ $padding_needed -gt 0 ]; then
    padding=$(printf '%*s' $padding_needed '')
    corrected_line="│ ${colored_text}${padding} │"
    echo -e "$corrected_line"
    echo "Corrected length: ${#corrected_line}"
else
    echo "Content too long for card!"
fi
echo ""

echo "Testing in complete box:"
echo "┌─ Test Card ─────────────────────────────────────────────────────────────┐"
printf "│ %-${CONTENT_WIDTH}s │\n" "ID: TEST-001"
printf "│ %-${CONTENT_WIDTH}s │\n" "Title: Regular title"
echo -e "│ ${colored_text}${padding} │"
echo "└────────────────────────────────────────────────────────────────────────┘"