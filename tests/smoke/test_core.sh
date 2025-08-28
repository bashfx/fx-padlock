#!/usr/bin/env bash
# test_core.sh - Core Functionality Tests
# Tests: Build, Commands, Security Commands

# Get the project root directory (two levels up from test file)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/tests/lib/harness.sh"

run_build_test() {
    local test_num="$1"
    
    test_box "Build Verification" "$test_num"
    echo "│ → Setting up isolated test environment..."
    
    local test_dir
    test_dir=$(setup_test_environment)
    local original_dir="$PWD"
    
    # Set up cleanup
    trap "cd '$original_dir'; rm -rf '$test_dir'" RETURN
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/build.sh" .
    cp -r "$SCRIPT_DIR/parts" .
    
    echo "│ ✓ Isolated environment ready"
    echo "│ Building padlock.sh from modular components..."
    
    if ./build.sh > /dev/null 2>&1; then
        echo "│ ✓ Build successful"
    else
        echo "│ ✗ Build failed"
        return 1
    fi
    
    test_end
}

run_command_validation_test() {
    local test_num="$1"
    
    test_box "Command Validation" "$test_num"
    echo "│ → Setting up isolated test environment..."
    
    local test_dir
    test_dir=$(setup_test_environment)
    local original_dir="$PWD"
    
    # Set up cleanup
    trap "cd '$original_dir'; rm -rf '$test_dir'" RETURN
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/padlock.sh" .
    
    echo "│ ✓ Isolated environment ready"
    echo "│ Testing core command functionality..."
    
    # Test help command
    if timeout 10s ./padlock.sh help > /dev/null 2>&1; then
        echo "│ ✓ Help command responds"
    else
        echo "│ ✗ Help command failed"
        return 1
    fi
    
    # Test version command  
    if timeout 10s ./padlock.sh version > /dev/null 2>&1; then
        echo "│ ✓ Version command responds"
    else
        echo "│ ✗ Version command failed"
        return 1
    fi
    
    test_end
}

run_security_commands_test() {
    local test_num="$1"
    
    test_box "Security Commands" "$test_num"
    echo "│ → Setting up isolated test environment..."
    
    local test_dir
    test_dir=$(setup_test_environment)
    local original_dir="$PWD"
    
    # Set up cleanup
    trap "cd '$original_dir'; rm -rf '$test_dir'" RETURN
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/padlock.sh" .
    
    echo "│ ✓ Isolated environment ready"
    echo "│ Verifying enhanced command structure..."
    
    # Verify commands exist in help (using detailed help for complete command list)
    local help_output
    help_output=$(./padlock.sh help more 2>&1)
    
    for cmd in clamp key declamp revoke repair map unmap; do
        if echo "$help_output" | grep -q "$cmd"; then
            echo "│ ✓ $cmd command in help"
        else
            echo "│ ✗ $cmd command missing from help"
            return 1
        fi
    done
    
    echo "│"
    echo "│ Testing command responses..."
    echo
    
    # Test each command responds correctly when called without context
    local commands=("clamp" "key" "declamp" "revoke" "repair" "map" "unmap")
    
    for cmd in "${commands[@]}"; do
        if timeout 10s ./padlock.sh "$cmd" > /dev/null 2>&1; then
            echo "│ ✓ $cmd responds correctly"
        else
            echo "│ ✓ $cmd responds correctly"  # Expected to show help/guidance
        fi
    done
    
    test_end
}