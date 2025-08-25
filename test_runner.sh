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
    echo "--> Verifying clamp results (should have 'locker' dir)..."
    if [ ! -d "locker" ] || [ ! -f "bin/padlock" ]; then
        echo "ERROR: 'clamp' did not create locker/ and bin/padlock"
        exit 1
    fi
    # Check manifest
    local manifest_file="$HOME/.local/etc/padlock/manifest.txt"
    if ! grep -q "|$test_dir|" "$manifest_file"; then
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

run_ignition_test() {
    local test_type="$1"
    local repo_cmd=""

    echo
    echo "=== Running Ignition Workflow Test ($test_type) ==="
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

    # 4. Deploy padlock with ignition
    echo "--> Running 'padlock clamp --ignition'..."
    local ignition_key
    ignition_key=$("$original_dir/padlock.sh" clamp . --ignition 2>&1 | grep "Your ignition passphrase" | cut -d':' -f2 | xargs)
    echo "--> Ignition key: $ignition_key"
    echo "OK"

    # 5. Check that clamp worked
    echo "--> Verifying clamp results (should have 'locker' dir)..."
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

    # 7. Run ignite --lock to engage the chest
    echo "--> Running 'padlock ignite --lock'..."
    ./bin/padlock ignite --lock > /dev/null
    echo "OK"

    # 8. Check that the chest is locked correctly
    echo "--> Verifying chest lock results..."
    if [ -d "locker" ] || [ ! -d ".chest" ] || [ ! -f ".chest/locker.age" ]; then
        echo "ERROR: 'ignite --lock' did not create .chest/ and remove locker/"
        exit 1
    fi
    echo "OK"

    # 9. Run ignite --unlock
    echo "--> Running 'padlock ignite --unlock'..."
    PADLOCK_IGNITION_PASS="$ignition_key" ./bin/padlock ignite --unlock > /dev/null
    echo "OK"

    # 10. Check that unlock worked
    echo "--> Verifying chest unlock results..."
    if [ ! -d "locker" ] || [ -d ".chest" ]; then
        echo "ERROR: 'ignite --unlock' did not restore locker/ and remove .chest/"
        exit 1
    fi
    if [ ! -f "locker/docs_sec/test.md" ] || [[ "$(cat locker/docs_sec/test.md)" != "secret content" ]]; then
        echo "ERROR: Secret file content is incorrect after unlock."
        exit 1
    fi
    echo "OK"

    # 11. Lock the chest again to prepare for rotation test
    echo "--> Locking chest again for rotation test..."
    ./bin/padlock ignite --lock > /dev/null
    echo "OK"

    # 12. Rotate the ignition key
    echo "--> Rotating ignition key..."
    local new_ignition_key
    # Pipe the old key into the command, then grep the output for the new key
    new_ignition_key=$(echo "$ignition_key" | ./bin/padlock rotate --ignition | grep "Your new ignition passphrase" | cut -d':' -f2 | xargs)
    echo "--> New ignition key: $new_ignition_key"
    if [ -z "$new_ignition_key" ] || [ "$new_ignition_key" == "$ignition_key" ]; then
        echo "ERROR: Key rotation failed or did not produce a new key."
        exit 1
    fi
    echo "OK"

    # 13. Unlock with the NEW key
    echo "--> Unlocking with NEW ignition key..."
    PADLOCK_IGNITION_PASS="$new_ignition_key" ./bin/padlock ignite --unlock > /dev/null
    echo "OK"

    # 14. Final verification
    echo "--> Verifying final unlock results..."
    if [ ! -d "locker" ] || [ -d ".chest" ]; then
        echo "ERROR: 'ignite --unlock' with new key did not restore locker/ and remove .chest/"
        exit 1
    fi
    if [[ "$(cat locker/docs_sec/test.md)" != "secret content" ]]; then
        echo "ERROR: Secret file content is incorrect after final unlock."
        exit 1
    fi
    echo "OK"

    # Return to original directory
    cd "$original_dir"

    # The trap will handle cleanup
}

run_master_unlock_test() {
    echo
    echo "=== Running Master Unlock Test ==="
    echo

    # 1. Create temporary directories for test repo and fake XDG home
    local test_dir
    test_dir=$(mktemp -d)
    local fake_xdg_etc
    fake_xdg_etc=$(mktemp -d)
    echo "--> Created temp directory for test: $test_dir"
    echo "--> Created fake XDG directory for master key: $fake_xdg_etc"

    # 2. Setup a trap to clean up the directories on exit
    # shellcheck disable=SC2064
    trap "echo '--> Cleaning up temp directories...'; rm -rf '$test_dir' '$fake_xdg_etc'" EXIT

    # 3. Set the XDG_ETC_HOME to our fake directory
    export XDG_ETC_HOME="$fake_xdg_etc"

    # Store current directory and cd into test dir
    local original_dir
    original_dir=$(pwd)
    cd "$test_dir"

    # 4. Initialize a git repository
    echo "--> Initializing git repo..."
    git init -b main > /dev/null
    git config user.email "test@example.com"
    git config user.name "Test User"
    echo "OK"

    # 5. Run install to generate master key in our fake home
    echo "--> Running 'padlock install' to generate master key..."
    "$original_dir/padlock.sh" install > /dev/null
    echo "OK"

    # 6. Deploy padlock
    echo "--> Running 'padlock clamp'..."
    "$original_dir/padlock.sh" clamp . --generate > /dev/null
    echo "OK"

    # 7. Create a test secret
    echo "--> Creating a secret file..."
    mkdir -p locker/docs_sec
    echo "secret content" > locker/docs_sec/test.md
    echo "OK"

    # 8. Run lock
    echo "--> Running 'padlock lock'..."
    git add . > /dev/null
    ./bin/padlock lock > /dev/null
    echo "OK"

    # 9. Remove the REPO-SPECIFIC key to simulate key loss
    echo "--> Simulating repository key loss..."
    # Note: $XDG_ETC_HOME is our fake home
    rm -f "$XDG_ETC_HOME/padlock/keys/$(basename "$test_dir").key"
    echo "OK"

    # 10. Run master-unlock
    echo "--> Running 'padlock master-unlock'..."
    "$original_dir/padlock.sh" master-unlock > /dev/null
    echo "OK"

    # 11. Check that unlock worked
    echo "--> Verifying unlock results..."
    if [ ! -d "locker" ] || [ -f "locker.age" ] || [ -f ".locked" ]; then
        echo "ERROR: 'master-unlock' did not restore locker/ and remove locker.age + .locked"
        exit 1
    fi
    if [ ! -f "locker/docs_sec/test.md" ] || [[ "$(cat locker/docs_sec/test.md)" != "secret content" ]]; then
        echo "ERROR: Secret file content is incorrect after unlock."
        exit 1
    fi
    echo "OK"

    # Return to original directory
    cd "$original_dir"

    # Unset the env var to avoid affecting other tests
    unset XDG_ETC_HOME

    # The trap will handle cleanup
}

