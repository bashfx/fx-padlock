#!/usr/bin/env bash
# test.sh - Unified Test Dispatcher for fx-padlock
# BashFX 3.0 Compliant Testing Framework

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TESTS_DIR="$SCRIPT_DIR/tests"

# Test categories and their descriptions
declare -A TEST_CATEGORIES=(
    ["smoke"]="Quick validation tests (2-3 min)"
    ["integration"]="Full workflow tests (5-10 min)"
    ["security"]="Security validation tests (3-5 min)"
    ["benchmark"]="Performance tests (1-2 min)"
    ["advanced"]="Complex feature tests (3-5 min)"
    ["all"]="Run all test categories"
)

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Usage information
show_usage() {
    echo "🧪 fx-padlock Unified Test Dispatcher"
    echo
    echo "Usage: $0 <command> [options]"
    echo
    echo "Commands:"
    echo "  run <category> [test]     Run tests in category, optionally specific test"
    echo "  list [category]           List available tests"
    echo "  help                      Show this help"
    echo
    echo "Categories:"
    for category in "${!TEST_CATEGORIES[@]}"; do
        if [[ "$category" != "all" ]]; then
            printf "  %-12s %s\n" "$category" "${TEST_CATEGORIES[$category]}"
        fi
    done
    echo "  all                       ${TEST_CATEGORIES[all]}"
    echo
    echo "Examples:"
    echo "  $0 run smoke              # Run all smoke tests"
    echo "  $0 run security validation # Run specific security test"
    echo "  $0 run all                # Run everything"
    echo "  $0 list                   # Show all available tests"
    echo "  $0 list security          # Show security tests"
}

# Discover tests in a category
discover_tests() {
    local category="$1"
    local category_dir="$TESTS_DIR/$category"
    
    if [[ ! -d "$category_dir" ]]; then
        return 1
    fi
    
    find "$category_dir" -name "*.sh" -type f | sort
}

# List available tests
list_tests() {
    local filter_category="${1:-}"
    
    echo "📋 Available Tests:"
    echo
    
    if [[ -n "$filter_category" ]]; then
        if [[ ! "${TEST_CATEGORIES[$filter_category]+_}" ]]; then
            echo -e "${RED}❌ Unknown category: $filter_category${NC}"
            return 1
        fi
        
        echo -e "${CYAN}Category: $filter_category${NC} - ${TEST_CATEGORIES[$filter_category]}"
        echo
        
        if tests=$(discover_tests "$filter_category"); then
            while IFS= read -r test_file; do
                local test_name
                test_name=$(basename "$test_file" .sh)
                printf "  • %s\n" "$test_name"
            done <<< "$tests"
        else
            echo "  (No tests found)"
        fi
    else
        for category in "${!TEST_CATEGORIES[@]}"; do
            if [[ "$category" == "all" ]]; then continue; fi
            
            echo -e "${CYAN}$category${NC} - ${TEST_CATEGORIES[$category]}"
            
            if tests=$(discover_tests "$category"); then
                while IFS= read -r test_file; do
                    local test_name
                    test_name=$(basename "$test_file" .sh)
                    printf "  • %s\n" "$test_name"
                done <<< "$tests"
            else
                echo "  (No tests found)"
            fi
            echo
        done
    fi
}

# Execute a specific test file
execute_test() {
    local test_file="$1"
    local test_name
    test_name=$(basename "$test_file" .sh)
    
    echo -e "${BLUE}▶ Running: $test_name${NC}"
    
    if [[ -x "$test_file" ]]; then
        if "$test_file"; then
            echo -e "${GREEN}✅ $test_name: PASSED${NC}"
            return 0
        else
            echo -e "${RED}❌ $test_name: FAILED${NC}"
            return 1
        fi
    else
        echo -e "${YELLOW}⚠️  $test_name: Not executable, skipping${NC}"
        return 0
    fi
}

# Run tests in a category
run_tests() {
    local category="$1"
    local specific_test="${2:-}"
    
    # Special handling for 'all' category
    if [[ "$category" == "all" ]]; then
        echo -e "${CYAN}🚀 Running ALL test categories${NC}"
        echo
        
        local total_passed=0
        local total_failed=0
        
        for cat in smoke security integration benchmark advanced; do
            if [[ "${TEST_CATEGORIES[$cat]+_}" ]]; then
                echo -e "${CYAN}═══ Category: $cat ═══${NC}"
                if run_tests "$cat"; then
                    ((total_passed++))
                else
                    ((total_failed++))
                fi
                echo
            fi
        done
        
        echo -e "${CYAN}📊 Overall Results:${NC}"
        echo "  Categories passed: $total_passed"
        echo "  Categories failed: $total_failed"
        
        return $([[ $total_failed -eq 0 ]])
    fi
    
    # Validate category
    if [[ ! "${TEST_CATEGORIES[$category]+_}" ]]; then
        echo -e "${RED}❌ Unknown category: $category${NC}"
        echo "Available categories: ${!TEST_CATEGORIES[*]}"
        return 1
    fi
    
    # Discover tests
    if ! tests=$(discover_tests "$category"); then
        echo -e "${YELLOW}⚠️  No tests found in category: $category${NC}"
        return 0
    fi
    
    echo -e "${CYAN}🧪 Running $category tests${NC} - ${TEST_CATEGORIES[$category]}"
    echo
    
    local passed=0
    local failed=0
    local executed_any=false
    
    while IFS= read -r test_file; do
        local test_name
        test_name=$(basename "$test_file" .sh)
        
        # If specific test requested, only run that one
        if [[ -n "$specific_test" && "$test_name" != *"$specific_test"* ]]; then
            continue
        fi
        
        executed_any=true
        
        if execute_test "$test_file"; then
            ((passed++))
        else
            ((failed++))
        fi
        echo
    done <<< "$tests"
    
    if [[ "$executed_any" == false && -n "$specific_test" ]]; then
        echo -e "${RED}❌ No test matching '$specific_test' found in $category${NC}"
        return 1
    fi
    
    echo -e "${CYAN}📊 Results for $category:${NC}"
    echo "  Passed: $passed"
    echo "  Failed: $failed"
    echo "  Total:  $((passed + failed))"
    
    return $([[ $failed -eq 0 ]])
}

# Main dispatcher
main() {
    local command="${1:-help}"
    
    case "$command" in
        "run")
            local category="${2:-}"
            local specific_test="${3:-}"
            
            if [[ -z "$category" ]]; then
                echo -e "${RED}❌ Missing category for run command${NC}"
                echo
                show_usage
                return 1
            fi
            
            run_tests "$category" "$specific_test"
            ;;
        "list")
            local filter_category="${2:-}"
            list_tests "$filter_category"
            ;;
        "help"|"-h"|"--help")
            show_usage
            ;;
        *)
            echo -e "${RED}❌ Unknown command: $command${NC}"
            echo
            show_usage
            return 1
            ;;
    esac
}

# Execute main function with all arguments
main "$@"