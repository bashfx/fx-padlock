################################################################################
# API Functions - High-Level Dispatchable (do_* pattern)
################################################################################

do_clamp() {
    local target_path="${1:-.}"
    local use_global_key=false
    local generate_key=false
    local explicit_key=""
    
    # Parse arguments
    shift
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --global-key) use_global_key=true; shift ;;
            --generate) generate_key=true; shift ;;
            --key) explicit_key="$2"; shift 2 ;;
            *) error "Unknown option: $1"; return 1 ;;
        esac
    done
    
    target_path="$(realpath "$target_path")"
    info "Deploying padlock to: $target_path"
    
    # Validate target
    if ! is_git_repo "$target_path"; then
        fatal "Target is not a git repository: $target_path"
    fi
    
    REPO_ROOT="$(_get_repo_root "$target_path")"
    LOCKER_DIR="$REPO_ROOT/locker"
    LOCKER_BLOB="$REPO_ROOT/locker.age"
    LOCKER_CONFIG="$LOCKER_DIR/.padlock"
    
    # Check if already deployed
    if is_deployed "$REPO_ROOT"; then
        warn "Padlock already deployed to this repository"
        info "Use 'padlock update' to refresh files"
        return 0
    fi
    
    lock "🔧 Setting up padlock structure..."
    
    # Ensure age is available
    _validate_age_installation
    
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
    
    # Update git configuration files
    _append_gitattributes "$REPO_ROOT"
    _append_gitignore "$REPO_ROOT"
    
    # Configure git
    git -C "$REPO_ROOT" config filter.locker-crypt.clean "$REPO_ROOT/bin/age-wrapper clean"
    git -C "$REPO_ROOT" config filter.locker-crypt.smudge "$REPO_ROOT/bin/age-wrapper smudge"
    git -C "$REPO_ROOT" config filter.locker-crypt.required true
    git -C "$REPO_ROOT" config core.hooksPath .githooks
    trace "Configured git filters and hooks"
    
    # Handle key setup
    if [[ -n "$explicit_key" ]]; then
        AGE_RECIPIENTS="$explicit_key"
        info "Using explicit key: $explicit_key"
    elif [[ "$use_global_key" == true ]]; then
        if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
            AGE_RECIPIENTS="$(cat "$PADLOCK_GLOBAL_KEY")"
            info "Using global key"
        else
            warn "No global key found, generating new one"
            generate_key=true
        fi
    elif [[ "$generate_key" == true ]]; then
        info "Generating new keypair for repository"
    else
        # Default behavior - try global key, fallback to generate
        if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
            AGE_RECIPIENTS="$(cat "$PADLOCK_GLOBAL_KEY")"
            info "Using existing global key"
        else
            generate_key=true
        fi
    fi
    
    # Generate keypair if needed
    if [[ "$generate_key" == true ]]; then
        local key_file="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
        age-keygen -o "$key_file"
        
        AGE_RECIPIENTS=$(grep "public key:" "$key_file" | awk '{print $4}')
        AGE_KEY_FILE="$key_file"
        
        okay "Generated keypair: $key_file"
        info "Public key: $AGE_RECIPIENTS"
        
        # Store as global if requested
        if [[ "$use_global_key" == true ]]; then
            echo "$AGE_RECIPIENTS" > "$PADLOCK_GLOBAL_KEY"
            okay "Saved as global key"
        fi
    fi
    
    # Create locker structure and starter files
    mkdir -p "$LOCKER_DIR"
    __print_starter_files "$LOCKER_DIR"
    __print_padlock_config "$LOCKER_CONFIG" "$(basename "$REPO_ROOT")"
    
    # Create SECURITY.md
    __print_security_md "$REPO_ROOT/SECURITY.md"
    
    # Update manifest
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    touch "$manifest_file"
    if ! grep -q -F -x "$REPO_ROOT" "$manifest_file"; then
        echo "$REPO_ROOT" >> "$manifest_file"
        trace "Added $REPO_ROOT to manifest"
    fi

    okay "Padlock deployment complete!"
    info "Add sensitive files to locker/ directory"
    info "Run 'bin/padlock status' to check state"
}

