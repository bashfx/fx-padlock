do_clamp() {
    local target_path="${1:-.}"
    local use_global_key=false
    local generate_key=false
    local explicit_key=""
    local use_ignition=false
    local ignition_key=""
    
    # Parse arguments
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global-key) 
                use_global_key=true
                shift
                ;;
            --generate) 
                generate_key=true
                shift
                ;;
            --key)
                if [[ $# -lt 2 ]]; then fatal "--key option requires an argument"; fi
                explicit_key="$2"
                shift 2
                ;;
            -K|--ignition)
                use_ignition=true
                if [[ $# -gt 1 && -n "${2:-}" && "$2" != -* ]]; then
                    ignition_key="$2"
                    shift 2
                else
                    shift
                fi
                ;;
            *) 
                error "Unknown option: $1"
                return 1
                ;;
        esac
    done
    
    target_path="$(realpath "$target_path")"
    
    # Validate target is a git repository - show help if not
    if ! is_git_repo "$target_path"; then
        info "Target is not a git repository: $target_path"
        info "The 'clamp' command deploys padlock encryption to a git repository"
        info ""
        info "Usage: padlock clamp <path> [options]"
        info ""
        info "Options:"
        info "  --global-key     Use or create global key"
        info "  --generate       Generate new repo-specific key"
        info "  --key <key>      Use explicit key"
        info "  -K, --ignition   Enable ignition mode for AI collaboration"
        info ""
        info "Prerequisites:"
        info "  • Target directory must be a git repository"
        info "  • Run 'git init' first if needed"
        return 0
    fi
    
    _logo
    info "Deploying padlock to: $target_path"
    
    # Set up paths
    REPO_ROOT="$(_get_repo_root "$target_path")"
    LOCKER_DIR="$REPO_ROOT/locker"
    LOCKER_BLOB="$REPO_ROOT/locker.age"
    LOCKER_CONFIG="$LOCKER_DIR/.padlock"
    
    lock "🔧 Setting up padlock structure..."
    
    # Enhanced age validation with helpful errors
    if ! _validate_age_installation; then
        return 1
    fi
    
    # Create bin directory and copy tools
    mkdir -p "$REPO_ROOT/bin"
    
    # Copy self to target repo
    cp "$SCRIPT_PATH" "$REPO_ROOT/bin/padlock"
    chmod +x "$REPO_ROOT/bin/padlock"
    trace "Copied padlock to bin/"
    
    # Create age-wrapper
    __print_age_wrapper "$REPO_ROOT/bin/age-wrapper" "$REPO_ROOT"
    trace "Created age-wrapper"
    
    # Create .githooks directory and hooks
    mkdir -p "$REPO_ROOT/.githooks"
    __print_hook "$REPO_ROOT/.githooks/pre-commit" "pre-commit" "$REPO_ROOT"
    __print_hook "$REPO_ROOT/.githooks/post-checkout" "post-checkout" "$REPO_ROOT"
    __print_hook "$REPO_ROOT/.githooks/post-merge" "post-merge" "$REPO_ROOT"
    __print_hook "$REPO_ROOT/.githooks/post-commit" "post-commit" "$REPO_ROOT"
    trace "Created git hooks"
    
    # Configure git integration
    __print_gitattributes "$REPO_ROOT/.gitattributes"
    __print_gitignore "$REPO_ROOT/.gitignore"
    
    # Git configuration
    git -C "$REPO_ROOT" config core.hooksPath .githooks 2>/dev/null || true
    git -C "$REPO_ROOT" config filter.locker-crypt.clean 'bin/age-wrapper encrypt' 2>/dev/null || true
    git -C "$REPO_ROOT" config filter.locker-crypt.smudge 'bin/age-wrapper decrypt' 2>/dev/null || true
    trace "Configured git filters"
    
    lock "🔑 Setting up encryption..."
    
    # Determine key strategy
    local repo_key_file
    if [[ -n "$explicit_key" ]]; then
        repo_key_file="$explicit_key"
        trace "Using explicit key: $repo_key_file"
    elif [[ "$use_global_key" == true ]]; then
        repo_key_file="$PADLOCK_GLOBAL_KEY"
        if [[ ! -f "$repo_key_file" ]]; then
            info "🔑 Generating global key..."
            age-keygen > "$repo_key_file"
            chmod 600 "$repo_key_file"
        fi
        trace "Using global key"
    else
        # Generate repository-specific key
        repo_key_file="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
        if [[ ! -f "$repo_key_file" ]]; then
            info "🔑 Generating repository key..."
            age-keygen > "$repo_key_file"
            chmod 600 "$repo_key_file"
        fi
        trace "Using repo-specific key"
    fi
    
    # Create locker directory structure
    mkdir -p "$LOCKER_DIR"
    
    # Enhanced crypto setup with master key integration
    if [[ "$use_ignition" == true ]]; then
        # Generate ignition passphrase if not provided by the user
        if [[ -z "$ignition_key" ]]; then
            ignition_key="$(_generate_ignition_key)"
        fi
        
        # Call the new ignition system setup helper
        _setup_ignition_system "$ignition_key"
        
        # Add to manifest as ignition type
        _add_to_manifest "$REPO_ROOT" "ignition"
        
    else
        # Standard mode with master key backup
        _setup_crypto_with_master "$repo_key_file" "false" ""
        info "🔐 Standard mode configured"
        
        # Add to manifest as standard type
        _add_to_manifest "$REPO_ROOT" "standard"
    fi
    
    # Create starter files
    __print_starter_files "$LOCKER_DIR"
    __print_security_readme "$REPO_ROOT/SECURITY.md"
    trace "Created starter files"
    
    # Backup critical artifacts
    _backup_repo_artifacts "$REPO_ROOT"
    
    # Final success message
    okay "✓ Padlock deployed successfully"
    
    # Show next steps based on mode
    echo
    printf "%bNext steps:%b\n" "$cyan" "$xx"
    if [[ "$use_ignition" == true ]]; then
        printf "  • 🔥 Ignition key: %b%s%b\n" "$cyan" "$ignition_key" "$xx"
        echo "  • Share this key for AI/automation access"
        echo "  • Edit files in locker/ or use chest mode"
    else
        echo "  • Edit files in locker/docs_sec/ and locker/conf_sec/"
        echo "  • Run 'git add . && git commit' to encrypt"
    fi
    echo "  • 🗝️  Master key configured as backup"
    echo "  • Run 'bin/padlock status' to check state"
}

do_status() {
    local repo_root="$(_get_repo_root .)"
    
    if [[ ! -d "$repo_root" ]]; then
        error "Not in a git repository"
        return 1
    fi
    
    info "Repository status: $repo_root"
    
    local state="$(_get_lock_state "$repo_root")"
    
    case "$state" in
        "unlocked")
            okay "🔓 UNLOCKED - Secrets accessible in locker/"
            info "📝 Files ready for editing"
            echo
            printf "%bNext steps:%b\n" "$cyan" "$xx"
            echo "  • Edit files in locker/"
            echo "  • Run 'git commit' (auto-locks on commit)"
            echo "  • Manual lock: bin/padlock lock"
            ;;
        "locked")
            # Check if it's chest mode or legacy mode
            if [[ -d "$repo_root/.chest" ]]; then
                if [[ -f "$repo_root/.chest/ignition.age" ]]; then
                    warn "🗃️  CHEST MODE - Advanced encryption active"
                    info "📦 Ignition key system detected"
                    echo
                    printf "%bNext steps:%b\n" "$cyan" "$xx"
                    echo "  • Run: bin/padlock ignite --unlock"
                    echo "  • With: PADLOCK_IGNITION_PASS=your-key"
                else
                    warn "🔒 LOCKED - Secrets encrypted in .chest/locker.age"
                    local size
                    size=$(du -h "$repo_root/.chest/locker.age" 2>/dev/null | cut -f1 || echo "unknown")
                    info "📦 Encrypted size: $size"
                    echo
                    printf "%bNext steps:%b\n" "$cyan" "$xx"
                    echo "  • To unlock, run: padlock unlock"
                fi
            else
                warn "🔒 LOCKED - Secrets encrypted in locker.age"
                local size
                size=$(du -h "$repo_root/locker.age" 2>/dev/null | cut -f1 || echo "unknown")
                info "📦 Encrypted size: $size"
                echo
                printf "%bNext steps:%b\n" "$cyan" "$xx"
                echo "  • To unlock, run: padlock unlock"
            fi
            ;;
        *)
            error "❓ UNKNOWN STATE - Padlock not properly configured"
            echo
            printf "%bNext steps:%b\n" "$cyan" "$xx"
            echo "  • Run: bin/padlock setup"
            echo "  • Or:  padlock clamp . --generate"
            ;;
    esac
    
    # Show files count if unlocked
    if [[ -d "$repo_root/locker" ]]; then
        local file_count
        file_count=$(find "$repo_root/locker" -type f | wc -l)
        trace "📁 Files in locker: $file_count"
    fi
}

