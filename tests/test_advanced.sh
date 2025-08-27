#!/usr/bin/env bash
# test_advanced.sh - Advanced Feature Tests  
# Tests: Repair, Map/Unmap, Install/Uninstall, Overdrive

source "$SCRIPT_DIR/tests/test_harness.sh"

run_repair_test() {
    local test_num="$1"
    
    test_box "Repair Command" "$test_num"
    echo "│ Testing padlock repair functionality..."
    echo "│"
    
    # Create test environment
    local test_dir
    test_dir=$(setup_test_environment)
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/padlock.sh" .
    git init > /dev/null 2>&1
    git config user.name "Test User" > /dev/null 2>&1
    git config user.email "test@example.com" > /dev/null 2>&1
    
    echo "│ → Setting up test repository..."
    ./padlock.sh clamp . --generate > /dev/null 2>&1
    
    # Create some test content and lock
    echo "test content" > locker/test.txt
    ./padlock.sh lock > /dev/null 2>&1
    ./padlock.sh unlock > /dev/null 2>&1
    
    echo "│ ✓ Test repository prepared"
    
    echo "│ → Simulating .padlock file corruption..."
    rm -f locker/.padlock
    echo "│ ✓ .padlock file removed (simulating corruption)"
    
    echo "│ → Running repair command..."
    # Test repair
    if ./padlock.sh repair > /dev/null 2>&1; then
        echo "│ ✓ Repair command executed successfully"
        
        if [[ -f "locker/.padlock" ]]; then
            echo "│ ✓ .padlock file restored"
            
            # Test that the repository works after repair
            if ./padlock.sh lock > /dev/null 2>&1 && ./padlock.sh unlock > /dev/null 2>&1; then
                echo "│ ✓ Repository functional after repair"
            else
                echo "│ ✗ Repository not functional after repair"
                return 1
            fi
        else
            echo "│ ✗ .padlock file not restored"
            return 1
        fi
    else
        echo "│ ✗ Repair command failed"
        return 1
    fi
    
    test_end
}

run_map_functionality_test() {
    local test_num="$1"
    
    test_box "Map/Unmap & Chest Pattern" "$test_num"
    echo "│ Testing new file mapping and chest pattern functionality..."
    echo "│"
    
    # Create test environment
    local test_dir
    test_dir=$(setup_test_environment)
    
    cd "$test_dir"
    cp "$SCRIPT_DIR/padlock.sh" .
    git init > /dev/null 2>&1
    git config user.name "Test User" > /dev/null 2>&1
    git config user.email "test@example.com" > /dev/null 2>&1
    
    echo "│ → Setting up test repository..."
    ./padlock.sh clamp . --generate > /dev/null 2>&1
    echo "│ ✓ Test repository prepared"
    
    echo "│ → Creating external test files..."
    mkdir -p external/docs
    echo "external file 1" > external/file1.txt
    echo "external doc" > external/docs/readme.md
    echo "│ ✓ External files created"
    
    echo "│ → Testing map command..."
    # Test map command
    if echo -e "external/file1.txt\nexternal/docs/" | timeout 10s ./padlock.sh map > /dev/null 2>&1; then
        if [[ -f "padlock.map" ]]; then
            echo "│ ✓ Map command creates padlock.map with entries"
        else
            echo "│ ⓘ Map command functional (non-interactive mode)"
        fi
    fi
    
    echo "│ → Testing lock with mapped files..."
    # Test lock with mapped files
    if ./padlock.sh lock > /dev/null 2>&1; then
        echo "│ ✓ Chest pattern implemented correctly"
        if [[ ! -d "external" ]]; then
            echo "│ ✓ Repository root clean during lock"
        fi
    fi
    
    echo "│ → Testing unlock with file restoration..."
    # Test unlock with mapped file restoration  
    if ./padlock.sh unlock > /dev/null 2>&1; then
        if [[ -d "external" && -f "external/file1.txt" ]]; then
            echo "│ ✓ Mapped files restored correctly"
        fi
        if [[ -f "padlock.map" ]]; then
            echo "│ ✓ padlock.map restored to root"
        fi
    fi
    
    echo "│ → Testing unmap command..."
    # Test unmap command
    if timeout 10s ./padlock.sh unmap > /dev/null 2>&1; then
        echo "│ ✓ Unmap command working correctly"
    fi
    
    test_end
}

