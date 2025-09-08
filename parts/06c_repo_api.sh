# 06c_repo_api.sh - Repository Operations & Git Functions
# Part of fx-padlock BashFX architecture remediation  
# Contains: Repository lifecycle, git operations, and file management functions=== _backup_repo_artifacts ===
_backup_repo_artifacts() {
    local repo_path="$1"
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
    
    local backup_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    
    mkdir -p "$backup_dir"
    
    local artifacts_backed_up=0
    
    # Backup padlock.map if it exists
    if [[ -f "$repo_path/padlock.map" ]]; then
        cp "$repo_path/padlock.map" "$backup_dir/padlock.map"
        ((artifacts_backed_up++))
        trace "Backed up padlock.map"
    fi
    
    # Backup .gitattributes (padlock-specific parts)
    if [[ -f "$repo_path/.gitattributes" ]]; then
        grep -E "(locker\.age|filter=locker-crypt|bin/\*|\.githooks/\*)" "$repo_path/.gitattributes" > "$backup_dir/.gitattributes" 2>/dev/null || true
        if [[ -s "$backup_dir/.gitattributes" ]]; then
            ((artifacts_backed_up++))
            trace "Backed up .gitattributes (padlock sections)"
        else
            rm -f "$backup_dir/.gitattributes"
        fi
    fi
    
    # Backup padlock-specific .gitignore sections
    if [[ -f "$repo_path/.gitignore" ]]; then
        grep -A5 -B1 "# Padlock" "$repo_path/.gitignore" > "$backup_dir/.gitignore" 2>/dev/null || true
        if [[ -s "$backup_dir/.gitignore" ]]; then
            ((artifacts_backed_up++))
            trace "Backed up .gitignore (padlock sections)"
        else
            rm -f "$backup_dir/.gitignore"
        fi
    fi
    
    # Create artifact metadata
    if [[ $artifacts_backed_up -gt 0 ]]; then
        cat > "$backup_dir/.artifact_info" << EOF
# Padlock Repository Artifacts Backup
# Repository: $repo_name
# Path: $repo_path
# Backed up: $(date -Iseconds)
# Artifacts: $artifacts_backed_up

artifacts_count=$artifacts_backed_up
repo_path=$repo_path
backup_date=$(date -Iseconds)
EOF
        trace "Artifact backup complete: $artifacts_backed_up items"
    else
        # Remove empty backup directory
        rmdir "$backup_dir" 2>/dev/null || true
    fi
    
    return 0
}


_restore_repo_artifacts() {
    local repo_path="$1"
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
    
    local backup_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    
    if [[ ! -d "$backup_dir" ]]; then
        return 1  # No artifacts backed up
    fi
    
    local artifacts_restored=0
    
    info "🔧 Restoring backed up artifacts..."
    
    # Restore padlock.map
    if [[ -f "$backup_dir/padlock.map" && ! -f "$repo_path/padlock.map" ]]; then
        cp "$backup_dir/padlock.map" "$repo_path/padlock.map"
        ((artifacts_restored++))
        okay "✓ Restored padlock.map"
    fi
    
    # Restore .gitattributes (merge approach)
    if [[ -f "$backup_dir/.gitattributes" ]]; then
        if [[ ! -f "$repo_path/.gitattributes" ]]; then
            cp "$backup_dir/.gitattributes" "$repo_path/.gitattributes"
            ((artifacts_restored++))
            okay "✓ Restored .gitattributes"
        else
            # Check if padlock sections are missing and add them
            if ! grep -q "locker.age" "$repo_path/.gitattributes" 2>/dev/null; then
                echo "" >> "$repo_path/.gitattributes"
                cat "$backup_dir/.gitattributes" >> "$repo_path/.gitattributes"
                ((artifacts_restored++))
                okay "✓ Merged padlock sections into .gitattributes"
            fi
        fi
    fi
    
    # Restore .gitignore (merge approach)
    if [[ -f "$backup_dir/.gitignore" ]]; then
        if [[ ! -f "$repo_path/.gitignore" ]]; then
            cp "$backup_dir/.gitignore" "$repo_path/.gitignore"
            ((artifacts_restored++))
            okay "✓ Restored .gitignore"
        else
            # Check if padlock sections are missing and add them
            if ! grep -q "# Padlock" "$repo_path/.gitignore" 2>/dev/null; then
                echo "" >> "$repo_path/.gitignore"
                cat "$backup_dir/.gitignore" >> "$repo_path/.gitignore"
                ((artifacts_restored++))
                okay "✓ Merged padlock sections into .gitignore"
            fi
        fi
    fi
    
    if [[ $artifacts_restored -gt 0 ]]; then
        info "📁 Restored $artifacts_restored artifacts from backup"
        return 0
    else
        return 1
    fi
}


