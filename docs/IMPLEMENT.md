# 🔥 Padlock Ignition System - Implementation Plan

## Overview

This implementation plan provides step-by-step instructions for building the Padlock Ignition System. It's designed for Claude Code (or any developer) to follow systematically without confusion or architectural ambiguity.

**Estimated Timeline**: 7-10 days  
**Complexity**: High (cryptographic key management, BashFX architecture compliance)
**Prerequisites**: Understanding of age encryption, bash scripting, BashFX 2.1 patterns

---

## Phase 1: Foundation & Core Infrastructure (2-3 days)

### **Step 1.1: Fix Dispatcher Routing**
**File**: `parts/07_core.sh`  
**Issue**: `ignite` command exists but not routed in dispatcher

```bash
# Current dispatcher (missing ignite):
case "$command" in
    clamp) do_clamp "$@" ;;
    setup) do_setup "$@" ;;
    # ... other commands ...
    # MISSING: ignite) do_ignite "$@" ;;
esac

# Required fix:
case "$command" in
    clamp) do_clamp "$@" ;;
    ignite) do_ignite "$@" ;;  # ADD THIS LINE
    setup) do_setup "$@" ;;    # Remove duplicate if exists
    # ... other commands ...
esac
```

**Validation**: `padlock ignite --help` should show help instead of "unknown command"

### **Step 1.2: Analyze Existing do_ignite Function**
**File**: `parts/06_api.sh`  
**Current State**: Stub implementation with incorrect skull key usage

**Analysis Required**:
```bash
# Review current do_ignite() function
# Identify what can be salvaged vs needs rewriting
# Document current --unlock, --lock, --status behavior
# Plan migration to proper I/D key model
```

**Deliverable**: Analysis document of current state and migration plan

### **Step 1.3: Create Ignition Directory Structure**
**Location**: Repository `.chest/` directory  
**Purpose**: Standardized storage for ignition keys and metadata

```bash
# Required directory structure:
/repo/.chest/
├── ignition-master.key        # I key (passphrase-wrapped)
├── ignition-master.meta       # I key metadata  
├── distro-{name}.key         # D keys (passphrase-wrapped)
├── distro-{name}.meta        # D key metadata
└── ignition-manifest.json    # Master tracking file

# Manifest format:
{
  "version": "1.0",
  "created": "2025-01-01T00:00:00Z",
  "last_rotation": "2025-01-01T00:00:00Z",
  "auto_rotate_days": 180,
  "ignition_master": {
    "created": "2025-01-01T00:00:00Z",
    "key_file": "ignition-master.key"
  },
  "distributed_keys": {
    "ai-bot": {
      "created": "2025-01-01T00:00:00Z",
      "last_used": "2025-01-27T00:00:00Z", 
      "key_file": "distro-ai-bot.key",
      "revoked": false
    }
  }
}
```

**Functions to Create**:
- `_ensure_ignition_directory()`
- `_create_ignition_manifest()`
- `_update_ignition_manifest()`
- `_read_ignition_manifest()`

### **Step 1.4: Implement Double Encryption Pattern**
**Purpose**: Master-readable keys with passphrase access  
**Challenge**: Age limitations with interactive-only passphrases

**Key Creation Pattern**:
```bash
_create_ignition_key() {
    local key_name="$1"
    local passphrase="$2"
    local key_type="$3"  # "ignition-master" or "distro"
    
    # Generate actual age keypair
    local temp_keypair=$(mktemp)
    age-keygen > "$temp_keypair"
    
    # Extract public key
    local public_key=$(grep "Public key:" <<< "$(age-keygen)" | awk '{print $3}')
    
    # Create metadata
    local metadata="TYPE=$key_type
NAME=$key_name
CREATED=$(date -Iseconds)
AUTHORITY=master
MD5=$(md5sum "$temp_keypair" | awk '{print $1}')
---"
    
    # Create inner bundle (metadata + key)
    local inner_bundle=$(mktemp)
    {
        echo "$metadata"
        cat "$temp_keypair"
    } > "$inner_bundle"
    
    # Inner encryption: passphrase-wrapped
    local inner_encrypted=$(mktemp)
    echo "$passphrase" | script -qec "age -p < '$inner_bundle' > '$inner_encrypted'" /dev/null
    
    # Outer encryption: master-key wrapped for authority verification
    local master_pub=$(get_master_public_key)
    age -r "$master_pub" < "$inner_encrypted" > ".chest/$key_type-$key_name.key"
    
    # Create metadata file
    echo "$metadata" > ".chest/$key_type-$key_name.meta"
    
    # Cleanup
    rm "$temp_keypair" "$inner_bundle" "$inner_encrypted"
}
```

