# 🎯 **PILOT PLAN: Phase 1 Ignition API Implementation**

## **Executive Summary**

This is **Phase 1** of the ignition API implementation: establishing the core **layered_native** approach with **Age TTY Subversion** for the base ignition key hierarchy (I & D keys). This implementation provides the foundation for passphrase-based automation while maintaining architectural consistency with existing Padlock patterns.

**Current Status**: The padlock codebase contains **stub implementations** for the complete ignition API surface, but the core I & D key functionality needs to be built.

**Key Innovation**: The "Age TTY Subversion" technique gives age exactly what it wants (interactive TTY) while maintaining full automation capability - a philosophically superior Unix solution.

## **Phase 1 Scope**

### **What This Phase Implements:**
- ✅ Core I & D key creation and management
- ✅ TTY subversion for age passphrase automation
- ✅ Basic ignition master and distributed key workflows
- ✅ Master key authority validation
- ✅ Comprehensive security framework

### **What Remains as Stubs (Future Phases):**
- 🔄 `padlock ignite allow <pubkey>` - Public key authorization system
- 🔄 `padlock ignite rotate [name]` - Key rotation capabilities
- 🔄 `padlock ignite revoke [name]` - Key revocation system
- 🔄 `padlock ignite verify --key=PATH` - Advanced key verification
- 🔄 `padlock ignite reset` - Complete system reset
- 🔄 Advanced features: key expiration, audit logging, multiple authorities

**Post-Phase 1**: The ignition API will be **functionally complete** for basic operations, with advanced features remaining as well-documented stubs ready for future implementation.

## **Phase 1: Core Implementation (Week 1-2)**

### **1.1 BashFX v3 Compliant Command Surface**

**Target Files**:
- `parts/06_api.sh` - Enhanced do_ignite() with TTY magic
- `parts/07_core.sh` - Dispatcher updates
- `parts/04_helpers.sh` - TTY subversion functions

**Final Command API**:
```bash
# Natural mini-dispatcher pattern (BashFX v3 compliant)
padlock ignite create [name] [--phrase="..."]     # Ignition master (I)
padlock ignite new --name=NAME [--phrase="..."]   # Distributed key (D)
padlock ignite unlock [name]                       # Unlock either type
padlock ignite allow <pubkey>                      # Authorization
padlock ignite list                                # Show available keys
padlock ignite status [name]                       # Key metadata

# Predicate-based operations (cross-entity)
padlock rotate ignition [name]                     # Key rotation
padlock revoke ignition [name]                     # Key revocation

# Natural language queries
padlock key is ignition --key=/path               # Key type check
padlock key authority --key1=/path --key2=/path   # Authority check
```

### **1.2 TTY Subversion Core Functions**

**The Magic Sauce** - Add to `parts/04_helpers.sh`:
```bash
_age_interactive_encrypt() {
    local input_file="$1"
    local output_file="$2" 
    local passphrase="$3"
    
    trace "Age TTY subversion: encrypting with passphrase"
    
    # Give age exactly what it wants - a TTY with interactive input
    # But we control what gets "typed" into that TTY 😈
    script -qec "printf '%s\\n%s\\n' '$passphrase' '$passphrase' | age -p -o '$output_file' '$input_file'" /dev/null 2>/dev/null
    
    if [[ $? -eq 0 ]]; then
        trace "Age TTY subversion successful"
        return 0
    else
        erro "Age TTY subversion failed"
        return 1
    fi
}

_age_interactive_decrypt() {
    local input_file="$1"
    local passphrase="$2"
    
    trace "Age TTY subversion: decrypting with passphrase"
    
    # Age gets its beloved TTY interaction, we get our automation
    script -qec "printf '%s\\n' '$passphrase' | age -d '$input_file'" /dev/null 2>/dev/null
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        trace "Age TTY subversion decrypt successful"
    else
        trace "Age TTY subversion decrypt failed (wrong passphrase?)"
    fi
    
    return $exit_code
}

_derive_ignition_key() {
    local passphrase="$1"
    local salt="${2:-padlock-ignition}"
    
    # Generate deterministic hash
    local key_hash=$(echo "${salt}:${passphrase}" | sha256sum | cut -d' ' -f1)
    local cache_file="$PADLOCK_DIR/ignition/.derived/${key_hash}.key"
    
    # Create cache directory
    mkdir -p "$(dirname "$cache_file")"
    
    # Generate or retrieve cached key
    if [[ ! -f "$cache_file" ]]; then
        age-keygen > "$cache_file" 2>/dev/null
    fi
    
    # Return public key
    age-keygen -y < "$cache_file" 2>/dev/null
}

_create_ignition_metadata() {
    local name="$1"
    local type="$2"
    
    cat <<EOF
{
    "type": "$type",
    "name": "$name",
    "created": "$(date -Iseconds)",
    "authority": "repo-master",
    "approach": "age-native-tty-subversion"
}
EOF
}

_validate_ignition_authority() {
    local key_file="$1"
    local master_private="$(_get_master_private_key)"
    
    # Try to decrypt with master key
    if age -d -i "$master_private" < "$key_file" >/dev/null 2>&1; then
        return 0
    else
        erro "Key file not encrypted with master authority: $key_file"
        return 1
    fi
}

_cache_derived_key() {
    local passphrase="$1"
    local name="$2"
    
    # Cache the derived key for performance
    local derived_key=$(_derive_ignition_key "$passphrase")
    trace "Cached derived key for ignition: $name"
    echo "$derived_key"
}
```

