# TEST PLAN - Ignition API Phase 1

## Testing Framework Requirements

This test plan implements the **mandatory gitsim security testing framework** specified in PILOT_PLANX.md. ALL security features must be tested with gitsim environment virtualization.

## Test Categories

### 1. Build Integration Tests
**Purpose**: Verify parts/ changes integrate correctly with Build.sh pattern

```bash
test_build_integration() {
    # Verify build completes successfully
    ./build.sh
    
    # Syntax validation
    bash -n padlock.sh
    
    # Size validation (should be reasonable growth from ~6231 lines)
    local lines=$(wc -l < padlock.sh)
    [[ $lines -lt 8000 ]] || fail "Script too large: $lines lines"
    
    # Function presence validation
    grep -q "_age_interactive_encrypt" padlock.sh || fail "TTY encrypt function missing"
    grep -q "_age_interactive_decrypt" padlock.sh || fail "TTY decrypt function missing"
    grep -q "_derive_ignition_key" padlock.sh || fail "Key derivation function missing"
}
```

### 2. TTY Subversion Functional Tests
**Purpose**: Validate the core Age TTY Subversion technique

```bash
test_tty_subversion_encrypt_decrypt() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Create test content
    echo "test secret content" > test.txt
    
    # Test encryption
    if _age_interactive_encrypt "test.txt" "encrypted.age" "test-passphrase-123"; then
        [[ -f "encrypted.age" ]] || fail "Encryption did not create output file"
        [[ ! -f "test.txt" ]] && fail "Original file should still exist"
    else
        fail "TTY subversion encryption failed"
    fi
    
    # Test decryption
    local decrypted_content
    if decrypted_content=$(_age_interactive_decrypt "encrypted.age" "test-passphrase-123"); then
        [[ "$decrypted_content" == "test secret content" ]] || fail "Decrypted content mismatch"
    else
        fail "TTY subversion decryption failed"
    fi
    
    # Test wrong passphrase
    if _age_interactive_decrypt "encrypted.age" "wrong-passphrase" >/dev/null 2>&1; then
        fail "Wrong passphrase should fail decryption"
    fi
    
    rm -rf "$test_dir"
}
```

### 3. Security Tests (gitsim Required)

#### 3.1 Master Key Authority Validation
```bash
test_master_key_authority_gitsim() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Initialize gitsim environment
    gitsim init
    gitsim config user.name "Test User"
    gitsim config user.email "test@example.com"
    
    # Setup padlock with ignition
    ../padlock.sh clamp . --generate
    
    # Create ignition key
    ../padlock.sh ignite create test-key --phrase="strong-pass-123"
    
    # Verify master key authority is required
    local master_key=".padlock/master.key"
    [[ -f "$master_key" ]] || fail "Master key not found"
    
    # Simulate master key corruption
    mv "$master_key" "$master_key.backup"
    
    # Test that operations fail without master key
    if ../padlock.sh ignite unlock test-key --phrase="strong-pass-123" 2>/dev/null; then
        fail "SECURITY FAILURE: Ignition worked without master key authority"
    fi
    
    # Restore master key
    mv "$master_key.backup" "$master_key"
    
    # Verify operations work with master key
    if ! ../padlock.sh ignite unlock test-key --phrase="strong-pass-123" 2>/dev/null; then
        fail "Operations should work with valid master key"
    fi
    
    cd /tmp && rm -rf "$test_dir"
}
```

#### 3.2 Passphrase Strength Enforcement
```bash
test_passphrase_strength_gitsim() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    ../padlock.sh clamp . --generate
    
    # Test weak passphrases are rejected
    local weak_passphrases=("123" "password" "abc123" "short")
    local failed_tests=0
    
    for weak_pass in "${weak_passphrases[@]}"; do
        if ../padlock.sh ignite create weak-test --phrase="$weak_pass" 2>/dev/null; then
            error "SECURITY FAILURE: Weak passphrase accepted: $weak_pass"
            ((failed_tests++))
        fi
    done
    
    # Test strong passphrase is accepted  
    if ! ../padlock.sh ignite create strong-test --phrase="StrongPass123!@#" 2>/dev/null; then
        error "Strong passphrase incorrectly rejected"
        ((failed_tests++))
    fi
    
    cd /tmp && rm -rf "$test_dir"
    [[ $failed_tests -eq 0 ]] || fail "Passphrase validation failed"
}
```

#### 3.3 Environment Variable Security
```bash
test_env_var_security_gitsim() {
    local test_dir=$(mktemp -d)  
    cd "$test_dir"
    
    gitsim init
    ../padlock.sh clamp . --generate
    ../padlock.sh ignite create env-test --phrase="env-test-pass-456"
    
    # Set environment variable
    export PADLOCK_IGNITION_PASS="secret-env-passphrase"
    
    # Use ignition with env var
    ../padlock.sh ignite unlock env-test
    
    # Verify env var is cleared after use
    if [[ -n "$PADLOCK_IGNITION_PASS" ]]; then
        fail "SECURITY FAILURE: Environment variable not cleared after use"
    fi
    
    # Test that passphrase doesn't leak to process list
    export PADLOCK_IGNITION_PASS="test-leak-detection"
    
    # Run ignition in background to check process list
    ../padlock.sh ignite unlock env-test &
    local pid=$!
    
    # Check if passphrase appears in process info
    if ps aux | grep -v grep | grep -q "test-leak-detection"; then
        kill $pid 2>/dev/null || true
        fail "SECURITY FAILURE: Passphrase visible in process list"
    fi
    
    wait $pid 2>/dev/null || true
    unset PADLOCK_IGNITION_PASS
    cd /tmp && rm -rf "$test_dir"
}
```

