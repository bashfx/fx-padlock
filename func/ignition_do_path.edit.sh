# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:do_path | edit:ignition_do_path | orig_sum:004073c41f7d8353f51bef282dd35874e2ab8f1685b545f1002079b4a5b511a1
ignition_do_path() {
    local repo_path="${1:-.}"
    repo_path="$(realpath "$repo_path")"
    
    local repo_name=$(basename "$repo_path")
    
    # Determine namespace from git remote or use 'local'
    local namespace="local"
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
            
            # Create namespace as host, repo as user/repo to avoid collisions
            namespace="$host"
            repo_name="$user_repo"
        fi
    fi
    
    info "📍 Repository path analysis for: $repo_path"
    echo
    
    if [[ -d "$repo_path/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            info "🔗 Git remote: $remote_url"
        else
            info "🔗 Git remote: (none - local repository)"
        fi
    else
        info "🔗 Git remote: (not a git repository)"
    fi
    
    echo
    info "📋 Computed storage paths:"
    printf "  Namespace: %b%s%b\n" "$cyan" "$namespace" "$xx"
    printf "  Repository: %b%s%b\n" "$cyan" "$repo_name" "$xx"
    echo
    printf "  Key file: %b%s%b\n" "$green" "$PADLOCK_KEYS/$(basename "$repo_path").key" "$xx"
    printf "  Artifacts: %b%s%b\n" "$green" "$PADLOCK_ETC/repos/$namespace/$repo_name/" "$xx"
    echo
    
    # Show what artifacts exist
    local artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    local key_file="$PADLOCK_KEYS/$(basename "$repo_path").key"
    
    info "📁 Current storage status:"
    if [[ -f "$key_file" ]]; then
        printf "  ✓ Key file exists: %s\n" "$(basename "$key_file")"
    else
        printf "  ✗ Key file missing: %s\n" "$(basename "$key_file")"
    fi
    
    if [[ -d "$artifacts_dir" ]]; then
        local artifact_count
        artifact_count=$(find "$artifacts_dir" -type f | wc -l)
        printf "  ✓ Artifacts backed up: %d files\n" "$artifact_count"
        
        # List specific artifacts
        if [[ -f "$artifacts_dir/.artifact_info" ]]; then
            local backup_date
            backup_date=$(grep "backup_date=" "$artifacts_dir/.artifact_info" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
            printf "  📅 Last backup: %s\n" "$backup_date"
        fi
        
        echo "  📄 Artifacts:"
        find "$artifacts_dir" -type f -not -name ".artifact_info" | while read -r file; do
            printf "    • %s\n" "$(basename "$file")"
        done
    else
        printf "  ✗ No artifacts backed up\n"
        
        # Check if artifacts exist in the 'local' namespace (migration scenario) - just show info
        if [[ "$namespace" != "local" ]]; then
            local local_artifacts_dir="$PADLOCK_ETC/repos/local/$(basename "$repo_path")"
            if [[ -d "$local_artifacts_dir" ]]; then
                echo
                warn "🚨 Migration available!"
                info "Found artifacts in local namespace that can be migrated:"
                printf "  From: %b%s%b\n" "$yellow" "$local_artifacts_dir" "$xx"
                printf "  To:   %b%s%b\n" "$green" "$artifacts_dir" "$xx"
                echo
                printf "  Run: %bpadlock remote%b to update for remote namespace\n" "$green" "$xx"
            fi
        fi
    fi
}
