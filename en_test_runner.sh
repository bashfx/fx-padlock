#!/usr/bin/env bash
# enhanced_test_runner.sh - FIXED comprehensive test suite for padlock.sh
# Features: Numbered tests, clear titles, summary with celebration
# FIXES: Removed Unicode, fixed exit->return, completed missing functions

set -e

# Colors and formatting (ASCII only - no Unicode)
readonly GREEN='\033[32m'
readonly RED='\033[31m'
readonly BLUE='\033[34m'
readonly YELLOW='\033[33m'
readonly CYAN='\033[36m'
readonly BOLD='\033[1m'
readonly RESET='\033[0m'

# Test tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
CURRENT_TEST=0
declare -a TEST_RESULTS=()

print_header() {
    echo
    printf "%b%b=== PADLOCK TEST SUITE ===%b\n" "$BOLD" "$CYAN" "$RESET"
    printf "%b%b=========================%b\n" "$BOLD" "$CYAN" "$RESET"
    echo
}

start_test() {
    local test_name="$1"
    ((CURRENT_TEST++))
    ((TOTAL_TESTS++))
    printf "%b[%02d]%b %b%s%b" "$BOLD$BLUE" "$CURRENT_TEST" "$RESET" "$BOLD" "$test_name" "$RESET"
    printf " ... "
}

pass_test() {
    local details="${1:-}"
    ((PASSED_TESTS++))
    printf "%b[PASS]%b" "$GREEN" "$RESET"
    if [[ -n "$details" ]]; then
        printf " %b(%s)%b" "$CYAN" "$details" "$RESET"
    fi
    echo
    TEST_RESULTS+=("[PASS] Test $CURRENT_TEST: PASSED")
}

fail_test() {
    local error_msg="$1"
    ((FAILED_TESTS++))
    printf "%b[FAIL]%b\n" "$RED" "$RESET"
    printf "%b    Error: %s%b\n" "$RED" "$error_msg" "$RESET"
    TEST_RESULTS+=("[FAIL] Test $CURRENT_TEST: FAILED - $error_msg")
    return 1  # FIXED: Changed from exit 1 to return 1
}