do_setup() {
    REPO_ROOT="$(_get_repo_root)"
    LOCKER_DIR="$REPO_ROOT/locker"
    LOCKER_BLOB="$REPO_ROOT/locker.age"
    LOCKER_CONFIG="$LOCKER_DIR/.padlock"
    
    if [[ ! -f "$REPO_ROOT/bin/age-wrapper" ]]; then
        fatal "Padlock not deployed. Run 'padlock clamp' first"
    fi
    
    lock "🔧 Setting up padlock encryption..."
    
    _validate_age_installation
    
    # Use existing config if available
    if [[ -f "$LOCKER_CONFIG" ]]; then
        _load_crypto_config "$LOCKER_CONFIG"
        okay "Using existing configuration"
        return 0
    fi
    
    # Generate keypair if no crypto provided
    if [[ -z "${AGE_RECIPIENTS:-}${AGE_PASSPHRASE:-}" ]]; then
        info "Generating new encryption keypair..."
        local key_file="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
        mkdir -p "$(dirname "$key_file")"
        age-keygen -o "$key_file"
        
        AGE_RECIPIENTS=$(grep "public key:" "$key_file" | awk '{print $4}')
        AGE_KEY_FILE="$key_file"
        
        okay "Generated keypair: $key_file"
        info "Public key: $AGE_RECIPIENTS"
    fi
    
    # Create locker structure if needed
    if [[ ! -d "$LOCKER_DIR" ]]; then
        mkdir -p "$LOCKER_DIR"
        __print_starter_files "$LOCKER_DIR"
    fi
    
    # Create .padlock config
    __print_padlock_config "$LOCKER_CONFIG" "$(basename "$REPO_ROOT")"
    
    okay "Padlock encryption configured!"
    info "Edit files in locker/ then commit normally"
}

do_lock() {
    REPO_ROOT="$(_get_repo_root)"
    LOCKER_DIR="$REPO_ROOT/locker"
    LOCKER_BLOB="$REPO_ROOT/locker.age"
    LOCKER_CONFIG="$LOCKER_DIR/.padlock"
    
    if [[ ! -d "$LOCKER_DIR" ]]; then
        error "No locker directory found"
        return 1
    fi
    
    if [[ ! -f "$LOCKER_CONFIG" ]]; then
        error "No .padlock config found. Run 'padlock setup' first"
        return 1
    fi
    
    lock "🔐 Locking locker..."
    
    # Load crypto config
    _load_crypto_config "$LOCKER_CONFIG"
    
    # Encrypt locker to locker.age
    tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        -C "$REPO_ROOT" -czf - "locker" | __encrypt_stream > "$LOCKER_BLOB"
    
    # Create .locked file with unlock instructions
    __print_locked_file "$REPO_ROOT/.locked"
    
    # Remove plaintext locker
    rm -rf "$LOCKER_DIR"
    
    local size
    size=$(du -h "$LOCKER_BLOB" | cut -f1)
    okay "Locker locked → locker.age ($size)"
    info "Created .locked file for unlocking"
    info "Run 'source .locked' to unlock"
}

do_unlock() {
    REPO_ROOT="$(_get_repo_root)"
    LOCKER_DIR="$REPO_ROOT/locker"
    LOCKER_BLOB="$REPO_ROOT/locker.age"
    LOCKER_CONFIG="$LOCKER_DIR/.padlock"
    
    if [[ ! -f "$LOCKER_BLOB" ]]; then
        error "No locker.age found"
        return 1
    fi
    
    lock "🔓 Unlocking locker..."
    
    # Decrypt locker.age to locker/
    __decrypt_stream < "$LOCKER_BLOB" | tar -C "$REPO_ROOT" -xzf -
    
    if [[ -d "$LOCKER_DIR" ]] && [[ -f "$LOCKER_CONFIG" ]]; then
        # Remove .locked file and locker.age since we're now unlocked
        rm -f "$REPO_ROOT/.locked"
        rm -f "$LOCKER_BLOB"
        
        local file_count
        file_count=$(find "$LOCKER_DIR" -type f 2>/dev/null | wc -l)
        okay "Locker unlocked ($file_count files)"
        info "Removed .locked and locker.age"
    else
        error "Failed to unlock locker"
        return 1
    fi
}

