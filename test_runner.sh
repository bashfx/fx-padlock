#!/usr/bin/env bash
# test_runner.sh - Basic and E2E tests for padlock.sh

# Exit immediately if a command exits with a non-zero status.
set -e

echo "=== Running Basic Padlock Tests ==="
echo

# Ensure padlock.sh is executable
if [ ! -x ./padlock.sh ]; then
    echo "ERROR: ./padlock.sh is not executable. Run chmod +x ./padlock.sh"
    exit 1
fi

echo "--> Testing './padlock.sh --help'..."
./padlock.sh --help > /dev/null
echo "OK"
echo

echo "--> Testing './padlock.sh version'..."
./padlock.sh version > /dev/null
echo "OK"
echo

run_e2e_test() {
    local test_type="$1"
    local repo_cmd=""

    echo
    echo "=== Running End-to-End Workflow Test ($test_type) ==="
    echo

    # 1. Create a temporary directory
    local test_dir
    test_dir=$(mktemp -d)
    echo "--> Created temp directory for test: $test_dir"

    # 2. Setup a trap to clean up the directory on exit
    # shellcheck disable=SC2064
    trap "echo '--> Cleaning up temp directory...'; rm -rf '$test_dir'" EXIT

    # Store current directory and cd into test dir
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir"

    # 3. Initialize a git or gitsim repository
    if [[ "$test_type" == "gitsim" ]]; then
        echo "--> Downloading gitsim.sh..."
        curl -sL "https://raw.githubusercontent.com/bashfx/fx-gitsim/refs/heads/main/gitsim.sh" > gitsim.sh
        chmod +x gitsim.sh
        repo_cmd="./gitsim.sh"
        echo "--> Initializing gitsim repo..."
        $repo_cmd init > /dev/null
    else
        repo_cmd="git"
        echo "--> Initializing git repo..."
        $repo_cmd init -b main > /dev/null
        $repo_cmd config user.email "test@example.com"
        $repo_cmd config user.name "Test User"
    fi
    echo "OK"

    # 4. Deploy padlock
    echo "--> Running 'padlock clamp'..."
    "$original_dir/padlock.sh" clamp . --generate > /dev/null
    echo "OK"

    # 5. Check that clamp worked
    echo "--> Verifying clamp results..."
    if [ ! -d "locker" ] || [ ! -f "bin/padlock" ]; then
        echo "ERROR: 'clamp' did not create locker/ and bin/padlock"
        exit 1
    fi
    # Check manifest
    local manifest_file="$HOME/.local/etc/padlock/manifest.txt"
    if ! grep -q -F -x "$test_dir" "$manifest_file"; then
        echo "ERROR: 'clamp' did not add repo to manifest"
        exit 1
    fi
    echo "OK"

    # 6. Create a test secret
    echo "--> Creating a secret file..."
    mkdir -p locker/docs_sec
    echo "secret content" > locker/docs_sec/test.md
    echo "OK"

    # 7. Run lock
    echo "--> Running 'padlock lock'..."
    # Need to add files for lock to work
    $repo_cmd add . > /dev/null
    ./bin/padlock lock > /dev/null
    echo "OK"

    # 8. Check that lock worked
    echo "--> Verifying lock results..."
    if [ -d "locker" ] || [ ! -f "locker.age" ] || [ ! -f ".locked" ]; then
        echo "ERROR: 'lock' did not remove locker/ and create locker.age + .locked"
        exit 1
    fi
    echo "OK"

    # 9. Run unlock (simulating `source .locked`)
    echo "--> Simulating 'source .locked' to unlock..."
    # shellcheck source=.locked
    source ./.locked > /dev/null
    echo "OK"

    # 10. Check that unlock worked
    echo "--> Verifying unlock results..."
    if [ ! -d "locker" ] || [ -f "locker.age" ] || [ -f ".locked" ]; then
        echo "ERROR: 'unlock' did not restore locker/ and remove locker.age + .locked"
        exit 1
    fi
    if [ ! -f "locker/docs_sec/test.md" ] || [[ "$(cat locker/docs_sec/test.md)" != "secret content" ]]; then
        echo "ERROR: Secret file content is incorrect after unlock."
        exit 1
    fi
    echo "OK"

    # Return to original directory
    cd "$original_dir"

    # The trap will handle cleanup
}

run_install_tests() {
    echo
    echo "=== Running Install/Uninstall Tests ==="
    echo

    # Define paths for clarity
    local install_dir="$HOME/.local/lib/fx/padlock"
    local link_path="$HOME/.local/bin/fx/padlock"
    local padlock_etc_dir="$HOME/.local/etc/padlock"

    # Cleanup any previous test runs
    rm -rf "$install_dir" "$link_path" "$padlock_etc_dir"

    # 1. Test install
    echo "--> Testing 'padlock install'..."
    ./padlock.sh install > /dev/null
    if [ ! -f "$install_dir/padlock.sh" ] || [ ! -L "$link_path" ]; then
        echo "ERROR: 'install' did not create script and symlink"
        exit 1
    fi
    echo "OK"

    # 2. Test safe uninstall (should fail)
    echo "--> Testing safe 'uninstall' (should fail)..."
    # First, clamp a repo to create a manifest entry
    local test_dir
    test_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$test_dir'" EXIT
    local original_dir
    original_dir=$(pwd)
    (cd "$test_dir" && git init -b main >/dev/null && "$original_dir/padlock.sh" clamp . --generate >/dev/null)
    # Now, try to uninstall (it should fail because the manifest is not empty)
    if ./padlock.sh uninstall > /dev/null; then
        echo "ERROR: 'uninstall' succeeded when it should have failed (safety check)."
        exit 1
    fi
    # Clean up the test repo for the next step
    rm -rf "$test_dir"
    echo "OK"

    # 3. Test forced uninstall
    echo "--> Testing forced 'uninstall --purge-all-data'..."
    # We need to re-clamp a repo to have something to purge
    test_dir=$(mktemp -d)
    # shellcheck disable=SC2064
    trap "rm -rf '$test_dir'" EXIT
    (cd "$test_dir" && git init -b main >/dev/null && "$original_dir/padlock.sh" clamp . --generate >/dev/null)
    # Now run the forced purge uninstall
    ./padlock.sh -D uninstall --purge-all-data > /dev/null
    if [ -d "$padlock_etc_dir" ] || [ -L "$link_path" ] || [ -d "$install_dir" ]; then
        echo "ERROR: Forced 'uninstall' did not remove all data and script files"
        exit 1
    fi
    echo "OK"
}

# Run all tests
run_e2e_test "git"
run_e2e_test "gitsim"
run_install_tests

echo
echo "================================"
echo "✓ All tests passed."
echo "================================"

exit 0
