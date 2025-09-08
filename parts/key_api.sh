# 06d_key_api.sh - General Key Management & Storage Functions
# Part of fx-padlock BashFX architecture remediation
# Contains: Key storage, bundle management, and general key operations=== do_key ===
do_key() {
    local action="${1:-}"
    shift || true
    
    case "$action" in
        --set-global)
            local key_file="$1"
            if [[ ! -f "$key_file" ]]; then
                fatal "Key file not found: $key_file"
            fi
            
            info "🔑 Setting global master key..."
            mkdir -p "$(dirname "$PADLOCK_GLOBAL_KEY")"
            cp "$key_file" "$PADLOCK_GLOBAL_KEY"
            chmod 600 "$PADLOCK_GLOBAL_KEY"
            okay "✓ Global master key set"
            ;;
        --show-global)
            if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
                error "No global master key found"
                info "Run: padlock key --generate-global"
                return 1
            fi
            
            local public_key
            public_key=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
            echo "$public_key"
            ;;
        --generate-global)
            _logo
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]] && [[ "${2:-}" != "--force" ]]; then
                error "Global master key already exists"
                info "Use --force to overwrite"
                return 1
            fi
            
            _ensure_master_key
            okay "✓ Global master key generated"
            ;;
        --add-recipient)
            local recipient="$1"
            if [[ -z "$recipient" ]]; then
                fatal "--add-recipient requires a public key"
            fi
            
            # Check if we're in a repo with locker config
            if [[ ! -f "locker/.padlock" ]]; then
                error "Not in an unlocked padlock repository"
                info "Run 'padlock unlock' first"
                return 1
            fi
            
            # Load current config
            source "locker/.padlock"
            
            # Add recipient to existing list
            if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
                export AGE_RECIPIENTS="$AGE_RECIPIENTS,$recipient"
            else
                export AGE_RECIPIENTS="$recipient"
            fi
            
            # Update config file
            __print_padlock_config "locker/.padlock" "$(basename "$PWD")"
            
            okay "✓ Added recipient: ${recipient:0:20}..."
            info "Re-encrypt with: padlock lock"
            ;;
        restore)
            _logo
            _restore_master_key
            ;;
        
        # New key testing commands
        is)
            # padlock key is <type> --key=/path
            local key_type="$1"
            local key_path=""
            shift || true
            
            # Parse options with BashFX pattern
            local opts=("$@")
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key=*)
                        key_path="${opts[i]#*=}"
                        ;;
                    --path=*)
                        key_path="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key_path" ]]; then
                error "Missing --key or --path parameter"
                info "Usage: padlock key is <type> --key=/path/to/key"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if key at '$key_path' is type '$key_type'"
            info "This feature will analyze key metadata and structure"
            return 0
            ;;
            
        authority)
            # padlock key authority --key1=/path --key2=/path
            local key1="" key2=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key1=*)
                        key1="${opts[i]#*=}"
                        ;;
                    --key2=*)
                        key2="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key1" ]] || [[ -z "$key2" ]]; then
                error "Missing required parameters"
                info "Usage: padlock key authority --key1=/path --key2=/path"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if '$key1' has authority over '$key2'"
            info "This will verify key hierarchy relationships"
            return 0
            ;;
            
        subject)
            # padlock key subject --key1=/path --key2=/path
            local key1="" key2=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key1=*)
                        key1="${opts[i]#*=}"
                        ;;
                    --key2=*)
                        key2="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key1" ]] || [[ -z "$key2" ]]; then
                error "Missing required parameters"
                info "Usage: padlock key subject --key1=/path --key2=/path"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if '$key1' is subject to '$key2'"
            info "This will verify child-parent key relationships"
            return 0
            ;;
            
        type)
            # padlock key type --key=/path
            local key_path=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key=*)
                        key_path="${opts[i]#*=}"
                        ;;
                    --path=*)
                        key_path="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key_path" ]]; then
                error "Missing --key parameter"
                info "Usage: padlock key type --key=/path/to/key"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Identifying key type for: $key_path"
            info "Will return: skull|master|repo|ignition|distro|unknown"
            echo "unknown"  # Placeholder return
            return 0
            ;;
            
        ""|*)
            if [[ -z "$action" ]]; then
                info "Available key management actions:"
            else
                error "Unknown key action: $action"
            fi
            info "  --set-global <key>        Set global master key"
            info "  --show-global             Display global public key"
            info "  --generate-global         Generate new global key"
            info "  --add-recipient <key>     Add recipient to current repo"
            info "  restore                   Restore master key from skull backup"
            info ""
            info "Key Testing Commands:"
            info "  is <type> --key=/path     Test if key is specific type"
            info "  authority --key1=X --key2=Y  Test authority relationship"
            info "  subject --key1=X --key2=Y    Test subject relationship"
            info "  type --key=/path          Identify key type"
            [[ -n "$action" ]] && return 1 || return 0
            ;;
    esac
}


