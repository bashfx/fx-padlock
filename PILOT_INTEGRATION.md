# PILOT_INTEGRATION.md - Layered Native Implementation Blueprint

## Executive Summary

This document provides a comprehensive integration strategy for implementing the **layered_native** ignition key approach (winner of the Plan X pilot) into the production Padlock system. Based on empirical pilot testing, layered_native delivers optimal performance (0.240s), strong security, and minimal implementation complexity (13 story points).

## Architecture Overview

### Core Design Pattern: Passphrase-to-Key Derivation
```bash
# Deterministic key derivation from passphrase
passphrase → SHA256 hash → Age key file → Public key
```

**Key Components**:
1. **Master Key Authority**: All ignition keys encrypted with existing master key
2. **Deterministic Derivation**: Reproducible key generation from passphrases
3. **JSON Metadata**: Rich metadata embedded in key bundles
4. **Age Native**: Pure age encryption maintains architectural consistency

## Integration Strategy

### Phase 1: Core Implementation (Week 1-2)

#### 1.1 BashFX Integration Points

**Target Files for Modification**:
```bash
parts/06_api.sh        # Add ignition API functions
parts/07_core.sh       # Update dispatcher with ignition commands
parts/08_helpers.sh    # Add key derivation utilities
```

**New Functions Required**:
```bash
_derive_ignition_key()          # Core key derivation from passphrase
_create_ignition_master()       # Create ignition master key
_create_ignition_distro()       # Create distributed key
_unlock_ignition_key()          # Unlock with passphrase validation
_validate_ignition_authority()  # Verify master key authority
_manage_ignition_metadata()     # Handle JSON metadata operations
```

#### 1.2 Command API Mapping

**Current Padlock Commands** → **New Ignition Commands**:
```bash
# Existing pattern:
padlock clamp /repo -K              # Create ignition-enabled repo

# New API additions needed:
padlock ignite create-master [name] [--passphrase=PASS]
padlock ignite create-distro [name] [--passphrase=PASS] 
padlock ignite unlock [name] [--passphrase=PASS]
padlock ignite list              # Show available ignition keys
padlock ignite status [name]     # Key status and metadata
padlock ignite rotate [name]     # Key rotation (future)
padlock ignite revoke [name]     # Key revocation (future)
```

**Environment Variable Support**:
```bash
export PADLOCK_IGNITION_PASSPHRASE="flame-rocket-boost-spark"
padlock ignite unlock distro-key-name  # Uses env var
```

#### 1.3 Storage Architecture

**Directory Structure**:
```bash
.padlock/
├── master.key              # Existing master key
├── ignition/               # New ignition key storage
│   ├── master/            
│   │   └── [name].key     # Ignition master keys
│   ├── distro/
│   │   └── [name].key     # Distributed keys  
│   ├── metadata/
│   │   └── [name].json    # Key metadata files
│   └── .derived/          # Cached derived keys
│       └── [hash].key     # Deterministic key cache
```

### Phase 2: Security Integration (Week 2)

#### 2.1 Authority Validation Chain
```bash
# Validation sequence:
User Passphrase → Derived Key → Decrypt Key Bundle → Validate Master Authority → Extract Private Key
```

**Security Checkpoints**:
1. **Master Key Presence**: Verify master key exists and is valid
2. **Authority Signature**: All ignition keys must be encrypted with master key
3. **Passphrase Strength**: Enforce minimum entropy requirements
4. **Metadata Integrity**: Validate JSON structure and required fields
5. **Expiration Checks**: Support optional key expiration (future)

#### 2.2 Critical Edge Cases

**High Priority Edge Cases**:
```bash
# 1. Master Key Compromise
if master_key_compromised; then
    rotate_all_ignition_keys
    notify_security_incident
fi

# 2. Passphrase Collision
if derive_key_collision_detected; then
    add_salt_to_derivation
    regenerate_affected_keys
fi

# 3. Metadata Corruption
if json_metadata_invalid; then
    attempt_recovery_from_backup
    fallback_to_basic_key_info
fi

# 4. Derived Key Cache Poisoning
if derived_cache_inconsistent; then
    purge_cache
    regenerate_from_passphrase
fi

# 5. Environment Variable Leakage
if env_var_exposed_in_logs; then
    rotate_affected_keys
    clear_environment_variables
fi
```

#### 2.3 Risk Mitigation Strategies

**Implementation Safeguards**:
1. **Input Validation**: Strict passphrase and name validation
2. **Atomic Operations**: All key operations succeed or fail completely  
3. **Backup Integration**: Hook into existing backup systems
4. **Audit Logging**: Track all ignition key operations
5. **Recovery Procedures**: Clear recovery paths for each failure mode

## Implementation Blueprint

### Code Integration Pattern

**Based on pilot implementation** (`pilot.sh` layered_native functions):

```bash
# Core key derivation (from pilot)
layered_native_derive_key() {
    local passphrase="$1"
    local key_hash=$(echo "layered_native_key:$passphrase" | sha256sum | cut -d' ' -f1)
    local key_file="$PADLOCK_DIR/.derived_keys/$key_hash"
    
    mkdir -p "$PADLOCK_DIR/.derived_keys"
    
    if [[ ! -f "$key_file" ]]; then
        age-keygen > "$key_file" 2>/dev/null
    fi
    
    age-keygen -y < "$key_file" 2>/dev/null
}

# Ignition master creation (adapted from pilot)
do_ignite_create_master() {
    local name="${1:-default}"
    local passphrase="${2:-$(_prompt_secret "Ignition passphrase")}"
    
    # Generate base key
    local temp_key=$(mktemp)
    age-keygen > "$temp_key"
    
    # Create metadata bundle
    local metadata=$(create_ignition_metadata "$name" "ignition-master" "$passphrase")
    local key_bundle=$(create_key_bundle "$metadata" "$temp_key")
    
    # Encrypt with master key authority
    echo "$key_bundle" | age -r "$(get_master_public_key)" > "$PADLOCK_DIR/ignition/master/$name.key"
    
    # Cache derived key for future use
    layered_native_derive_key "$passphrase" > /dev/null
    
    okay "Ignition master key created: $name"
    rm -f "$temp_key"
}
```