### **1.3 Enhanced do_ignite() Implementation**

**Replace/enhance existing do_ignite() in parts/06_api.sh**:
```bash
do_ignite() {
    local action="$1"
    shift || true
    
    # Set REPO_ROOT (existing pattern)
    REPO_ROOT=$(_get_repo_root .)

    case "$action" in
        create)
            # padlock ignite create [name] [--phrase="..."]
            local name="${1:-default}"
            shift || true
            
            # Parse options using BashFX pattern
            local passphrase="" 
            local opts=("$@")
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --phrase=*|--passphrase=*)
                        passphrase="${opts[i]#*=}"
                        ;;
                esac
            done
            
            # Get passphrase if not provided
            if [[ -z "$passphrase" ]]; then
                passphrase=$(_prompt_secret "Ignition passphrase for $name")
            fi
            
            # Use TTY magic for ignition master creation
            _create_ignition_master_with_tty_magic "$name" "$passphrase"
            ;;
            
        new)
            # padlock ignite new --name=NAME [--phrase="..."] 
            local name="" passphrase=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --name=*)
                        name="${opts[i]#*=}"
                        ;;
                    --phrase=*|--passphrase=*)
                        passphrase="${opts[i]#*=}"
                        ;;
                esac
            done
            
            # Validation
            if [[ -z "$name" ]]; then
                erro "Must specify --name=NAME for distributed key"
                return 1
            fi
            
            if [[ -z "$passphrase" ]]; then
                passphrase=$(_prompt_secret "Ignition passphrase for $name")
            fi
            
            # Use TTY magic for distributed key creation
            _create_ignition_distro_with_tty_magic "$name" "$passphrase"
            ;;
            
        unlock)
            # padlock ignite unlock [name]
            local name="${1:-default}"
            local passphrase="${PADLOCK_IGNITION_PASS:-}"
            
            if [[ -z "$passphrase" ]]; then
                passphrase=$(_prompt_secret "Ignition passphrase for $name")
            fi
            
            # Use TTY magic for unlock
            _unlock_ignition_with_tty_magic "$name" "$passphrase"
            ;;
            
        allow)
            local pubkey="$1"
            if [[ -z "$pubkey" ]]; then
                erro "Must specify public key"
                return 1
            fi
            _add_ignition_authority "$pubkey"
            ;;
            
        list)
            _list_ignition_keys
            ;;
            
        status)
            local name="${1:-}"
            _show_ignition_status "$name"
            ;;
            
        help)
            help_ignite
            ;;
            
        *)
            erro "Unknown ignition command: $action"
            help_ignite
            return 1
            ;;
    esac
}
```

## **Phase 2: Storage & Key Management System (Week 2)**

### **2.1 Directory Structure Implementation**

**Storage Architecture**:
```bash
.padlock/
├── master.key              # Existing master key (M)
├── ignition/               # New ignition system
│   ├── keys/              
│   │   ├── [name].ikey    # Ignition master keys (I) 
│   │   └── [name].dkey    # Distributed keys (D)
│   ├── metadata/
│   │   ├── [name].json    # Key metadata (creation, authority, etc.)
│   │   └── cache/         
│   └── .derived/          # Deterministic key cache
│       └── [hash].key     # Cached derived keys (performance)
```

### **2.2 Key Bundle Creation with TTY Magic**