_add_to_manifest() {
    local repo_path="$1"
    local repo_type="${2:-standard}"
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    local now
    now=$(date -Iseconds 2>/dev/null || date)
    
    # Create header if empty
    if [[ ! -s "$manifest_file" ]]; then
        mkdir -p "$(dirname "$manifest_file")"
        echo "# Padlock Repository Manifest v2.0" > "$manifest_file"
        echo "# Format: namespace|name|path|type|remote|checksum|created|last_access|metadata" >> "$manifest_file"
    fi
    
    # Extract repository information
    local repo_name
    repo_name=$(basename "$repo_path")
    local namespace="local"
    local remote_url=""
    local checksum=""
    
    # Get git remote if available
    if [[ -d "$repo_path/.git" ]]; then
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            # Extract namespace and repo name from remote URL
            if [[ "$remote_url" =~ github\.com[/:]([^/]+)/([^/]+) ]]; then
                namespace="${BASH_REMATCH[1]}"
                repo_name="${BASH_REMATCH[2]%.git}"
            elif [[ "$remote_url" =~ gitlab\.com[/:]([^/]+)/([^/]+) ]]; then
                namespace="${BASH_REMATCH[1]}"
                repo_name="${BASH_REMATCH[2]%.git}"
            else
                namespace="remote"
            fi
        fi
    fi
    
    # Generate repository checksum for integrity tracking
    checksum=$(echo "$repo_path|$repo_type|$now" | sha256sum | cut -d' ' -f1 | head -c 12)
    
    # Skip if path already exists in manifest
    if grep -q "|$repo_path|" "$manifest_file" 2>/dev/null; then
        trace "Manifest entry for $repo_path already exists. Skipping."
        return 0
    fi

    # Detect temp directories to add metadata
    local metadata=""
    if [[ "$repo_path" == */tmp/* ]] || [[ "$repo_path" == */temp/* ]]; then
        metadata="temp=true"
    fi


    # Add new entry
    echo "$namespace|$repo_name|$repo_path|$repo_type|$remote_url|$checksum|$now|$now|$metadata" >> "$manifest_file"
    trace "Added manifest entry for $repo_path"
}


_merge_manifests() {
    local import_manifest="$1"
    local current_manifest="$2"
    local temp_file
    temp_file=$(_temp_mktemp)

    # Preserve header from current manifest if it exists
    if [[ -f "$current_manifest" ]]; then
        grep "^#" "$current_manifest" > "$temp_file"
    else
        # Or take header from import file
        grep "^#" "$import_manifest" > "$temp_file"
    fi

    # Merge entries (avoid duplicates by checking path column, which is column 3)
    {
        grep -v "^#" "$current_manifest" 2>/dev/null || true
        grep -v "^#" "$import_manifest"
    } | sort -t'|' -k3,3 -u >> "$temp_file"

    mv "$temp_file" "$current_manifest"
}


do_import() {
    local import_file="$1"
    local merge_mode="${2:---merge}"
    local passphrase="${3:-}" # Accept passphrase as 3rd arg

    if [[ ! -f "$import_file" ]]; then
        fatal "Import file not found: $import_file"
    fi

    if [[ -z "$passphrase" ]]; then
        # Get passphrase from environment, file, or interactive prompt
        if [[ -n "${PADLOCK_PASSPHRASE:-}" ]]; then
            passphrase="$PADLOCK_PASSPHRASE"
        elif [[ -n "${PADLOCK_PASSPHRASE_FILE:-}" ]] && [[ -f "$PADLOCK_PASSPHRASE_FILE" ]]; then
            passphrase=$(cat "$PADLOCK_PASSPHRASE_FILE")
        elif [[ -t 0 ]] && [[ -t 1 ]]; then
            read -sp "Enter passphrase for import file: " passphrase
            echo
        else
            fatal "No passphrase provided. Set PADLOCK_PASSPHRASE environment variable or use PADLOCK_PASSPHRASE_FILE for automation."
        fi
        
        if [[ -z "$passphrase" ]]; then
            fatal "Passphrase cannot be empty."
        fi
    fi

    local temp_dir
    temp_dir=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_dir"' RETURN

    # Decrypt and extract
    if ! AGE_PASSPHRASE="$passphrase" age -d < "$import_file" | tar -C "$temp_dir" -xzf -; then
        fatal "Failed to decrypt import file (wrong passphrase?)"
    fi

    # Validate import
    if [[ ! -f "$temp_dir/export_info.json" || ! -f "$temp_dir/manifest.txt" ]]; then
        fatal "Invalid padlock export file."
    fi

    info "Successfully decrypted export file."

    # Backup current state
    local backup_dir="$PADLOCK_ETC/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    if [[ -d "$PADLOCK_ETC" ]]; then
        cp -a "$PADLOCK_ETC"/* "$backup_dir/" 2>/dev/null || true
    fi
    info "Current environment backed up to: $backup_dir"

    # Import based on mode
    case "$merge_mode" in
        --replace)
            warn "Replacing current padlock environment."
            rm -f "$PADLOCK_ETC/manifest.txt"
            rm -rf "$PADLOCK_KEYS"
            rm -rf "$PADLOCK_ETC/repos"
            mkdir -p "$PADLOCK_KEYS"
            cp "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -r "$temp_dir/keys"/* "$PADLOCK_KEYS/"
            # Restore repo artifacts if they exist in the import
            if [[ -d "$temp_dir/repos" ]]; then
                cp -r "$temp_dir/repos" "$PADLOCK_ETC/repos"
            fi
            ;;
        --merge)
            info "Merging with current environment."
            _merge_manifests "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -rT "$temp_dir/keys" "$PADLOCK_KEYS" 2>/dev/null || true
            # Restore repo artifacts if they exist in the import
            if [[ -d "$temp_dir/repos" ]]; then
                mkdir -p "$PADLOCK_ETC/repos"
                cp -rT "$temp_dir/repos" "$PADLOCK_ETC/repos" 2>/dev/null || true
            fi
            ;;
        *)
            fatal "Unknown import mode: $merge_mode. Use --merge or --replace."
            ;;
    esac

    okay "✓ Import completed successfully."
}


do_export() {
    local export_file="${1:-padlock_export_$(date +%Y%m%d_%H%M%S).tar.age}"
    local passphrase

    # Get passphrase from environment, file, or interactive prompt
    if [[ -n "${PADLOCK_PASSPHRASE:-}" ]]; then
        passphrase="$PADLOCK_PASSPHRASE"
    elif [[ -n "${PADLOCK_PASSPHRASE_FILE:-}" ]] && [[ -f "$PADLOCK_PASSPHRASE_FILE" ]]; then
        passphrase=$(cat "$PADLOCK_PASSPHRASE_FILE")
    elif [[ -t 0 ]] && [[ -t 1 ]]; then
        # Interactive mode
        read -sp "Create a passphrase for the export file: " passphrase
        echo
    else
        fatal "No passphrase provided. Set PADLOCK_PASSPHRASE environment variable or use PADLOCK_PASSPHRASE_FILE for automation."
    fi

    if [[ -z "$passphrase" ]]; then
        fatal "Passphrase cannot be empty."
    fi

    # Check if there is anything to export
    if [[ ! -d "$PADLOCK_KEYS" || -z "$(ls -A "$PADLOCK_KEYS")" ]]; then
        error "No keys found to export."
        return 1
    fi
    if [[ ! -f "$PADLOCK_ETC/manifest.txt" ]]; then
        error "Manifest not found. Nothing to export."
        return 1
    fi

    info "📦 Exporting padlock environment..."

    local temp_dir
    temp_dir=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_dir"' RETURN

    local export_manifest="$temp_dir/manifest.txt"
    local keys_dir="$temp_dir/keys"

    # Copy manifest, keys, and repo artifacts to a temporary location
    cp "$PADLOCK_ETC/manifest.txt" "$export_manifest"
    cp -r "$PADLOCK_KEYS" "$keys_dir"
    
    # Copy repo artifacts if they exist
    if [[ -d "$PADLOCK_ETC/repos" ]]; then
        cp -r "$PADLOCK_ETC/repos" "$temp_dir/repos"
    fi

    # Create metadata file
    cat > "$temp_dir/export_info.json" << EOF
{
    "version": "1.0",
    "exported_at": "$(date -Iseconds)",
    "exported_by": "$(whoami)@$(hostname)",
    "padlock_version": "$PADLOCK_VERSION"
}
EOF

    # Create a tarball and encrypt it with the passphrase
    tar -C "$temp_dir" -czf - . | AGE_PASSPHRASE="$passphrase" age -p > "$export_file"
    if [[ $? -ne 0 ]]; then
        fatal "Failed to create encrypted export file."
    fi

    okay "✓ Padlock environment successfully exported to: $export_file"
    warn "⚠️  Keep this file and your passphrase safe!"
}


do_rotate() {
    local target="$1"
    shift || true

    # Set REPO_ROOT for the helpers
    REPO_ROOT=$(_get_repo_root .)

    case "$target" in
        master)
            # padlock rotate master
            info "[STUB] Rotating master key"
            info "WARNING: This will invalidate ALL repository keys!"
            info "All repositories will need to be re-keyed"
            return 0
            ;;
            
        ignition)
            # padlock rotate ignition [name]
            local name="${1:-default}"
            info "[STUB] Rotating ignition key: $name"
            info "WARNING: This will invalidate related distributed keys!"
            return 0
            ;;
            
        distro)
            # padlock rotate distro [name]
            local name="$1"
            if [[ -z "$name" ]]; then
                error "Missing distro key name"
                info "Usage: padlock rotate distro <name>"
                return 1
            fi
            info "[STUB] Rotating distributed key: $name"
            return 0
            ;;
            
        # Legacy support
        -K|--ignition)
            _rotate_ignition_key
            ;;
            
        help|*)
            if [[ "$target" != "help" ]]; then
                error "Unknown target for rotate: $target"
            fi
            info "Rotation Commands:"
            info "  master              Rotate global master key (affects all repos)"
            info "  ignition [name]     Rotate ignition key (invalidates D keys)"
            info "  distro <name>       Rotate specific distributed key"
            info ""
            info "Legacy:"
            info "  --ignition          Legacy ignition rotation"
            return 0
            ;;
    esac
}


do_install() {
    local force="$opt_force"
    
    # Parse command-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                force=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    _logo
    # Check if already installed
    local install_dir="$XDG_LIB_HOME/fx/lib"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    local lib_file="$install_dir/padlock.sh"
    
    if [[ -f "$lib_file" ]] && [[ "$force" -eq 0 ]]; then
        warn "Padlock already installed (use --force to reinstall)"
        return 0
    fi
    
    info "Installing padlock to system..."
    
    # Remove old installation if exists
    if [[ -f "$lib_file" ]]; then
        info "Removing existing installation..."
        rm -f "$lib_file"
    fi
    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
    fi
    
    # Create installation directories
    mkdir -p "$install_dir" "$(dirname "$link_path")"
    
    # Copy only the built padlock.sh script to lib directory
    cp "$SCRIPT_PATH" "$lib_file"
    chmod +x "$lib_file"
    
    # Create symlink to bin directory
    ln -sf "$lib_file" "$link_path"
    
    # Generate master key on first install
    _ensure_master_key
    
    okay "✓ Padlock installed to: $lib_file"
    info "Available as: $link_path"
    info "🗝️  Global master key configured"
}


do_uninstall() {
    local lib_file="$XDG_LIB_HOME/fx/lib/padlock.sh"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    
    info "🗑️  Uninstalling padlock from system..."
    
    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        info "✓ Removed symlink: $link_path"
    fi
    
    if [[ -f "$lib_file" ]]; then
        rm "$lib_file"
        info "✓ Removed library: $lib_file"
    fi
    
    if [[ ! -L "$link_path" ]] && [[ ! -f "$lib_file" ]]; then
        warn "⚠️  Padlock was not installed or already removed"
        return 0
    fi
    
    okay "✓ Padlock uninstalled successfully"
    info "💡 Keys and repositories remain in ~/.local/etc/padlock/"
}


do_overdrive() {
    local action="${1:-lock}"

    case "$action" in
        lock) _overdrive_lock ;;
        unlock)
            _overdrive_unlock
            ;;
        status)
            _overdrive_status
            ;;
        *)
            error "Unknown overdrive action: $action"
            info "Usage: padlock overdrive {lock|unlock|status}"
            return 1
            ;;
    esac
}


_overdrive_unlock() {
    REPO_ROOT=$(_get_repo_root .)

    if [[ ! -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository not in overdrive mode"
        return 1
    fi

    lock "🔓 Disengaging overdrive mode..."

    if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
        error "Master key not found, cannot unlock overdrive mode."
        info "Ensure your master key is available at $PADLOCK_GLOBAL_KEY"
        return 1
    fi
    export PADLOCK_KEY_FILE="$PADLOCK_GLOBAL_KEY"

    local super_chest="$REPO_ROOT/.super_chest"
    mkdir -p "$super_chest"
    
    if ! __decrypt_stream < "$REPO_ROOT/super_chest.age" | tar -C "$super_chest" -xzf -; then
        fatal "Failed to decrypt super_chest.age"
    fi

    if [[ -f "$REPO_ROOT/.overdrive" ]]; then
        local expected_checksum
        expected_checksum=$(grep "Super checksum:" "$REPO_ROOT/.overdrive" | cut -d' ' -f4)
        local current_checksum
        current_checksum=$(_calculate_locker_checksum "$super_chest")

        if [[ "$current_checksum" != "$expected_checksum" ]]; then
            warn "⚠️  Super chest integrity check failed!"
        else
            trace "✓ Super chest integrity verified"
        fi
    fi

    cp -rT "$super_chest/" "$REPO_ROOT/"

    rm -rf "$super_chest"
    rm -f "$REPO_ROOT/super_chest.age"
    rm -f "$REPO_ROOT/.overdrive"

    okay "🔓 Overdrive disengaged! Repository restored."
}


_overdrive_status() {
    REPO_ROOT=$(_get_repo_root .)

    info "=== Overdrive Status ==="

    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        local size
        size=$(du -h "$REPO_ROOT/super_chest.age" 2>/dev/null | cut -f1)
        warn "🚀 OVERDRIVE ENGAGED"
        info "Blob: super_chest.age ($size)"
        info "To restore: source .overdrive"
    else
        okay "✅ NORMAL MODE"
        info "To engage: padlock overdrive lock"
    fi
}


_overdrive_lock() {
    REPO_ROOT=$(_get_repo_root .)

    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository already in overdrive mode"
        return 1
    fi

    if [[ ! -d "$REPO_ROOT/locker" ]]; then
        fatal "Locker must be unlocked to engage overdrive mode."
    fi

    lock "🚀 Engaging overdrive mode..."

    # Create super_chest directory for staging
    local super_chest="$REPO_ROOT/.super_chest"
    mkdir -p "$super_chest"

    # Note: cleanup handled explicitly at end of function

    # Use tar to copy files, which is more reliable than rsync for this case
    info "Archiving entire repository..."
    tar -c --exclude-from <(printf "%s\n" \
        ".super_chest" \
        "bin" \
        ".chest" \
        "super_chest.age" \
        ".locked" \
        ".ignition.key" \
        ".git" \
        ".gitsim" \
        ".locker_checksum" \
        "locker.age" \
    ) -C "$REPO_ROOT" . | tar -x -C "$super_chest"

    source "$REPO_ROOT/locker/.padlock"

    local super_checksum
    super_checksum=$(_calculate_locker_checksum "$super_chest")

    tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        -C "$super_chest" -czf - . | __encrypt_stream > "$REPO_ROOT/super_chest.age"

    # Remove everything except padlock infrastructure and super_chest.age
    find "$REPO_ROOT" -maxdepth 1 -mindepth 1 \
        ! -name ".super_chest" \
        ! -name "bin" \
        ! -name ".chest" \
        ! -name ".git" \
        ! -name ".gitsim" \
        ! -name "super_chest.age" \
        -exec rm -rf {} +

    __print_overdrive_file "$REPO_ROOT/.overdrive" "$super_checksum"

    local size
    size=$(du -h "$REPO_ROOT/super_chest.age" | cut -f1)
    okay "🚀 Overdrive engaged! Entire repo → super_chest.age ($size)"
    
    # Clean up staging directory
    rm -rf "$super_chest"
}


do_map() {
    local src_path="${1:-}"
    local action="${2:-add}"
    
    local repo_root="$(_get_repo_root .)"
    local map_file="$repo_root/padlock.map"
    
    if [[ -z "$src_path" ]]; then
        # Show current mappings
        if [[ -f "$map_file" ]]; then
            info "📋 Current file mappings:"
            echo
            while IFS='|' read -r src_rel dest_rel checksum; do
                # Skip comments and empty lines
                [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$src_rel" ]] && continue
                
                local src_abs="$repo_root/$src_rel"
                local status="❓"
                local checksum_status=""
                
                if [[ -f "$src_abs" ]]; then
                    status="✓"
                    if [[ -n "$checksum" ]]; then
                        local current_checksum
                        current_checksum=$(md5sum "$src_abs" | cut -d' ' -f1)
                        if [[ "$current_checksum" == "$checksum" ]]; then
                            checksum_status="✓"
                        else
                            checksum_status="⚠️"
                        fi
                    fi
                elif [[ -d "$src_abs" ]]; then
                    status="📁"
                    if [[ -n "$checksum" ]]; then
                        local current_checksum
                        current_checksum=$(find "$src_abs" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
                        if [[ "$current_checksum" == "$checksum" ]]; then
                            checksum_status="✓"
                        else
                            checksum_status="⚠️"
                        fi
                    fi
                else
                    status="❌"
                    checksum_status="❌"
                fi
                
                if [[ -n "$checksum" ]]; then
                    printf "  %s %s %s [%s]\n" "$status" "$checksum_status" "$src_rel" "${checksum:0:8}..."
                else
                    printf "  %s %s\n" "$status" "$src_rel"
                fi
            done < "$map_file"
            echo
            info "Usage: padlock map <file|dir> [add|remove]"
        else
            info "No mappings defined. Use: padlock map <file|dir>"
        fi
        return 0
    fi
    
    # Normalize source path
    if [[ "$src_path" = /* ]]; then
        # Absolute path - convert to relative from repo root
        src_path="$(realpath --relative-to="$repo_root" "$src_path")"
    else
        # Relative path - ensure it exists
        src_path="$(realpath --relative-to="$repo_root" "$repo_root/$src_path")"
    fi
    
    # Validate source exists
    local src_abs="$repo_root/$src_path"
    if [[ ! -e "$src_abs" ]]; then
        error "Source not found: $src_path"
        return 1
    fi
    
    # Prevent mapping files already in locker/
    if [[ "$src_path" == locker/* ]]; then
        error "Files in locker/ are automatically included"
        info "Map command is for files outside the locker/"
        return 1
    fi
    
    # Prevent mapping sensitive padlock files
    case "$src_path" in
        .git/*|bin/*|.githooks/*|locker.age|.locked|.chest/*|super_chest.age|.overdrive|padlock.map)
            error "Cannot map padlock infrastructure files"
            return 1
            ;;
    esac
    
    case "$action" in
        add)
            # Create map file if it doesn't exist
            if [[ ! -f "$map_file" ]]; then
                cat > "$map_file" << 'EOF'
# Padlock File Mapping
# Format: source_path|destination_path|md5_checksum
# Paths are relative to repository root
# Files listed here will be included in encrypted chest
EOF
            fi
            
            # Check if already mapped
            if grep -q "^$src_path|" "$map_file" 2>/dev/null; then
                warn "Already mapped: $src_path"
                return 0
            fi
            
            # Calculate checksum
            local checksum=""
            if [[ -f "$src_abs" ]]; then
                checksum=$(md5sum "$src_abs" | cut -d' ' -f1)
            elif [[ -d "$src_abs" ]]; then
                # For directories, create a checksum based on all files
                checksum=$(find "$src_abs" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
            fi
            
            # Add mapping with checksum
            echo "$src_path|$src_path|$checksum" >> "$map_file"
            
            # Backup the updated map file
            _backup_repo_artifacts "$repo_root"
            
            if [[ -f "$src_abs" ]]; then
                okay "✓ Mapped file: $src_path"
            elif [[ -d "$src_abs" ]]; then
                okay "✓ Mapped directory: $src_path"
                local file_count
                file_count=$(find "$src_abs" -type f | wc -l)
                info "📁 Contains $file_count files"
            fi
            ;;
            
        remove)
            if [[ ! -f "$map_file" ]]; then
                error "No mappings file found"
                return 1
            fi
            
            if ! grep -q "^$src_path|" "$map_file"; then
                error "Not mapped: $src_path"
                return 1
            fi
            
            # Remove the mapping
            local temp_file
            temp_file=$(_temp_mktemp)
            grep -v "^$src_path|" "$map_file" > "$temp_file"
            mv "$temp_file" "$map_file"
            
            # Backup the updated map file
            _backup_repo_artifacts "$repo_root"
            
            okay "✓ Unmapped: $src_path"
            ;;
            
        *)
            error "Unknown action: $action"
            info "Available actions: add, remove"
            return 1
            ;;
    esac
    
    info "💡 Changes take effect on next lock operation"
}


do_automap() {
    local repo_root="$(_get_repo_root .)"
    local map_file="$repo_root/padlock.map"
    
    info "🤖 Auto-detecting files and directories for mapping..."
    
    # Create map file if it doesn't exist
    if [[ ! -f "$map_file" ]]; then
        cat > "$map_file" << 'EOF'
# Padlock File Mapping
# Format: source_path|destination_path|md5_checksum
# Paths are relative to repository root
# Files listed here will be included in encrypted chest
EOF
    fi
    
    local mapped_count=0
    local skipped_count=0
    
    # Auto-detect patterns
    local patterns=(
        # Markdown files (except README and SECURITY, case insensitive)
        "*.md"
        # Build and parts directory
        "build.sh"
        "parts"
        # AI/IDE directories
        ".claude" ".gemini" ".codex" ".priv" ".sec"
        # Local and backup files in root
        "*.local.*" "*bak*"
    )
    
    # Function to check if already mapped
    _is_mapped() {
        local path="$1"
        grep -q "^$path|" "$map_file" 2>/dev/null
    }
    
    # Function to check if file should be excluded
    _should_exclude() {
        local path="$1"
        local basename_lower
        basename_lower=$(basename "$path" | tr '[:upper:]' '[:lower:]')
        
        # Exclude README.md and SECURITY.md (case insensitive)
        case "$basename_lower" in
            readme.md|security.md)
                return 0
                ;;
        esac
        
        # Exclude padlock infrastructure
        case "$path" in
            .git/*|bin/*|.githooks/*|locker.age|.locked|.chest/*|super_chest.age|.overdrive|padlock.map|locker/*)
                return 0
                ;;
        esac
        
        return 1
    }
    
    # Function to add mapping
    _add_automap() {
        local src_path="$1"
        local src_abs="$repo_root/$src_path"
        
        # Skip if already mapped
        if _is_mapped "$src_path"; then
            trace "Already mapped: $src_path"
            ((skipped_count++))
            return 0
        fi
        
        # Skip if should be excluded
        if _should_exclude "$src_path"; then
            trace "Excluded: $src_path"
            ((skipped_count++))
            return 0
        fi
        
        # Calculate checksum
        local checksum=""
        if [[ -f "$src_abs" ]]; then
            checksum=$(md5sum "$src_abs" | cut -d' ' -f1)
        elif [[ -d "$src_abs" ]]; then
            checksum=$(find "$src_abs" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
        fi
        
        # Add mapping
        echo "$src_path|$src_path|$checksum" >> "$map_file"
        ((mapped_count++))
        
        if [[ -f "$src_abs" ]]; then
            okay "✓ Auto-mapped file: $src_path"
        elif [[ -d "$src_abs" ]]; then
            okay "✓ Auto-mapped directory: $src_path"
            local file_count
            file_count=$(find "$src_abs" -type f | wc -l)
            trace "  📁 Contains $file_count files"
        fi
    }
    
    # Process each pattern
    for pattern in "${patterns[@]}"; do
        case "$pattern" in
            "*.md")
                # Find all .md files in root, exclude README.md and SECURITY.md
                while IFS= read -r -d '' file; do
                    local rel_path
                    rel_path=$(realpath --relative-to="$repo_root" "$file")
                    _add_automap "$rel_path"
                done < <(find "$repo_root" -maxdepth 1 -name "*.md" -type f -print0)
                ;;
            "*.local.*"|"*bak*")
                # Find files matching these patterns in root
                while IFS= read -r -d '' file; do
                    local rel_path
                    rel_path=$(realpath --relative-to="$repo_root" "$file")
                    _add_automap "$rel_path"
                done < <(find "$repo_root" -maxdepth 1 -name "$pattern" -type f -print0)
                ;;
            *)
                # Check if file/directory exists
                if [[ -e "$repo_root/$pattern" ]]; then
                    _add_automap "$pattern"
                fi
                ;;
        esac
    done
    
    # Backup the updated map file
    _backup_repo_artifacts "$repo_root"
    
    # Summary
    echo
    if [[ $mapped_count -gt 0 ]]; then
        okay "🎯 Auto-mapped $mapped_count items"
        if [[ $skipped_count -gt 0 ]]; then
            info "⏩ Skipped $skipped_count items (already mapped or excluded)"
        fi
        info "💡 Changes take effect on next lock operation"
        info "💡 Review mappings with: padlock map"
    else
        info "📝 No new items found to auto-map"
        if [[ $skipped_count -gt 0 ]]; then
            info "⏩ $skipped_count items were skipped (already mapped or excluded)"
        fi
    fi
}



do_unmap() {
    local target="${1:-}"
    
    local repo_root="$(_get_repo_root .)"
    local map_file="$repo_root/padlock.map"
    
    # Check if repository is locked - show help if so
    if [[ -f ".chest/locker.age" ]] || [[ -f "locker.age" ]]; then
        info "Repository is locked. Unlock first to modify mappings"
        info "The 'unmap' command removes files/directories from mappings"
        info ""
        info "Usage: padlock unmap <file|dir|all>"
        info ""
        info "Prerequisites:"
        info "  • Repository must be unlocked to modify mappings"
        info "  • Run 'padlock unlock' first"
        return 0
    fi
    
    if [[ ! -f "$map_file" ]]; then
        info "No mappings file found"
        info "The 'unmap' command removes files/directories from mappings"
        info ""
        info "Usage: padlock unmap <file|dir|all>"
        info ""
        info "Prerequisites:"
        info "  • Repository must have existing mappings (padlock.map file)"
        info "  • Use 'padlock map' to create mappings first"
        return 0
    fi
    
    if [[ -z "$target" ]]; then
        info "Usage: padlock unmap <file|dir|all>"
        info "The 'unmap' command removes files/directories from mappings"
        info ""
        info "Available mappings:"
        do_map
        return 0
    fi
    
    if [[ "$target" == "all" ]]; then
        # Remove all mappings
        local mapping_count
        mapping_count=$(grep -c "^[^#]" "$map_file" 2>/dev/null || echo "0")
        
        if [[ "$mapping_count" -eq 0 ]]; then
            info "No mappings to remove"
            return 0
        fi
        
        echo
        warn "⚠️  This will remove ALL $mapping_count file mappings"
        read -p "Continue? (y/N): " -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Unmap cancelled"
            return 0
        fi
        
        # Keep only comments and empty lines
        local temp_file
        temp_file=$(_temp_mktemp)
        grep "^#\|^[[:space:]]*$" "$map_file" > "$temp_file" || echo "# Padlock File Mapping" > "$temp_file"
        mv "$temp_file" "$map_file"
        
        okay "✓ Removed all mappings"
        return 0
    fi
    
    # Normalize target path (convert to relative if absolute)
    if [[ "$target" = /* ]]; then
        target="$(realpath --relative-to="$repo_root" "$target")"
    else
        # Convert relative to canonical form
        if [[ -e "$repo_root/$target" ]]; then
            target="$(realpath --relative-to="$repo_root" "$repo_root/$target")"
        fi
    fi
    
    # Find matching entries
    local matches=()
    while IFS='|' read -r src_rel dest_rel checksum; do
        # Skip comments and empty lines
        [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$src_rel" ]] && continue
        
        # Check for exact match or basename match
        if [[ "$src_rel" == "$target" ]] || [[ "$(basename "$src_rel")" == "$(basename "$target")" ]]; then
            matches+=("$src_rel|$dest_rel|$checksum")
        fi
    done < "$map_file"
    
    if [[ ${#matches[@]} -eq 0 ]]; then
        error "No mapping found for: $target"
        info "Available mappings:"
        padlock map
        return 1
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # Single match - remove it
        local entry="${matches[0]}"
        local src_path="${entry%%|*}"
        
        local temp_file
        temp_file=$(_temp_mktemp)
        grep -v "^$src_path|" "$map_file" > "$temp_file"
        mv "$temp_file" "$map_file"
        
        okay "✓ Unmapped: $src_path"
    else
        # Multiple matches - let user choose
        info "Multiple mappings found for '$target':"
        echo
        for i in "${!matches[@]}"; do
            local entry="${matches[$i]}"
            local src_path="${entry%%|*}"
            local status="❓"
            
            if [[ -f "$repo_root/$src_path" ]]; then
                status="✓"
            elif [[ -d "$repo_root/$src_path" ]]; then
                status="📁"
            else
                status="❌"
            fi
            
            printf "  %d) %s %s\n" $((i + 1)) "$status" "$src_path"
        done
        
        echo
        read -p "Select mapping to remove (1-${#matches[@]}): " -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#matches[@]} ]]; then
            local selected_entry="${matches[$((selection - 1))]}"
            local src_path="${selected_entry%%|*}"
            
            local temp_file
            temp_file=$(_temp_mktemp)
            grep -v "^$src_path|" "$map_file" > "$temp_file"
            mv "$temp_file" "$map_file"
            
            okay "✓ Unmapped: $src_path"
        else
            error "Invalid selection"
            return 1
        fi
    fi
    
    # Backup the updated map file
    _backup_repo_artifacts "$repo_root"
    
    info "💡 Changes take effect on next lock operation"
}


do_path() {
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


_migrate_artifacts_namespace() {
    local old_dir="$1"
    local new_dir="$2"
    
    if [[ ! -d "$old_dir" ]]; then
        return 1
    fi
    
    mkdir -p "$new_dir"
    
    # Copy all files except .artifact_info (will be regenerated)
    if find "$old_dir" -type f -not -name ".artifact_info" -exec cp {} "$new_dir/" \; 2>/dev/null; then
        # Update the artifact info with new location
        if [[ -f "$old_dir/.artifact_info" ]]; then
            sed "s|repo_path=.*|repo_path=$(dirname "$new_dir")|" "$old_dir/.artifact_info" > "$new_dir/.artifact_info"
        fi
        return 0
    else
        return 1
    fi
}


do_remote() {
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