### Mini-Dispatcher Integration

**Add to existing dispatcher pattern**:
```bash
# In parts/07_core.sh dispatch() function
ignite)
    case "${args[0]:-}" in
        create-master)  do_ignite_create_master "${args[1]:-}" "${args[2]:-}" ;;
        create-distro)  do_ignite_create_distro "${args[1]:-}" "${args[2]:-}" ;;
        unlock)         do_ignite_unlock "${args[1]:-}" "${args[2]:-}" ;;
        list)           do_ignite_list ;;
        status)         do_ignite_status "${args[1]:-}" ;;
        help)           help_ignite ;;
        *)              usage_ignite; return 1 ;;
    esac
    ;;
```

## Validation & Testing Strategy

### Success Criteria

**Phase 1 Completion Criteria**:
- [ ] All ignition API commands functional
- [ ] Integration with existing clamp/declamp workflow
- [ ] Master key authority validation working
- [ ] Environment variable passphrase support
- [ ] Basic error handling implemented

**Phase 2 Security Validation**:
- [ ] All 5 critical edge cases handled
- [ ] Security audit of key derivation functions
- [ ] Penetration testing of passphrase handling
- [ ] Authority chain validation under attack scenarios
- [ ] Performance regression tests (< 1s for typical operations)

### Test Scenarios

**Functional Tests**:
```bash
# Integration test sequence
test_ignition_integration() {
    padlock init /tmp/test-repo
    padlock clamp /tmp/test-repo -K "test-passphrase"
    
    padlock ignite create-master test-master --passphrase="master-pass"
    padlock ignite create-distro test-distro --passphrase="distro-pass"
    padlock ignite unlock test-distro --passphrase="distro-pass"
    
    # Verify key authority
    validate_master_authority test-distro
    
    # Test environment variable unlock
    export PADLOCK_IGNITION_PASSPHRASE="distro-pass"
    padlock ignite unlock test-distro
    
    padlock declamp /tmp/test-repo
}
```

**Security Tests**:
```bash
# Security validation sequence  
test_ignition_security() {
    # Test passphrase collision resistance
    test_passphrase_collision_resistance
    
    # Test master key authority bypass attempts
    test_authority_bypass_attempts
    
    # Test metadata tampering resistance
    test_metadata_tampering_resistance
    
    # Test environment variable isolation
    test_env_var_isolation
    
    # Test derived key cache security
    test_derived_key_cache_security
}
```

## Integration Risks & Mitigation

### High-Risk Areas

**1. Key Derivation Security (HIGH)**
- **Risk**: Weak derivation function compromises all keys
- **Mitigation**: Use proven SHA256 + age-keygen pattern from pilot
- **Validation**: Security audit of derivation algorithm

**2. Master Key Authority Bypass (HIGH)**  
- **Risk**: Attacker creates ignition keys without master authority
- **Mitigation**: Strict validation that all keys encrypted with master
- **Validation**: Penetration testing of authority validation

**3. Environment Variable Exposure (MEDIUM)**
- **Risk**: Passphrases logged or exposed in process lists
- **Mitigation**: Clear variables immediately after use
- **Validation**: Process monitoring and log auditing

**4. Backward Compatibility Break (MEDIUM)**
- **Risk**: Integration breaks existing padlock workflows  
- **Mitigation**: Extensive regression testing
- **Validation**: Full test suite execution

### Low-Risk Areas

**1. Performance Regression (LOW)**
- **Pilot Data**: 0.240s proven fast enough
- **Mitigation**: Benchmark monitoring during integration

**2. Storage Space (LOW)**
- **Impact**: Minimal additional storage for ignition keys
- **Mitigation**: Optional cleanup commands

## Future Evolution Path

### Rust Port Considerations

**Key Design Decisions for Rust Port**:
1. **Key Derivation**: Use Rust crypto libraries (ring, rustcrypto)
2. **JSON Handling**: serde for metadata serialization
3. **Performance**: Async key operations for parallelism
4. **Security**: Zero-copy operations where possible

**Migration Strategy**:
- Bash implementation validates approach with real users
- Rust port inherits proven security model and API design
- Cross-compatibility maintained through shared key formats

### Enhancement Opportunities

**Post-Implementation Features**:
1. **Key Rotation**: Automated key lifecycle management
2. **Threshold Schemes**: Integration of lattice_proxy concepts for high-security repos
3. **Forward Secrecy**: Integration of temporal_chain concepts for audit-heavy environments
4. **Hardware Security**: HSM integration for enterprise deployments

## Implementation Timeline

**Week 1**: Core API implementation, basic functionality
**Week 2**: Security integration, edge case handling, testing
**Week 3**: Integration testing, performance validation
**Week 4**: Documentation, deployment preparation

**Success Milestone**: Full ignition API functional with proven security model, ready for production deployment.

---

*This integration blueprint represents the culmination of Plan X pilot research, providing a concrete roadmap for implementing the winning layered_native approach in production Padlock systems.*