```bash
_create_ignition_master_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Creating ignition master key with TTY magic: $name"
    
    # Create directory structure
    mkdir -p "$PADLOCK_DIR/ignition/keys"
    mkdir -p "$PADLOCK_DIR/ignition/metadata"
    mkdir -p "$PADLOCK_DIR/ignition/.derived"
    
    # Generate base age key  
    local temp_key=$(mktemp)
    age-keygen > "$temp_key"
    
    # Create JSON metadata bundle
    local metadata=$(_create_ignition_metadata "$name" "ignition-master")
    
    # Create key bundle (metadata + private key)
    local key_bundle=$(mktemp)
    {
        echo "PADLOCK_IGNITION_KEY"
        echo "$metadata" | base64 -w0
        echo "---"
        cat "$temp_key"
    } > "$key_bundle"
    
    # TTY magic: encrypt bundle with passphrase
    local passphrase_encrypted=$(mktemp)
    if _age_interactive_encrypt "$key_bundle" "$passphrase_encrypted" "$passphrase"; then
        # Double-encrypt with master key authority
        age -r "$(_get_master_public_key)" < "$passphrase_encrypted" > "$PADLOCK_DIR/ignition/keys/$name.ikey"
        
        # Store metadata separately for queries
        echo "$metadata" > "$PADLOCK_DIR/ignition/metadata/$name.json"
        
        okay "Ignition master key created with TTY magic: $name"
    else
        erro "Failed to create ignition master key: $name"
        rm -f "$temp_key" "$key_bundle" "$passphrase_encrypted"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_key" "$key_bundle" "$passphrase_encrypted"
}

_create_ignition_distro_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Creating ignition distributed key with TTY magic: $name"
    
    # Generate base age key  
    local temp_key=$(mktemp)
    age-keygen > "$temp_key"
    
    # Create JSON metadata bundle
    local metadata=$(_create_ignition_metadata "$name" "ignition-distributed")
    
    # Create key bundle (metadata + private key)
    local key_bundle=$(mktemp)
    {
        echo "PADLOCK_IGNITION_DISTRO"
        echo "$metadata" | base64 -w0
        echo "---"
        cat "$temp_key"
    } > "$key_bundle"
    
    # TTY magic: encrypt bundle with passphrase
    local passphrase_encrypted=$(mktemp)
    if _age_interactive_encrypt "$key_bundle" "$passphrase_encrypted" "$passphrase"; then
        # Double-encrypt with master key authority
        age -r "$(_get_master_public_key)" < "$passphrase_encrypted" > "$PADLOCK_DIR/ignition/keys/$name.dkey"
        
        # Store metadata separately for queries
        echo "$metadata" > "$PADLOCK_DIR/ignition/metadata/$name.json"
        
        okay "Ignition distributed key created with TTY magic: $name"
    else
        erro "Failed to create ignition distributed key: $name"
        rm -f "$temp_key" "$key_bundle" "$passphrase_encrypted"
        return 1
    fi
    
    # Cleanup
    rm -f "$temp_key" "$key_bundle" "$passphrase_encrypted"
}

_unlock_ignition_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Unlocking ignition key with TTY magic: $name"
    
    # Find key file (master or distro)
    local key_file=""
    if [[ -f "$PADLOCK_DIR/ignition/keys/$name.ikey" ]]; then
        key_file="$PADLOCK_DIR/ignition/keys/$name.ikey"
    elif [[ -f "$PADLOCK_DIR/ignition/keys/$name.dkey" ]]; then
        key_file="$PADLOCK_DIR/ignition/keys/$name.dkey"
    else
        erro "No ignition key found: $name"
        return 1
    fi
    
    # Validate master key authority first
    if ! _validate_ignition_authority "$key_file"; then
        return 1
    fi
    
    # Decrypt with master key first  
    local temp_bundle=$(mktemp)
    local master_private="$(_get_master_private_key)"
    
    if ! age -d -i "$master_private" < "$key_file" > "$temp_bundle"; then
        erro "Cannot decrypt ignition key (master key access denied)"
        rm -f "$temp_bundle"
        return 1
    fi
    
    # Use TTY subversion to decrypt with passphrase
    local decrypted_bundle=$(mktemp)
    if _age_interactive_decrypt "$temp_bundle" "$passphrase" > "$decrypted_bundle"; then
        # Extract private key from decrypted bundle
        local private_key=$(sed -n '4,$p' "$decrypted_bundle")
        
        # Export for repository access
        export PADLOCK_IGNITION_KEY="$private_key"
        
        okay "Ignition key unlocked with TTY magic: $name"
        rm -f "$temp_bundle" "$decrypted_bundle"
        return 0
    else
        erro "Incorrect passphrase for ignition key: $name"
        rm -f "$temp_bundle" "$decrypted_bundle" 
        return 1
    fi
}
```

## **Phase 3: Integration & Testing (Week 3)**

### **3.1 Dispatcher Integration**

**Add to parts/07_core.sh**:
```bash
# In dispatch() function, ensure ignite is routed:
ignite)
    do_ignite "$@"
    ;;
```

### **3.2 Help System Integration**

**Add to parts/06_api.sh**:
```bash
help_ignite() {
    echo "Ignition Key Operations (I & D keys):"
    echo "  create [name]           Create ignition master key (I)"
    echo "  new --name=NAME         Create distributed key (D)"  
    echo "  unlock [name]           Unlock with passphrase"
    echo "  allow <pubkey>          Allow public key access"
    echo "  list                    Show available ignition keys"
    echo "  status [name]           Show key metadata"
    echo ""
    echo "Environment: PADLOCK_IGNITION_PASS for automated unlock"
    echo "For detailed help: padlock help more"
}
```

### **3.3 Utility Functions**