do_revoke() {
    local target="${1:-}"
    shift || true
    
    case "$target" in
        ignition)
            # padlock revoke ignition [name]
            local name="${1:-default}"
            info "[STUB] Revoking ignition key: $name"
            info "This will permanently invalidate the ignition key"
            return 0
            ;;
            
        distro)
            # padlock revoke distro [name]
            local name="$1"
            if [[ -z "$name" ]]; then
                error "Missing distro key name"
                info "Usage: padlock revoke distro <name>"
                return 1
            fi
            info "[STUB] Revoking distributed key: $name"
            info "Third-party access with this key will be terminated"
            return 0
            ;;
            
        # Legacy support
        --local)
            _revoke_local_access "$1"
            ;;
        -K|--ignition)
            _revoke_ignition_access "$1"
            ;;
            
        ""|help|*)
            if [[ -z "$target" ]]; then
                info "Available revocation commands:"
            elif [[ "$target" != "help" ]]; then
                error "Unknown revocation target: $target"
            else
                info "Revocation Commands:"
            fi
            info "  ignition [name]     Revoke ignition key (invalidates D keys)"
            info "  distro <name>       Revoke specific distributed key"
            info ""
            info "Legacy:"
            info "  --local             Revoke local access (WARNING: unrecoverable)"
            info "  --ignition          Revoke legacy ignition access"
            [[ -n "$target" ]] && [[ "$target" != "help" ]] && return 1 || return 0
            ;;
    esac
}


_revoke_local_access() {
    local force="$1"
    
    REPO_ROOT="$(_get_repo_root .)"
    
    error "⚠️  DESTRUCTIVE OPERATION: Local access revocation"
    warn "This will make ALL encrypted content permanently unrecoverable!"
    warn "Even with master keys, the content will be lost."
    echo
    info "This operation will:"
    info "  • Remove local repository key"
    info "  • Remove master key references"
    info "  • Leave locker.age encrypted but unrecoverable"
    echo
    
    if [[ "$force" != "--force" ]]; then
        error "This operation requires --force flag to confirm"
        info "Usage: padlock revoke --local --force"
        return 1
    fi
    
    # Additional confirmation
    echo
    warn "⚠️  FINAL WARNING: This will permanently destroy access to encrypted data"
    read -p "Type 'DESTROY' to confirm: " -r confirm
    if [[ "$confirm" != "DESTROY" ]]; then
        info "Revocation cancelled"
        return 0
    fi
    
    local revoked_items=()
    
    # Remove local repository key
    local repo_key="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
    if [[ -f "$repo_key" ]]; then
        rm -f "$repo_key"
        revoked_items+=("local repository key")
    fi
    
    # Remove master key reference from any config
    if [[ -f "$REPO_ROOT/locker/.padlock" ]]; then
        # If unlocked, remove master key from recipients
        source "$REPO_ROOT/locker/.padlock"
        if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
            # Remove master key recipient
            local master_public
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                master_public=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null || true)
                if [[ -n "$master_public" ]]; then
                    # Remove master key from recipients list
                    AGE_RECIPIENTS=$(echo "$AGE_RECIPIENTS" | sed "s/,$master_public//g" | sed "s/$master_public,//g" | sed "s/$master_public//g")
                    export AGE_RECIPIENTS
                    __print_padlock_config "$REPO_ROOT/locker/.padlock" "$(basename "$REPO_ROOT")"
                    revoked_items+=("master key access")
                fi
            fi
        fi
    fi
    
    # Remove from manifest
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" ]]; then
        local temp_manifest
        temp_manifest=$(mktemp)
        grep -v -F "$REPO_ROOT" "$manifest_file" > "$temp_manifest" 2>/dev/null || true
        mv "$temp_manifest" "$manifest_file"
        revoked_items+=("manifest entry")
    fi
    
    # Create revocation marker
    cat > "$REPO_ROOT/.revoked" << EOF
