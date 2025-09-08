# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/04_helpers.sh | src_sum:006090cb5331df867a9c820b7a6fc3a1eb87cc667567a92afca45282d7d9a760 | orig:_create_ignition_distro_with_tty_magic | edit:helpers__create_ignition_distro_with_tty_magic | orig_sum:5844bff3c1dec54ffab50bd53174dbf66aa5755987a0369a9150c6a6aef1344d
helpers__create_ignition_distro_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Creating ignition distributed key with TTY magic: $name"
    
    # Setup temp file cleanup
    _temp_setup_trap
    
    # Generate base age key  
    local temp_key="$(_temp_mktemp)"
    age-keygen > "$temp_key"
    
    # Create JSON metadata bundle
    local metadata
    metadata=$(_create_ignition_metadata "$name" "ignition-distributed")
    
    # Create key bundle (metadata + private key)
    local key_bundle="$(_temp_mktemp)"
    {
        echo "PADLOCK_IGNITION_DISTRO"
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
        age -r "$master_pubkey" < "$passphrase_encrypted" > "$PADLOCK_DIR/ignition/keys/$name.dkey"
        
        # Store metadata separately for queries
        echo "$metadata" > "$PADLOCK_DIR/ignition/metadata/$name.json"
        
        okay "Ignition distributed key created with TTY magic: $name"
        return 0
    else
        error "Failed to create ignition distributed key: $name"
        return 1
    fi
}