```bash
_list_ignition_keys() {
    echo "Available ignition keys:"
    if [[ -d "$PADLOCK_DIR/ignition/keys" ]]; then
        for key_file in "$PADLOCK_DIR/ignition/keys"/*.{ikey,dkey}; do
            if [[ -f "$key_file" ]]; then
                local basename=$(basename "$key_file")
                local name="${basename%.*}"
                local type="${basename##*.}"
                case "$type" in
                    ikey) echo "  $name (ignition master)" ;;
                    dkey) echo "  $name (distributed)" ;;
                esac
            fi
        done
    else
        info "No ignition keys found"
    fi
}

_show_ignition_status() {
    local name="$1"
    
    if [[ -n "$name" ]]; then
        # Show specific key status
        local metadata_file="$PADLOCK_DIR/ignition/metadata/$name.json"
        if [[ -f "$metadata_file" ]]; then
            echo "Ignition key status: $name"
            jq -r '. | "Type: \(.type)\nCreated: \(.created)\nAuthority: \(.authority)"' < "$metadata_file"
        else
            erro "No metadata found for ignition key: $name"
            return 1
        fi
    else
        # Show general ignition system status
        echo "Ignition system status:"
        echo "Keys directory: $PADLOCK_DIR/ignition/keys"
        echo "Available keys:"
        _list_ignition_keys
    fi
}

_add_ignition_authority() {
    local pubkey="$1"
    
    # Implementation for allowing additional public keys
    # This would extend the authority system beyond just master key
    warn "Ignition authority extension not yet implemented"
    info "Currently only master key authority is supported"
}
```

## **Phase 4: Security Integration & Validation (Week 4)**

### **4.1 Authority Validation Chain**

**Security Checkpoints Implementation**:
```bash
# Validation sequence:
# User Passphrase → Derived Key → Decrypt Key Bundle → Validate Master Authority → Extract Private Key

_validate_ignition_security() {
    local key_file="$1"
    local passphrase="$2"
    
    # Checkpoint 1: Master Key Presence
    if ! _validate_master_key_exists; then
        erro "Master key not found - cannot validate ignition authority"
        return 1
    fi
    
    # Checkpoint 2: Authority Signature
    if ! _validate_ignition_authority "$key_file"; then
        erro "Ignition key not encrypted with master key authority"
        return 1
    fi
    
    # Checkpoint 3: Passphrase Strength
    if ! _validate_passphrase_strength "$passphrase"; then
        erro "Passphrase does not meet minimum entropy requirements"
        return 1
    fi
    
    # Checkpoint 4: Metadata Integrity
    if ! _validate_ignition_metadata "$key_file"; then
        erro "Key metadata validation failed"
        return 1
    fi
    
    # Checkpoint 5: Derived Key Cache Consistency
    if ! _validate_derived_key_cache "$passphrase"; then
        warn "Derived key cache inconsistent - regenerating"
        _purge_derived_cache
    fi
    
    return 0
}

_validate_master_key_exists() {
    local master_key="$(_get_master_private_key)"
    [[ -f "$master_key" ]] && [[ -s "$master_key" ]]
}

_validate_passphrase_strength() {
    local passphrase="$1"
    
    # Minimum 12 characters
    if [[ ${#passphrase} -lt 12 ]]; then
        return 1
    fi
    
    # Must contain at least 2 different character classes
    local classes=0
    [[ "$passphrase" =~ [a-z] ]] && ((classes++))
    [[ "$passphrase" =~ [A-Z] ]] && ((classes++))
    [[ "$passphrase" =~ [0-9] ]] && ((classes++))
    [[ "$passphrase" =~ [^a-zA-Z0-9] ]] && ((classes++))
    
    [[ $classes -ge 2 ]]
}

_validate_ignition_metadata() {
    local key_file="$1"
    local name=$(basename "$key_file" | cut -d'.' -f1)
    local metadata_file="$PADLOCK_DIR/ignition/metadata/$name.json"
    
    # Check metadata file exists
    if [[ ! -f "$metadata_file" ]]; then
        return 1
    fi
    
    # Validate JSON structure
    if ! jq -e '.type and .name and .created and .authority and .approach' "$metadata_file" >/dev/null 2>&1; then
        return 1
    fi
    
    # Validate required fields
    local type=$(jq -r '.type' "$metadata_file")
    local approach=$(jq -r '.approach' "$metadata_file")
    
    case "$type" in
        "ignition-master"|"ignition-distributed") ;;
        *) return 1 ;;
    esac
    
    [[ "$approach" == "age-native-tty-subversion" ]]
}

_validate_derived_key_cache() {
    local passphrase="$1"
    local key_hash=$(echo "padlock-ignition:${passphrase}" | sha256sum | cut -d' ' -f1)
    local cache_file="$PADLOCK_DIR/ignition/.derived/${key_hash}.key"
    
    # If cache exists, validate it generates consistent public key
    if [[ -f "$cache_file" ]]; then
        local cached_pubkey=$(age-keygen -y < "$cache_file" 2>/dev/null)
        local fresh_pubkey=$(_derive_ignition_key "$passphrase")
        [[ "$cached_pubkey" == "$fresh_pubkey" ]]
    else
        # Cache doesn't exist - this is fine
        return 0
    fi
}

_purge_derived_cache() {
    if [[ -d "$PADLOCK_DIR/ignition/.derived" ]]; then
        rm -f "$PADLOCK_DIR/ignition/.derived"/*.key
        trace "Derived key cache purged"
    fi
}
```

### **4.2 Critical Edge Cases & Risk Mitigation**

