#!/bin/bash
set -euo pipefail

# FireBox - Dynamic General Purpose Box Rendering Function
# Handles auto-wrapping, dynamic width, field overflow calculations
# Maintains UTF-8 box drawing aesthetics with header preservation

# ANSI Color Functions
colorize() {
    local text="$1"
    local color="${2:-}"
    
    case "$color" in
        "red")     echo -e "\033[0;31m${text}\033[0m" ;;
        "green")   echo -e "\033[0;32m${text}\033[0m" ;;
        "yellow")  echo -e "\033[0;33m${text}\033[0m" ;;
        "blue")    echo -e "\033[0;34m${text}\033[0m" ;;
        "purple")  echo -e "\033[0;35m${text}\033[0m" ;;
        "cyan")    echo -e "\033[0;36m${text}\033[0m" ;;
        "gray")    echo -e "\033[0;37m${text}\033[0m" ;;
        "bold")    echo -e "\033[1m${text}\033[0m" ;;
        *)         echo "$text" ;;
    esac
}

# Calculate visible length excluding ANSI codes
get_visible_length() {
    local text="$1"
    local clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    echo ${#clean_text}
}

# Enhanced visible length calculation that handles emojis better
get_enhanced_visible_length() {
    local text="$1"
    
    # Remove ANSI escape codes
    local clean_text=$(echo -e "$text" | sed 's/\x1b\[[0-9;]*m//g')
    
    # More precise emoji counting - count actual emoji impact
    local emoji_count=0
    if echo "$clean_text" | grep -qE '🚨|🏃|🚧|🔥|🆔|📋|⚡|👥|📅|📊|🔗|⚠️|📝|🎯|📞|✅|🔄|⏳'; then
        emoji_count=1  # Most emojis take 1 extra display column
    fi
    
    # Progress bar characters seem to display correctly as 1-width
    if echo "$clean_text" | grep -qE '[█░▓▒]'; then
        emoji_count=$((emoji_count + 0))  # No extra padding needed for progress bars
    fi
    
    local base_length=${#clean_text}
    local adjusted_length=$((base_length + emoji_count))
    
    echo $adjusted_length
}

# Detect if content has complex formatting (emojis or ANSI codes)
has_complex_formatting() {
    local text="$1"
    
    # Check for ANSI escape codes
    if echo -e "$text" | grep -q $'\x1b\[[0-9;]*m'; then
        return 0  # true
    fi
    
    # Check for specific emojis that cause issues
    if echo "$text" | grep -qE '🚨|🏃|🚧|🔥|🆔|📋|⚡|👥|📅|📊|🔗|⚠️|📝|🎯|📞|✅|🔄|⏳'; then
        return 0  # true
    fi
    
    # Check for progress bar characters that might affect display
    if echo "$text" | grep -qE '[█░▓▒]'; then
        return 0  # true
    fi
    
    return 1  # false
}

# Complex row formatter for content with emojis and colors
format_complex_row() {
    local content="$1"
    local content_width="$2"
    local use_colors="${USE_COLORS:-true}"
    
    if [ "$use_colors" != "true" ]; then
        # Strip colors for plain text mode (keep emojis for now as they're display characters)
        content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    fi
    
    # Use the same simple approach as the debug script - don't overthink emoji width
    local clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
    local visible_length=${#clean_content}
    
    # Use the standard padding calculation with a small adjustment for emoji display
    local padding_needed=$((content_width - visible_length))
    
    # Small conservative adjustment for emoji display issues
    if has_complex_formatting "$content"; then
        padding_needed=$((padding_needed - 1))  # Just -1 for emoji display width
    fi
    
    if [ $padding_needed -gt 0 ]; then
        local padding=$(printf '%*s' $padding_needed '')
        printf "│ %s%s │\n" "$content" "$padding"
    elif [ $padding_needed -eq 0 ]; then
        printf "│ %s │\n" "$content"
    else
        # Content too long, truncate more aggressively for complex content
        local clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
        local truncate_at=$((content_width - 5))  # More buffer for complex content
        local truncated=${clean_content:0:$truncate_at}
        printf "│ %s... │\n" "$truncated"
    fi
}

# Word wrap function that preserves ANSI codes
word_wrap() {
    local text="$1"
    local max_width="$2"
    local lines=()
    
    # Handle empty input
    if [ -z "$text" ]; then
        echo ""
        return
    fi
    
    # Split on spaces but preserve ANSI codes
    local words=()
    local current_word=""
    local in_ansi=false
    local i=0
    
    # Simple approach: split by spaces, handle ANSI codes later
    IFS=' ' read -ra word_array <<< "$text"
    
    local current_line=""
    local current_length=0
    
    for word in "${word_array[@]}"; do
        local word_length=$(get_visible_length "$word")
        local space_length=1
        
        # Check if adding this word would exceed width
        local test_length=$((current_length + space_length + word_length))
        
        if [ $current_length -eq 0 ]; then
            # First word on line
            if [ $word_length -le $max_width ]; then
                current_line="$word"
                current_length=$word_length
            else
                # Word too long, truncate with ellipsis
                local truncated=$(echo -e "$word" | sed 's/\x1b\[[0-9;]*m//g')
                truncated=${truncated:0:$((max_width-3))}
                current_line="${truncated}..."
                current_length=$max_width
            fi
        elif [ $test_length -le $max_width ]; then
            # Add word to current line
            current_line="$current_line $word"
            current_length=$test_length
        else
            # Start new line
            lines+=("$current_line")
            if [ $word_length -le $max_width ]; then
                current_line="$word"
                current_length=$word_length
            else
                # Word too long, truncate
                local truncated=$(echo -e "$word" | sed 's/\x1b\[[0-9;]*m//g')
                truncated=${truncated:0:$((max_width-3))}
                current_line="${truncated}..."
                current_length=$max_width
            fi
        fi
    done
    
    # Add final line
    if [ -n "$current_line" ]; then
        lines+=("$current_line")
    fi
    
    # Output all lines
    printf '%s\n' "${lines[@]}"
}

# Format a line with proper padding and ANSI code handling
format_content_line() {
    local content="$1"
    local content_width="$2"
    
    # Auto-detect if we need complex formatting
    if has_complex_formatting "$content"; then
        format_complex_row "$content" "$content_width"
        return
    fi
    
    # Use standard formatting for simple content
    local visible_length=$(get_visible_length "$content")
    local padding_needed=$((content_width - visible_length))
    
    if [ $padding_needed -gt 0 ]; then
        local padding=$(printf '%*s' $padding_needed '')
        printf "│ %s%s │\n" "$content" "$padding"
    elif [ $padding_needed -eq 0 ]; then
        printf "│ %s │\n" "$content"
    else
        # Content too long, truncate with ellipsis
        local clean_content=$(echo -e "$content" | sed 's/\x1b\[[0-9;]*m//g')
        local truncated=${clean_content:0:$((content_width-3))}
        printf "│ %s... │\n" "$truncated"
    fi
}

# Main FireBox function
firebox() {
    local max_width=80  # Default width
    local header=""
    local auto_wrap=false
    local fields=()
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --width)
                max_width="$2"
                shift 2
                ;;
            --header)
                header="$2"
                shift 2
                ;;
            --wrap)
                auto_wrap=true
                shift
                ;;
            --field)
                fields+=("$2")
                shift 2
                ;;
            *)
                echo "Unknown option: $1" >&2
                return 1
                ;;
        esac
    done
    
    # Validate width
    if [ $max_width -lt 10 ]; then
        echo "Error: Width too small (minimum 10)" >&2
        return 1
    fi
    
    local content_width=$((max_width - 4))  # Account for "│ " and " │"
    
    # Build top border
    if [ -n "$header" ]; then
        local header_text="─ $header ─"
        local header_length=$(get_visible_length "$header_text")
        local remaining_dashes=$((max_width - 2 - header_length))
        
        if [ $remaining_dashes -lt 0 ]; then
            # Header too long, truncate
            local truncated_header=${header:0:$((max_width-8))}
            header_text="─ ${truncated_header}... ─"
            remaining_dashes=0
        fi
        
        local right_dashes=$(printf '─%.0s' $(seq 1 $remaining_dashes))
        echo "┌${header_text}${right_dashes}┐"
    else
        local all_dashes=$(printf '─%.0s' $(seq 1 $((max_width - 2))))
        echo "┌${all_dashes}┐"
    fi
    
    # Process fields
    for field in "${fields[@]}"; do
        if [ "$auto_wrap" = true ]; then
            # Auto-wrap the field content
            local wrapped_lines
            mapfile -t wrapped_lines < <(word_wrap "$field" $content_width)
            
            for line in "${wrapped_lines[@]}"; do
                format_content_line "$line" $content_width
            done
        else
            # Single line with truncation if needed
            format_content_line "$field" $content_width
        fi
    done
    
    # Bottom border
    local bottom_dashes=$(printf '─%.0s' $(seq 1 $((max_width - 2))))
    echo "└${bottom_dashes}┘"
}