run_basic_tests() {
    echo "=== BASIC FUNCTIONALITY TESTS ==="
    echo "=================================="
    
    start_test "Help System (--help)"
    if ./padlock.sh --help > /dev/null 2>&1; then
        pass_test "help displayed"
    else
        fail_test "help command failed" || return 1
    fi
    
    start_test "Version Display"
    local version_output
    if version_output=$(./padlock.sh version 2>/dev/null); then
        local version=$(echo "$version_output" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+' | head -1)
        pass_test "v${version:-unknown}"
    else
        fail_test "version command failed" || return 1
    fi
    
    start_test "Script Syntax Validation"
    if bash -n ./padlock.sh; then
        pass_test "syntax valid"
    else
        fail_test "syntax errors detected" || return 1
    fi
    
    echo
}

run_e2e_test() {
    local test_type="$1"
    
    echo "=== END-TO-END WORKFLOW TEST ($test_type) ==="
    echo "============================================="
    
    local test_dir
    test_dir=$(mktemp -d)
    local cleanup_done=false
    
    cleanup() {
        if [[ "$cleanup_done" == false ]]; then
            cleanup_done=true
            rm -rf "$test_dir" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT
    
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir"
    
    start_test "Repository Initialization ($test_type)"
    if [[ "$test_type" == "gitsim" ]]; then
        if curl -sL "https://raw.githubusercontent.com/bashfx/fx-gitsim/refs/heads/main/gitsim.sh" > gitsim.sh 2>/dev/null; then
            chmod +x gitsim.sh
            if ./gitsim.sh init > /dev/null 2>&1; then
                pass_test "gitsim repo created"
            else
                fail_test "gitsim init failed" || { cd "$original_dir"; return 1; }
            fi
        else
            fail_test "failed to download gitsim" || { cd "$original_dir"; return 1; }
        fi
    else
        if git init -b main > /dev/null 2>&1; then
            git config user.email "test@example.com" > /dev/null 2>&1
            git config user.name "Test User" > /dev/null 2>&1
            pass_test "git repo created"
        else
            fail_test "git init failed" || { cd "$original_dir"; return 1; }
        fi
    fi
    
    start_test "Padlock Deployment (clamp)"
    if "$original_dir/padlock.sh" clamp . --generate > /dev/null 2>&1; then
        if [[ -d "locker" && -f "bin/padlock" ]]; then
            pass_test "structure created"
        else
            fail_test "deployment incomplete" || { cd "$original_dir"; return 1; }
        fi
    else
        fail_test "clamp command failed" || { cd "$original_dir"; return 1; }
    fi
    
    start_test "Secret Content Creation"
    if mkdir -p locker/docs_sec && echo "secret content" > locker/docs_sec/test.md; then
        if [[ -f "locker/docs_sec/test.md" ]]; then
            pass_test "secret file created"
        else
            fail_test "secret file not found" || { cd "$original_dir"; return 1; }
        fi
    else
        fail_test "failed to create secret content" || { cd "$original_dir"; return 1; }
    fi
    
    start_test "Locker Encryption (lock)"
    if [[ "$test_type" == "git" ]]; then
        git add . > /dev/null 2>&1 || true
    fi
    
    if ./bin/padlock lock > /dev/null 2>&1; then
        if [[ ! -d "locker" && -f "locker.age" && -f ".locked" ]]; then
            local size
            size=$(du -h locker.age 2>/dev/null | cut -f1 || echo "unknown")
            pass_test "encrypted to $size"
        else
            fail_test "lock state incorrect" || { cd "$original_dir"; return 1; }
        fi
    else
        fail_test "lock command failed" || { cd "$original_dir"; return 1; }
    fi
    
    start_test "Locker Decryption (unlock)"
    if (source ./.locked > /dev/null 2>&1); then
        if [[ -d "locker" && ! -f "locker.age" && ! -f ".locked" ]]; then
            local content
            if content=$(cat locker/docs_sec/test.md 2>/dev/null) && [[ "$content" == "secret content" ]]; then
                pass_test "content verified"
            else
                fail_test "content corruption detected" || { cd "$original_dir"; return 1; }
            fi
        else
            fail_test "unlock state incorrect" || { cd "$original_dir"; return 1; }
        fi
    else
        fail_test "unlock failed" || { cd "$original_dir"; return 1; }
    fi
    
    cd "$original_dir"
    echo
}

run_install_tests() {
    echo "=== INSTALLATION TESTS ==="
    echo "=========================="
    
    local install_dir="$HOME/.local/lib/fx/padlock"
    local link_path="$HOME/.local/bin/fx/padlock"
    local padlock_etc_dir="$HOME/.local/etc/padlock"
    
    rm -rf "$install_dir" "$link_path" "$padlock_etc_dir" 2>/dev/null || true
    
    start_test "Global Installation"
    if ./padlock.sh install > /dev/null 2>&1; then
        if [[ -f "$install_dir/padlock.sh" && -L "$link_path" ]]; then
            pass_test "installed to system"
        else
            fail_test "installation incomplete" || return 1
        fi
    else
        fail_test "install command failed" || return 1
    fi
    
    start_test "Uninstall Safety Check"
    local test_dir
    test_dir=$(mktemp -d)
    local cleanup_done=false
    
    cleanup() {
        if [[ "$cleanup_done" == false ]]; then
            cleanup_done=true
            rm -rf "$test_dir" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT
    
    local original_dir
    original_dir=$(pwd)
    (cd "$test_dir" && git init -b main >/dev/null 2>&1 && "$original_dir/padlock.sh" clamp . --generate >/dev/null 2>&1)
    
    if ! ./padlock.sh uninstall > /dev/null 2>&1; then
        pass_test "safety check active"
    else
        fail_test "safety check bypassed" || return 1
    fi
    
    rm -rf "$test_dir"
    
    start_test "Forced Uninstall"
    test_dir=$(mktemp -d)
    trap cleanup EXIT
    (cd "$test_dir" && git init -b main >/dev/null 2>&1 && "$original_dir/padlock.sh" clamp . --generate >/dev/null 2>&1)
    
    if ./padlock.sh -D uninstall --purge-all-data > /dev/null 2>&1; then
        if [[ ! -d "$padlock_etc_dir" && ! -L "$link_path" && ! -d "$install_dir" ]]; then
            pass_test "completely removed"
        else
            fail_test "incomplete removal" || return 1
        fi
    else
        fail_test "forced uninstall failed" || return 1
    fi
    
    echo
}

print_summary() {
    echo
    printf "%b%b=== TEST SUMMARY ===%b\n" "$BOLD" "$YELLOW" "$RESET"
    printf "%b%b===================%b\n" "$BOLD" "$YELLOW" "$RESET"
    echo
    
    printf "Total Tests Run: %b%d%b\n" "$BOLD" "$TOTAL_TESTS" "$RESET"
    printf "Passed: %b%d%b\n" "$GREEN" "$PASSED_TESTS" "$RESET"
    printf "Failed: %b%d%b\n" "$RED" "$FAILED_TESTS" "$RESET"
    
    echo
    printf "%b%bDETAILED RESULTS:%b\n" "$BOLD" "$CYAN" "$RESET"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
    done
    
    echo
    if [[ "$FAILED_TESTS" -eq 0 ]]; then
        printf "%b%b*** ALL TESTS PASSED! ***%b\n" "$BOLD" "$GREEN" "$RESET"
        printf "%b%bPadlock is ready for production!%b\n" "$BOLD" "$GREEN" "$RESET"
        return 0
    else
        printf "%b%b*** SOME TESTS FAILED ***%b\n" "$BOLD" "$RED" "$RESET"
        printf "%b%bPlease review the errors above.%b\n" "$BOLD" "$RED" "$RESET"
        return 1
    fi
}

main() {
    if [[ ! -x ./padlock.sh ]]; then
        echo "ERROR: ./padlock.sh is not executable. Run: chmod +x ./padlock.sh"
        exit 1
    fi
    
    print_header
    
    local basic_result=0
    local git_result=0
    local install_result=0
    
    run_basic_tests || basic_result=$?
    run_e2e_test "git" || git_result=$?
    run_install_tests || install_result=$?
    
    local summary_result=0
    print_summary || summary_result=$?
    
    if [[ $basic_result -ne 0 || $git_result -ne 0 || $install_result -ne 0 || $summary_result -ne 0 ]]; then
        exit 1
    else
        exit 0
    fi
}

main "$@"
