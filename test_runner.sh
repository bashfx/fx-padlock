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

# Run all tests
run_e2e_test "git"
run_e2e_test "gitsim"

echo
echo "================================"
echo "✓ All tests passed."
echo "================================"

exit 0
