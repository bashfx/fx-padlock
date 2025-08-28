#!/bin/bash

echo "Testing different methods for border generation:"
echo ""

# Method 1: Using tr (problematic)
echo "Method 1: Using tr"
dashes1=$(printf '%*s' 10 '' | tr ' ' '─')
echo "Result: '$dashes1'"
echo ""

# Method 2: Using seq and printf
echo "Method 2: Using seq and printf"
dashes2=""
for i in $(seq 1 10); do
    dashes2+="─"
done
echo "Result: '$dashes2'"
echo ""

# Method 3: Using bash string manipulation
echo "Method 3: Using bash string repetition"
dash_char="─"
dashes3=""
for ((i=0; i<10; i++)); do
    dashes3+="$dash_char"
done
echo "Result: '$dashes3'"
echo ""

# Method 4: Using printf with repetition
echo "Method 4: Using printf repetition"
dashes4=$(printf '─%.0s' {1..10})
echo "Result: '$dashes4'"
echo ""

echo "Testing complete borders:"
echo ""

# Test with method 4 (printf repetition)
CARD_WIDTH=50
header_text="─ Test ─" 
remaining=$((CARD_WIDTH - 2 - ${#header_text}))

echo "Using printf repetition method:"
top_dashes=$(printf '─%.0s' $(seq 1 $remaining))
echo "┌${header_text}${top_dashes}┐"

bottom_dashes=$(printf '─%.0s' $(seq 1 $((CARD_WIDTH - 2))))
echo "└${bottom_dashes}┘"