# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_create_ignition_distro_with_tty_magic | edit:ignition__create_ignition_distro_with_tty_magic | orig_sum:643f7cd6d5c2948b57c5945564ef99f08730f9dcbbc18b359f7e2b1e23bf54e2
ignition__create_ignition_distro_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating distributed key for $name"
    
    # Check if distributed key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.dkey" ]]; then
        error "Distributed ignition key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the distributed key (D key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate distributed ignition key"
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
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "distro" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store distributed ignition key"
        return 1
    }
    
    # Export the key to current directory for third-party sharing
    local export_file="./ignition.${name}.key"
    echo "$key_bundle" > "$export_file" || {
        error "Failed to export distributed key to: $export_file"
        return 1
    }
    
    # Create MD5 checksum per requirements
    local checksum=$(md5sum "$export_file" | cut -d' ' -f1)
    
    info "✓ Distributed ignition key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    info "  Key file: $export_file"
    info "  MD5 checksum: $checksum"
    
    return 0
}
_create_ignition_distro_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating distributed key for $name"
    
    # Check if distributed key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.dkey" ]]; then
        error "Distributed ignition key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the distributed key (D key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate distributed ignition key"
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
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "distro" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store distributed ignition key"
        return 1
    }
    
    # Export the key to current directory for third-party sharing
    local export_file="./ignition.${name}.key"
    echo "$key_bundle" > "$export_file" || {
        error "Failed to export distributed key to: $export_file"
        return 1
    }
    
    # Create MD5 checksum per requirements
    local checksum=$(md5sum "$export_file" | cut -d' ' -f1)
    
    info "✓ Distributed ignition key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    info "  Key file: $export_file"
    info "  MD5 checksum: $checksum"
    
    return 0
}
