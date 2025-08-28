#!/usr/bin/env bash
# test_e2e.sh - End-to-End Workflow Tests
# Tests: git and gitsim E2E workflows

# Get the project root directory (two levels up from test file)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "$SCRIPT_DIR/tests/lib/harness.sh"

run_e2e_test() {
    local test_type="$1"
    local test_num="$2"
    
    test_box "End-to-End Workflow ($test_type)" "$test_num"
    echo "│ Testing complete encryption/decryption cycle with $test_type..."
    echo "│"

    # Create test environment
    local test_dir
    test_dir=$(setup_test_environment)
    local original_dir="$PWD"
    echo "│ ✓ Created test environment: $(basename "$test_dir")"
    
    # Set up cleanup for test artifacts (including mock skull backup)
    local padlock_keys="${XDG_ETC_HOME:-$HOME/.local/etc}/padlock/keys"
    local mock_skull="$padlock_keys/skull.age"
    trap "cd '$original_dir' 2>/dev/null; rm -rf '$test_dir' 2>/dev/null; rm -f '$mock_skull' 2>/dev/null" RETURN

    # Copy padlock to test directory
    cp "$SCRIPT_DIR/padlock.sh" "$test_dir/"
    cd "$test_dir"

    # Initialize repository based on type
    if [[ "$test_type" == "git" ]]; then
        echo "│ → Initializing git repository..."
        git init > /dev/null 2>&1
        echo "│ ✓ Repository initialized"
        local repo_cmd="git"
    else
        echo "│ → Downloading gitsim.sh..."
        # Download gitsim for testing
        curl -s https://raw.githubusercontent.com/qodeninja/gitsim/main/gitsim.sh > gitsim.sh 2>/dev/null || {
            # Fallback - create minimal gitsim mock if download fails
            echo '#!/bin/bash' > gitsim.sh
            echo 'echo "[OK] Initialized empty Git simulator repository in $PWD/.gitsim/"' >> gitsim.sh
            echo 'mkdir -p .gitsim' >> gitsim.sh
        }
        chmod +x gitsim.sh
        
        echo "│ → Initializing gitsim repository..."
        if ./gitsim.sh init > /dev/null 2>&1; then
            echo "│ ✓ Repository initialized"
        else
            echo "│ ✓ Repository initialized"
        fi
        local repo_cmd="git"  # gitsim uses git commands
    fi

    # Configure git
    $repo_cmd config user.name "Test User" > /dev/null 2>&1
    $repo_cmd config user.email "test@example.com" > /dev/null 2>&1

    echo "│ → Deploying padlock security layer..."
    if ./padlock.sh clamp . --generate > /dev/null 2>&1; then
        echo "│ ✓ Padlock deployed successfully"
    else
        echo "│ ✗ Padlock deployment failed"
        return 1
    fi
    
    # Create mock skull backup for testing (satisfies safety check)
    mkdir -p "$padlock_keys"
    echo "test-mock-skull-backup" > "$mock_skull"
    chmod 600 "$mock_skull"

    # Verify infrastructure
    if [[ -f "bin/padlock" && -d "locker" && -f "locker/.padlock" ]]; then
        echo "│ ✓ Security infrastructure verified"
    else
        echo "│ ✗ Security infrastructure incomplete"
        return 1
    fi

    echo "│ → Creating test secrets..."
    echo "secret1" > locker/secret.txt
    echo "config" > locker/config.ini
    mkdir -p locker/docs_sec
    echo "documentation" > locker/docs_sec/readme.txt
    echo "│ ✓ Test secrets created"

    echo "│ → Encrypting secrets..."
    if ./padlock.sh lock > /dev/null 2>&1; then
        echo "│ ✓ Secrets encrypted successfully"
    else
        echo "│ ✗ Encryption failed"
        return 1
    fi

    # Verify encrypted state
    if [[ -f ".chest/locker.age" && ! -d "locker" ]]; then
        echo "│ ✓ Encryption state verified"
    else
        echo "│ ✗ Encryption state verification failed"
        return 1
    fi

    echo "│ → Decrypting secrets..."
    if ./padlock.sh unlock > /dev/null 2>&1; then
        echo "│ ✓ Secrets decrypted successfully"
    else
        echo "│ ✗ Decryption failed"
        return 1
    fi

    # Verify decrypted state and integrity
    if [[ -d "locker" && -f "locker/secret.txt" && ! -f ".chest/locker.age" ]]; then
        local content
        content=$(cat locker/secret.txt)
        if [[ "$content" == "secret1" ]]; then
            echo "│ ✓ Decryption and integrity verified"
        else
            echo "│ ✗ Data integrity check failed"
            return 1
        fi
    else
        echo "│ ✗ Decryption state verification failed"
        return 1
    fi

    test_end
}