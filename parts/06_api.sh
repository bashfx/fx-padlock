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
    info "Deploying padlock to: $target_path"
    
    # Enhanced validation with helpful errors
    if ! _validate_clamp_target "$target_path"; then
        return 1
    fi
    
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
    
    if [[ -d "$repo_root/locker" && -f "$repo_root/locker/.padlock" ]]; then
        okay "🔓 UNLOCKED - Secrets accessible in locker/"
        info "📝 Files ready for editing"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Edit files in locker/"
        echo "  • Run 'git commit' (auto-locks on commit)"
        echo "  • Manual lock: bin/padlock lock"
        
    elif [[ -f "$repo_root/.locked" && -f "$repo_root/locker.age" ]]; then
        warn "🔒 LOCKED - Secrets encrypted in locker.age"
        local size
        size=$(du -h "$repo_root/locker.age" 2>/dev/null | cut -f1 || echo "unknown")
        info "📦 Encrypted size: $size"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • To unlock, run: padlock unlock"
        
    elif [[ -d "$repo_root/.chest" ]]; then
        warn "🗃️  CHEST MODE - Advanced encryption active"
        info "📦 Ignition key system detected"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Run: bin/padlock ignite --unlock"
        echo "  • With: PADLOCK_IGNITION_PASS=your-key"
        
    else
        error "❓ UNKNOWN STATE - Padlock not properly configured"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Run: bin/padlock setup"
        echo "  • Or:  padlock clamp . --generate"
    fi
    
    # Show files count if unlocked
    if [[ -d "$repo_root/locker" ]]; then
        local file_count
        file_count=$(find "$repo_root/locker" -type f | wc -l)
        trace "📁 Files in locker: $file_count"
    fi
}

