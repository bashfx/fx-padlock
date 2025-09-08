# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/06_master_api.sh | src_sum:2158434627cf43659ef6d04d2a2446b980df50f94b93eddb92a6b1e842ee5855 | orig:do_declamp | edit:master_do_declamp | orig_sum:48c166bf4e2a2cccc071ca59f2a2c03d131f34da4b00f967735e94e76c9a7e1e
master_do_declamp() {
    local repo_path="${1:-.}"
    local force="${2:-}"
    
    repo_path="$(realpath "$repo_path")"
    
    # Validate target - show help if not a git repository
    if ! is_git_repo "$repo_path"; then
        info "Target is not a git repository: $repo_path"
        info "The 'declamp' command removes padlock encryption from a git repository"
        info ""
        info "Usage: padlock declamp [path] [--force]"
        info ""
        info "Options:"
        info "  --force    Force removal even if repository is locked"
        info ""
        info "Prerequisites:"
        info "  • Target directory must be a git repository with padlock deployed"
        info "  • Repository should be unlocked (or use --force)"
        return 0
    fi
    
    REPO_ROOT="$(_get_repo_root "$repo_path")"
    
    # Check if padlock is deployed - show help if not
    if ! is_deployed "$REPO_ROOT"; then
        info "Padlock not deployed in this repository"
        info "The 'declamp' command removes padlock encryption from a repository"
        info ""
        info "Usage: padlock declamp [path] [--force]"
        info ""
        info "Prerequisites:"
        info "  • Repository must have padlock already deployed (see 'padlock clamp')"
        info "  • Nothing to declamp from this repository"
        return 0
    fi
    
    lock "🔓 Safely declamping padlock from repository..."
    
    # Ensure repository is unlocked first
    local state="$(_get_lock_state "$REPO_ROOT")"
    if [[ "$state" == "locked" ]]; then
        if [[ "$force" != "--force" ]]; then
            error "Repository is locked. Unlock first or use --force"
            info "To unlock: padlock unlock"
            info "Or force: padlock declamp --force"
            return 1
        fi
        
        # Force unlock before declamp
        warn "Force-unlocking locked repository..."
        if [[ -f "$REPO_ROOT/locker.age" ]]; then
            info "Unlocking standard locker..."
            if ! (cd "$REPO_ROOT" && "$REPO_ROOT/bin/padlock" unlock); then
                fatal "Failed to unlock repository for declamp"
            fi
        elif [[ -f "$REPO_ROOT/.chest/locker.age" ]]; then
            info "Unlocking chest mode..."
            if ! (cd "$REPO_ROOT" && "$REPO_ROOT/bin/padlock" unlock); then
                fatal "Failed to unlock repository for declamp"
            fi
        fi
    fi
    
    # Show what will be preserved
    if [[ -d "$REPO_ROOT/locker" ]]; then
        local file_count
        file_count=$(find "$REPO_ROOT/locker" -type f | wc -l)
        info "📁 Preserving $file_count files from locker/ (will remain as plaintext)"
    else
        warn "No locker directory found - nothing to preserve"
    fi
    
    # Show what will be removed
    local items_to_remove=()
    [[ -d "$REPO_ROOT/bin" ]] && items_to_remove+=("bin/")
    [[ -d "$REPO_ROOT/.githooks" ]] && items_to_remove+=(".githooks/")
    [[ -f "$REPO_ROOT/locker.age" ]] && items_to_remove+=("locker.age")
    [[ -f "$REPO_ROOT/.locked" ]] && items_to_remove+=(".locked")
    [[ -d "$REPO_ROOT/.chest" ]] && items_to_remove+=(".chest/")
    [[ -f "$REPO_ROOT/padlock.map" ]] && items_to_remove+=("padlock.map")
    [[ -f "$REPO_ROOT/.locker_checksum" ]] && items_to_remove+=(".locker_checksum")
    [[ -f "$REPO_ROOT/SECURITY.md" ]] && items_to_remove+=("SECURITY.md")
    
    if [[ ${#items_to_remove[@]} -gt 0 ]]; then
        info "🗑️  Will remove: ${items_to_remove[*]}"
    fi
    
    # Confirm destructive operation
    if [[ "$force" != "--force" ]]; then
        echo
        warn "⚠️  This will permanently remove padlock infrastructure"
        read -p "Continue? (y/N): " -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Declamp cancelled"
            return 0
        fi
    fi
    
    # Remove padlock infrastructure
    local removed_items=()
    
    # Remove bin directory
    if [[ -d "$REPO_ROOT/bin" ]]; then
        rm -rf "$REPO_ROOT/bin"
        removed_items+=("bin/")
    fi
    
    # Remove git hooks
    if [[ -d "$REPO_ROOT/.githooks" ]]; then
        rm -rf "$REPO_ROOT/.githooks"
        removed_items+=(".githooks/")
    fi
    
    # Remove encrypted artifacts
    if [[ -f "$REPO_ROOT/locker.age" ]]; then
        rm -f "$REPO_ROOT/locker.age"
        removed_items+=("locker.age")
    fi
    
    if [[ -f "$REPO_ROOT/.locked" ]]; then
        rm -f "$REPO_ROOT/.locked"
        removed_items+=(".locked")
    fi
    
    if [[ -d "$REPO_ROOT/.chest" ]]; then
        rm -rf "$REPO_ROOT/.chest"
        removed_items+=(".chest/")
    fi
    
    # Remove padlock.map and checksums
    if [[ -f "$REPO_ROOT/padlock.map" ]]; then
        rm -f "$REPO_ROOT/padlock.map"
        removed_items+=("padlock.map")
    fi
    
    if [[ -f "$REPO_ROOT/.locker_checksum" ]]; then
        rm -f "$REPO_ROOT/.locker_checksum"
        removed_items+=(".locker_checksum")
    fi
    
    # Remove other padlock files
    rm -f "$REPO_ROOT/.overdrive"
    rm -f "$REPO_ROOT/super_chest.age"
    
    # Clean up .gitattributes (remove padlock lines)
    if [[ -f "$REPO_ROOT/.gitattributes" ]]; then
        local temp_attrs
        temp_attrs=$(mktemp)
        grep -v "locker.age\|filter=locker-crypt\|bin/\*\|.githooks/\*" "$REPO_ROOT/.gitattributes" > "$temp_attrs" || true
        mv "$temp_attrs" "$REPO_ROOT/.gitattributes"
        
        # Remove file if empty (except comments and whitespace)
        if ! grep -q "^[^#[:space:]]" "$REPO_ROOT/.gitattributes" 2>/dev/null; then
            rm -f "$REPO_ROOT/.gitattributes"
            removed_items+=(".gitattributes")
        fi
    fi
    
    # Clean up .gitignore (remove padlock lines)
    if [[ -f "$REPO_ROOT/.gitignore" ]]; then
        local temp_ignore
        temp_ignore=$(mktemp)
        grep -v "^locker/$\|^# Padlock" "$REPO_ROOT/.gitignore" > "$temp_ignore" || true
        mv "$temp_ignore" "$REPO_ROOT/.gitignore"
    fi
    
    # Remove git configuration
    (cd "$REPO_ROOT" && {
        git config --unset filter.locker-crypt.clean 2>/dev/null || true
        git config --unset filter.locker-crypt.smudge 2>/dev/null || true
        git config --unset filter.locker-crypt.required 2>/dev/null || true
        git config --unset core.hooksPath 2>/dev/null || true
    })
    
    # Remove from global manifest
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" ]]; then
        local temp_manifest
        temp_manifest=$(mktemp)
        grep -v -F "$REPO_ROOT" "$manifest_file" > "$temp_manifest" 2>/dev/null || true
        mv "$temp_manifest" "$manifest_file"
        trace "Removed from global manifest"
    fi
    
    # Remove repository-specific keys and namespace artifacts
    local repo_name="$(basename "$REPO_ROOT")"
    local repo_key_file="$PADLOCK_KEYS/$repo_name.key"
    
    # Determine namespace to find artifacts
    local namespace="local"
    if [[ -d "$REPO_ROOT/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/(.+) ]]; then
            namespace="github.com"
        elif [[ "$remote_url" =~ gitlab\.com[:/]([^/]+)/(.+) ]]; then
            namespace="gitlab.com"
        elif [[ "$remote_url" =~ ([^/:]+)[:/]([^/]+)/(.+) ]]; then
            namespace="${BASH_REMATCH[1]}"
        fi
    fi
    
    # Remove repository key
    if [[ -f "$repo_key_file" ]]; then
        rm -f "$repo_key_file"
        trace "Removed repository key: $repo_key_file"
    fi
    
    # Remove namespace artifacts directory
    local artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    if [[ -d "$artifacts_dir" ]]; then
        rm -rf "$artifacts_dir"
        trace "Removed artifacts directory: $artifacts_dir"
        
        # Clean up empty parent directories
        local namespace_dir="$PADLOCK_ETC/repos/$namespace"
        if [[ -d "$namespace_dir" ]] && [[ -z "$(ls -A "$namespace_dir" 2>/dev/null)" ]]; then
            rmdir "$namespace_dir"
            trace "Removed empty namespace directory: $namespace_dir"
        fi
    fi
    
    # Remove template SECURITY.md if it's the padlock one
    if [[ -f "$REPO_ROOT/SECURITY.md" ]] && grep -q "Padlock" "$REPO_ROOT/SECURITY.md" 2>/dev/null; then
        rm -f "$REPO_ROOT/SECURITY.md"
        removed_items+=("SECURITY.md")
    fi
    
    # Success message
    okay "✓ Padlock safely removed from repository"
    
    if [[ -d "$REPO_ROOT/locker" ]]; then
        local preserved_count
        preserved_count=$(find "$REPO_ROOT/locker" -type f | wc -l)
        okay "✅ Preserved $preserved_count files in locker/ (now unencrypted)"
        warn "⚠️  locker/ is now unencrypted plaintext"
        info "💡 Add 'locker/' to .gitignore before committing"
    fi
    
    if [[ ${#removed_items[@]} -gt 0 ]]; then
        info "🗑️  Removed: ${removed_items[*]}"
    fi
    
    info "📋 Repository restored to standard git repo"
}
