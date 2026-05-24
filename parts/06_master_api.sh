# 06a_master_api.sh - Core API Commands & Master Key Operations
# Part of fx-padlock BashFX architecture remediation
# Contains: Primary user-facing API commands and master key management functions

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
            _age_keygen_private_file "$repo_key_file" || fatal "Failed to generate global key"
        fi
        trace "Using global key"
    else
        # Generate repository-specific key
        repo_key_file="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
        if [[ ! -f "$repo_key_file" ]]; then
            info "🔑 Generating repository key..."
            _age_keygen_private_file "$repo_key_file" || fatal "Failed to generate repository key"
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
    
    # Show key availability status
    echo
    info "🔑 Key availability:"
    local master_key_status="❌ Missing"
    local skull_backup_status="❌ Missing" 
    local repo_key_status="❌ Missing"
    
    if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
        master_key_status="✓ Available"
    fi
    
    local skull_backup="$PADLOCK_KEYS/skull.age"
    if [[ -f "$skull_backup" ]]; then
        skull_backup_status="✓ Available"
    fi
    
    local repo_name=$(basename "$repo_root")
    local repo_key="$PADLOCK_KEYS/$repo_name.key"
    if [[ -f "$repo_key" ]]; then
        repo_key_status="✓ Available"
    fi
    
    echo "  • Master key:      $master_key_status"
    echo "  • Skull key backup: $skull_backup_status"
    echo "  • Repository key:  $repo_key_status"
    echo
    
    case "$state" in
        "unlocked")
            okay "🔓 UNLOCKED - Padlock deployed, secrets accessible in locker/"
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
                    warn "🗃️  LOCKED (CHEST MODE) - Advanced encryption active"
                    info "📦 Ignition key system detected"
                    echo
                    printf "%bNext steps:%b\n" "$cyan" "$xx"
                    echo "  • Run: bin/padlock ignite --unlock"
                    echo "  • With: PADLOCK_IGNITION_PASS=your-key"
                    if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                        echo "  • Emergency: padlock master-unlock"
                    fi
                else
                    warn "🔒 LOCKED - Secrets encrypted in .chest/locker.age"
                    local size
                    size=$(du -h "$repo_root/.chest/locker.age" 2>/dev/null | cut -f1 || echo "unknown")
                    info "📦 Encrypted size: $size"
                    echo
                    printf "%bNext steps:%b\n" "$cyan" "$xx"
                    if [[ -f "$repo_key" ]]; then
                        echo "  • To unlock: padlock unlock"
                    fi
                    if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                        echo "  • Emergency: padlock master-unlock"
                    fi
                fi
            else
                warn "🔒 LOCKED - Secrets encrypted in locker.age"
                local size
                size=$(du -h "$repo_root/locker.age" 2>/dev/null | cut -f1 || echo "unknown")
                info "📦 Encrypted size: $size"
                echo
                printf "%bNext steps:%b\n" "$cyan" "$xx"
                if [[ -f "$repo_key" ]]; then
                    echo "  • To unlock: padlock unlock"
                fi
                if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                    echo "  • Emergency: padlock master-unlock"
                fi
            fi
            ;;
        "unclamped")
            warn "⚠️  NOT CLAMPED - Locker directory exists but padlock not deployed"
            info "📁 Found locker/ directory with unprotected files"
            echo
            printf "%bNext steps:%b\n" "$cyan" "$xx"
            echo "  • Run: padlock clamp . --generate  (deploy padlock)"
            echo "  • Or:  padlock setup               (interactive setup)"
            ;;
        "not-deployed")
            info "🚫 NOT DEPLOYED - Padlock not configured in this repository"
            echo
            printf "%bNext steps:%b\n" "$cyan" "$xx"
            echo "  • Run: padlock clamp . --generate  (deploy with new key)"
            echo "  • Or:  padlock setup               (interactive setup)"
            ;;
        *)
            error "❓ UNKNOWN STATE - Repository in inconsistent state"
            echo
            printf "%bNext steps:%b\n" "$cyan" "$xx"
            echo "  • Run: padlock clamp . --generate  (redeploy padlock)"
            echo "  • Or:  padlock setup               (interactive setup)"
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
    
    # Safety check: Verify we can unlock before allowing lock
    if ! _verify_unlock_capability "$PWD"; then
        error "❌ Safety check failed - aborting lock operation"
        info "Fix the issues above before attempting to lock"
        return 1
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
        temp_map=$(_temp_mktemp)
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
    temp_blob=$(_temp_mktemp "$(dirname "$PWD/locker.age")/locker.age.XXXXXX")
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
    temp_file=$(_temp_mktemp)

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
            local skull_backup="$PADLOCK_KEYS/skull.age"
            if [[ -f "$skull_backup" ]]; then
                okay "💀 Skull backup exists: $skull_backup"
            else
                warn "⚠️  No skull backup found: $skull_backup"
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