# Auto-generate test boxes with different complexity levels
auto_generate() {
    local complexity="${1:-all}"
    
    echo "🔥 FireBox Auto-Generator - Test Box Suite"
    echo ""
    
    case "$complexity" in
        "simple"|"all")
            echo "=== SIMPLE CARD ==="
            firebox --width 40 --header "Basic Task" \
                --field "ID: TSK-001" \
                --field "Title: Simple task" \
                --field "Status: $(colorize "ACTIVE" "green")" \
                --field "Priority: $(colorize "🏃 HIGH" "yellow")"
            echo ""
            ;;
    esac
    
    case "$complexity" in
        "medium"|"all")
            echo "=== MEDIUM COMPLEXITY CARD ==="
            firebox --width 65 --header "Feature Development Task" \
                --field "ID: FEAT-2024-001" \
                --field "Title: Implement user authentication system" \
                --field "Status: $(colorize "🚧 IN_PROGRESS" "yellow")" \
                --field "Priority: $(colorize "🚨 CRITICAL" "red")" \
                --field "Assigned: $(colorize "Agent-Alpha" "cyan")" \
                --field "Team: $(colorize "Backend Engineering" "blue")" \
                --field "Due: 2024-12-15" \
                --field "Progress: ████████░░ 80%"
            echo ""
            ;;
    esac
    
    case "$complexity" in
        "complex"|"all")
            echo "=== COMPLEX LARGE CARD ==="
            firebox --width 90 --header "Enterprise Integration Project - Phase 3" --wrap \
                --field "$(colorize "🆔 PROJECT ID:" "bold") ENTERPRISE-AUTH-2024-Q4-PHASE3-001" \
                --field "$(colorize "📋 TITLE:" "bold") Implement Multi-Tenant OAuth2 Authentication with Role-Based Access Control and External Identity Provider Integration" \
                --field "$(colorize "⚡ STATUS:" "bold") $(colorize "🚧 ACTIVE_DEVELOPMENT" "yellow") - Currently in sprint 3 of 5" \
                --field "$(colorize "🚨 PRIORITY:" "bold") $(colorize "🔥 BUSINESS_CRITICAL" "red") - Blocking Q1 2025 customer rollout" \
                --field "$(colorize "👥 ASSIGNED TEAM:" "bold")" \
                --field "  • Lead: $(colorize "Senior-Agent-007" "cyan") (Architecture & Security)" \
                --field "  • Dev: $(colorize "Agent-Alpha" "green") (Backend Implementation)" \
                --field "  • Dev: $(colorize "Agent-Beta" "green") (Frontend Integration)" \
                --field "  • QA: $(colorize "Agent-Gamma" "purple") (Testing & Validation)" \
                --field "$(colorize "📅 TIMELINE:" "bold")" \
                --field "  • Started: 2024-11-01" \
                --field "  • Current Sprint End: 2024-12-15" \
                --field "  • Final Delivery: 2025-01-31" \
                --field "  • Production Deploy: 2025-02-14" \
                --field "$(colorize "📊 PROGRESS BREAKDOWN:" "bold")" \
                --field "  • Authentication Core: ████████████░ 95% $(colorize "✅ COMPLETE" "green")" \
                --field "  • Multi-Tenant Support: ████████░░░░░ 65% $(colorize "🚧 IN_PROGRESS" "yellow")" \
                --field "  • External Provider Integration: ████░░░░░░░░░ 30% $(colorize "🔄 STARTED" "cyan")" \
                --field "  • Role-Based Access Control: ██░░░░░░░░░░░ 15% $(colorize "📋 PLANNED" "gray")" \
                --field "  • Security Audit & Testing: ░░░░░░░░░░░░░ 5% $(colorize "⏳ PENDING" "gray")" \
                --field "$(colorize "🔗 DEPENDENCIES:" "bold")" \
                --field "  • [BLOCKED] Awaiting legal approval for GDPR compliance framework" \
                --field "  • [READY] Database schema migration (v2.1.3) - completed 2024-11-28" \
                --field "  • [PENDING] Load balancer configuration for multi-region support" \
                --field "$(colorize "⚠️  RISKS & BLOCKERS:" "bold")" \
                --field "  • $(colorize "HIGH:" "red") External provider API rate limits may impact testing phase" \
                --field "  • $(colorize "MEDIUM:" "yellow") Team capacity reduced due to holiday schedule Dec 20-Jan 5" \
                --field "  • $(colorize "LOW:" "green") Potential browser compatibility issues with new OAuth flow" \
                --field "$(colorize "📝 RECENT UPDATES:" "bold")" \
                --field "  • 2024-11-28: Completed core authentication module with unit tests" \
                --field "  • 2024-11-25: Resolved performance bottleneck in token validation (2s → 50ms)" \
                --field "  • 2024-11-22: Added support for custom claim mapping in JWT tokens" \
                --field "$(colorize "🎯 SUCCESS METRICS:" "bold")" \
                --field "  • Authentication latency < 100ms (current: 75ms avg)" \
                --field "  • Support for 10,000+ concurrent users per tenant" \
                --field "  • 99.9% uptime SLA compliance" \
                --field "  • Zero security vulnerabilities in penetration testing" \
                --field "$(colorize "📞 STAKEHOLDERS:" "bold")" \
                --field "  • Product Owner: $(colorize "Sarah Chen" "blue") (sarah.chen@company.com)" \
                --field "  • Security Officer: $(colorize "Marcus Rodriguez" "red") (marcus.r@company.com)" \
                --field "  • Customer Success: $(colorize "Emily Watson" "purple") (emily.w@company.com)"
            echo ""
            ;;
    esac
    
    case "$complexity" in
        "showcase"|"all")
            echo "=== SHOWCASE: DIFFERENT WIDTHS ==="
            local widths=(30 50 70 90)
            local content="This content adapts to different box widths dynamically"
            
            for width in "${widths[@]}"; do
                echo "📏 Width: $width characters"
                firebox --width $width --header "W:$width Test" --wrap \
                    --field "Content: $content" \
                    --field "Status: $(colorize "✅ ADAPTIVE" "green")"
                echo ""
            done
            ;;
    esac
    
    case "$complexity" in
        "edge"|"all")
            echo "=== EDGE CASES ==="
            
            echo "🔸 Minimum width box:"
            firebox --width 15 --header "Mini" \
                --field "VeryLongContentThatWillBeTruncated" \
                --field "OK"
            echo ""
            
            echo "🔸 No header box:"
            firebox --width 40 \
                --field "ID: NO-HEADER-001" \
                --field "Status: $(colorize "HEADERLESS" "cyan")"
            echo ""
            
            echo "🔸 Single field box:"
            firebox --width 35 --header "Solo" \
                --field "Only one field here"
            echo ""
            ;;
    esac
}

