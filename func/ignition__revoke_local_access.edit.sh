# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_revoke_local_access | edit:ignition__revoke_local_access | orig_sum:87a4f77da4e200e746119bd194a7e934593c41727b2742bc4afbd16affb754b0
ignition__revoke_local_access() {
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
