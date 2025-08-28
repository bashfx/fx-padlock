#!/bin/bash

echo "Debugging box alignment issue:"
echo ""

# Test with precise character counting
CARD_WIDTH=50
CONTENT_WIDTH=$((CARD_WIDTH - 4))  # 46 chars for content

echo "CARD_WIDTH: $CARD_WIDTH"
echo "CONTENT_WIDTH: $CONTENT_WIDTH"
echo ""

# Create borders manually to count characters
echo "Top border breakdown:"
top_border="┌─ Test Card ─────────────────────────────────────┐"
echo "Length: ${#top_border}"
echo "$top_border"
echo ""

echo "Content line breakdown:"
content_line="│ ID: TEST-001                                   │"
echo "Length: ${#content_line}"
echo "$content_line"
echo ""

echo "Bottom border breakdown:"
bottom_border="└─────────────────────────────────────────────────┘"
echo "Length: ${#bottom_border}"
echo "$bottom_border"
echo ""

echo "Proper alignment test:"
echo "┌─ Test Card ─────────────────────────────────────┐"
printf "│ %-46s │\n" "ID: TEST-001"
printf "│ %-46s │\n" "Title: Test title here"
printf "│ %-46s │\n" "State: PASS"
printf "│ %-46s │\n" "Priority: HIGH"
echo "└─────────────────────────────────────────────────┘"
echo ""

echo "Testing with different content widths:"
for width in 44 45 46 47 48; do
    echo "Content width: $width"
    echo "┌─ Test $width ──────────────────────────────────────┐"
    printf "│ %-${width}s │\n" "Content here"
    echo "└────────────────────────────────────────────────────┘"
    echo ""
done