do_lock() {
    # Early validation
    if [[ ! -d "$PWD/locker" ]]; then
        error "No locker directory found"
        info "Run 'padlock clamp' first to set up encryption"
        return 1
    fi
    
    if [[ ! -f "$PWD/locker/.padlock" ]]; then
        error "Locker not properly configured"
        info "Missing .padlock config file"
        return 1
    fi
    
    # Load configuration
    # shellcheck source=/dev/null
    source "$PWD/locker/.padlock"
    
    if [[ -z "${AGE_RECIPIENTS:-}" && -z "${AGE_PASSPHRASE:-}" ]]; then
        error "No encryption method configured (recipients or passphrase)"
        return 1
    fi
    
    lock "🔒 Encrypting locker directory..."
    
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
        # Encryption successful, proceed with replacing old blob and removing plaintext
        mv "$temp_blob" "locker.age"
        local size
        size=$(du -h locker.age | cut -f1)
        okay "✓ Locked: locker/ → locker.age ($size)"
        
        # Calculate checksum
        local checksum
        checksum=$(find locker -type f -exec md5sum {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1)

        # Calculate checksum of the original content and save it
        local checksum
        checksum=$(_calculate_locker_checksum "locker")
        echo "$checksum" > .locker_checksum
        trace "Saved checksum: $checksum"

        # Create a simple state file to indicate locked status
        touch .locked
        

        # Remove plaintext locker *after* successful encryption and move
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
    # Early validation
    if [[ ! -f "locker.age" ]]; then
        error "No encrypted locker found (locker.age missing)"
        info "Repository may already be unlocked"
        return 1
    fi

    if [[ -d "locker" ]]; then
        warn "Locker directory already exists"
        info "Repository appears to be unlocked"
        return 0
    fi

    # Determine key file path, preferring env var if set, otherwise derive it
    local key_file="${AGE_KEY_FILE:-}"
    if [[ -z "$key_file" ]]; then
        local repo_root
        repo_root=$(_get_repo_root .)
        key_file="$PADLOCK_KEYS/$(basename "$repo_root").key"

        if [[ ! -f "$key_file" ]]; then
            error "Could not find default decryption key for this repository."
            info "Looked for key at: $key_file"
            info "You can also set the AGE_KEY_FILE environment variable manually."
            return 1
        fi
        trace "Using derived repository key: $key_file"
    else
        trace "Using key from AGE_KEY_FILE env var: $key_file"
    fi

    lock "🔓 Decrypting locker.age..."

    # Decrypt and extract using the determined key file
    if age -d -i "$key_file" < locker.age | tar -xzf -; then
        local file_count
        file_count=$(find locker -type f | wc -l)
        okay "✓ Unlocked: locker.age → locker/ ($file_count files)"

        # Verify integrity against the stored checksum
        if [[ -f ".locker_checksum" ]]; then
            local expected_checksum
            expected_checksum=$(cat .locker_checksum)
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

        # Clean up encrypted file and state indicators
        rm -f locker.age .locked .locker_checksum

        info "Repository unlocked successfully. Your shell session is not affected."
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Edit files in the 'locker' directory."
        echo "  • Run 'git commit' to auto-lock when done."
        warn "⚠️  Secrets are now in plaintext. The 'locker/' directory is in .gitignore."

    else
        fatal "Failed to decrypt locker.age. Check your key permissions or repository state."

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

    # Early validation for locker.age
    if [[ ! -f "locker.age" ]]; then
        error "No encrypted locker found (locker.age missing)."
        info "Cannot perform master unlock without locker.age."
        return 1
    fi

    # Use the global key for decryption by setting AGE_KEY_FILE for __decrypt_stream
    export AGE_KEY_FILE="$PADLOCK_GLOBAL_KEY"

    info "Attempting decryption with master key..."
    if __decrypt_stream < locker.age | tar -xzf -; then
        rm -f locker.age .locked
        info "Successfully unlocked with master key."
        unset AGE_KEY_FILE
        return 0
    else
        error "Failed to decrypt locker.age with master key."
        unset AGE_KEY_FILE
        return 1
    fi
}

# Placeholders for unimplemented ignition features
_ignition_lock() {
    error "Ignition lock feature not implemented."
    return 1
}
_chest_status() {
    error "Chest status feature not implemented."
    return 1
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
            # Simple status for now, can be enhanced later.
            if [[ -d "$REPO_ROOT/.chest" ]]; then
                info "Chest is LOCKED."
            elif [[ -d "$REPO_ROOT/locker" ]]; then
                info "Chest is UNLOCKED."
            else
                info "Chest status is unknown (not an ignition repo?)."
            fi
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

    # Copy manifest and keys to a temporary location
    cp "$PADLOCK_ETC/manifest.txt" "$export_manifest"
    cp -r "$PADLOCK_KEYS" "$keys_dir"

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
            mkdir -p "$PADLOCK_KEYS"
            cp "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -r "$temp_dir/keys"/* "$PADLOCK_KEYS/"
            ;;
        --merge)
            info "Merging with current environment."
            _merge_manifests "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -rT "$temp_dir/keys" "$PADLOCK_KEYS" 2>/dev/null || true
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
    local force="${1:-0}"
    
    # Check if already installed
    local install_dir="$XDG_LIB_HOME/fx/padlock"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    
    if [[ -d "$install_dir" ]] && [[ "$force" -eq 1 ]]; then
        warn "Padlock already installed (use --force to reinstall)"
        return 0
    fi
    
    info "Installing padlock to system..."
    
    # Create installation directories
    mkdir -p "$(dirname "$install_dir")" "$(dirname "$link_path")"
    
    # Copy script to installation location
    cp -r "$(dirname "$SCRIPT_PATH")" "$install_dir"
    
    # Create symlink
    ln -sf "$install_dir/$(basename "$SCRIPT_PATH")" "$link_path"
    
    # Generate master key on first install
    _ensure_master_key
    
    okay "✓ Padlock installed to: $install_dir"
    info "Available as: $link_path"
    info "🗝️  Global master key configured"
}

