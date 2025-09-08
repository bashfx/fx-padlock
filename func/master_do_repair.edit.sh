# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/06_master_api.sh | src_sum:2158434627cf43659ef6d04d2a2446b980df50f94b93eddb92a6b1e842ee5855 | orig:do_repair | edit:master_do_repair | orig_sum:28c456fddc3a5aaff1ef63aaad12ac45f2a2737fdb2d34a264c6494f6b01f344
master_do_repair() {
    local repo_path="${1:-.}"
    repo_path="$(realpath "$repo_path")"
    
    info "🔧 Padlock Repair Tool"
    echo
    
    # Check if this looks like a padlock repository - show help if not
    if [[ ! -f "$repo_path/bin/padlock" ]]; then
        info "No padlock installation found in: $repo_path"
        info "The 'repair' command fixes existing padlock repositories"
        info ""
        info "Usage: padlock repair [path]"
        info ""
        info "Prerequisites:"
        info "  • Repository must have padlock already deployed"
        info "  • Use 'padlock clamp' to set up a new repository first"
        return 0
    fi
    
    # Check what's missing and what can be repaired
    local missing_items=()
    local can_repair=false
    local was_locked=false
    
    if [[ ! -f "$repo_path/locker/.padlock" ]]; then
        if [[ -d "$repo_path/locker" ]]; then
            # Repository is unlocked but .padlock is missing
            missing_items+=(".padlock config file")
            can_repair=true
        else
            # Repository appears to be locked, check if encrypted data exists
            if [[ -f "$repo_path/.chest/locker.age" ]] || [[ -f "$repo_path/locker.age" ]]; then
                info "Repository is currently locked. Unlocking first..."
                if cd "$repo_path" && ./bin/padlock unlock; then
                    was_locked=true
                    can_repair=true
                    missing_items+=(".padlock config file")
                else
                    error "Cannot unlock repository. Repair cannot proceed."
                    info "Ensure you have the correct master key or try 'padlock key restore'"
                    return 1
                fi
            else
                # No encrypted data found and no locker directory
                info "No encrypted locker found (locker.age or .chest/locker.age missing)"
                info "The 'repair' command expects to find encrypted locker data"
                info ""
                info "Usage: padlock repair [path]"
                info ""
                info "Prerequisites:"
                info "  • Repository should have a locker.age file (old format) or .chest/locker.age (new format)"
                info "  • Use 'padlock clamp' first if this is a new setup"
                return 0
            fi
        fi
    fi
    
    if [[ ${#missing_items[@]} -eq 0 ]]; then
        okay "✓ No missing artifacts detected"
        info "Repository appears to be in good condition."
        return 0
    fi
    
    # Look up repository in manifest for repair information
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    local manifest_entry=""
    
    if [[ -f "$manifest_file" ]]; then
        manifest_entry=$(grep "|$repo_path|" "$manifest_file" 2>/dev/null || true)
    fi
    
    if [[ -z "$manifest_entry" ]]; then
        warn "⚠️  Repository not found in global manifest"
        info "Attempting repair from available evidence..."
    else
        info "📋 Found manifest entry for this repository"
        trace "Manifest: $manifest_entry"
    fi
    
    # Repair missing .padlock file
    if printf '%s\n' "${missing_items[@]}" | grep -q ".padlock config file"; then
        info "🔧 Repairing .padlock configuration..."
        
        # Determine repository type and key configuration
        local repo_type="standard"
        local key_file=""
        local recipients=""
        
        if [[ -n "$manifest_entry" ]]; then
            repo_type=$(echo "$manifest_entry" | cut -d'|' -f4)
        fi
        
        # Try to determine key configuration from existing setup
        if [[ "$repo_type" == "ignition" ]]; then
            # For ignition mode, we need to check if chest exists
            if [[ -d "$repo_path/.chest" && -f "$repo_path/.chest/ignition.age" ]]; then
                info "🔥 Detected ignition mode setup"
                # This would require ignition key to decrypt, for now set up for master key access
                key_file="$PADLOCK_GLOBAL_KEY"
                recipients=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null || echo "")
            else
                warn "Ignition setup incomplete, falling back to standard mode"
                repo_type="standard"
            fi
        fi
        
        if [[ "$repo_type" == "standard" ]]; then
            # Try to find repository-specific key
            local repo_name
            repo_name=$(basename "$repo_path")
            local repo_key="$PADLOCK_KEYS/$repo_name.key"
            
            if [[ -f "$repo_key" ]]; then
                key_file="$repo_key"
                recipients=$(age-keygen -y "$repo_key" 2>/dev/null || echo "")
                info "🔑 Using repository-specific key"
            elif [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                key_file="$PADLOCK_GLOBAL_KEY"
                recipients=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null || echo "")
                info "🔑 Using global master key"
            else
                error "No suitable key found for repair"
                info "Options:"
                info "  • Run 'padlock key --generate-global' to create master key"
                info "  • Run 'padlock key restore' if you have skull backup"
                return 1
            fi
        fi
        
        if [[ -n "$recipients" ]]; then
            # Set up environment for config generation
            export AGE_RECIPIENTS="$recipients"
            export PADLOCK_KEY_FILE="$key_file"
            export AGE_PASSPHRASE=""
            export REPO_ROOT="$repo_path"
            
            # Generate new .padlock config
            __print_padlock_config "$repo_path/locker/.padlock" "$(basename "$repo_path")"
            
            okay "✓ Regenerated .padlock configuration"
            info "Key: $(basename "$key_file")"
            info "Recipient: ${recipients:0:20}..."
        else
            error "Failed to determine encryption configuration"
            return 1
        fi
    fi
    
    # Try to restore any missing artifacts
    if _restore_repo_artifacts "$repo_path"; then
        info "🔧 Additional artifacts restored from backup"
    else
        # Check if artifacts exist in local namespace (migration scenario)
        local repo_name=$(basename "$repo_path")
        local namespace="local"
        if [[ -d "$repo_path/.git" ]]; then
            local remote_url
            remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$remote_url" ]]; then
                # Parse remote URL to determine current namespace
                local host user_repo
                if [[ "$remote_url" =~ ^https?://([^/]+)/([^/]+)/([^/]+) ]]; then
                    host="${BASH_REMATCH[1]}"
                    user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
                elif [[ "$remote_url" =~ ^[^@]+@([^:]+):([^/]+)/([^/]+) ]]; then
                    host="${BASH_REMATCH[1]}"
                    user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
                else
                    host="unknown"
                    user_repo=$(basename "$repo_path")
                fi
                namespace="$host"
                repo_name="$user_repo"
            fi
        fi
        
        # If current namespace is not 'local', check for orphaned local artifacts
        if [[ "$namespace" != "local" ]]; then
            local local_artifacts_dir="$PADLOCK_ETC/repos/local/$(basename "$repo_path")"
            local current_artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
            if [[ -d "$local_artifacts_dir" && ! -d "$current_artifacts_dir" ]]; then
                info "🚨 Found orphaned artifacts in local namespace"
                info "Migrating from local to current namespace..."
                if _migrate_artifacts_namespace "$local_artifacts_dir" "$current_artifacts_dir"; then
                    okay "✓ Migrated orphaned artifacts"
                    rm -rf "$local_artifacts_dir"
                    _restore_repo_artifacts "$repo_path"  # Try restore again
                fi
            fi
        fi
    fi
    
    echo
    okay "✓ Repair completed successfully"
    info "Repository should now be functional."
    info "Test with: padlock status"
}