#### 3.4 Metadata Corruption Recovery
```bash
test_metadata_corruption_gitsim() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init  
    ../padlock.sh clamp . --generate
    ../padlock.sh ignite create metadata-test --phrase="metadata-pass-789"
    
    # Corrupt metadata file
    echo "invalid json" > ".padlock/ignition/metadata/metadata-test.json"
    
    # Test recovery mechanism
    if ! _recover_metadata_corruption ".padlock/ignition/keys/metadata-test.ikey"; then
        fail "Metadata recovery mechanism failed"
    fi
    
    # Verify key still works after recovery
    if ! ../padlock.sh ignite unlock metadata-test --phrase="metadata-pass-789"; then
        fail "Key not functional after metadata recovery"
    fi
    
    cd /tmp && rm -rf "$test_dir"
}
```

#### 3.5 Cache Security Validation
```bash
test_cache_security_gitsim() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    ../padlock.sh clamp . --generate
    ../padlock.sh ignite create cache-test --phrase="cache-test-pass"
    
    # Check cache directory permissions
    local cache_dir=".padlock/ignition/.derived"
    if [[ -d "$cache_dir" ]]; then
        local perms=$(stat -c %a "$cache_dir" 2>/dev/null || stat -f %A "$cache_dir")
        [[ "$perms" == "700" ]] || fail "Cache directory permissions too permissive: $perms"
        
        # Check cache file permissions
        for cache_file in "$cache_dir"/*.key; do
            if [[ -f "$cache_file" ]]; then
                local file_perms=$(stat -c %a "$cache_file" 2>/dev/null || stat -f %A "$cache_file")
                [[ "$file_perms" == "600" ]] || fail "Cache file permissions too permissive: $file_perms"
            fi
        done
    fi
    
    cd /tmp && rm -rf "$test_dir"
}
```

### 4. Performance Tests
**Purpose**: Validate Plan X benchmark requirements (~0.240s)

```bash
test_ignition_performance() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    ../padlock.sh clamp . --generate
    
    # Benchmark key creation
    local start_time=$(date +%s.%3N)
    ../padlock.sh ignite create perf-test --phrase="performance-test-pass"
    local create_time=$(date +%s.%3N)
    local create_duration=$(echo "$create_time - $start_time" | bc -l)
    
    # Benchmark unlock operation  
    start_time=$(date +%s.%3N)
    ../padlock.sh ignite unlock perf-test --phrase="performance-test-pass"
    local unlock_time=$(date +%s.%3N)
    local unlock_duration=$(echo "$unlock_time - $start_time" | bc -l)
    
    # Validate performance (Plan X benchmark: 0.240s)
    if (( $(echo "$create_duration > 1.0" | bc -l) )); then
        warn "Key creation slow: ${create_duration}s (target: <1.0s)"
    fi
    
    if (( $(echo "$unlock_duration > 0.5" | bc -l) )); then
        warn "Key unlock slow: ${unlock_duration}s (target: <0.5s)"
    fi
    
    info "Performance - Create: ${create_duration}s, Unlock: ${unlock_duration}s"
    cd /tmp && rm -rf "$test_dir"
}
```

### 5. Integration Tests
**Purpose**: Validate compatibility with existing padlock workflows

```bash
test_ignition_integration() {
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    
    # Standard padlock workflow
    ../padlock.sh clamp . --generate
    mkdir -p locker/docs_sec
    echo "secret content" > locker/docs_sec/test.txt
    
    # Add ignition system
    ../padlock.sh ignite create integration-test --phrase="integration-pass"
    
    # Test that standard operations still work
    ../padlock.sh lock || fail "Standard lock broken with ignition"
    [[ -f ".chest/locker.age" ]] || fail "Chest pattern broken with ignition"
    
    ../padlock.sh unlock || fail "Standard unlock broken with ignition"
    [[ -d "locker" ]] || fail "Locker restoration broken with ignition"
    [[ -f "locker/docs_sec/test.txt" ]] || fail "Content integrity broken with ignition"
    
    cd /tmp && rm -rf "$test_dir"
}
```

## Test Execution Plan

### Phase 1 Validation Sequence
1. **Build Integration** → Verify parts/ changes compile correctly
2. **TTY Subversion** → Validate core cryptographic functions  
3. **Security (gitsim)** → Comprehensive security scenario testing
4. **Performance** → Benchmark validation against Plan X requirements
5. **Integration** → Compatibility with existing workflows

### Acceptance Criteria
- [ ] All build integration tests pass
- [ ] TTY subversion functions work correctly with age encryption
- [ ] ALL gitsim security tests pass (no exceptions)
- [ ] Performance within acceptable limits (create <1.0s, unlock <0.5s)
- [ ] No regression in existing padlock functionality
- [ ] BashFX v3.0 architecture compliance maintained

### Risk Areas Requiring Extra Validation
1. **TTY Subversion**: Complex script command interaction with age
2. **Master Key Authority**: Integration with existing authority system
3. **Environment Variable Handling**: Secure cleanup and no process leakage
4. **Cache Security**: Proper file permissions and cleanup
5. **Metadata Recovery**: Robust handling of corruption scenarios

## Notes for QA Validation
- **NO STUBBED TESTS**: All security tests must use real gitsim environments
- **NO SHORTCUTS**: Security validation cannot be skipped or mocked
- **COMPREHENSIVE**: Every security scenario from PILOT_PLANX.md must be tested
- **REPEATABLE**: Tests must work consistently across different environments

This test plan ensures the ignition system meets the high security and performance standards required for production deployment.