**Functions to Implement**:
- `_create_ignition_key()`
- `_decrypt_ignition_key()`  
- `_verify_ignition_key()`
- `_extract_ignition_metadata()`

---

## Phase 2: Core API Implementation (3-4 days)

### **Step 2.1: Implement do_ignite Command Parser**
**File**: `parts/06_api.sh`  
**Purpose**: Clean argument parsing following BashFX patterns

```bash
do_ignite() {
    local action="$1"
    shift
    
    # Set REPO_ROOT for helpers
    REPO_ROOT=$(_get_repo_root .)
    
    case "$action" in
        create)
            local name="default"
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --name=*) name="${1#*=}"; shift ;;
                    *) shift ;;
                esac
            done
            _ignition_create_master "$name"
            ;;
        new)
            local name=""
            local phrase=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --name=*) name="${1#*=}"; shift ;;
                    --phrase=*) phrase="${1#*=}"; shift ;;
                    *) shift ;;
                esac
            done
            [[ -n "$name" ]] || fatal "Missing required --name argument"
            _ignition_create_distributed "$name" "$phrase"
            ;;
        unlock)
            local name="default"
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --name=*) name="${1#*=}"; shift ;;
                    *) shift ;;
                esac
            done
            _ignition_unlock "$name"
            ;;
        list)
            _ignition_list
            ;;
        revoke)
            local name=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --name=*) name="${1#*=}"; shift ;;
                    *) shift ;;
                esac
            done
            [[ -n "$name" ]] || fatal "Missing required --name argument"
            _ignition_revoke "$name"
            ;;
        rotate)
            _ignition_rotate
            ;;
        reset)
            _ignition_reset
            ;;
        status)
            _ignition_status
            ;;
        verify)
            local key_path=""
            local phrase=""
            while [[ $# -gt 0 ]]; do
                case $1 in
                    --key=*) key_path="${1#*=}"; shift ;;
                    --phrase=*) phrase="${1#*=}"; shift ;;
                    *) shift ;;
                esac
            done
            [[ -n "$key_path" ]] || fatal "Missing required --key argument"
            _ignition_verify "$key_path" "$phrase"
            ;;
        register|maybe|integrity)
            # Advanced commands for Phase 3
            warn "Advanced ignition command '$action' not yet implemented"
            return 1
            ;;
        help|*)
            _ignition_help
            ;;
    esac
}
```

### **Step 2.2: Implement Core Helper Functions**
**File**: `parts/04_helpers.sh`  
**Purpose**: Core ignition operations

**Required Functions**:

```bash
_ignition_create_master() {
    local name="$1"
    
    # Check if already exists
    [[ ! -f ".chest/ignition-master.key" ]] || fatal "Ignition master key already exists"
    
    # Ensure directory structure
    _ensure_ignition_directory
    
    # Generate passphrase if not provided
    local passphrase=$(_generate_ignition_passphrase)
    
    # Create the I key
    _create_ignition_key "$name" "$passphrase" "ignition-master"
    
    # Update manifest
    _update_ignition_manifest "ignition_master" "{\"created\": \"$(date -Iseconds)\", \"key_file\": \"ignition-master.key\"}"
    
    okay "✓ Ignition master key created: $name"
    info "🔑 Keep this passphrase secure: $passphrase"
}

_ignition_create_distributed() {
    local name="$1"
    local passphrase="$2"
    
    # Verify ignition master exists
    [[ -f ".chest/ignition-master.key" ]] || fatal "No ignition master key found. Run 'padlock ignite create' first."
    
    # Check for name conflicts
    [[ ! -f ".chest/distro-$name.key" ]] || fatal "Distributed key '$name' already exists"
    
    # Generate passphrase if not provided
    [[ -n "$passphrase" ]] || passphrase=$(_generate_ignition_passphrase)
    
    # Create the D key
    _create_ignition_key "$name" "$passphrase" "distro"
    
    # Update manifest
    _update_ignition_manifest "distributed_keys.$name" "{\"created\": \"$(date -Iseconds)\", \"key_file\": \"distro-$name.key\", \"revoked\": false}"
    
    okay "✓ Distributed ignition key created: $name"
    info "🔑 Share this passphrase with AI system: $passphrase"
}

_ignition_unlock() {
    local name="$1"
    local passphrase="${PADLOCK_IGNITION_PASS:-}"
    
    [[ -n "$passphrase" ]] || fatal "Missing PADLOCK_IGNITION_PASS environment variable"
    
    # Check if D key exists
    local key_file=".chest/distro-$name.key"
    [[ -f "$key_file" ]] || fatal "Distributed ignition key '$name' not found"
    
    # Decrypt repository using D key
    if _decrypt_with_ignition_key "$key_file" "$passphrase"; then
        okay "✓ Repository unlocked with ignition key: $name"
        _update_ignition_manifest "distributed_keys.$name.last_used" "\"$(date -Iseconds)\""
    else
        fatal "Failed to unlock repository with ignition key: $name"
    fi
}

_ignition_list() {
    [[ -f ".chest/ignition-manifest.json" ]] || { info "No ignition keys found"; return 0; }
    
    echo "💀 Ignition Master Key:"
    local master_created=$(jq -r '.ignition_master.created // "unknown"' ".chest/ignition-manifest.json")
    echo "  master (created: $master_created)"
    echo
    
    echo "🔥 Distributed Access Keys:"
    jq -r '.distributed_keys // {} | to_entries[] | "  \(.key) (created: \(.value.created), last_used: \(.value.last_used // "never"), revoked: \(.value.revoked))"' ".chest/ignition-manifest.json"
}

_ignition_revoke() {
    local name="$1"
    
    # Check if D key exists  
    [[ -f ".chest/distro-$name.key" ]] || fatal "Distributed ignition key '$name' not found"
    
    # Remove key files
    rm -f ".chest/distro-$name.key" ".chest/distro-$name.meta"
    
    # Update manifest
    _update_ignition_manifest "distributed_keys.$name.revoked" "true"
    
    okay "✓ Distributed ignition key revoked: $name"
    warn "⚠️  AI systems using this key will no longer have access"
}
```

### **Step 2.3: Implement Age Encryption Workarounds**
**Challenge**: Age `-p` passphrase mode is interactive-only  
**Solutions**: Fake TTY or rage with custom pinentry

**Option 1: Fake TTY Implementation**
```bash
_decrypt_with_ignition_key() {
    local key_file="$1" 
    local passphrase="$2"
    
    # Decrypt outer layer (master-encrypted) to get inner layer
    local master_key=$(get_master_private_key)
    local inner_encrypted=$(mktemp)
    age -d -i "$master_key" < "$key_file" > "$inner_encrypted"
    
    # Decrypt inner layer (passphrase-encrypted) using fake TTY
    local decrypted_key=$(mktemp)
    echo "$passphrase" | script -qec "age -d < '$inner_encrypted' > '$decrypted_key'" /dev/null
    
    # Use decrypted key to unlock repository
    if age -d -i "$decrypted_key" < "locker.age" | tar -xzf -; then
        rm -f locker.age .locked
        rm -f "$inner_encrypted" "$decrypted_key"
        return 0
    else
        rm -f "$inner_encrypted" "$decrypted_key"
        return 1
    fi
}
```

**Option 2: Rage Migration (Alternative)**
```bash
# Replace age with rage throughout ignition system
# Implement custom pinentry that reads from PADLOCK_IGNITION_PASS
# This requires changing encryption backend
```

### **Step 2.4: Integration with Clamp Command**
**File**: `parts/06_api.sh`  
**Purpose**: Enable ignition during repository setup

