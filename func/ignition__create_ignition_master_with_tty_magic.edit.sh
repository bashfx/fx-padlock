# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_create_ignition_master_with_tty_magic | edit:ignition__create_ignition_master_with_tty_magic | orig_sum:b4c4e8b281946751a5edfd56551fcdf68efc28debb657a97c7153c379d4324ad
ignition__create_ignition_master_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating ignition master for $name"
    
    # Check if master key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.ikey" ]]; then
        error "Ignition master key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the ignition master (I key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate ignition master key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    # Extract public key  
    age-keygen -y < "$temp_key" > "$temp_pub" 2>/dev/null || {
        error "Failed to extract public key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    local private_key=$(cat "$temp_key")
    local public_key=$(cat "$temp_pub")
    
    # Clean up temp files
    rm -f "$temp_key" "$temp_pub"
    
    # For development: Store key with passphrase marker (TODO: implement proper age encryption)
    local key_bundle
    if [[ -n "$passphrase" ]]; then
        # Store key with passphrase metadata for now (TODO: proper encryption)
        # In production, this would use age encryption or similar
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "master" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store ignition master key"
        return 1
    }
    
    info "✓ Ignition master key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    
    return 0
}
_create_ignition_master_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating ignition master for $name"
    
    # Check if master key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.ikey" ]]; then
        error "Ignition master key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the ignition master (I key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate ignition master key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    # Extract public key  
    age-keygen -y < "$temp_key" > "$temp_pub" 2>/dev/null || {
        error "Failed to extract public key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    local private_key=$(cat "$temp_key")
    local public_key=$(cat "$temp_pub")
    
    # Clean up temp files
    rm -f "$temp_key" "$temp_pub"
    
    # For development: Store key with passphrase marker (TODO: implement proper age encryption)
    local key_bundle
    if [[ -n "$passphrase" ]]; then
        # Store key with passphrase metadata for now (TODO: proper encryption)
        # In production, this would use age encryption or similar
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "master" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store ignition master key"
        return 1
    }
    
    info "✓ Ignition master key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    
    return 0
}
