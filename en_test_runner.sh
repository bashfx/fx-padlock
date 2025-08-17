#!/usr/bin/env bash
# Enhanced test_runner.sh - Comprehensive test suite for padlock.sh
# Features: Numbered tests, clear titles, summary with celebration

set -e

# Colors and formatting
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

# Test results storage
declare -a TEST_RESULTS=()

print_header() {
    echo
    printf "%b%b🔐 PADLOCK TEST SUITE 🔐%b\n" "$BOLD" "$CYAN" "$RESET"
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
    printf "%b✓ PASS%b" "$GREEN" "$RESET"
    if [[ -n "$details" ]]; then
        printf " %b(%s)%b" "$CYAN" "$details" "$RESET"
    fi
    echo
    TEST_RESULTS+=("✓ Test $CURRENT_TEST: PASSED")
}

fail_test() {
    local error_msg="$1"
    ((FAILED_TESTS++))
    printf "%b✗ FAIL%b\n" "$RED" "$RESET"
    printf "%b    Error: %s%b\n" "$RED" "$error_msg" "$RESET"
    TEST_RESULTS+=("✗ Test $CURRENT_TEST: FAILED - $error_msg")
    exit 1
}

run_basic_tests() {
    echo "📋 BASIC FUNCTIONALITY TESTS"
    echo "─────────────────────────────"
    
    # Test 1: Help system
    start_test "Help System (--help)"
    if ./padlock.sh --help > /dev/null 2>&1; then
        pass_test "help displayed"
    else
        fail_test "help command failed"
    fi
    
    # Test 2: Version display
    start_test "Version Display"
    local version_output
    if version_output=$(./padlock.sh version 2>/dev/null); then
        pass_test "v$(echo "$version_output" | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')"
    else
        fail_test "version command failed"
    fi
    
    # Test 3: Syntax check
    start_test "Script Syntax Validation"
    if bash -n ./padlock.sh; then
        pass_test "syntax valid"
    else
        fail_test "syntax errors detected"
    fi
    
    echo
}

run_e2e_test() {
    local test_type="$1"
    local test_num_start=$((CURRENT_TEST + 1))
    
    echo "🔄 END-TO-END WORKFLOW TEST ($test_type)"
    echo "────────────────────────────────────────"
    
    # Create temporary directory
    local test_dir
    test_dir=$(mktemp -d)
    local cleanup_done=false
    
    # Setup cleanup trap
    cleanup() {
        if [[ "$cleanup_done" == false ]]; then
            cleanup_done=true
            rm -rf "$test_dir" 2>/dev/null || true
        fi
    }
    trap cleanup EXIT
    
    # Store current directory and cd into test dir
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir"
    
    # Test 4/8: Repository initialization
    start_test "Repository Initialization ($test_type)"
    if [[ "$test_type" == "gitsim" ]]; then
        if curl -sL "https://raw.githubusercontent.com/bashfx/fx-gitsim/refs/heads/main/gitsim.sh" > gitsim.sh; then
            chmod +x gitsim.sh
            if ./gitsim.sh init > /dev/null 2>&1; then
                pass_test "gitsim repo created"
            else
                fail_test "gitsim init failed"
            fi
        else
            fail_test "failed to download gitsim"
        fi
    else
        if git init -b main > /dev/null 2>&1; then
            git config user.email "test@example.com" > /dev/null 2>&1
            git config user.name "Test User" > /dev/null 2>&1
            pass_test "git repo created"
        else
            fail_test "git init failed"
        fi
    fi
    
    # Test 5/9: Padlock deployment
    start_test "Padlock Deployment (clamp)"
    if "$original_dir/padlock.sh" clamp . --generate > /dev/null 2>&1; then
        if [[ -d "locker" && -f "bin/padlock" ]]; then
            pass_test "structure created"
        else
            fail_test "deployment incomplete"
        fi
    else
        fail_test "clamp command failed"
    fi
    
    # Test 6/10: Secret file creation
    start_test "Secret Content Creation"
    if mkdir -p locker/docs_sec && echo "secret content" > locker/docs_sec/test.md; then
        if [[ -f "locker/docs_sec/test.md" ]]; then
            pass_test "secret file created"
        else
            fail_test "secret file not found"
        fi
    else
        fail_test "failed to create secret content"
    fi
    
    # Test 7/11: Encryption (lock)
    start_test "Locker Encryption (lock)"
    # Add files for git (required for lock to work)
    if [[ "$test_type" == "git" ]]; then
        git add . > /dev/null 2>&1 || true
    fi
    
    if ./bin/padlock lock > /dev/null 2>&1; then
        if [[ ! -d "locker" && -f "locker.age" && -f ".locked" ]]; then
            local size
            size=$(du -h locker.age 2>/dev/null | cut -f1 || echo "unknown")
            pass_test "encrypted to $size"
        else
            fail_test "lock state incorrect"
        fi
    else
        fail_test "lock command failed"
    fi
    
    # Test 8/12: Decryption (unlock)
    start_test "Locker Decryption (unlock)"
    # Simulate sourcing .locked (the way users actually unlock)
    if (source ./.locked > /dev/null 2>&1); then
        if [[ -d "locker" && ! -f "locker.age" && ! -f ".locked" ]]; then
            local content
            if content=$(cat locker/docs_sec/test.md 2>/dev/null) && [[ "$content" == "secret content" ]]; then
                pass_test "content verified"
            else
                fail_test "content corruption detected"
            fi
        else
            fail_test "unlock state incorrect"
        fi
    else
        fail_test "unlock failed"
    fi
    
    # Return to original directory
    cd "$original_dir"
    
    echo
}

