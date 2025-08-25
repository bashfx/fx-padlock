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
    trace "Created git hooks"
    
    # Configure git integration
    __print_gitattributes "$REPO_ROOT/.gitattributes"
    __print_gitignore "$REPO_ROOT/.gitignore"
    
    # Git configuration
    git -C "$REPO_ROOT" config core.hooksPath .githooks
    git -C "$REPO_ROOT" config filter.locker-crypt.clean 'bin/age-wrapper encrypt'
    git -C "$REPO_ROOT" config filter.locker-crypt.smudge 'bin/age-wrapper decrypt'
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
    
    # Create archive and encrypt to a temporary file
    local temp_blob="locker.age.tmp"
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
                warn "Locker integrity check FAILED. Contents may differ from last lock."
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

# Enhanced manifest management
_add_to_manifest() {
    local repo_path="$1"
    local repo_type="${2:-standard}"
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    local now
    now=$(date -Iseconds 2>/dev/null || date)
    
    # Create header if empty
    if [[ ! -s "$manifest_file" ]]; then
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
        info "This key is usually generated automatically on first install."
        info "Try running 'padlock install' to generate it."
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