```bash
# In do_clamp() function, add ignition support:
do_clamp() {
    local target_path="${1:-.}"
    local with_ignition=false
    local ignition_passphrase=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-ignition) with_ignition=true; shift ;;
            -K|--ignition=*) 
                with_ignition=true
                ignition_passphrase="${1#*=}"
                shift ;;
            *) shift ;;
        esac
    done
    
    # ... existing clamp logic ...
    
    # Add ignition setup
    if [[ "$with_ignition" == true ]]; then
        cd "$target_path"
        _ignition_create_master "default"
        
        if [[ -n "$ignition_passphrase" ]]; then
            # Use provided passphrase for first D key
            _ignition_create_distributed "default" "$ignition_passphrase"
        fi
        
        info "🔥 Repository configured with ignition access"
    fi
}
```

---

## Phase 3: Advanced Features & Polish (2-3 days)

### **Step 3.1: Implement Advanced Commands**
**Functions**: `verify`, `register`, `maybe`, `integrity`

```bash
_ignition_verify() {
    local key_path="$1"
    local passphrase="$2"
    
    # Test if provided key can access current repository
    if [[ -n "$passphrase" ]]; then
        # Dry run test with passphrase
        echo "Testing ignition key: $key_path with provided passphrase..."
        # Implementation: attempt decrypt without actually unlocking
    else
        # Just verify key format and metadata
        echo "Verifying ignition key format: $key_path"
        # Implementation: check if key has valid ignition metadata
    fi
}

_ignition_integrity() {
    # Verify all I/D key relationships are valid
    # Check manifest consistency
    # Validate all key files exist and are accessible
    # Report any inconsistencies
}
```

### **Step 3.2: Implement Auto-Expiration**
**Purpose**: Repository-controlled automatic key rotation

```bash
_check_ignition_expiration() {
    [[ -f ".chest/ignition-manifest.json" ]] || return 0
    
    local last_rotation=$(jq -r '.last_rotation // .created' ".chest/ignition-manifest.json")
    local auto_rotate_days=$(jq -r '.auto_rotate_days // 180' ".chest/ignition-manifest.json")
    
    local days_since_rotation=$(( ($(date +%s) - $(date -d "$last_rotation" +%s)) / 86400 ))
    
    if [[ $days_since_rotation -gt $auto_rotate_days ]]; then
        warn "🔄 Ignition keys are $days_since_rotation days old (limit: $auto_rotate_days days)"
        info "Auto-rotating ignition master key for security..."
        
        if _confirm "Rotate ignition keys now? This will invalidate all distributed keys."; then
            _ignition_rotate
            okay "✓ Ignition keys auto-rotated. Redistribute new access keys."
        else
            warn "⚠️  Ignition keys remain expired. Manual rotation recommended."
        fi
    fi
}

# Call expiration check in unlock operations
_ignition_unlock() {
    # ... existing unlock logic ...
    _check_ignition_expiration
    # ... continue with unlock ...
}
```

### **Step 3.3: Integration Testing & Validation**
**Purpose**: Comprehensive testing of all ignition workflows

**Test Scenarios**:
```bash
#!/usr/bin/env bash
# test_ignition_integration.sh

# Test 1: Basic ignition setup
test_basic_ignition_setup() {
    local test_repo=$(mktemp -d)
    cd "$test_repo"
    git init
    
    padlock clamp . --with-ignition
    assert_file_exists ".chest/ignition-master.key"
    assert_file_exists ".chest/ignition-manifest.json"
}

# Test 2: Distributed key creation and usage  
test_distributed_key_workflow() {
    padlock ignite new --name=test-ai
    local passphrase=$(get_last_displayed_passphrase)
    
    PADLOCK_IGNITION_PASS="$passphrase" padlock ignite unlock --name=test-ai
    assert_repo_unlocked
}

# Test 3: Key revocation
test_key_revocation() {
    padlock ignite new --name=revoke-test
    local passphrase=$(get_last_displayed_passphrase)
    
    padlock ignite revoke --name=revoke-test
    
    PADLOCK_IGNITION_PASS="$passphrase" padlock ignite unlock --name=revoke-test
    assert_unlock_fails
}

# Test 4: Master key rotation
test_ignition_rotation() {
    padlock ignite new --name=rotate-test
    local old_passphrase=$(get_last_displayed_passphrase)
    
    padlock ignite rotate
    
    PADLOCK_IGNITION_PASS="$old_passphrase" padlock ignite unlock --name=rotate-test
    assert_unlock_fails
}
```

