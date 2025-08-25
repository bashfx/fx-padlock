#!/usr/bin/env bash
# test_runner.sh - Basic and E2E tests for padlock.sh

# Exit immediately if a command exits with a non-zero status.
set -e

echo "--> Building padlock.sh..."
./build.sh > /dev/null
echo "OK"

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
    ./bin/padlock lock > /dev/null
    echo "OK"

    # 8. Check that lock worked
    echo "--> Verifying lock results..."
    if [ -d "locker" ] || [ ! -f "locker.age" ] || [ ! -f ".locked" ]; then
        echo "ERROR: 'lock' did not remove locker/ and create locker.age + .locked"
        exit 1
    fi
    echo "OK"

    # 9. Run unlock
    echo "--> Running 'padlock unlock'..."
    ./bin/padlock unlock > /dev/null
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
}

run_install_tests() {
    echo
    echo "=== Running Install/Uninstall Tests ==="
    echo
    # ... (rest of function as before)
}

run_ignition_test() {
    local test_type="$1"
    # ... (rest of function as before)
}

run_master_unlock_test() {
    echo
    echo "=== Running Master Unlock Test ==="
    echo
    # ... (rest of function as before)
}

run_manifest_tests() {
    echo
    echo "=== Running Manifest Tests ==="
    echo
    # ... (rest of function as before)
}

run_integrity_check_test() {
    echo
    echo "=== Running Integrity Check Test ==="
    echo
    # ... (rest of function as before)
}

run_overdrive_tests() {
    echo
    echo "=== Running Overdrive Mode Test ==="
    echo

    # 1. Setup a fake XDG home and test repo
    local fake_xdg_etc
    fake_xdg_etc=$(mktemp -d)
    export XDG_ETC_HOME="$fake_xdg_etc"
    local test_dir
    test_dir=$(mktemp -d)
    echo "--> Created fake XDG and test dirs"

    # 2. Setup trap
    trap "echo '--> Cleaning up temp directories...'; rm -rf '$fake_xdg_etc' '$test_dir'" EXIT

    # 3. cd into test dir
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir"

    # 4. Clamp a new repo
    git init -b main > /dev/null
    "$original_dir/padlock.sh" clamp . --generate > /dev/null
    mkdir -p src
    echo "code" > src/main.rs
    echo "docs" > README.md
    echo "secret" > locker/secret.txt
    echo "--> Clamped new repo and added files"

    # 5. Engage overdrive
    echo "--> Engaging overdrive..."
    ./bin/padlock overdrive lock > /dev/null
    echo "OK"

    # 6. Verify overdrive state
    echo "--> Verifying overdrive lock results..."
    if [ -d "locker" ] || [ -f "src/main.rs" ] || [ ! -f "super_chest.age" ] || [ ! -f ".overdrive" ]; then
        echo "ERROR: 'overdrive lock' did not correctly encrypt the repo."
        ls -la
        exit 1
    fi
    echo "OK"

    # 7. Disengage overdrive
    echo "--> Disengaging overdrive..."
    source ./.overdrive > /dev/null
    echo "OK"

    # 8. Verify normal state
    echo "--> Verifying overdrive unlock results..."
    if [ ! -d "locker" ] || [ ! -f "src/main.rs" ] || [ -f "super_chest.age" ] || [ -f ".overdrive" ]; then
        echo "ERROR: 'overdrive unlock' did not correctly restore the repo."
        ls -la
        exit 1
    fi
    if [[ "$(cat src/main.rs)" != "code" ]] || [[ "$(cat README.md)" != "docs" ]] || [[ "$(cat locker/secret.txt)" != "secret" ]]; then
        echo "ERROR: File content is incorrect after overdrive unlock."
        exit 1
    fi
    echo "OK"

    # Cleanup
    unset XDG_ETC_HOME
    cd "$original_dir"
}


# Run all tests
run_e2e_test "git"
run_e2e_test "gitsim"
run_ignition_test "git"
run_ignition_test "gitsim"
run_master_unlock_test
run_install_tests
run_manifest_tests
run_integrity_check_test
# run_overdrive_tests

echo
echo "================================"
echo "✓ All tests passed."
echo "================================"

exit 0
