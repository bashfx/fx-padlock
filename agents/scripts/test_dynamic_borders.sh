#!/bin/bash

echo "Testing dynamic border calculation:"
echo ""

CARD_WIDTH=74
CONTENT_WIDTH=$((CARD_WIDTH - 4))

echo "CARD_WIDTH: $CARD_WIDTH"
echo "CONTENT_WIDTH: $CONTENT_WIDTH"
echo ""

# Test the dynamic top border calculation
header_text="─ Task Details ─"
header_length=${#header_text}
remaining_dashes=$((CARD_WIDTH - 2 - header_length))

echo "Header text: '$header_text'"
echo "Header length: $header_length"
echo "Remaining dashes needed: $remaining_dashes"
echo ""

# Build the border
right_dashes=$(printf '%*s' $remaining_dashes '' | tr ' ' '─')
top_border="┌${header_text}${right_dashes}┐"

echo "Top border:"
echo "$top_border"
echo "Length: ${#top_border}"
echo ""

# Test content line
content_line=$(printf "│ %-${CONTENT_WIDTH}s │" "ID: TEST-001")
echo "Content line:"
echo "$content_line"
echo "Length: ${#content_line}"
echo ""

# Test bottom border  
bottom_dashes=$(printf '%*s' $((CARD_WIDTH - 2)) '' | tr ' ' '─')
bottom_border="└${bottom_dashes}┘"
echo "Bottom border:"
echo "$bottom_border"
echo "Length: ${#bottom_border}"
echo ""

echo "Complete box:"
echo "$top_border"
printf "│ %-${CONTENT_WIDTH}s │\n" "ID: TEST-001"
printf "│ %-${CONTENT_WIDTH}s │\n" "Title: Test title"
printf "│ %-${CONTENT_WIDTH}s │\n" "State: PASS"
echo "$bottom_border"