do_lock() {
    # Early validation - show help when called in wrong context
    if [[ ! -d "$PWD/locker" ]]; then
        info "No locker directory found"
        info "The 'lock' command encrypts a locker directory into locker.age"
        info ""
        info "Usage: padlock lock"
        info ""
        info "Prerequisites:"
        info "  • Run 'padlock clamp' first to set up encryption in this repository"
        info "  • Ensure you have a locker/ directory with files to encrypt"
        return 0
    fi
    
    if [[ ! -f "$PWD/locker/.padlock" ]]; then
        info "Locker not properly configured"
        info "The 'lock' command requires a configured locker directory"
        info ""
        info "Usage: padlock lock"
        info ""
        info "Prerequisites:"
        info "  • Missing .padlock config file"
        info "  • Run 'padlock clamp' to set up encryption properly"
        return 0
    fi
    
    # Load configuration
    # shellcheck source=/dev/null
    source "$PWD/locker/.padlock"
    
    if [[ -z "${AGE_RECIPIENTS:-}" && -z "${AGE_PASSPHRASE:-}" ]]; then
        error "No encryption method configured (recipients or passphrase)"
        return 1
    fi
    
    # Validate encryption keys before proceeding
    if [[ -n "${PADLOCK_KEY_FILE:-}" ]]; then
        if [[ ! -f "$PADLOCK_KEY_FILE" ]]; then
            error "❌ Repository key not found: $PADLOCK_KEY_FILE"
            info "Cannot lock without encryption key"
            return 1
        fi
    fi
    
    # Check if recipients include master key
    if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
        # If using recipients, verify master key exists
        if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
            warn "⚠️  Master key not found: $PADLOCK_GLOBAL_KEY"
            info "Without master key, you won't be able to use master-unlock"
            info "Continue anyway? (y/N)"
            read -r confirm
            if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
                info "Lock cancelled for safety"
                return 1
            fi
        fi
    fi
    
    lock "🔒 Encrypting locker directory..."
    
    # Process mapped files first
    local map_file="$PWD/padlock.map"
    if [[ -f "$map_file" ]]; then
        info "📋 Processing mapped files..."
        
        # Create map directory in locker
        mkdir -p locker/map
        
        # Process each mapped file/directory
        while IFS='|' read -r src_rel dest_rel checksum; do
            # Skip comments and empty lines
            [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$src_rel" ]] && continue
            
            local src_abs="$PWD/$src_rel"
            if [[ ! -e "$src_abs" ]]; then
                warn "Mapped file not found, skipping: $src_rel"
                continue
            fi
            
            if [[ -f "$src_abs" ]]; then
                # Copy file to map directory
                local dest_dir="locker/map/$(dirname "$src_rel")"
                mkdir -p "$dest_dir"
                cp "$src_abs" "locker/map/$src_rel"
                trace "Mapped file: $src_rel"
            elif [[ -d "$src_abs" ]]; then
                # Tar and compress directory
                local tar_name="$(basename "$src_rel").tar.gz"
                local dest_dir="locker/map/$(dirname "$src_rel")"
                mkdir -p "$dest_dir"
                
                (cd "$(dirname "$src_abs")" && tar -czf "$PWD/$dest_dir/$tar_name" "$(basename "$src_abs")")
                trace "Mapped directory as archive: $src_rel -> $tar_name"
            fi
        done < "$map_file"
        
        # Update checksums in map file after processing
        local temp_map
        temp_map=$(mktemp)
        while IFS='|' read -r src_rel dest_rel old_checksum; do
            # Skip comments and empty lines
            if [[ "$src_rel" =~ ^[[:space:]]*# ]] || [[ -z "$src_rel" ]]; then
                echo "$src_rel|$dest_rel|$old_checksum" >> "$temp_map"
                continue
            fi
            
            local src_abs="$PWD/$src_rel"
            local new_checksum=""
            
            if [[ -f "$src_abs" ]]; then
                new_checksum=$(md5sum "$src_abs" | cut -d' ' -f1)
            elif [[ -d "$src_abs" ]]; then
                new_checksum=$(find "$src_abs" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
            fi
            
            echo "$src_rel|$dest_rel|$new_checksum" >> "$temp_map"
        done < "$map_file"
        
        mv "$temp_map" "$map_file"
        
        # Move map file into locker for encryption (keeps metadata encrypted)
        mv "$map_file" "locker/padlock.map"
    fi
    
    # Calculate file count before locking
    local file_count
    file_count=$(find locker -type f | wc -l)
    trace "📁 Files to encrypt: $file_count"
    
    # Create archive and encrypt to a secure temporary file
    local temp_blob
    temp_blob=$(mktemp "$(dirname "$PWD/locker.age")/locker.age.XXXXXX")
    tar -czf - locker | __encrypt_stream > "$temp_blob"

    # Check if encryption was successful before proceeding
    if [[ $? -eq 0 && -s "$temp_blob" ]]; then
        # Create .chest directory for clean artifact storage
        mkdir -p .chest
        
        # Encryption successful, move to chest and clean up
        mv "$temp_blob" ".chest/locker.age"
        local size
        size=$(du -h .chest/locker.age | cut -f1)
        okay "✓ Locked: locker/ → .chest/locker.age ($size)"
        
        # Calculate checksum of the original content and save it
        local checksum
        checksum=$(_calculate_locker_checksum "locker")
        echo "$checksum" > .chest/.locker_checksum
        trace "Saved checksum: $checksum"

        # Create a simple state file to indicate locked status
        touch .chest/.locked
        
        # Note: padlock.map was moved into locker/ before encryption for security
        # It should not exist in root or be copied to .chest as that would expose metadata
        

        # Remove original mapped files/directories before removing locker
        if [[ -f "locker/padlock.map" ]]; then
            info "🧹 Removing original mapped files..."
            while IFS='|' read -r src_rel dest_rel checksum; do
                # Skip comments and empty lines
                [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$src_rel" ]] && continue
                
                local src_abs="$PWD/$src_rel"
                if [[ -e "$src_abs" ]]; then
                    if [[ -f "$src_abs" ]]; then
                        rm -f "$src_abs"
                        trace "Removed mapped file: $src_rel"
                    elif [[ -d "$src_abs" ]]; then
                        rm -rf "$src_abs"
                        trace "Removed mapped directory: $src_rel"
                    fi
                fi
            done < "locker/padlock.map"
        fi

        # Remove plaintext locker *after* successful encryption and cleanup
        rm -rf locker
        
        info "Repository locked successfully."
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • git add . && git commit"
        echo "  • To unlock, run: padlock unlock"
        warn "⚠️  Secrets are now encrypted and safe to commit"
        
    else
        # Encryption failed, clean up temporary file and abort
        rm -f "$temp_blob"
        fatal "Failed to encrypt locker directory. Plaintext data remains untouched."
    fi
}

do_unlock() {
    # Early validation - check both old location and new .chest location
    local locker_age_file=""
    local checksum_file=""
    local locked_file=""
    
    if [[ -f ".chest/locker.age" ]]; then
        locker_age_file=".chest/locker.age"
        checksum_file=".chest/.locker_checksum"
        locked_file=".chest/.locked"
    elif [[ -f "locker.age" ]]; then
        locker_age_file="locker.age"
        checksum_file=".locker_checksum"
        locked_file=".locked"
    else
        info "No encrypted locker found (locker.age missing)"
        info "The 'unlock' command decrypts locker.age into a locker directory"
        info ""
        info "Usage: padlock unlock"
        info ""
        info "Prerequisites:"
        info "  • Have a locker.age file (created by 'padlock lock')"
        info "  • Have the appropriate decryption key available"
        info "  • Repository may already be unlocked if locker/ directory exists"
        return 0
    fi

    if [[ -d "locker" ]]; then
        warn "Locker directory already exists"
        info "Repository appears to be unlocked"
        return 0
    fi

    # Determine key file path, preferring env var if set, otherwise derive it
    local key_file="${PADLOCK_KEY_FILE:-}"
    if [[ -z "$key_file" ]]; then
        local repo_root
        repo_root=$(_get_repo_root .)
        key_file="$PADLOCK_KEYS/$(basename "$repo_root").key"

        if [[ ! -f "$key_file" ]]; then
            error "Could not find default decryption key for this repository."
            info "Looked for key at: $key_file"
            info "You can also set the PADLOCK_KEY_FILE environment variable manually."
            return 1
        fi
        trace "Using derived repository key: $key_file"
    else
        trace "Using key from PADLOCK_KEY_FILE env var: $key_file"
    fi

    lock "🔓 Decrypting $locker_age_file..."

    # Decrypt and extract using the determined key file
    if age -d -i "$key_file" < "$locker_age_file" | tar -xzf -; then
        local file_count
        file_count=$(find locker -type f | wc -l)
        okay "✓ Unlocked: $locker_age_file → locker/ ($file_count files)"

        # Verify integrity against the stored checksum
        if [[ -f "$checksum_file" ]]; then
            local expected_checksum
            expected_checksum=$(cat "$checksum_file")
            local current_checksum
            current_checksum=$(_calculate_locker_checksum "locker")

            trace "Verifying checksum. Expected: $expected_checksum, Current: $current_checksum"
            if [[ "$expected_checksum" == "$current_checksum" ]]; then
                okay "✓ Locker integrity verified."
            else
                error "🔒 Integrity check FAILED. Contents may have been tampered with."
                info "Expected: $expected_checksum"
                info "Current:  $current_checksum"
                if [[ "${opt_force:-0}" -eq 1 ]]; then
                    warn "⚠️  --force flag used, continuing despite integrity failure"
                else
                    fatal "Use --force to override integrity check and unlock anyway"
                fi
            fi
        fi

        # Restore mapped files from locker/map to their original locations
        if [[ -f "locker/padlock.map" ]]; then
            info "📋 Restoring mapped files to original locations..."
            local restored_count=0
            
            while IFS='|' read -r src_rel dest_rel checksum; do
                # Skip comments and empty lines
                [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$src_rel" ]] && continue
                
                local stored_file="locker/map/$src_rel"
                local restore_path="$PWD/$dest_rel"
                
                if [[ -f "$stored_file" ]]; then
                    # Restore regular file
                    mkdir -p "$(dirname "$restore_path")"
                    cp "$stored_file" "$restore_path"
                    okay "✓ Restored file: $dest_rel"
                    ((restored_count++))
                elif [[ -f "locker/map/$(basename "$src_rel").tar.gz" ]] || [[ -f "locker/map/$(dirname "$src_rel")/$(basename "$src_rel").tar.gz" ]]; then
                    # Find the tar file (could be in map root or subdirectory)
                    local tar_file=""
                    if [[ -f "locker/map/$(basename "$src_rel").tar.gz" ]]; then
                        tar_file="locker/map/$(basename "$src_rel").tar.gz"
                    else
                        tar_file="locker/map/$(dirname "$src_rel")/$(basename "$src_rel").tar.gz"
                    fi
                    
                    # Extract directly to repository root
                    if tar -xzf "$tar_file" -C "$PWD" 2>/dev/null; then
                        okay "✓ Restored directory: $dest_rel"
                        ((restored_count++))
                    else
                        warn "Failed to extract: $tar_file"
                    fi
                else
                    warn "Mapped item not found in locker/map, skipping: $src_rel"
                fi
            done < "locker/padlock.map"
            
            # Move padlock.map back to root
            cp "locker/padlock.map" "padlock.map"
            rm -f "locker/padlock.map"
            
            # Clean up map directory from locker
            rm -rf "locker/map"
            
            if [[ $restored_count -gt 0 ]]; then
                info "📁 Restored $restored_count mapped items to original locations"
            fi
        fi

        # Clean up encrypted file and state indicators
        rm -f "$locker_age_file" "$locked_file" "$checksum_file"
        
        # Remove .chest directory when unlocked (should be empty after cleanup)
        if [[ -d ".chest" ]]; then
            # Force removal of any remaining files in .chest and the directory itself
            rm -rf ".chest"
            trace "Removed .chest directory"
        fi

        info "Repository unlocked successfully. Your shell session is not affected."
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Edit files in the 'locker' directory."
        echo "  • Run 'git commit' to auto-lock when done."
        warn "⚠️  Secrets are now in plaintext. The 'locker/' directory is in .gitignore."

    else
        fatal "Failed to decrypt $locker_age_file. Check your key permissions or repository state."

    fi
}

do_clean_manifest() {
    local manifest_file="$PADLOCK_ETC/manifest.txt"

    if [[ ! -f "$manifest_file" || ! -s "$manifest_file" ]]; then
        info "Manifest is empty or not found. Nothing to clean."
        return
    fi

    local temp_file
    temp_file=$(mktemp)

    # Preserve header
    grep "^#" "$manifest_file" > "$temp_file"

    # Use a temporary variable to store the lines to keep
    local lines_to_keep=""
    while IFS= read -r line; do
        # Skip comments
        [[ "$line" =~ ^# ]] && continue

        # Parse the line
        IFS='|' read -r namespace name path type remote checksum created access metadata <<< "$line"

        # Keep if the path exists and is not a temp path
        if [[ -d "$path" && "$metadata" != *"temp=true"* && "$path" != */tmp/* ]]; then
            lines_to_keep+="$line\n"
        else
            trace "Pruning from manifest: $namespace/$name ($path)"
        fi
    done < "$manifest_file"

    # Write the kept lines to the temp file
    printf "%b" "$lines_to_keep" >> "$temp_file"

    mv "$temp_file" "$manifest_file"
    okay "✓ Manifest cleaned"
}

do_list() {
    local filter="$1"
    local manifest_file="$PADLOCK_ETC/manifest.txt"

    if [[ ! -f "$manifest_file" || ! -s "$manifest_file" ]]; then
        info "Manifest is empty or not found. No repositories tracked yet."
        return
    fi

    case "$filter" in
        --all)
            awk -F'|' '!/^#/ { printf "%-15s %-20s %s (%s)\n", $1, $2, $3, $4 }' "$manifest_file"
            ;;
        --ignition)
            awk -F'|' '!/^#/ && $4 == "ignition" && $9 !~ /temp=true/ { printf "%-15s %-20s %s\n", $1, $2, $3 }' "$manifest_file"
            ;;
        --namespace)
            local ns="$2"
            awk -F'|' -v namespace="$ns" '!/^#/ && $1 == namespace && $9 !~ /temp=true/ { printf "%-20s %s (%s)\n", $2, $3, $4 }' "$manifest_file"
            ;;
        *)
            # Default: exclude temp directories, show namespace/name/path
            awk -F'|' '!/^#/ && $9 !~ /temp=true/ && $3 !~ /\/tmp\// { printf "%-15s %-20s %s (%s)\n", $1, $2, $3, $4 }' "$manifest_file"
            ;;
    esac
}

do_ls() {
    local target="${1:-}"
    
    case "$target" in
        master)
            # Show master key path and status
            info "🔑 Master key information:"
            echo
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                okay "✓ Master key exists: $PADLOCK_GLOBAL_KEY"
                local key_size
                key_size=$(wc -c < "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
                trace "   Size: $key_size bytes"
                
                # Show creation time if available
                if command -v stat >/dev/null 2>&1; then
                    local created
                    if stat --version >/dev/null 2>&1; then
                        # GNU stat
                        created=$(stat -c %y "$PADLOCK_GLOBAL_KEY" 2>/dev/null | cut -d. -f1)
                    else
                        # BSD stat (macOS)
                        created=$(stat -f "%Sm" "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
                    fi
                    [[ -n "$created" ]] && trace "   Created: $created"
                fi
                
                # Show public key
                if command -v age-keygen >/dev/null 2>&1; then
                    local pubkey
                    pubkey=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null || echo "Unable to read")
                    info "🔐 Public key: $pubkey"
                fi
            else
                error "❌ Master key not found: $PADLOCK_GLOBAL_KEY"
                info "Create with: padlock key --generate-global"
            fi
            
            # Check for ignition backup
            local ignition_backup="$PADLOCK_KEYS/ignition.age"
            if [[ -f "$ignition_backup" ]]; then
                okay "🔥 Ignition backup exists: $ignition_backup"
            else
                warn "⚠️  No ignition backup found: $ignition_backup"
                info "Create with: padlock setup (in interactive mode)"
            fi
            ;;
        *)
            error "Unknown ls target: $target"
            info "Available targets:"
            info "  master  - Show master key path and status"
            return 1
            ;;
    esac
}

# Backup critical repository artifacts
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

# Restore critical repository artifacts
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

# Enhanced manifest management
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

# Master unlock command
do_master_unlock() {
    # Check if already unlocked
    local repo_root="$(_get_repo_root .)"
    local state="$(_get_lock_state "$repo_root")"
    
    if [[ "$state" == "unlocked" ]]; then
        warn "⚠️  Repository is already unlocked"
        info "📁 Locker directory exists and is accessible"
        return 0
    fi
    
    lock "🔑 Unlocking with master key..."
    if ! _master_unlock; then
        return 1
    fi
    
    okay "✓ Repository unlocked with master key"
    info "📝 Environment loaded and ready"
    warn "⚠️  Secrets are now in plaintext - DO NOT commit locker/"
}

_master_unlock() {
    # Check if the global key exists
    if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
        error "Master key not found at: $PADLOCK_GLOBAL_KEY"
        info "Options to resolve this:"
        info "  • Run 'padlock key --generate-global' to create a new master key"
        info "  • Run 'padlock key restore' if you have an ignition backup"
        info "  • Run 'padlock setup' for interactive setup"
        return 1
    fi

    local encrypted_file=""
    local is_chest_mode=false
    
    # Check for chest mode first, then legacy mode
    if [[ -f ".chest/locker.age" ]]; then
        encrypted_file=".chest/locker.age"
        is_chest_mode=true
        info "Found chest mode encrypted locker"
    elif [[ -f "locker.age" ]]; then
        encrypted_file="locker.age"
        info "Found legacy mode encrypted locker"
    else
        error "No encrypted locker found (locker.age or .chest/locker.age missing)."
        info "Cannot perform master unlock without encrypted locker."
        return 1
    fi

    # Use the global key for decryption by setting AGE_KEY_FILE for __decrypt_stream
    export PADLOCK_KEY_FILE="$PADLOCK_GLOBAL_KEY"

    info "Attempting decryption with master key..."
    if __decrypt_stream < "$encrypted_file" | tar -xzf -; then
        local file_count
        file_count=$(find locker -type f | wc -l)
        okay "✓ Unlocked: $encrypted_file → locker/ ($file_count files)"
        
        # Restore mapped files from locker/map to their original locations
        if [[ -f "locker/padlock.map" ]]; then
            info "📋 Restoring mapped files to original locations..."
            local restored_count=0
            
            while IFS='|' read -r src_rel dest_rel checksum; do
                # Skip comments and empty lines
                [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$src_rel" ]] && continue
                
                local stored_file="locker/map/$src_rel"
                local restore_path="$PWD/$dest_rel"
                
                if [[ -f "$stored_file" ]]; then
                    # Restore regular file
                    mkdir -p "$(dirname "$restore_path")"
                    cp "$stored_file" "$restore_path"
                    okay "✓ Restored file: $dest_rel"
                    ((restored_count++))
                elif [[ -f "locker/map/$(basename "$src_rel").tar.gz" ]] || [[ -f "locker/map/$(dirname "$src_rel")/$(basename "$src_rel").tar.gz" ]]; then
                    # Find the tar file (could be in map root or subdirectory)
                    local tar_file=""
                    if [[ -f "locker/map/$(basename "$src_rel").tar.gz" ]]; then
                        tar_file="locker/map/$(basename "$src_rel").tar.gz"
                    else
                        tar_file="locker/map/$(dirname "$src_rel")/$(basename "$src_rel").tar.gz"
                    fi
                    
                    # Extract directly to repository root
                    if tar -xzf "$tar_file" -C "$PWD" 2>/dev/null; then
                        okay "✓ Restored directory: $dest_rel"
                        ((restored_count++))
                    else
                        warn "Failed to extract: $tar_file"
                    fi
                else
                    warn "Mapped item not found in locker/map, skipping: $src_rel"
                fi
            done < "locker/padlock.map"
            
            # Move padlock.map back to root
            cp "locker/padlock.map" "padlock.map"
            rm -f "locker/padlock.map"
            
            # Clean up map directory from locker
            rm -rf "locker/map"
            
            if [[ $restored_count -gt 0 ]]; then
                info "📁 Restored $restored_count mapped items to original locations"
            fi
        fi
        
        if [[ "$is_chest_mode" == true ]]; then
            # In chest mode, remove the entire .chest directory after successful unlock
            rm -rf .chest
            info "Successfully unlocked chest with master key."
        else
            # In legacy mode, remove the encrypted file and lock marker
            rm -f locker.age .locked
            info "Successfully unlocked with master key."
        fi
        unset PADLOCK_KEY_FILE
        return 0
    else
        error "Failed to decrypt encrypted locker with master key."
        unset PADLOCK_KEY_FILE
        return 1
    fi
}

# Placeholders for unimplemented ignition features
_ignition_lock() {
    local repo_root="$(_get_repo_root .)"
    
    # Check if we have a locker to lock
    if [[ ! -d "$repo_root/locker" ]]; then
        error "No locker directory found"
        info "Repository may already be locked"
        return 1
    fi
    
    # Check if we're in chest mode
    if [[ ! -d "$repo_root/.chest" ]]; then
        error "Repository is not in chest mode"
        info "Use 'padlock ignite --status' to check current state"
        return 1
    fi
    
    lock "🗃️  Locking locker into chest..."
    
    # Use the existing _lock_chest helper which does the actual work
    if _lock_chest; then
        okay "✓ Locker secured in chest"
        info "🔥 Ignition key required for unlock"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • git add . && git commit"
        echo "  • To unlock: padlock ignite --unlock"
        warn "⚠️  Chest is now locked and safe to commit"
        return 0
    else
        error "Failed to lock locker into chest"
        return 1
    fi
}
_chest_status() {
    local repo_root="$(_get_repo_root .)"
    
    if [[ ! -d "$repo_root/.chest" ]]; then
        error "Repository is not in chest mode"
        info "This repository uses standard locker encryption"
        return 1
    fi
    
    info "=== Chest Status ==="
    
    local chest_blob="$repo_root/.chest/locker.age"
    local ignition_blob="$repo_root/.chest/ignition.age"
    
    if [[ -f "$chest_blob" && -f "$ignition_blob" ]]; then
        local size
        size=$(du -h "$chest_blob" 2>/dev/null | cut -f1)
        warn "🗃️  CHEST LOCKED"
        info "Encrypted locker: $size"
        info "Ignition key: protected"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • To unlock: padlock ignite --unlock"
        echo "  • Set ignition key: export PADLOCK_IGNITION_PASS='your-key'"
        
    elif [[ -d "$repo_root/locker" ]]; then
        okay "🔓 CHEST UNLOCKED"
        local file_count
        file_count=$(find "$repo_root/locker" -type f | wc -l)
        info "Files accessible: $file_count"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Edit files in locker/"
        echo "  • To lock: padlock ignite --lock"
        echo "  • Manual commit locks automatically"
        
    else
        error "🔧 CHEST CORRUPTED"
        warn "Neither locked chest nor unlocked locker found"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Try: padlock repair"
        echo "  • Check ignition key: PADLOCK_IGNITION_PASS"
        echo "  • Or convert: padlock revoke --ignition"
    fi
    
    # Show chest contents if accessible
    if [[ -d "$repo_root/.chest" ]]; then
        local chest_items
        chest_items=$(find "$repo_root/.chest" -type f 2>/dev/null | wc -l)
        trace "🗃️  Chest items: $chest_items"
    fi
}

_ignition_unlock() {
    if [[ -z "${PADLOCK_IGNITION_PASS:-}" ]]; then
        error "Ignition key not found in environment variable PADLOCK_IGNITION_PASS."
        return 1
    fi

    if [[ ! -f "locker.age" ]]; then
        error "No encrypted locker found (locker.age missing)."
        return 1
    fi

    # Use the ignition pass as the age passphrase for decryption
    export AGE_PASSPHRASE="$PADLOCK_IGNITION_PASS"

    if __decrypt_stream < locker.age | tar -xzf -; then
        rm -f locker.age .locked
        return 0
    else
        error "Failed to decrypt locker.age with ignition key."
        return 1
    fi
}

# Ignition unlock command
do_ignite() {
    local action="$1"
    
    # Set REPO_ROOT for the helpers, as this is a top-level command.
    REPO_ROOT=$(_get_repo_root .)

    case "$action" in
        --unlock|-u)
            _unlock_chest
            ;;
        --lock|-l)
            _lock_chest
            ;;
        --status|-s)
            _chest_status
            ;;
        *)
            error "Unknown ignition action: $action"
            info "Available actions: --unlock, --lock, --status"
            return 1
            ;;
    esac
}

do_rotate() {
    local target="$1"

    # Set REPO_ROOT for the helpers
    REPO_ROOT=$(_get_repo_root .)

    case "$target" in
        -K|--ignition)
            _rotate_ignition_key
            ;;
        *)
            error "Unknown target for rotate: $target"
            info "Usage: padlock rotate --ignition"
            return 1
            ;;
    esac
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
    temp_dir=$(mktemp -d)
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

_merge_manifests() {
    local import_manifest="$1"
    local current_manifest="$2"
    local temp_file
    temp_file=$(mktemp)

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
    temp_dir=$(mktemp -d)
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

do_snapshot() {
    local snapshot_name="${1:-auto_$(date +%Y%m%d_%H%M%S)}"
    local snapshots_dir="$PADLOCK_ETC/snapshots"

    mkdir -p "$snapshots_dir"

    # Use a temporary, non-guessable passphrase for the snapshot export
    local snapshot_pass
    snapshot_pass=$(openssl rand -base64 32)

    local export_file="$snapshots_dir/${snapshot_name}.tar.age"

    info "Creating snapshot: $snapshot_name"

    local temp_dir
    temp_dir=$(mktemp -d)
    trap 'rm -rf "$temp_dir"' RETURN

    cp "$PADLOCK_ETC/manifest.txt" "$temp_dir/manifest.txt"
    cp -r "$PADLOCK_KEYS" "$temp_dir/keys"
    
    # Include repo artifacts in snapshot
    if [[ -d "$PADLOCK_ETC/repos" ]]; then
        cp -r "$PADLOCK_ETC/repos" "$temp_dir/repos"
    fi

    tar -C "$temp_dir" -czf - . | AGE_PASSPHRASE="$snapshot_pass" age -p > "$export_file"
    if [[ $? -ne 0 ]]; then
        fatal "Failed to create snapshot export file."
    fi

    # Create snapshot metadata, including the passphrase
    cat > "$snapshots_dir/${snapshot_name}.info" << EOF
name=$snapshot_name
created=$(date -Iseconds)
passphrase=$snapshot_pass
repos=$(grep -cv "^#" "$PADLOCK_ETC/manifest.txt")
keys=$(find "$PADLOCK_KEYS" -name "*.key" | wc -l)
EOF

    okay "✓ Snapshot created: $snapshot_name"
}

do_rewind() {
    local snapshot_name="$1"
    local snapshots_dir="$PADLOCK_ETC/snapshots"

    if [[ ! -f "$snapshots_dir/${snapshot_name}.tar.age" || ! -f "$snapshots_dir/${snapshot_name}.info" ]]; then
        error "Snapshot not found: $snapshot_name"
        info "Available snapshots:"
        ls -1 "$snapshots_dir"/*.info 2>/dev/null | sed 's/\.info$//' | xargs -I {} basename {} || echo " (none)"
        return 1
    fi

    warn "This will ERASE your current padlock environment and restore the snapshot."
    read -p "Type the snapshot name to confirm: '$snapshot_name': " confirm
    if [[ "$confirm" != "$snapshot_name" ]]; then
        info "Rewind cancelled."
        return 0
    fi

    # Get the passphrase from the metadata file
    local snapshot_pass
    snapshot_pass=$(grep "^passphrase=" "$snapshots_dir/${snapshot_name}.info" | cut -d'=' -f2)

    # Call do_import with the correct arguments for non-interactive restore
    do_import "$snapshots_dir/${snapshot_name}.tar.age" --replace "$snapshot_pass"

    okay "✓ Rewound to snapshot: $snapshot_name"
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
    if ! __decrypt_stream < "$REPO_ROOT/super_chest.age" | tar -C "$REPO_ROOT" -xzf -; then
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

    trap 'rm -rf "$super_chest"' EXIT

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

# Setup command - alias for clamp with common defaults
do_setup() {
    local target_path="${1:-.}"
    
    info "🔧 Setting up padlock in current repository..."
    
    # Default to generating a new key for setup
    do_clamp "$target_path" --generate
}

# Key management commands
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
        ""|*)
            if [[ -z "$action" ]]; then
                info "Available key management actions:"
            else
                error "Unknown key action: $action"
            fi
            info "  --set-global <key>     Set global master key"
            info "  --show-global          Display global public key"
            info "  --generate-global      Generate new global key"
            info "  --add-recipient <key>  Add recipient to current repo"
            info "  restore               Restore master key from ignition backup"
            [[ -n "$action" ]] && return 1 || return 0
            ;;
    esac
}

do_setup() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        ignition)
            # Direct ignition backup creation
            _create_ignition_backup
            return $?
            ;;
        *)
            # Default interactive setup
            _logo
            info "🔧 Padlock Interactive Setup"
            echo
            
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                okay "✓ Master key already exists"
                
                # Check if ignition backup exists
                local ignition_backup="$PADLOCK_KEYS/ignition.age"
                if [[ -f "$ignition_backup" ]]; then
                    okay "✓ Ignition backup exists"
                    info "Your padlock is fully configured."
                    echo
                    info "Available commands:"
                    info "  padlock clamp <dir>       - Deploy to a new repository"
                    info "  padlock setup ignition    - Recreate ignition backup"
                    info "  padlock key restore       - Restore from ignition backup"
                    info "  padlock --help            - Show all commands"
                    return 0
                else
                    warn "⚠️  Ignition backup is missing"
                    info "Creating ignition backup from existing master key..."
                    echo
                    _create_ignition_backup
                    return $?
                fi
            fi
            ;;
    esac
    
    echo "This will set up padlock encryption with a master key and ignition backup."
    echo "The ignition backup allows you to recover your master key if lost."
    echo
    read -p "Proceed with setup? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        info "Setup cancelled."
        return 1
    fi
    
    echo
    info "🔑 Creating master key and ignition backup..."
    _ensure_master_key
    
    echo
    okay "✓ Setup complete!"
    echo
    info "Next steps:"
    info "  1. Run 'padlock clamp <directory>' to secure a repository"
    info "  2. Keep your master key safe: $PADLOCK_GLOBAL_KEY"
    info "  3. Remember your ignition passphrase for emergency recovery"
}

do_repair() {
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
                info "  • Run 'padlock key restore' if you have ignition backup"
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

# Safe declamp operation - remove padlock infrastructure while preserving data
do_declamp() {
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

# Revocation operations - remove access to encrypted content
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
            temp_file=$(mktemp)
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

# Unmap files with support for file selection
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
        temp_file=$(mktemp)
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
        temp_file=$(mktemp)
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
            temp_file=$(mktemp)
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

# Helper function to migrate artifacts between namespaces
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

do_revoke() {
    local target="${1:-}"
    local force="${2:-}"
    
    case "$target" in
        --local)
            _revoke_local_access "$force"
            ;;
        -K|--ignition)
            _revoke_ignition_access "$force"
            ;;
        ""|*)
            if [[ -z "$target" ]]; then
                info "Available revocation targets:"
            else
                error "Unknown revocation target: $target"
            fi
            info "  --local       Revoke local access (WARNING: makes content unrecoverable)"
            info "  --ignition    Revoke ignition key access"
            [[ -n "$target" ]] && return 1 || return 0
            ;;
    esac
}

# Revoke local access - WARNING: This makes content permanently unrecoverable
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

# Revoke ignition access - removes ignition key system
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
