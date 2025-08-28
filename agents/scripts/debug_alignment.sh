#!/bin/bash
set -euo pipefail

# Debug alignment issues by showing exact character counts

CARD_WIDTH=60
CONTENT_WIDTH=$((CARD_WIDTH - 4))

echo "=== ALIGNMENT DEBUG ==="
echo "CARD_WIDTH: $CARD_WIDTH"
echo "CONTENT_WIDTH: $CONTENT_WIDTH"
echo ""

# Test different content types
contents=(
    "Status: 🚨 CRITICAL"
    "Progress: ████████░░ 80%"  
    "Team: 👥 Agent-Alpha"
    "Regular text line"
)

for content in "${contents[@]}"; do
    echo "Testing: '$content'"
    
    # Remove ANSI codes
    clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    clean_length=${#clean_content}
    
    # Calculate what padding should be
    padding_needed=$((CONTENT_WIDTH - clean_length))
    
    echo "  Clean content: '$clean_content'"
    echo "  Clean length: $clean_length"
    echo "  Padding needed: $padding_needed"
    
    # Build the actual line
    if [ $padding_needed -gt 0 ]; then
        padding=$(printf '%*s' $padding_needed '')
        line="│ ${content}${padding} │"
    else
        line="│ ${content} │"
    fi
    
    echo "  Actual line:"
    echo "$line"
    echo "  Line length: ${#line}"
    echo "  Expected length: $((CARD_WIDTH))"
    echo ""
done