do_emergency_unlock() {
    warn "⚠️  EMERGENCY UNLOCK - BYPASSING NORMAL SECURITY"
    warn "⚠️  This will restore repository access and clear all locks"
    
    local repo_root="$(_get_repo_root .)"
    local backup_dir="$repo_root/.padlock/emergency_backup_$(date +%s)"
    
    if [[ -z "$repo_root" ]]; then
        error "Not in a git repository"
        return 1
    fi
    
    # Force confirmation unless --force is used
    if [[ $opt_force -ne 1 ]]; then
        warn "This will:"
        warn "  • Create emergency backup"
        warn "  • Clear all repository locks"
        warn "  • Remove padlock state files"
        warn "  • Restore repository to accessible state"
        echo ""
        read -p "Continue with emergency unlock? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Emergency unlock cancelled"
            return 0
        fi
    fi
    
    info "🚨 Creating emergency backup..."
    if [[ -d "$repo_root/.padlock" ]]; then
        if ! mkdir -p "$backup_dir" && cp -r "$repo_root/.padlock"/* "$backup_dir/" 2>/dev/null; then
            warn "Could not create backup, continuing anyway..."
        else
            info "✓ Backup created at: $backup_dir"
        fi
    fi
    
    info "🔓 Clearing repository locks..."
    
    # Remove locker lock if exists
    if [[ -f "$repo_root/locker/.padlock_lock" ]]; then
        rm -f "$repo_root/locker/.padlock_lock" 2>/dev/null || true
        info "✓ Removed locker lock file"
    fi
    
    # Clear any ignition locks
    if [[ -d "$repo_root/.padlock/ignition" ]]; then
        find "$repo_root/.padlock/ignition" -name "*.lock" -delete 2>/dev/null || true
        info "✓ Cleared ignition locks"
    fi
    
    # Remove any temp/state files that might cause issues
    find "$repo_root" -name ".padlock_*" -type f -delete 2>/dev/null || true
    
    # Try to unlock locker if it exists and is encrypted
    if [[ -d "$repo_root/locker" ]] && [[ ! -f "$repo_root/locker/.env" ]]; then
        info "🔑 Attempting to unlock locker directory..."
        if _master_unlock 2>/dev/null; then
            info "✓ Locker unlocked with master key"
        else
            warn "Could not unlock locker with master key"
            warn "You may need to run 'padlock key --generate-global' and re-clamp"
        fi
    fi
    
    okay "✓ Emergency unlock completed"
    info "Repository should now be accessible"
    if [[ -d "$backup_dir" ]]; then
        info "Emergency backup preserved at: $backup_dir"
    fi
    
    # Check final state
    local final_state="$(_get_lock_state "$repo_root")"
    if [[ "$final_state" == "unlocked" ]]; then
        okay "✓ Repository verified unlocked"
    else
        warn "⚠️  Repository state unclear, manual intervention may be needed"
    fi
}


_master_unlock() {
    # Check if the global key exists
    if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
        error "Master key not found at: $PADLOCK_GLOBAL_KEY"
        info "Options to resolve this:"
        info "  • Run 'padlock key --generate-global' to create a new master key"
        info "  • Run 'padlock key restore' if you have a skull backup"
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


do_master() {
    local action="$1"
    shift || true
    
    case "$action" in
        generate)
            # padlock master generate
            _logo
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]] && [[ "$1" != "--force" ]]; then
                error "Global master key already exists"
                info "Use --force to overwrite"
                return 1
            fi
            
            _ensure_master_key
            okay "✓ Master key generated"
            ;;
            
        show)
            # padlock master show
            if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
                error "No global master key found"
                info "Run: padlock master generate"
                return 1
            fi
            
            local public_key
            public_key=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
            echo "$public_key"
            ;;
            
        restore)
            # padlock master restore
            _logo
            _restore_master_key
            ;;
            
        unlock)
            # padlock master unlock (same as master-unlock)
            do_master_unlock "$@"
            ;;
            
        help|*)
            if [[ "$action" != "help" ]]; then
                error "Unknown master action: $action"
            fi
            info "Master Key Management Commands:"
            info "  generate [--force]   Generate new global master key"
            info "  show                 Display master public key"
            info "  restore              Restore master key from skull backup"
            info "  unlock               Emergency unlock using master key"
            return 0
            ;;
    esac
}


do_sec() {
    local action="${1:-}"
    
    case "$action" in
        auto)
            # padlock sec auto (was: automap)
            shift || true
            do_automap "$@"
            ;;
            
        add)
            # padlock sec add /path
            shift || true
            local path="${1:-}"
            if [[ -z "$path" ]]; then
                error "Missing file path"
                info "Usage: padlock sec add <path>"
                return 1
            fi
            
            do_map add "$path" "${@:2}"
            ;;
            
        "")
            # padlock sec (no action) - show help
            info "File Security Commands:"
            info "  <path>              Secure file (default: add)"
            info "  add <path>          Add file to security mapping"
            info "  remove <path>       Remove file from security mapping"
            info "  auto                Auto-secure sensitive files (*.md, build.sh, etc.)"
            return 0
            ;;
            
        *)
            # padlock sec /path (treat first arg as path)
            if [[ -z "$action" ]]; then
                error "Missing file path"
                info "Usage: padlock sec <path>"
                return 1
            fi
            
            do_map add "$action" "${@:2}"
            ;;
            
        remove)
            # padlock sec remove /path
            local path="$1"
            if [[ -z "$path" ]]; then
                error "Missing file path"
                info "Usage: padlock sec remove <path>"
                return 1
            fi
            
            do_map remove "$path" "${@:2}"
            ;;
            
        help|*)
            if [[ "$action" != "help" ]] && [[ "$action" != "auto" ]] && [[ -n "$action" ]]; then
                # Treat as path for backward compatibility
                do_map add "$action" "$@"
                return
            fi
            
            if [[ "$action" != "help" ]] && [[ "$action" != "auto" ]]; then
                error "Unknown sec action: $action"
            fi
            info "File Security Commands:"
            info "  <path>              Secure file (default: add)"
            info "  add <path>          Add file to security mapping"
            info "  remove <path>       Remove file from security mapping"
            info "  auto                Auto-secure sensitive files (*.md, build.sh, etc.)"
            return 0
            ;;
    esac
}


do_setup() {
    local target_path="${1:-.}"
    
    info "🔧 Setting up padlock in current repository..."
    
    # Default to generating a new key for setup
    do_clamp "$target_path" --generate
}
do_setup() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        ignition)
            # Direct skull backup creation
            _create_skull_backup
            return $?
            ;;
        *)
            # Default interactive setup
            _logo
            info "🔧 Padlock Interactive Setup"
            echo
            
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                okay "✓ Master key already exists"
                
                # Check if skull backup exists
                local skull_backup="$PADLOCK_KEYS/skull.age"
                if [[ -f "$skull_backup" ]]; then
                    okay "✓ Skull backup exists"
                    info "Your padlock is fully configured."
                    echo
                    info "Available commands:"
                    info "  padlock clamp <dir>       - Deploy to a new repository"
                    info "  padlock setup skull       - Recreate skull backup"
                    info "  padlock key restore       - Restore from skull backup"
                    info "  padlock --help            - Show all commands"
                    return 0
                else
                    warn "⚠️  Skull backup is missing"
                    info "Creating skull backup from existing master key..."
                    echo
                    _create_skull_backup
                    return $?
                fi
            fi
            ;;
    esac
    
    echo "This will set up padlock encryption with a master key and skull backup."
    echo "The skull backup allows you to recover your master key if lost."
    echo
    read -p "Proceed with setup? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        info "Setup cancelled."
        return 1
    fi
    
    echo
    info "🔑 Creating master key and skull backup..."
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
    temp_dir=$(_temp_mktemp_d)
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
