#!/bin/bash

echo "Testing box drawing characters individually:"
echo ""

echo "Corner characters:"
echo "Top-left:     ┌"
echo "Top-right:    ┐" 
echo "Bottom-left:  └"
echo "Bottom-right: ┘"
echo ""

echo "Line characters:"
echo "Horizontal:   ─"
echo "Vertical:     │"
echo ""

echo "Full box test:"
echo "┌─────────────────────────┐"
echo "│ This is test content    │"
echo "│ Second line of content  │"
echo "└─────────────────────────┘"
echo ""

echo "Card with proper formatting:"
CARD_WIDTH=50
CONTENT_WIDTH=46

echo "┌─ Test Card ─────────────────────────────────────┐"
printf "│ %-${CONTENT_WIDTH}s │\n" "ID: TEST-001"
printf "│ %-${CONTENT_WIDTH}s │\n" "Title: Test title here"
printf "│ %-${CONTENT_WIDTH}s │\n" "State: PASS"
printf "│ %-${CONTENT_WIDTH}s │\n" "Priority: HIGH"
echo "└─────────────────────────────────────────────────┘"