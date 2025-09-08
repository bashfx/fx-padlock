# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/09_key_api.sh | src_sum:e9fb365ce0c83b8e04e7a60e77f8660efb4e356a770fa7303a2a81d23e8cd466 | orig:_revoke_ignition_access | edit:key__revoke_ignition_access | orig_sum:5d44ce4e87d85dac2a4e430c73cbb12e88022de8d251b97465c792ee776b9397
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