run_install_tests() {
    echo "⚙️  INSTALLATION TESTS"
    echo "──────────────────────"
    
    # Define paths
    local install_dir="$HOME/.local/lib/fx/padlock"
    local link_path="$HOME/.local/bin/fx/padlock"
    local padlock_etc_dir="$HOME/.local/etc/padlock"
    
    # Cleanup any previous test runs
    rm -rf "$install_dir" "$link_path" "$padlock_etc_dir" 2>/dev/null || true
    
    # Test: Installation
    start_test "Global Installation"
    if ./padlock.sh install > /dev/null 2>&1; then
        if [[ -f "$install_dir/padlock.sh" && -L "$link_path" ]]; then
            pass_test "installed to system"
        else
            fail_test "installation incomplete"
        fi
    else
        fail_test "install command failed"
    fi
    
    # Test: Safety check (create a repo to manage)
    start_test "Uninstall Safety Check"
    local test_dir
    test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT
    
    local original_dir
    original_dir=$(pwd)
    (cd "$test_dir" && git init -b main >/dev/null 2>&1 && "$original_dir/padlock.sh" clamp . --generate >/dev/null 2>&1)
    
    # Try to uninstall (should fail due to safety check)
    if ! ./padlock.sh uninstall > /dev/null 2>&1; then
        pass_test "safety check active"
    else
        fail_test "safety check bypassed"
    fi
    
    # Clean up test repo
    rm -rf "$test_dir"
    
    # Test: Forced uninstall
    start_test "Forced Uninstall"
    # Re-create a test repo
    test_dir=$(mktemp -d)
    trap "rm -rf '$test_dir'" EXIT
    (cd "$test_dir" && git init -b main >/dev/null 2>&1 && "$original_dir/padlock.sh" clamp . --generate >/dev/null 2>&1)
    
    # Force uninstall with purge
    if ./padlock.sh -D uninstall --purge-all-data > /dev/null 2>&1; then
        if [[ ! -d "$padlock_etc_dir" && ! -L "$link_path" && ! -d "$install_dir" ]]; then
            pass_test "completely removed"
        else
            fail_test "incomplete removal"
        fi
    else
        fail_test "forced uninstall failed"
    fi
    
    echo
}

print_summary() {
    echo
    printf "%b%b📊 TEST SUMMARY%b\n" "$BOLD" "$YELLOW" "$RESET"
    printf "%b%b═══════════════%b\n" "$BOLD" "$YELLOW" "$RESET"
    echo
    
    printf "Total Tests Run: %b%d%b\n" "$BOLD" "$TOTAL_TESTS" "$RESET"
    printf "Passed: %b%s%d%b\n" "$GREEN" "✓ " "$PASSED_TESTS" "$RESET"
    printf "Failed: %b%s%d%b\n" "$RED" "✗ " "$FAILED_TESTS" "$RESET"
    
    echo
    printf "%b%bDETAILED RESULTS:%b\n" "$BOLD" "$CYAN" "$RESET"
    for result in "${TEST_RESULTS[@]}"; do
        echo "  $result"
    done
    
    echo
    if [[ "$FAILED_TESTS" -eq 0 ]]; then
        printf "%b%b🎉 ALL TESTS PASSED! 🎉%b\n" "$BOLD" "$GREEN" "$RESET"
        printf "%b%bPadlock is ready for production! 🚀%b\n" "$BOLD" "$GREEN" "$RESET"
    else
        printf "%b%b❌ SOME TESTS FAILED ❌%b\n" "$BOLD" "$RED" "$RESET"
        printf "%b%bPlease review the errors above.%b\n" "$BOLD" "$RED" "$RESET"
        exit 1
    fi
    echo
}

main() {
    # Ensure padlock.sh exists and is executable
    if [[ ! -x ./padlock.sh ]]; then
        echo "ERROR: ./padlock.sh is not executable. Run: chmod +x ./padlock.sh"
        exit 1
    fi
    
    print_header
    
    # Run all test suites
    run_basic_tests
    run_e2e_test "git"
    run_e2e_test "gitsim"
    run_install_tests
    
    # Print final summary
    print_summary
}

# Run the test suite
main "$@"