### **Step 3.4: Error Handling & Recovery**
**Purpose**: Comprehensive error messages and recovery guidance

```bash
# Enhanced error handling with recovery suggestions
_ignition_unlock() {
    local name="$1"
    local passphrase="${PADLOCK_IGNITION_PASS:-}"
    
    # Error: Missing passphrase
    if [[ -z "$passphrase" ]]; then
        error "Missing ignition passphrase"
        info "Set environment variable: export PADLOCK_IGNITION_PASS='your-passphrase'"
        info "Or run: PADLOCK_IGNITION_PASS='phrase' padlock ignite unlock --name=$name"
        return 1
    fi
    
    # Error: Key not found
    if [[ ! -f ".chest/distro-$name.key" ]]; then
        error "Distributed ignition key '$name' not found"
        info "Available keys:"
        _ignition_list | grep -E "^  [a-zA-Z0-9-]+" || info "  (no distributed keys found)"
        info "Create key with: padlock ignite new --name=$name"
        return 1
    fi
    
    # Error: Wrong passphrase
    if ! _decrypt_with_ignition_key ".chest/distro-$name.key" "$passphrase"; then
        error "Invalid passphrase for ignition key '$name'"
        info "Check passphrase or contact repository owner for correct phrase"
        info "Verify key status: padlock ignite list"
        return 1
    fi
    
    # Success path continues...
}
```

---

## Phase 4: Documentation & Finalization (1-2 days)

### **Step 4.1: Update Help System**
**Files**: `parts/05_printers.sh`, help functions  
**Purpose**: Complete command documentation

```bash
_ignition_help() {
    cat << 'HELP_EOF'
💀 Padlock Ignition System - Third-Party Repository Access

USAGE:
  padlock ignite <command> [options]

REPOSITORY OWNER COMMANDS:
  create [--name=NAME]              Create ignition master key (I key)
  new --name=NAME [--phrase=PASS]   Create distributed access key (D key)
  revoke --name=NAME                Revoke distributed access key  
  rotate                            Rotate all ignition keys (nuclear option)
  reset                             Remove ignition system from repository

AI/AUTOMATION COMMANDS:  
  unlock [--name=NAME]              Unlock repository with distributed key
  status                            Show ignition system status
  list                              List available distributed keys

ADVANCED COMMANDS:
  verify --key=PATH [--phrase=PASS] Test if key can access repository
  register --key=PATH               Add existing key to manifest
  maybe --key=PATH                  Check if wayward key belongs here
  integrity                         Verify all key relationships

EXAMPLES:
  # Repository owner setup
  padlock clamp /repo --with-ignition
  padlock ignite new --name=ai-bot
  
  # AI system access
  export PADLOCK_IGNITION_PASS="provided-passphrase"
  padlock ignite unlock --name=ai-bot
  
  # Management  
  padlock ignite list
  padlock ignite revoke --name=old-ai

ENVIRONMENT VARIABLES:
  PADLOCK_IGNITION_PASS    Passphrase for automated unlock

See 'padlock help' for general padlock commands.
HELP_EOF
}
```

### **Step 4.2: Update Status Integration**
**Files**: Status and listing functions  
**Purpose**: Show ignition information in padlock status

```bash
# Update main status command to include ignition info
do_status() {
    # ... existing status logic ...
    
    # Add ignition status
    if [[ -f ".chest/ignition-manifest.json" ]]; then
        local distributed_count=$(jq -r '.distributed_keys // {} | length' ".chest/ignition-manifest.json")
        local active_count=$(jq -r '.distributed_keys // {} | [.[] | select(.revoked != true)] | length' ".chest/ignition-manifest.json")
        
        echo "Ignition: enabled ($active_count/$distributed_count active keys)"
        
        if [[ $distributed_count -gt 0 ]]; then
            local last_used=$(jq -r '.distributed_keys // {} | [.[] | select(.last_used)] | sort_by(.last_used) | .[-1].last_used // "never"' ".chest/ignition-manifest.json")
            echo "Last ignition unlock: $last_used"
        fi
    else
        echo "Ignition: disabled"
    fi
}
```

