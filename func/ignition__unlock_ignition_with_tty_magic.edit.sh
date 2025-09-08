# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_unlock_ignition_with_tty_magic | edit:ignition__unlock_ignition_with_tty_magic | orig_sum:e63b769121dc8b1869be9dd36ba6ee552a15a9b200a45ba63750cf5654906f0e
ignition__unlock_ignition_with_tty_magic() {
    local name="$1"  
    local passphrase="$2"
    
    trace "TTY magic: unlocking with key $name"
    
    # Load the key bundle using storage system
    _load_key_bundle "$name" "auto" || {
        error "Failed to load ignition key: $name"
        return 1
    }
    
    # Decrypt the key bundle if it's encrypted (development mode)
    local decrypted_key
    if echo "$LOADED_KEY_DATA" | grep -q "# ENCRYPTED WITH PASSPHRASE"; then
        if [[ -n "$passphrase" ]]; then
            # Extract the actual key from development format
            decrypted_key=$(echo "$LOADED_KEY_DATA" | grep -v "^#" | head -1)
            trace "Development mode: Extracted key from passphrase-protected format"
        else
            error "Key is encrypted but no passphrase provided"
            return 1
        fi
    else
        # Use key directly if not encrypted
        decrypted_key="$LOADED_KEY_DATA"
    fi
    
    # Verify the decrypted key is valid age format
    if echo "$decrypted_key" | grep -q "AGE-SECRET-KEY"; then
        info "✓ Successfully unlocked ignition key: $name"
        info "  Key type: $LOADED_KEY_TYPE"
        
        # TODO: Use the decrypted key to unlock repository secrets
        # This would integrate with the existing padlock unlock mechanism
        info "  [PLACEHOLDER] Would unlock repository with decrypted key"
        
        return 0
    else
        error "Invalid key format after decryption"
        return 1
    fi
}
_unlock_ignition_with_tty_magic() {
    local name="$1"  
    local passphrase="$2"
    
    trace "TTY magic: unlocking with key $name"
    
    # Load the key bundle using storage system
    _load_key_bundle "$name" "auto" || {
        error "Failed to load ignition key: $name"
        return 1
    }
    
    # Decrypt the key bundle if it's encrypted (development mode)
    local decrypted_key
    if echo "$LOADED_KEY_DATA" | grep -q "# ENCRYPTED WITH PASSPHRASE"; then
        if [[ -n "$passphrase" ]]; then
            # Extract the actual key from development format
            decrypted_key=$(echo "$LOADED_KEY_DATA" | grep -v "^#" | head -1)
            trace "Development mode: Extracted key from passphrase-protected format"
        else
            error "Key is encrypted but no passphrase provided"
            return 1
        fi
    else
        # Use key directly if not encrypted
        decrypted_key="$LOADED_KEY_DATA"
    fi
    
    # Verify the decrypted key is valid age format
    if echo "$decrypted_key" | grep -q "AGE-SECRET-KEY"; then
        info "✓ Successfully unlocked ignition key: $name"
        info "  Key type: $LOADED_KEY_TYPE"
        
        # TODO: Use the decrypted key to unlock repository secrets
        # This would integrate with the existing padlock unlock mechanism
        info "  [PLACEHOLDER] Would unlock repository with decrypted key"
        
        return 0
    else
        error "Invalid key format after decryption"
        return 1
    fi
}