do_uninstall() {
    local install_dir="$XDG_LIB_HOME/fx/padlock"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    
    info "🗑️  Uninstalling padlock from system..."
    
    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        info "✓ Removed symlink: $link_path"
    fi
    
    if [[ -d "$install_dir" ]]; then
        rm -rf "$install_dir"
        info "✓ Removed installation: $install_dir"
    fi
    
    if [[ ! -L "$link_path" ]] && [[ ! -d "$install_dir" ]]; then
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
    export AGE_KEY_FILE="$PADLOCK_GLOBAL_KEY"

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
    local action="$1"
    shift
    
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
            _restore_master_key
            ;;
        *)
            error "Unknown key action: $action"
            info "Available actions:"
            info "  --set-global <key>     Set global master key"
            info "  --show-global          Display global public key"
            info "  --generate-global      Generate new global key"
            info "  --add-recipient <key>  Add recipient to current repo"
            info "  restore               Restore master key from ignition backup"
            return 1
            ;;
    esac
}

do_setup() {
    info "🔧 Padlock Interactive Setup"
    echo
    
    if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
        okay "✓ Master key already exists"
        info "Your padlock is already configured."
        echo
        info "Available commands:"
        info "  padlock clamp <dir>    - Deploy to a new repository"
        info "  padlock key restore    - Restore from ignition backup"
        info "  padlock --help         - Show all commands"
        return 0
    fi
    
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
    
    # Check if this looks like a padlock repository
    if [[ ! -f "$repo_path/bin/padlock" ]]; then
        error "No padlock installation found in: $repo_path"
        info "This command repairs existing padlock repositories."
        info "Use 'padlock clamp' to set up a new repository."
        return 1
    fi
    
    # Check if locker.age exists (encrypted state)
    if [[ ! -f "$repo_path/locker.age" ]]; then
        error "No locker.age found. Repository may not be properly clamped."
        info "Expected to find encrypted locker data."
        return 1
    fi
    
    # Check what's missing and what can be repaired
    local missing_items=()
    local can_repair=false
    
    if [[ ! -f "$repo_path/locker/.padlock" ]]; then
        if [[ -d "$repo_path/locker" ]]; then
            missing_items+=(".padlock config file")
            can_repair=true
        else
            info "Repository is currently locked. Unlocking first..."
            if cd "$repo_path" && ./bin/padlock unlock; then
                can_repair=true
                missing_items+=(".padlock config file")
            else
                error "Cannot unlock repository. Repair cannot proceed."
                info "Ensure you have the correct master key or try 'padlock key restore'"
                return 1
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
            export AGE_KEY_FILE="$key_file"
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
    
    # Validate target
    if ! is_git_repo "$repo_path"; then
        fatal "Target is not a git repository: $repo_path"
    fi
    
    REPO_ROOT="$(_get_repo_root "$repo_path")"
    
    # Check if padlock is deployed
    if ! is_deployed "$REPO_ROOT"; then
        error "Padlock not deployed in this repository"
        info "Nothing to declamp"
        return 1
    fi
    
    lock "🔓 Safely declamping padlock from repository..."
    
    # Ensure repository is unlocked first
    if [[ -f "$REPO_ROOT/locker.age" ]] || [[ -d "$REPO_ROOT/.chest" ]]; then
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
        elif [[ -d "$REPO_ROOT/.chest" ]]; then
            info "Unlocking chest mode..."
            if ! (cd "$REPO_ROOT" && "$REPO_ROOT/bin/padlock" ignite --unlock); then
                fatal "Failed to unlock chest for declamp"
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
    
    # Remove other padlock files
    rm -f "$REPO_ROOT/.locker_checksum"
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
do_revoke() {
    local target="$1"
    local force="${2:-}"
    
    case "$target" in
        --local)
            _revoke_local_access "$force"
            ;;
        -K|--ignition)
            _revoke_ignition_access "$force"
            ;;
        *)
            error "Unknown revocation target: $target"
            info "Available targets:"
            info "  --local       Revoke local access (WARNING: makes content unrecoverable)"
            info "  --ignition    Revoke ignition key access"
            return 1
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
        export AGE_KEY_FILE="$new_repo_key"
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