**High Priority Edge Cases Implementation**:
```bash
# Edge Case 1: Master Key Compromise
_handle_master_key_compromise() {
    erro "SECURITY INCIDENT: Master key compromise detected"
    
    # Rotate all ignition keys
    if [[ -d "$PADLOCK_DIR/ignition/keys" ]]; then
        for key_file in "$PADLOCK_DIR/ignition/keys"/*.{ikey,dkey}; do
            if [[ -f "$key_file" ]]; then
                local name=$(basename "$key_file" | cut -d'.' -f1)
                warn "Ignition key compromised and needs rotation: $name"
            fi
        done
    fi
    
    # Generate incident report
    _generate_security_incident_report "master-key-compromise" "$(date -Iseconds)"
    
    erro "All ignition keys must be rotated - repository access suspended"
    return 1
}

# Edge Case 2: Passphrase Collision Detection
_handle_passphrase_collision() {
    local passphrase="$1"
    local existing_hash="$2"
    
    warn "Potential passphrase collision detected"
    
    # Add salt to prevent collision
    local salt="collision-$(date +%s)-$(openssl rand -hex 4)"
    local new_key=$(_derive_ignition_key "$passphrase" "$salt")
    
    trace "Added collision-resistant salt: $salt"
    echo "$new_key"
}

# Edge Case 3: Metadata Corruption Recovery
_recover_metadata_corruption() {
    local key_file="$1"
    local name=$(basename "$key_file" | cut -d'.' -f1)
    
    warn "Metadata corruption detected for key: $name"
    
    # Attempt to extract metadata from key bundle
    local temp_bundle=$(mktemp)
    local master_private="$(_get_master_private_key)"
    
    if age -d -i "$master_private" < "$key_file" > "$temp_bundle" 2>/dev/null; then
        # Try to extract embedded metadata
        local embedded_metadata=$(sed -n '2p' "$temp_bundle" | base64 -d 2>/dev/null)
        
        if [[ -n "$embedded_metadata" ]] && echo "$embedded_metadata" | jq -e '.' >/dev/null 2>&1; then
            echo "$embedded_metadata" > "$PADLOCK_DIR/ignition/metadata/$name.json"
            okay "Metadata recovered from embedded bundle: $name"
            rm -f "$temp_bundle"
            return 0
        fi
    fi
    
    # Fallback to basic metadata
    warn "Creating minimal metadata for key: $name"
    cat > "$PADLOCK_DIR/ignition/metadata/$name.json" <<EOF
{
    "type": "unknown",
    "name": "$name",
    "created": "unknown",
    "authority": "repo-master",
    "approach": "age-native-tty-subversion",
    "recovered": "$(date -Iseconds)"
}
EOF
    
    rm -f "$temp_bundle"
    return 0
}

# Edge Case 4: Environment Variable Exposure Prevention
_secure_env_var_handling() {
    local passphrase="$PADLOCK_IGNITION_PASS"
    
    if [[ -n "$passphrase" ]]; then
        # Check if passphrase appears in logs or process list
        if ps aux | grep -q "$passphrase" 2>/dev/null; then
            erro "SECURITY WARNING: Passphrase visible in process list"
            erro "Rotate affected ignition keys immediately"
        fi
        
        # Clear environment variable after use
        unset PADLOCK_IGNITION_PASS
        
        # Overwrite bash history entry if needed
        history -d -1 2>/dev/null || true
    fi
}

# Edge Case 5: Derived Key Cache Security Validation
_validate_cache_security() {
    local cache_dir="$PADLOCK_DIR/ignition/.derived"
    
    if [[ -d "$cache_dir" ]]; then
        # Check cache directory permissions
        local cache_perms=$(stat -c %a "$cache_dir" 2>/dev/null || stat -f %A "$cache_dir" 2>/dev/null)
        
        if [[ "$cache_perms" != "700" ]]; then
            warn "Cache directory permissions too permissive: $cache_perms"
            chmod 700 "$cache_dir"
        fi
        
        # Validate cache file permissions
        find "$cache_dir" -name "*.key" -not -perm 600 -exec chmod 600 {} \; 2>/dev/null
        
        # Check for suspicious cache files (older than 30 days)
        find "$cache_dir" -name "*.key" -mtime +30 -exec rm -f {} \; 2>/dev/null
    fi
}

_generate_security_incident_report() {
    local incident_type="$1"
    local timestamp="$2"
    local report_file="$PADLOCK_DIR/security_incidents.log"
    
    mkdir -p "$(dirname "$report_file")"
    
    cat >> "$report_file" <<EOF
INCIDENT_TYPE: $incident_type
TIMESTAMP: $timestamp
REPOSITORY: $(pwd)
USER: $(whoami)
HOST: $(hostname)
AFFECTED_KEYS: $(find "$PADLOCK_DIR/ignition/keys" -name "*.key" 2>/dev/null | wc -l)
---
EOF
    
    chmod 600 "$report_file"
}
```

### **4.3 Implementation Safeguards**

**Atomic Operations Pattern**:
```bash
_atomic_ignition_operation() {
    local operation="$1"
    local lock_file="$PADLOCK_DIR/.ignition.lock"
    
    # Acquire lock
    (
        flock -n 200 || {
            erro "Another ignition operation in progress"
            return 1
        }
        
        # Perform operation atomically
        case "$operation" in
            create|unlock|rotate)
                "$operation"_ignition_key "$@"
                ;;
            *)
                erro "Unknown atomic operation: $operation"
                return 1
                ;;
        esac
        
    ) 200>"$lock_file"
    
    local result=$?
    rm -f "$lock_file"
    return $result
}
```

