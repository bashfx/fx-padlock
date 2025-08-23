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
                explicit_key="$2"
                shift 2
                ;;
            -K|--ignition)
                use_ignition=true
                if [[ -n "$2" && "$2" != -* ]]; then
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
        # Generate ignition key if not provided
        if [[ -z "$ignition_key" ]]; then
            ignition_key="$(_generate_ignition_key)"
        fi
        
        _setup_crypto_with_master "$repo_key_file" "true" "$ignition_key"
        info "🔥 Ignition mode configured"
        
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
        echo "  • Run: source .locked    # Quick unlock"
        echo "  • Or:  bin/padlock unlock"
        
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
    
    if [[ -z "$AGE_RECIPIENTS" ]]; then
        error "No encryption recipients configured"
        return 1
    fi
    
    lock "🔒 Encrypting locker directory..."
    
    # Calculate file count before locking
    local file_count
    file_count=$(find locker -type f | wc -l)
    trace "📁 Files to encrypt: $file_count"
    
    # Create archive and encrypt
    if tar -czf - locker | age -r "$AGE_RECIPIENTS" > locker.age; then
        local size
        size=$(du -h locker.age | cut -f1)
        okay "✓ Locked: locker/ → locker.age ($size)"
        
    # Calculate checksum
    local checksum
    checksum=$(find locker -type f -exec md5sum {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1)

        # Create enhanced .locked script
    __print_enhanced_locked_file ".locked" "$AGE_KEY_FILE" "$checksum"
        
        # Remove plaintext locker
        rm -rf locker
        
        info "📝 Created .locked script for easy unlocking"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • git add . && git commit"
        echo "  • To unlock: source .locked"
        warn "⚠️  Secrets are now encrypted and safe to commit"
        
    else
        fatal "Failed to encrypt locker directory"
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
    
    # Check for configuration
    if [[ -z "$AGE_KEY_FILE" && -z "$AGE_RECIPIENTS" ]]; then
        error "No decryption key configured"
        info "Set AGE_KEY_FILE environment variable"
        return 1
    fi
    
    lock "🔓 Decrypting locker.age..."
    
    # Decrypt and extract
    local decrypt_cmd="age -d"
    if [[ -n "$AGE_KEY_FILE" ]]; then
        decrypt_cmd="$decrypt_cmd -i $AGE_KEY_FILE"
    fi
    
    if $decrypt_cmd < locker.age | tar -xzf -; then
        local file_count
        file_count=$(find locker -type f | wc -l)
        okay "✓ Unlocked: locker.age → locker/ ($file_count files)"
        
        # Clean up encrypted files
        rm -f locker.age .locked
        
        # Load environment if config exists
        if [[ -f "locker/.padlock" ]]; then
            # shellcheck source=/dev/null
            source locker/.padlock
            info "📝 Environment loaded - crypto config active"
        fi
        
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Edit files in locker/"
        echo "  • Commit changes when ready"
        warn "⚠️  Secrets are now in plaintext - DO NOT commit locker/"
        
    else
        fatal "Failed to decrypt locker.age"
    fi
}

# Enhanced manifest management
_add_to_manifest() {
    local repo_path="$1"
    local repo_type="${2:-standard}"
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    local now=$(date -Iseconds 2>/dev/null || date)
    
    # Create header if manifest is empty or missing
    if [[ ! -f "$manifest_file" ]] || [[ ! -s "$manifest_file" ]]; then
        cat > "$manifest_file" << 'EOF'
# Padlock Repository Manifest
# Format: namespace|name|path|type|remote|checksum|created|last_access|metadata
EOF
    fi
    
    # Extract repository information
    local namespace="local"
    local repo_name
    repo_name=$(basename "$repo_path")
    local git_remote=""
    local repo_checksum
    
    # Try to get git remote for better organization
    if git -C "$repo_path" remote get-url origin 2>/dev/null; then
        git_remote=$(git -C "$repo_path" remote get-url origin 2>/dev/null)
        if [[ "$git_remote" =~ github\.com ]]; then
            namespace="github"
        elif [[ "$git_remote" =~ gitlab\.com ]]; then
            namespace="gitlab"
        elif [[ "$git_remote" =~ bitbucket\.org ]]; then
            namespace="bitbucket"
        else
            namespace="remote"
        fi
    fi
    
    # Generate repository checksum for integrity
    repo_checksum=$(echo "$repo_path$repo_type$now" | md5sum | cut -d' ' -f1)
    
    # Check if entry already exists
    if grep -q "^[^#]*|[^|]*|$repo_path|" "$manifest_file" 2>/dev/null; then
        # Update existing entry
        local temp_file
        temp_file=$(mktemp)
        while IFS='|' read -r ns name path type remote checksum created access meta; do
            if [[ "$path" == "$repo_path" ]]; then
                echo "$namespace|$repo_name|$repo_path|$repo_type|$git_remote|$repo_checksum|$created|$now|updated=true"
            else
                echo "$ns|$name|$path|$type|$remote|$checksum|$created|$access|$meta"
            fi
        done < <(grep -v "^#" "$manifest_file") > "$temp_file"
        mv "$temp_file" "$manifest_file"
        trace "Updated manifest entry for $repo_path"
    else
        # Add new entry
        echo "$namespace|$repo_name|$repo_path|$repo_type|$git_remote|$repo_checksum|$now|$now|new=true" >> "$manifest_file"
        trace "Added manifest entry for $repo_path"
    fi
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

# Ignition unlock command
do_ignite() {
    local action="$1"
    
    case "$action" in
        --unlock|-u)
            lock "🔥 Unlocking with ignition key..."
            if ! _ignition_unlock; then
                return 1
            fi
            okay "✓ Chest unlocked with ignition key"
            info "🔓 Locker is now accessible"
            ;;
        --lock|-l)
            lock "🔥 Securing locker in chest..."
            if ! _ignition_lock; then
                return 1
            fi
            okay "✓ Locker secured in chest"
            info "🔒 Locker is now encrypted"
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