do_status() {
    REPO_ROOT="$(_get_repo_root)"
    LOCKER_DIR="$REPO_ROOT/locker"
    LOCKER_BLOB="$REPO_ROOT/locker.age"
    
    printf "%s=== Padlock Status ===%s\n" "$blue" "$xx"
    printf "Repository: %s\n" "$(basename "$REPO_ROOT")"
    printf "Deployed: %s\n" "$(is_deployed "$REPO_ROOT" && echo "✓ Yes" || echo "✗ No")"
    
    local state
    state="$(_get_lock_state "$REPO_ROOT")"
    case "$state" in
        "locked")
            printf "State: %s🔒 LOCKED%s\n" "$red" "$xx"
            printf "Unlock: %ssource .locked%s\n" "$cyan" "$xx"
            ;;
        "unlocked") 
            printf "State: %s🔓 UNLOCKED%s\n" "$green" "$xx"
            if [[ -d "$LOCKER_DIR" ]]; then
                local file_count dir_count
                file_count=$(find "$LOCKER_DIR" -type f 2>/dev/null | wc -l)
                dir_count=$(find "$LOCKER_DIR" -type d 2>/dev/null | tail -n +2 | wc -l)
                printf "Locker: %d files in %d directories\n" "$file_count" "$dir_count"
            fi
            ;;
        *)
            printf "State: %s❓ UNKNOWN%s\n" "$yellow" "$xx"
            printf "Run: %spadlock setup%s\n" "$cyan" "$xx"
            ;;
    esac
    
    if [[ -f "$LOCKER_BLOB" ]]; then
        local size
        size=$(du -h "$LOCKER_BLOB" | cut -f1)
        printf "Encrypted: locker.age (%s)\n" "$size"
    fi
}

do_key() {
    local action="$1"
    shift
    
    case "$action" in
        --set-global)
            local key="$1"
            if [[ -z "$key" ]]; then
                fatal "Key required for --set-global"
            fi
            mkdir -p "$PADLOCK_KEYS"
            echo "$key" > "$PADLOCK_GLOBAL_KEY"
            okay "Global key saved"
            ;;
        --show-global)
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                cat "$PADLOCK_GLOBAL_KEY"
            else
                error "No global key found"
                return 1
            fi
            ;;
        --generate-global)
            mkdir -p "$PADLOCK_KEYS"
            local temp_key="/tmp/padlock-global-$.key"
            age-keygen -o "$temp_key"
            
            local public_key
            public_key=$(grep "public key:" "$temp_key" | awk '{print $4}')
            echo "$public_key" > "$PADLOCK_GLOBAL_KEY"
            
            mv "$temp_key" "$PADLOCK_KEYS/global.key"
            okay "Generated global key: $public_key"
            ;;
        *)
            error "Unknown key action: $action"
            info "Available: --set-global, --show-global, --generate-global"
            return 1
            ;;
    esac
}

do_install() {
    lock "Installing padlock for global use..."

    local install_dir="$XDG_LIB_HOME/fx/padlock"
    local bin_dir="$XDG_BIN_HOME/fx"
    local link_path="$bin_dir/padlock"

    mkdir -p "$install_dir"
    mkdir -p "$bin_dir"

    cp "$SCRIPT_PATH" "$install_dir/padlock.sh"
    chmod +x "$install_dir/padlock.sh"
    trace "Copied script to $install_dir"

    ln -sf "$install_dir/padlock.sh" "$link_path"
    trace "Created symlink at $link_path"

    okay "Padlock installed successfully!"

    # Check if the install directory is in the user's PATH
    if ! [[ ":$PATH:" == *":$bin_dir:"* ]]; then
        warn "The directory '$bin_dir' is not in your PATH."
        info "Please add it to your shell's startup file (e.g., .bashrc, .zshrc):"
        info "  export PATH=\"\$PATH:$bin_dir\""
    fi
}

do_uninstall() {
    local purge_all=false
    if [[ "${1:-}" == "--purge-all-data" ]]; then
        purge_all=true
    fi

    lock "Uninstalling padlock..."

    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" && -s "$manifest_file" ]]; then
        if [[ "$purge_all" == true && "$opt_dev" -eq 1 ]]; then
            warn "Purging all padlock data, including manifest and keys..."
            rm -rf "$PADLOCK_ETC"
            okay "All padlock data has been purged."
        else
            error "Padlock is still managing the following repositories:"
            cat "$manifest_file"
            info "Please manually remove padlock from these repositories before uninstalling."
            info "To override this safety check and purge all keys and data, run with -D and --purge-all-data."
            return 1
        fi
    fi

    local install_dir="$XDG_LIB_HOME/fx/padlock"
    local link_path="$XDG_BIN_HOME/fx/padlock"

    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        okay "Removed symlink: $link_path"
    fi

    if [[ -d "$install_dir" ]]; then
        rm -rf "$install_dir"
        okay "Removed installation directory: $install_dir"
    fi

    if [[ "$purge_all" == false ]]; then
        info "Keys and manifest file have been preserved in $PADLOCK_ETC"
    fi

    okay "Padlock uninstalled successfully."
}