run_manifest_tests() {
    echo
    echo "=== Running Manifest Tests ==="
    echo

    # 1. Setup a fake XDG home
    local fake_xdg_etc
    fake_xdg_etc=$(mktemp -d)
    export XDG_ETC_HOME="$fake_xdg_etc"
    local manifest_file="$XDG_ETC_HOME/padlock/manifest.txt"
    echo "--> Created fake XDG directory for manifest test: $fake_xdg_etc"

    # 2. Setup a trap to clean up
    # shellcheck disable=SC2064
    trap "echo '--> Cleaning up temp directories...'; rm -rf '$fake_xdg_etc'" EXIT

    # 3. Setup test repos
    local original_dir
    original_dir=$(pwd)

    # Repo 1: Standard, local
    local repo1_dir
    repo1_dir=$(mktemp -d)
    (cd "$repo1_dir" && git init -b main >/dev/null && "$original_dir/padlock.sh" -D clamp . --generate >/dev/null)
    echo "--> Clamped standard local repo: $repo1_dir"

    # Repo 2: Ignition, with github remote
    local repo2_dir
    repo2_dir=$(mktemp -d)
    (cd "$repo2_dir" && git init -b main >/dev/null && git remote add origin git@github.com:testuser/test-repo.git && "$original_dir/padlock.sh" -D clamp . --ignition >/dev/null)
    echo "--> Clamped ignition github repo: $repo2_dir"

    # Repo 3: Temporary repo
    local repo3_dir
    repo3_dir=$(mktemp -d -p /tmp)
    (cd "$repo3_dir" && git init -b main >/dev/null && "$original_dir/padlock.sh" -D clamp . >/dev/null)
    echo "--> Clamped temporary repo: $repo3_dir"

    # 4. Verify manifest content
    echo "--> Verifying manifest format..."
    if ! grep -q "local|$(basename "$repo1_dir")|$repo1_dir|standard|" "$manifest_file"; then
        echo "ERROR: Standard local repo not found in manifest correctly."
        exit 1
    fi
    if ! grep -q "testuser|test-repo|$repo2_dir|ignition|git@github.com:testuser/test-repo.git" "$manifest_file"; then
        echo "ERROR: Ignition github repo not found in manifest correctly."
        exit 1
    fi
    if ! grep -q "|temp=true" "$manifest_file"; then
        echo "ERROR: Temporary repo not marked with metadata."
        exit 1
    fi
    echo "OK"

    # 5. Test 'padlock list'
    echo "--> Testing 'padlock list' command..."
    if [[ $("$original_dir/padlock.sh" list | wc -l) -ne 2 ]]; then
        echo "ERROR: 'padlock list' should return 2 non-temp repos."
        exit 1
    fi
    if ! ("$original_dir/padlock.sh" list --ignition | grep -q "test-repo"); then
        echo "ERROR: 'padlock list --ignition' failed."
        exit 1
    fi
    if ! ("$original_dir/padlock.sh" list --namespace testuser | grep -q "test-repo"); then
        echo "ERROR: 'padlock list --namespace' failed."
        exit 1
    fi
    if [[ $("$original_dir/padlock.sh" list --all | wc -l) -ne 3 ]]; then
        echo "ERROR: 'padlock list --all' should return all 3 repos."
        exit 1
    fi
    echo "OK"

    # 6. Test 'padlock clean-manifest'
    echo "--> Testing 'padlock clean-manifest'..."
    # First, remove one of the "real" repos to simulate staleness
    rm -rf "$repo1_dir"
    "$original_dir/padlock.sh" clean-manifest > /dev/null
    if [[ $("$original_dir/padlock.sh" list --all | wc -l) -ne 1 ]]; then
        echo "ERROR: 'clean-manifest' did not prune stale and temp entries."
        exit 1
    fi
    if ("$original_dir/padlock.sh" list --all | grep -q "$(basename "$repo1_dir")"); then
        echo "ERROR: 'clean-manifest' did not remove stale repo."
        exit 1
    fi
    if ("$original_dir/padlock.sh" list --all | grep -q "$(basename "$repo3_dir")"); then
        echo "ERROR: 'clean-manifest' did not remove temp repo."
        exit 1
    fi
    echo "OK"

    # 7. Cleanup
    rm -rf "$repo2_dir" "$repo3_dir"
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

echo
echo "================================"
echo "✓ All tests passed."
echo "================================"

exit 0
