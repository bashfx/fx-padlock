# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_remote | edit:repo_do_remote | orig_sum:625b7a78d2a3c3c7cefec47bb55697044b0bf20499e9a4b1665a2cbd0798419d
repo_do_remote() {
    local repo_path="${1:-.}"
    repo_path="$(realpath "$repo_path")"
    
    info "🔗 Padlock Remote Update"
    echo
    
    local repo_name=$(basename "$repo_path")
    local namespace="local"
    local old_artifacts_dir=""
    local new_artifacts_dir=""
    
    # Determine current namespace from git remote
    if [[ -d "$repo_path/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            # Parse remote URL to extract host, user, and repo
            local host user_repo
            if [[ "$remote_url" =~ ^https?://([^/]+)/([^/]+)/([^/]+) ]]; then
                # HTTPS: https://github.com/user/repo.git
                host="${BASH_REMATCH[1]}"
                user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
            elif [[ "$remote_url" =~ ^[^@]+@([^:]+):([^/]+)/([^/]+) ]]; then
                # SSH: git@github.com:user/repo.git
                host="${BASH_REMATCH[1]}"
                user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
            else
                # Fallback for unusual formats
                host="unknown"
                user_repo=$(basename "$repo_path")
            fi
            
            # Create namespace as host, repo as user/repo
            namespace="$host"
            repo_name="$user_repo"
        fi
    fi
    
    # Check what migrations are available
    old_artifacts_dir="$PADLOCK_ETC/repos/local/$(basename "$repo_path")"
    new_artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    
    # If we're already in the correct namespace, nothing to do
    if [[ "$namespace" == "local" ]]; then
        okay "✓ Repository has no remote - using local namespace"
        return 0
    fi
    
    # Check if new location already has artifacts
    if [[ -d "$new_artifacts_dir" ]]; then
        okay "✓ Artifacts already updated for remote namespace"
        info "Current location: $new_artifacts_dir"
        return 0
    fi
    
    # Check if old artifacts exist to update
    if [[ ! -d "$old_artifacts_dir" ]]; then
        warn "⚠️  No artifacts found in local namespace to update"
        info "Expected old location: $old_artifacts_dir"
        info "Target location: $new_artifacts_dir"
        return 1
    fi
    
    # Show what will be migrated
    if [[ -d "$repo_path/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        info "🔗 Git remote: $remote_url"
    fi
    
    echo
    info "📋 Update plan:"
    printf "  From: %b%s%b\n" "$yellow" "$old_artifacts_dir" "$xx"
    printf "  To:   %b%s%b\n" "$green" "$new_artifacts_dir" "$xx"
    
    # Show what artifacts will be moved
    local artifact_count
    artifact_count=$(find "$old_artifacts_dir" -type f -not -name ".artifact_info" | wc -l)
    echo
    info "📁 Artifacts to update:"
    find "$old_artifacts_dir" -type f -not -name ".artifact_info" | while read -r file; do
        printf "  • %s\n" "$(basename "$file")"
    done
    
    echo
    read -p "Proceed with remote namespace update? [Y/n]: " -r update_response
    if [[ "$update_response" =~ ^[nN]$ ]]; then
        info "Update cancelled"
        return 0
    fi
    
    # Perform the update
    if _migrate_artifacts_namespace "$old_artifacts_dir" "$new_artifacts_dir"; then
        okay "✓ Artifacts updated successfully"
        rm -rf "$old_artifacts_dir"
        info "Removed old artifacts directory"
        
        echo
        info "🎯 Remote namespace update complete!"
        printf "  New location: %b%s%b\n" "$green" "$new_artifacts_dir" "$xx"
        echo
        info "You can now commit safely. The pre-commit hook will use the correct namespace."
    else
        error "Update failed - old artifacts preserved"
        return 1
    fi
}