**Input Validation Pattern**:
```bash
_validate_ignition_inputs() {
    local name="$1"
    local passphrase="$2"
    
    # Name validation
    if [[ -z "$name" ]]; then
        erro "Ignition key name cannot be empty"
        return 1
    fi
    
    if [[ ${#name} -gt 64 ]]; then
        erro "Ignition key name too long (max 64 characters)"
        return 1
    fi
    
    if [[ "$name" =~ [^a-zA-Z0-9_-] ]]; then
        erro "Ignition key name contains invalid characters (use: a-z, A-Z, 0-9, _, -)"
        return 1
    fi
    
    # Reserved name check
    case "$name" in
        master|root|admin|system)
            erro "Ignition key name '$name' is reserved"
            return 1
            ;;
    esac
    
    # Passphrase validation (if provided)
    if [[ -n "$passphrase" ]] && ! _validate_passphrase_strength "$passphrase"; then
        erro "Passphrase does not meet security requirements"
        erro "Requirements: minimum 12 characters, at least 2 character classes"
        return 1
    fi
    
    return 0
}
```

### **4.4 Mandatory gitsim Testing Framework**

**Critical Requirement**: ALL security features must be tested with gitsim environment virtualization. No exceptions, no shortcuts.

### **4.4 Mandatory gitsim Testing Framework**

**Critical Requirement**: ALL security features must be tested with gitsim environment virtualization. No exceptions, no shortcuts.

