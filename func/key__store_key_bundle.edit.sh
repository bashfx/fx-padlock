# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/09_key_api.sh | src_sum:e9fb365ce0c83b8e04e7a60e77f8660efb4e356a770fa7303a2a81d23e8cd466 | orig:_store_key_bundle | edit:key__store_key_bundle | orig_sum:58acd1e1acb23904434b8894efaca23102ca86c2bc1f941a44c7fd25d267e860
key__store_key_bundle() {
    local key_type="$1"     # "master" or "distro"
    local name="$2"
    local key_data="$3"
    local passphrase="$4"
    
    _setup_ignition_directories "$REPO_ROOT" || return 1
    
    local key_extension
    case "$key_type" in
        master) key_extension=".ikey" ;;
        distro) key_extension=".dkey" ;;
        *) error "Invalid key type: $key_type"; return 1 ;;
    esac
    
    local key_file="$REPO_ROOT/.padlock/ignition/keys/${name}${key_extension}"
    
    trace "Storing $key_type key bundle: $name"
    
    # For now, store key data directly (TODO: encrypt with passphrase using TTY magic)
    echo "$key_data" > "$key_file" || {
        error "Failed to store key bundle: $key_file"
        return 1
    }
    
    # Create fingerprint (simplified - use first 16 chars of key data hash)
    local fingerprint=$(echo "$key_data" | sha256sum | cut -c1-16)
    
    # Determine if key was encrypted
    local encrypted_status="false"
    if [[ -n "$passphrase" ]]; then
        encrypted_status="true"
    fi
    
    # Create metadata with encryption status
    _create_ignition_metadata "$key_type" "$name" "$key_file" "$fingerprint" "$encrypted_status" || {
        error "Failed to create metadata for key: $name"
        return 1
    }
    
    info "✓ Key bundle stored: $name ($key_type)"
    return 0
}
