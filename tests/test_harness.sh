#!/usr/bin/env bash
# test_harness.sh - Modular Test Suite Orchestrator
# BashFX 2.1 Compliant Testing Framework

set -e

# Test harness shared utilities
test_box() {
    local title="$1"
    local num="$2"
    
    # Get terminal width, fallback to 80 if not available
    local term_width
    term_width=$(tput cols 2>/dev/null || echo "80")
    
    # Ensure minimum width
    [[ $term_width -lt 50 ]] && term_width=50
    
    # Calculate content width (leave space for borders and padding)
    local content_width=$((term_width - 4))
    
    # Build the title line
    local test_label="Test ${num}: ${title}"
    local title_length=${#test_label}
    
    # If title is too long, truncate it
    if [[ $title_length -gt $((content_width - 4)) ]]; then
        test_label="${test_label:0:$((content_width - 7))}..."
        title_length=${#test_label}
    fi
    
    # Calculate padding needed
    local padding_needed=$((content_width - title_length - 3))  # 3 for "─ " and " "
    
    # Build the padding string
    local padding=""
    for ((i=0; i<padding_needed; i++)); do
        padding+="─"
    done
    
    echo
    echo "┌─ ${test_label} ${padding}┐"
}

test_end() {
    # Get terminal width, fallback to 80 if not available
    local term_width
    term_width=$(tput cols 2>/dev/null || echo "80")
    
    # Ensure minimum width
    [[ $term_width -lt 50 ]] && term_width=50
    
    # Calculate content width and build bottom border
    local content_width=$((term_width - 2))
    local bottom_border=""
    for ((i=0; i<content_width; i++)); do
        bottom_border+="─"
    done
    
    echo "└${bottom_border}┘"
}

# Shared test environment setup
setup_test_environment() {
    mkdir -p "$HOME/.cache/tmp"
    mktemp -d -p "$HOME/.cache/tmp"
}

# Export functions for use by test modules
export -f test_box test_end setup_test_environment