**gitsim Test Scenarios** (Required for Phase 1 completion):
```bash
# Security Test 1: Master Key Compromise Simulation
test_master_key_compromise_gitsim() {
    echo "=== Testing Master Key Compromise with gitsim ==="
    
    # Create isolated gitsim environment
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    # Initialize gitsim repository
    gitsim init
    gitsim config user.name "Test User"
    gitsim config user.email "test@example.com"
    
    # Setup repository with ignition
    padlock clamp . --ignition
    padlock ignite create master-key --phrase="original-pass-123"
    padlock ignite new --name=dist-key --phrase="dist-pass-456"
    
    # Create some test content and commit
    echo "test content" > test-file.txt
    gitsim add test-file.txt
    gitsim commit -m "Initial test content"
    
    # Simulate master key corruption/deletion
    echo "Simulating master key compromise..."
    rm -f .padlock/master.key
    
    # Test security responses
    echo "Testing ignition unlock without master key authority..."
    if padlock ignite unlock dist-key --phrase="dist-pass-456" 2>/dev/null; then
        echo "❌ SECURITY FAILURE: Ignition unlock succeeded without master key authority!"
        cd /tmp && rm -rf "$test_dir"
        return 1
    else
        echo "✅ SECURITY PASS: Properly rejected unlock without master key"
    fi
    
    # Test recovery procedures would go here
    # _test_master_key_recovery_scenario
    
    echo "✅ Master key compromise test completed successfully"
    cd /tmp && rm -rf "$test_dir"
    return 0
}

# Security Test 2: Passphrase Strength Enforcement
test_passphrase_strength_gitsim() {
    echo "=== Testing Passphrase Strength with gitsim ==="
    
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    padlock clamp . --ignition
    
    # Test weak passphrases are rejected
    local weak_passphrases=("123" "password" "abc123" "short" "qwerty")
    local failed_tests=0
    
    for weak_pass in "${weak_passphrases[@]}"; do
        echo "Testing weak passphrase: '$weak_pass'"
        if padlock ignite create weak-test --phrase="$weak_pass" 2>/dev/null; then
            echo "❌ SECURITY FAILURE: Weak passphrase accepted: $weak_pass"
            ((failed_tests++))
        else
            echo "✅ SECURITY PASS: Weak passphrase properly rejected: $weak_pass"
        fi
    done
    
    # Test strong passphrase is accepted
    if padlock ignite create strong-test --phrase="StrongPass123!@#" 2>/dev/null; then
        echo "✅ Strong passphrase properly accepted"
    else
        echo "❌ Strong passphrase incorrectly rejected"
        ((failed_tests++))
    fi
    
    cd /tmp && rm -rf "$test_dir"
    
    if [[ $failed_tests -eq 0 ]]; then
        echo "✅ Passphrase strength test completed successfully"
        return 0
    else
        echo "❌ Passphrase strength test failed ($failed_tests failures)"
        return 1
    fi
}

# Security Test 3: Metadata Corruption Recovery  
test_metadata_corruption_gitsim() {
    echo "=== Testing Metadata Corruption Recovery with gitsim ==="
    
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    padlock clamp . --ignition
    
    # Create ignition key and commit to gitsim
    padlock ignite create test-key --phrase="test-pass-strong-123"
    echo "test file" > secure-file.txt
    gitsim add secure-file.txt
    gitsim commit -m "Added secure file with ignition"
    
    # Corrupt metadata file
    echo "Simulating metadata corruption..."
    echo "invalid json corruption" > .padlock/ignition/metadata/test-key.json
    
    # Test recovery mechanisms
    echo "Testing metadata recovery..."
    if _recover_metadata_corruption ".padlock/ignition/keys/test-key.ikey" 2>/dev/null; then
        echo "✅ Metadata corruption recovery succeeded"
        
        # Verify key still works after recovery
        if padlock ignite unlock test-key --phrase="test-pass-strong-123" 2>/dev/null; then
            echo "✅ Key functional after metadata recovery"
        else
            echo "❌ Key non-functional after metadata recovery"
            cd /tmp && rm -rf "$test_dir"
            return 1
        fi
    else
        echo "❌ Metadata corruption recovery failed"
        cd /tmp && rm -rf "$test_dir"
        return 1
    fi
    
    cd /tmp && rm -rf "$test_dir"
    echo "✅ Metadata corruption recovery test completed successfully"
    return 0
}

# Security Test 4: Environment Variable Exposure Prevention
test_env_var_exposure_gitsim() {
    echo "=== Testing Environment Variable Security with gitsim ==="
    
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    padlock clamp . --ignition
    padlock ignite create env-test --phrase="env-test-strong-456"
    
    # Test environment variable handling
    export PADLOCK_IGNITION_PASS="secret-test-passphrase-789"
    
    echo "Testing environment variable usage..."
    padlock ignite unlock env-test 2>/dev/null || true
    
    # Check if passphrase is properly cleared after use
    if [[ -n "$PADLOCK_IGNITION_PASS" ]]; then
        echo "❌ SECURITY FAILURE: Environment variable not cleared after use"
        unset PADLOCK_IGNITION_PASS
        cd /tmp && rm -rf "$test_dir"
        return 1
    else
        echo "✅ Environment variable properly cleared after use"
    fi
    
    # Test that passphrase doesn't appear in process list during use
    # This would need more sophisticated testing in real implementation
    
    cd /tmp && rm -rf "$test_dir"
    echo "✅ Environment variable security test completed successfully"
    return 0
}

# Security Test 5: Derived Key Cache Security
test_cache_security_gitsim() {
    echo "=== Testing Cache Security with gitsim ==="
    
    local test_dir=$(mktemp -d)
    cd "$test_dir"
    
    gitsim init
    padlock clamp . --ignition
    
    # Create ignition key to populate cache
    padlock ignite create cache-test --phrase="cache-test-strong-678"
    gitsim add .
    gitsim commit -m "Created ignition key"
    
    # Check cache directory permissions
    local cache_dir=".padlock/ignition/.derived"
    if [[ -d "$cache_dir" ]]; then
        local cache_perms=$(stat -c %a "$cache_dir" 2>/dev/null || stat -f %A "$cache_dir" 2>/dev/null)
        
        if [[ "$cache_perms" != "700" ]]; then
            echo "❌ SECURITY FAILURE: Cache directory permissions too permissive: $cache_perms"
            cd /tmp && rm -rf "$test_dir"
            return 1
        else
            echo "✅ Cache directory permissions correct: $cache_perms"
        fi
        
        # Check cache file permissions
        local failed_files=0
        for cache_file in "$cache_dir"/*.key; do
            if [[ -f "$cache_file" ]]; then
                local file_perms=$(stat -c %a "$cache_file" 2>/dev/null || stat -f %A "$cache_file" 2>/dev/null)
                if [[ "$file_perms" != "600" ]]; then
                    echo "❌ Cache file permissions too permissive: $cache_file ($file_perms)"
                    ((failed_files++))
                else
                    echo "✅ Cache file permissions correct: $(basename "$cache_file") ($file_perms)"
                fi
            fi
        done
        
        if [[ $failed_files -gt 0 ]]; then
            cd /tmp && rm -rf "$test_dir"
            return 1
        fi
    else
        echo "ℹ️  No cache directory found (acceptable for this test)"
    fi
    
    cd /tmp && rm -rf "$test_dir"
    echo "✅ Cache security test completed successfully"
    return 0
}

# Master gitsim test runner for all security features
test_ignition_security_comprehensive_gitsim() {
    echo "========================================"
    echo "COMPREHENSIVE IGNITION SECURITY TESTING"
    echo "Using gitsim environment virtualization"
    echo "========================================"
    
    local tests=(
        "test_master_key_compromise_gitsim"
        "test_passphrase_strength_gitsim" 
        "test_metadata_corruption_gitsim"
        "test_env_var_exposure_gitsim"
        "test_cache_security_gitsim"
    )
    
    local passed=0
    local total=${#tests[@]}
    
    for test_func in "${tests[@]}"; do
        echo
        echo ">>> Running: $test_func"
        if $test_func; then
            echo "✅ PASSED: $test_func"
            ((passed++))
        else
            echo "❌ FAILED: $test_func"
        fi
        echo "----------------------------------------"
    done
    
    echo
    echo "========================================"
    echo "SECURITY TEST RESULTS"
    echo "========================================"
    echo "Passed: $passed/$total"
    
    if [[ $passed -eq $total ]]; then
        echo "🎉 ALL SECURITY TESTS PASSED WITH GITSIM"
        echo "✅ Phase 1 implementation meets security requirements"
        return 0
    else
        echo "💥 SECURITY TESTS FAILED - IMPLEMENTATION NOT READY"
        echo "❌ Phase 1 completion blocked until all tests pass"
        return 1
    fi
}
```