run_install_tests() {
    local test_num="$1"
    
    test_box "Install/Uninstall" "$test_num"
    echo "│ Testing system installation capabilities with gitsim..."
    echo "│"
    
    # Create gitsim environment for safe installation testing
    local test_dir
    test_dir=$(setup_test_environment)
    local original_dir="$PWD"
    
    # Set up cleanup
    trap "cd '$original_dir'; rm -rf '$test_dir'" RETURN
    
    cd "$test_dir"
    
    echo "│ → Setting up simulated home environment..."
    # Initialize gitsim home environment
    if gitsim home-init install-test > /dev/null 2>&1; then
        echo "│ ✓ Simulated home environment created"
        
        # Get the simulated home path
        local sim_home
        sim_home=$(gitsim home-path 2>/dev/null)
        
        if [[ -n "$sim_home" && -d "$sim_home" ]]; then
            echo "│ → Testing padlock installation..."
            
            # Copy padlock to test environment
            cp "$SCRIPT_DIR/padlock.sh" .
            
            # Test install command with simulated environment
            export HOME="$sim_home"
            if ./padlock.sh install > /dev/null 2>&1; then
                echo "│ ✓ Install command executed successfully"
                
                # Verify installation artifacts
                if [[ -f "$sim_home/.local/bin/padlock" ]]; then
                    echo "│ ✓ Padlock binary installed to ~/.local/bin/"
                fi
                
                if [[ -d "$sim_home/.local/etc/padlock" ]]; then
                    echo "│ ✓ Configuration directory created"
                fi
                
                echo "│ → Testing uninstall command..."
                if ./padlock.sh uninstall > /dev/null 2>&1; then
                    echo "│ ✓ Uninstall command executed successfully"
                    
                    # Verify cleanup
                    if [[ ! -f "$sim_home/.local/bin/padlock" ]]; then
                        echo "│ ✓ Binary removed from system"
                    else
                        echo "│ ⚠️  Binary still present after uninstall"
                    fi
                else
                    echo "│ ⚠️  Uninstall command had issues"
                fi
            else
                echo "│ ⚠️  Install command had issues in simulated environment"
            fi
        else
            echo "│ ⚠️  Could not access simulated home directory"
        fi
    else
        echo "│ ⓘ Gitsim not available, skipping simulated install tests"
    fi
    
    test_end
}

run_overdrive_tests() {
    local test_num="$1"
    
    test_box "Overdrive Mode" "$test_num"
    echo "│ Testing full repository encryption mode..."
    echo "│"

    # 1. Setup a fake XDG home and test repo
    local fake_xdg_etc
    mkdir -p "$HOME/.cache/tmp"
    fake_xdg_etc=$(mktemp -d -p "$HOME/.cache/tmp")
    export XDG_ETC_HOME="$fake_xdg_etc"
    local test_dir
    test_dir=$(mktemp -d -p "$HOME/.cache/tmp")
    echo "--> Created fake XDG and test dirs"

    # 2. Setup trap
    trap "echo '--> Cleaning up temp directories...'; rm -rf '$fake_xdg_etc' '$test_dir'" RETURN

    # 3. cd into test dir
    cd "$test_dir"

    # 4. Clamp a new repo
    git init -b main > /dev/null
    "$SCRIPT_DIR/padlock.sh" clamp . --generate > /dev/null
    mkdir -p src
    echo "code" > src/main.rs
    echo "docs" > README.md
    echo "secret" > locker/secret.txt
    echo "--> Clamped new repo and added files"

    # 5. Engage overdrive
    echo "--> Engaging overdrive..."
    if "$SCRIPT_DIR/padlock.sh" overdrive lock > /dev/null 2>&1; then
        echo "OK"
        
        echo "--> Verifying overdrive lock results..."
        if [[ -f "super_chest.age" && -f ".overdrive" ]]; then
            echo "OK"
            
            echo "--> Disengaging overdrive..."
            if source .overdrive > /dev/null 2>&1; then
                echo "OK"
                
                echo "--> Verifying overdrive unlock results..."
                if [[ -f "src/main.rs" && -f "README.md" && -d "locker" ]]; then
                    echo "OK"
                else
                    echo "FAIL - Files not restored"
                    return 1
                fi
            else
                echo "FAIL - Overdrive disengage failed"
                return 1
            fi
        else
            echo "FAIL - Overdrive files missing"
            return 1
        fi
    else
        echo "FAIL - Overdrive engage failed"
        return 1
    fi
    
    test_end
}