### **Step 4.3: Export/Import Integration**
**Files**: Export and import functions  
**Purpose**: Include ignition keys in repository backups

```bash
# Update export to include ignition infrastructure
do_export() {
    # ... existing export logic ...
    
    # Include ignition directory if it exists
    if [[ -d ".chest" ]]; then
        tar -rf "$temp_archive" ".chest/"
        info "Including ignition keys and configuration"
    fi
    
    # ... continue with encryption ...
}

# Update import to restore ignition infrastructure
do_import() {
    # ... existing import logic ...
    
    # Restore ignition directory
    if tar -tf "$decrypted_archive" | grep -q "^\.chest/"; then
        tar -xf "$decrypted_archive" ".chest/"
        info "Restored ignition keys and configuration"
        
        # Verify integrity after import
        if command -v jq >/dev/null && [[ -f ".chest/ignition-manifest.json" ]]; then
            padlock ignite integrity || warn "Ignition integrity check failed after import"
        fi
    fi
}
```

### **Step 4.4: Final Testing & BashFX Compliance**
**Purpose**: Comprehensive validation before release

**BashFX Compliance Checklist**:
- ✅ All functions follow BashFX naming conventions
- ✅ Error handling uses proper stderr/fatal patterns  
- ✅ Options parsing uses `--flag=value` pattern
- ✅ Functions have proper return codes
- ✅ Logging uses appropriate verbosity levels
- ✅ Build.sh pattern maintained
- ✅ XDG compliance for configuration storage

**Comprehensive Test Suite**:
```bash
#!/usr/bin/env bash
# test_ignition_comprehensive.sh

run_full_ignition_test_suite() {
    test_basic_setup_workflow
    test_distributed_key_lifecycle  
    test_unlock_automation
    test_revocation_security
    test_rotation_invalidation
    test_auto_expiration
    test_error_handling
    test_integration_compatibility
    test_export_import_preservation
    test_performance_scalability
}
```

---

## Delivery Checklist

### **Code Deliverables**
- ✅ `parts/07_core.sh` - Fixed dispatcher routing
- ✅ `parts/06_api.sh` - Complete `do_ignite()` implementation  
- ✅ `parts/04_helpers.sh` - All ignition helper functions
- ✅ `parts/05_printers.sh` - Updated help and status integration
- ✅ Enhanced clamp/export/import functions with ignition support

### **Testing Deliverables**
- ✅ `tests/test_ignition_core.sh` - Core functionality tests
- ✅ `tests/test_ignition_integration.sh` - Integration test suite
- ✅ `tests/test_ignition_security.sh` - Security boundary verification
- ✅ `tests/test_ignition_performance.sh` - Scalability testing
- ✅ Updated main test runner to include ignition tests

### **Documentation Deliverables**  
- ✅ Updated command help with ignition examples
- ✅ Integration guide for AI systems
- ✅ Troubleshooting guide for common scenarios
- ✅ Security model documentation
- ✅ Migration guide for existing repositories

### **Quality Assurance**
- ✅ All tests pass with 100% success rate
- ✅ BashFX 2.1 architecture compliance verified
- ✅ Performance benchmarks meet requirements
- ✅ Security audit completed
- ✅ Backward compatibility confirmed

---

## Post-Implementation Tasks

### **Immediate (Week 1)**
- Deploy to test environment
- User acceptance testing with AI systems
- Performance monitoring and optimization
- Bug fixes and polish

### **Short Term (Month 1)**  
- User feedback collection and analysis
- Feature usage metrics and optimization
- Documentation improvements
- Advanced feature requests evaluation

### **Long Term (Quarter 1)**
- Rage migration planning (if needed)
- Advanced automation features
- Integration with additional AI platforms
- Security model evolution

---

**This implementation plan provides complete step-by-step instructions for building the Padlock Ignition System with proper phase management, testing, and delivery criteria.**