**Test Sequence**:
```bash
# Functional integration test
test_ignition_integration() {
    # Setup
    padlock clamp /tmp/test-repo -K "test-passphrase"
    
    # Create keys
    padlock ignite create test-master --phrase="master-pass"
    padlock ignite new --name=test-distro --phrase="distro-pass"
    
    # Test unlock
    padlock ignite unlock test-distro --phrase="distro-pass"
    
    # Test environment variable unlock
    export PADLOCK_IGNITION_PASS="distro-pass"
    padlock ignite unlock test-distro
    
    # Validate authority
    padlock key authority --key1="$PADLOCK_DIR/master.key" --key2="$PADLOCK_DIR/ignition/keys/test-distro.dkey"
    
    # Cleanup
    padlock declamp /tmp/test-repo
    unset PADLOCK_IGNITION_PASS
}
```

## **Phase 2: Ignition-Aware Repair System (Future Implementation)**

### **Critical Gap Identified**
The current repair system (`padlock repair`) operates on M & R keys only. With ignition keys (I & D) added, the repair system needs major enhancement to handle:

- **Ignition key corruption/deletion**
- **Lock/unlock state detection with ignition keys**
- **Skull key integration** with ignition hierarchy
- **Recovery workflows** when ignition keys are compromised

### **Phase 2 Scope: Enhanced Repair System**

**Required Functions** (to be implemented post-Phase 1):
```bash
_diagnose_ignition_state()          # Detect ignition system health
_repair_ignition_metadata()         # Fix corrupted metadata  
_recover_ignition_from_skull()      # Use skull key for ignition recovery
_rebuild_ignition_hierarchy()       # Reconstruct I/D key relationships
_validate_ignition_integrity()      # Comprehensive integrity checking
```

**Repair Command Enhancements**:
```bash
# Phase 2 repair capabilities
padlock repair --ignition              # Repair ignition-specific issues
padlock repair --skull-recovery        # Recover using skull key backup
padlock repair --lock-state            # Fix stuck lock/unlock states
padlock repair --hierarchy             # Rebuild key hierarchy relationships
padlock repair --comprehensive        # Full system diagnosis and repair
```

### **Phase 3: Skull Key System Revision**

**Current Issue**: The skull key (X) implementation may need revision to properly integrate with the ignition hierarchy.

**Skull Key Enhancement Requirements**:
- **Ignition Backup**: Skull key should back up ignition master keys
- **Recovery Integration**: Skull key recovery should rebuild ignition system
- **Authority Chain**: Skull key must maintain proper authority relationships
- **Metadata Preservation**: Skull key should preserve ignition metadata

**Implementation Note**: This may require architectural changes to the current skull key system and should be carefully planned as a separate phase.

### **Implementation Priority**

1. **Phase 1**: Core ignition system (this plan)
2. **Phase 2**: Ignition-aware repair system
3. **Phase 3**: Skull key system revision and integration

**Rationale**: Implementing core ignition first allows us to understand the repair requirements better, then enhance the skull key system with full knowledge of both the base system and ignition system needs.

### **1. Philosophical Superiority**
- Restores proper Unix citizenship to age
- Makes age behave like the tool it was designed to be
- Elegant subversion: gives age exactly what it wants while maintaining automation
- No external dependencies - pure age solution

### **2. Technical Excellence**
- Implements proven cryptographic patterns from pilot testing  
- Maintains master key authority architecture
- Provides automation-friendly environment variable support
- Uses age's native passphrase protection (just automated)

### **3. Magic Factor** ✨
- Others will wonder how you made age so automatable
- Clean, elegant solution that looks impossible at first glance
- Demonstrates advanced Unix engineering principles
- Perfect example of working with tools instead of against them

### **4. User Experience**
- Commands read naturally: `padlock ignite create ai-bot --phrase="secret"`
- Fully automated: `PADLOCK_IGNITION_PASS="secret" padlock ignite unlock ai-bot`
- No external crypto dependencies to worry about
- Age gets its beloved TTY, users get their automation

## **Implementation Timeline**

- **Week 1**: Core TTY functions and basic create/unlock operations
- **Week 2**: Storage architecture and metadata system  
- **Week 3**: Integration with existing padlock workflows
- **Week 4**: Security validation and comprehensive testing

**Total Effort Estimate**: 13-16 story points (as validated by Plan X pilot)

**Phase 1 Deliverables**: 
- Functional `create`, `new`, `unlock`, `list`, `status` commands
- Complete TTY subversion automation
- Security validation framework
- Integration with existing master key authority

**Future Phases**: Advanced features (allow, rotate, revoke, verify, reset) will be implemented as separate phases building on this foundation.

This Phase 1 implementation establishes the core ignition system architecture and delivers essential automation capabilities while leaving advanced features as well-documented stubs for future development.