# Demo function to show capabilities
demo() {
    auto_generate "all"
}

# Show usage help
usage() {
    cat << 'EOF'
🔥 FireBox - Dynamic General Purpose Box Function

USAGE:
    firebox [OPTIONS] --field "content" [--field "more content"...]

OPTIONS:
    --width N       Set box width (default: 80, minimum: 10)
    --header TEXT   Set box header text
    --wrap         Enable auto-wrapping for long content
    --field TEXT    Add a content field (can be used multiple times)

EXAMPLES:
    # Basic box
    firebox --width 50 --header "Task" --field "ID: 001" --field "Status: Active"
    
    # Auto-wrapping box  
    firebox --width 60 --header "Details" --wrap --field "Long content that will wrap"
    
    # Narrow box with truncation
    firebox --width 30 --field "This will be truncated..."

FEATURES:
    • Dynamic width adjustment
    • Auto-wrapping with word boundaries
    • ANSI color code preservation
    • Perfect UTF-8 box drawing alignment
    • Content overflow handling (truncation with ellipsis)
    • Header text with dynamic border calculation
    • Minimum width enforcement for usability

EOF
}

# Main execution
case "${1:-demo}" in
    "demo")
        demo
        ;;
    "generate"|"gen")
        auto_generate "${2:-all}"
        ;;
    "simple")
        auto_generate "simple"
        ;;
    "medium")
        auto_generate "medium"
        ;;
    "complex")
        auto_generate "complex"
        ;;
    "showcase")
        auto_generate "showcase"
        ;;
    "edge")
        auto_generate "edge"
        ;;
    "usage"|"help"|"--help")
        usage
        ;;
    *)
        firebox "$@"
        ;;
esac