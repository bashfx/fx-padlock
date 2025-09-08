# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/04_helpers.sh | src_sum:006090cb5331df867a9c820b7a6fc3a1eb87cc667567a92afca45282d7d9a760 | orig:_create_ignition_master_with_tty_magic | edit:helpers__create_ignition_master_with_tty_magic | orig_sum:d81abaaffc567c54a57093a7fbe141812a07da681a86cdcf3ddcb8f9199a6a07
_create_ignition_master_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Creating ignition master key with TTY magic: $name"
    
    # Setup temp file cleanup
    _temp_setup_trap
    
    # Create directory structure
    mkdir -p "$PADLOCK_DIR/ignition/keys"
    mkdir -p "$PADLOCK_DIR/ignition/metadata"
    mkdir -p "$PADLOCK_DIR/ignition/.derived"
    
    # Generate base age key  
    local temp_key="$(_temp_mktemp)"
    age-keygen > "$temp_key"
    
    # Create JSON metadata bundle
    local metadata
    metadata=$(_create_ignition_metadata "$name" "ignition-master")
    
    # Create key bundle (metadata + private key)
    local key_bundle="$(_temp_mktemp)"
    {
        echo "PADLOCK_IGNITION_KEY"
        echo "$metadata" | base64 -w0
        echo "---"
        cat "$temp_key"
    } > "$key_bundle"
    
    # TTY magic: encrypt bundle with passphrase
    local passphrase_encrypted="$(_temp_mktemp)"
    if _age_interactive_encrypt "$key_bundle" "$passphrase_encrypted" "$passphrase"; then
        # Double-encrypt with master key authority
        local master_pubkey
        master_pubkey=$(_get_master_public_key)
        age -r "$master_pubkey" < "$passphrase_encrypted" > "$PADLOCK_DIR/ignition/keys/$name.ikey"
        
        # Store metadata separately for queries
        echo "$metadata" > "$PADLOCK_DIR/ignition/metadata/$name.json"
        
        okay "Ignition master key created with TTY magic: $name"
        return 0
    else
        error "Failed to create ignition master key: $name"
        return 1
    fi
}
