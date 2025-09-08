# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/04_helpers.sh | src_sum:006090cb5331df867a9c820b7a6fc3a1eb87cc667567a92afca45282d7d9a760 | orig:_unlock_ignition_with_tty_magic | edit:helpers__unlock_ignition_with_tty_magic | orig_sum:cb7c547caccd94fc6b537661f9461d317bf727aaef843b682d607e1778e13a07
helpers__unlock_ignition_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Unlocking ignition key with TTY magic: $name"
    
    # Setup temp file cleanup
    _temp_setup_trap
    
    # Find key file (master or distro)
    local key_file=""
    if [[ -f "$PADLOCK_DIR/ignition/keys/$name.ikey" ]]; then
        key_file="$PADLOCK_DIR/ignition/keys/$name.ikey"
    elif [[ -f "$PADLOCK_DIR/ignition/keys/$name.dkey" ]]; then
        key_file="$PADLOCK_DIR/ignition/keys/$name.dkey"
    else
        error "No ignition key found: $name"
        return 1
    fi
    
    # Validate master key authority first
    if ! _validate_ignition_authority "$key_file"; then
        return 1
    fi
    
    # Decrypt with master key first  
    local temp_bundle="$(_temp_mktemp)"
    local master_private="$(_get_master_private_key)"
    
    if ! age -d -i "$master_private" < "$key_file" > "$temp_bundle"; then
        error "Cannot decrypt ignition key (master key access denied)"
        return 1
    fi
    
    # Use TTY subversion to decrypt with passphrase
    local decrypted_bundle="$(_temp_mktemp)"
    if _age_interactive_decrypt "$temp_bundle" "$passphrase" > "$decrypted_bundle"; then
        # Extract private key from decrypted bundle
        local private_key
        private_key=$(sed -n '4,$p' "$decrypted_bundle")
        
        # Export for repository access
        export PADLOCK_IGNITION_KEY="$private_key"
        
        okay "Ignition key unlocked with TTY magic: $name"
        return 0
    else
        error "Incorrect passphrase for ignition key: $name"
        return 1
    fi
}