# Padlock Access Revoked
# Generated: $(date)
# Repository: $(basename "$REPO_ROOT")

This repository's encryption keys have been revoked.
The encrypted content in locker.age is permanently unrecoverable.

Revoked access types:
$(printf "  • %s\n" "${revoked_items[@]}")

If this was done in error, restore from backup immediately.
EOF
    
    error "🔒 Local access permanently revoked"
    if [[ ${#revoked_items[@]} -gt 0 ]]; then
        info "Revoked: ${revoked_items[*]}"
    fi
    warn "⚠️  Encrypted content is now permanently unrecoverable"
    info "💀 Created .revoked file as marker"
}


_revoke_ignition_access() {
    local force="$1"
    
    REPO_ROOT="$(_get_repo_root .)"
    
    if [[ ! -d "$REPO_ROOT/.chest" ]]; then
        error "Repository is not using ignition system"
        info "Nothing to revoke"
        return 1
    fi
    
    lock "🔥 Revoking ignition key access..."
    
    local revoked_items=()
    
    # Remove ignition key files
    if [[ -f "$REPO_ROOT/.chest/ignition.age" ]]; then
        rm -f "$REPO_ROOT/.chest/ignition.age"
        revoked_items+=("encrypted ignition key")
    fi
    
    # Remove any temporary ignition keys
    rm -f "$REPO_ROOT/.ignition.key"
    
    # If chest is unlocked, we need to transition to standard mode
    if [[ -d "$REPO_ROOT/locker" ]] && [[ -f "$REPO_ROOT/locker/.padlock" ]]; then
        info "Converting from ignition to standard mode..."
        
        # Generate new repository key
        local new_repo_key="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
        age-keygen -o "$new_repo_key" >/dev/null
        chmod 600 "$new_repo_key"
        
        # Get new public key
        local new_public
        new_public=$(age-keygen -y "$new_repo_key")
        
        # Update configuration to standard mode with master key backup
        _ensure_master_key
        local master_public
        master_public=$(age-keygen -y "$PADLOCK_GLOBAL_KEY")
        
        export AGE_RECIPIENTS="$new_public,$master_public"
        export PADLOCK_KEY_FILE="$new_repo_key"
        export AGE_PASSPHRASE=""
        
        __print_padlock_config "$REPO_ROOT/locker/.padlock" "$(basename "$REPO_ROOT")"
        
        info "🔑 Generated new repository key for standard mode"
        revoked_items+=("ignition system")
        revoked_items+=("converted to standard mode")
    fi
    
    # Remove chest directory if empty
    if [[ -d "$REPO_ROOT/.chest" ]] && [[ -z "$(ls -A "$REPO_ROOT/.chest" 2>/dev/null)" ]]; then
        rm -rf "$REPO_ROOT/.chest"
        revoked_items+=("chest directory")
    fi
    
    # Update manifest type
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" ]]; then
        local temp_manifest
        temp_manifest=$(mktemp)
        # Change type from ignition to standard
        sed "s/|$REPO_ROOT|ignition|/|$REPO_ROOT|standard|/g" "$manifest_file" > "$temp_manifest" 2>/dev/null || true
        mv "$temp_manifest" "$manifest_file"
        trace "Updated manifest type to standard"
    fi
    
    okay "✓ Ignition access revoked"
    if [[ ${#revoked_items[@]} -gt 0 ]]; then
        info "Changes: ${revoked_items[*]}"
    fi
    
    if [[ -d "$REPO_ROOT/locker" ]]; then
        info "📝 Repository is now in standard mode"
        info "🔐 Re-encrypt with: padlock lock"
    else
        info "🔒 Repository remains locked in standard mode"
        info "🔓 Unlock with: padlock unlock"
    fi
}


_setup_ignition_directories() {
    local repo_root="${1:-$REPO_ROOT}"
    
    if [[ -z "$repo_root" ]]; then
        error "No repository root specified for ignition setup"
        return 1
    fi
    
    local padlock_dir="$repo_root/.padlock"
    local ignition_dir="$padlock_dir/ignition"
    
    # Create ignition directory structure per ROADMAP.md
    trace "Setting up ignition directories in $padlock_dir"
    
    mkdir -p "$ignition_dir/keys" || {
        error "Failed to create ignition keys directory"
        return 1
    }
    
    mkdir -p "$ignition_dir/metadata" || {
        error "Failed to create ignition metadata directory"  
        return 1
    }
    
    mkdir -p "$ignition_dir/metadata/cache" || {
        error "Failed to create ignition cache directory"
        return 1
    }
    
    mkdir -p "$ignition_dir/.derived" || {
        error "Failed to create derived keys directory"
        return 1
    }
    
    # Create ignition manifest if it doesn't exist
    local manifest="$ignition_dir/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        trace "Creating ignition manifest: $manifest"
        cat > "$manifest" << 'EOF'
{
  "version": "1.0",
  "created": "",
  "updated": "",
  "repo_id": "",
  "master_key_fingerprint": "",
  "ignition_keys": {},
  "distro_keys": {}
}
EOF
        # Set creation timestamp
        local timestamp=$(date -Iseconds)
        sed -i "s/\"created\": \"\"/\"created\": \"$timestamp\"/" "$manifest"
        sed -i "s/\"updated\": \"\"/\"updated\": \"$timestamp\"/" "$manifest"
    fi
    
    info "✓ Ignition directories ready: $ignition_dir"
    return 0
}


_create_ignition_metadata() {
    local key_type="$1"     # "master" or "distro"  
    local name="$2"
    local key_path="$3"
    local fingerprint="$4"
    local encrypted="${5:-true}"  # Default to encrypted
    
    local metadata_file="$REPO_ROOT/.padlock/ignition/metadata/${name}.json"
    local timestamp=$(date -Iseconds)
    
    trace "Creating metadata for $key_type key: $name"
    
    cat > "$metadata_file" << EOF
{
  "name": "$name",
  "type": "$key_type",
  "created": "$timestamp",
  "updated": "$timestamp",
  "key_file": "$(basename "$key_path")",
  "fingerprint": "$fingerprint",
  "encrypted": $encrypted,
  "status": "active",
  "authority": {
    "master_key": true,
    "repo_key": true
  },
  "usage": {
    "unlock_count": 0,
    "last_used": null
  }
}
EOF
    
    return 0
}


_store_key_bundle() {
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


_load_key_bundle() {
    local name="$1"
    local key_type="${2:-auto}"  # "master", "distro", or "auto"
    
    # Auto-detect key type if not specified
    if [[ "$key_type" == "auto" ]]; then
        if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.ikey" ]]; then
            key_type="master"
        elif [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.dkey" ]]; then
            key_type="distro"  
        else
            error "No ignition key found for: $name"
            return 1
        fi
    fi
    
    local key_extension
    case "$key_type" in
        master) key_extension=".ikey" ;;
        distro) key_extension=".dkey" ;;
        *) error "Invalid key type: $key_type"; return 1 ;;
    esac
    
    local key_file="$REPO_ROOT/.padlock/ignition/keys/${name}${key_extension}"
    local metadata_file="$REPO_ROOT/.padlock/ignition/metadata/${name}.json"
    
    if [[ ! -f "$key_file" ]]; then
        error "Key file not found: $key_file"
        return 1
    fi
    
    if [[ ! -f "$metadata_file" ]]; then
        error "Metadata file not found: $metadata_file"
        return 1
    fi
    
    trace "Loading $key_type key bundle: $name"
    
    # Export key data and metadata for caller
    LOADED_KEY_DATA=$(cat "$key_file")
    LOADED_KEY_METADATA=$(cat "$metadata_file")
    LOADED_KEY_TYPE="$key_type"
    
    return 0
}

