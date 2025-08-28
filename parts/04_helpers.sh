################################################################################
# Helper Functions - Mid and Low-Level
################################################################################

# Temporary file cleanup system
declare -a TEMP_FILES=()

_temp_cleanup() {
    local exit_code="${1:-$?}"
    
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        trace "Cleaning up ${#TEMP_FILES[@]} temporary files..."
        for temp_file in "${TEMP_FILES[@]}"; do
            if [[ -f "$temp_file" ]]; then
                rm -f "$temp_file" 2>/dev/null || true
                trace "Removed: $temp_file"
            elif [[ -d "$temp_file" ]]; then
                rm -rf "$temp_file" 2>/dev/null || true
                trace "Removed: $temp_file/"
            fi
        done
        TEMP_FILES=()
    fi
    
    return "$exit_code"
}

_temp_register() {
    local temp_path="$1"
    TEMP_FILES+=("$temp_path")
    trace "Registered temp file: $temp_path"
    return 0
}

_temp_mktemp() {
    local temp_file
    temp_file=$(mktemp "$@")
    _temp_register "$temp_file"
    echo "$temp_file"
    return 0
}

_temp_mktemp_d() {
    local temp_dir
    temp_dir=$(mktemp -d "$@")
    _temp_register "$temp_dir"
    echo "$temp_dir"
    return 0
}

# Set up cleanup trap (should be called by functions that use temp files)
_temp_setup_trap() {
    trap '_temp_cleanup' EXIT ERR INT TERM
    return 0
}

# Portable realpath --relative-to replacement
_relative_path() {
    local target="$1"
    local base="$2"
    
    # Convert both to absolute paths
    target="$(realpath "$target")"
    base="$(realpath "$base")"
    
    # Use Python if available for proper relative path calculation
    if command -v python3 >/dev/null 2>&1; then
        python3 -c "import os; print(os.path.relpath('$target', '$base'))"
    else
        # Simple fallback - strip base from target if it's a prefix
        if [[ "$target" == "$base"/* ]]; then
            echo "${target#"$base"/}"
        else
            echo "$target"
        fi
    fi
}

# User interaction helpers
_prompt() {
    local prompt_text="$1"
    local var_name="$2"
    local default_value="${3:-}"
    
    # Check if we can interact
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        if [[ -n "$default_value" ]]; then
            printf -v "$var_name" "%s" "$default_value"
            return 0
        fi
        return 1
    fi
    
    local response
    if [[ -n "$default_value" ]]; then
        read -p "$prompt_text [$default_value]: " response
        response="${response:-$default_value}"
    else
        read -p "$prompt_text: " response
    fi
    
    printf -v "$var_name" "%s" "$response"
}

_prompt_secret() {
    local prompt_text="$1"
    local var_name="$2"
    
    # Check if we can interact
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        return 1
    fi
    
    local response
    read -s -p "$prompt_text: " response
    echo  # New line after hidden input
    printf -v "$var_name" "%s" "$response"
}

_confirm() {
    local prompt_text="$1"
    local default="${2:-n}"  # Default to 'no' if not specified
    
    # Auto-confirm if -y flag is set
    if [[ "$opt_yes" -eq 1 ]]; then
        return 0
    fi
    
    # Check if we can interact
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        if [[ "$default" == "y" ]]; then
            return 0
        else
            return 1
        fi
    fi
    
    local response
    if [[ "$default" == "y" ]]; then
        read -p "$prompt_text [Y/n]: " response
        response="${response:-y}"
    else
        read -p "$prompt_text [y/N]: " response
        response="${response:-n}"
    fi
    
    case "$response" in
        [yY]|[yY][eE][sS]) return 0 ;;
        *) return 1 ;;
    esac
}

# Guard functions (is_* pattern)
is_git_repo() {
    local target_dir="${1:-.}"
    [[ -d "$target_dir/.git" ]] || [[ -d "$target_dir/.gitsim" ]]
    return 0
}

is_deployed() {
    local repo_root="$1"
    [[ -f "$repo_root/bin/age-wrapper" ]] && [[ -f "$repo_root/.gitattributes" ]]
    return 0
}

# Safety check to prevent lock-out
_verify_unlock_capability() {
    local repo_root="${1:-$REPO_ROOT}"
    local warnings=0
    
    info "🔍 Verifying unlock capability to prevent lock-out..."
    
    # Check 1: Repository key exists
    local repo_name=$(basename "$repo_root")
    local repo_key="$PADLOCK_KEYS/${repo_name}.key"
    if [[ -f "$repo_key" ]]; then
        okay "✓ Repository key exists: $repo_key"
    else
        ((warnings++))
        warn "⚠️  No repository-specific key found"
    fi
    
    # Check 2: Global master key exists
    if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
        okay "✓ Global master key exists"
    else
        ((warnings++))
        warn "⚠️  No global master key found"
    fi
    
    # Check 3: Ignition backup exists
    local skull_backup="$PADLOCK_KEYS/skull.age"
    if [[ -f "$skull_backup" ]]; then
        okay "✓ Ignition backup available for key recovery"
    else
        ((warnings++))
        warn "⚠️  No skull key backup for emergency recovery"
    fi
    
    # Check 4: If in ignition mode, verify setup
    if [[ -f "$repo_root/.chest/ignition.key" ]] || [[ -f "$repo_root/.chest/ignition.ref" ]]; then
        okay "✓ Ignition mode configured"
        if [[ -f "$repo_root/.chest/ignition.ref" ]]; then
            local stored_ref=$(cat "$repo_root/.chest/ignition.ref" 2>/dev/null)
            local stored_pass="${stored_ref%%:*}"
            if [[ -n "$stored_pass" ]]; then
                info "  📝 Remember your ignition passphrase: starts with '${stored_pass:0:4}...'"
            fi
        fi
    fi
    
    # Check 5: Verify recipients in .padlock config
    local locker_config="$repo_root/locker/.padlock"
    if [[ -f "$locker_config" ]]; then
        local recipients=$(grep "^export AGE_RECIPIENTS=" "$locker_config" 2>/dev/null | cut -d'"' -f2)
        if [[ -n "$recipients" ]]; then
            okay "✓ Encryption recipients configured"
        else
            ((warnings++))
            warn "⚠️  No encryption recipients configured"
        fi
    fi
    
    # Final safety decision
    if [[ $warnings -eq 0 ]]; then
        okay "✅ All unlock methods verified - safe to proceed"
        return 0
    elif [[ $warnings -le 2 ]]; then
        warn "⚠️  $warnings warning(s) detected but recovery still possible"
        if _confirm "Continue despite warnings?" "n"; then
            return 0
        else
            return 1
        fi
    else
        error "❌ HIGH RISK: $warnings critical issues - you may lock yourself out!"
        error "Please ensure at least one of the following:"
        error "  1. Repository key exists in $PADLOCK_KEYS/"
        error "  2. Global master key exists"
        error "  3. Ignition backup created with 'padlock setup'"
        error "  4. Valid recipients configured"
        
        if [[ "$opt_force" -eq 1 ]]; then
            warn "⚠️  Force flag detected - proceeding despite risk"
            return 0
        else
            info "Use --force to override (NOT RECOMMENDED)"
            return 1
        fi
    fi
}

is_dev() {
    [[ "$opt_dev" -eq 1 ]] || [[ -n "${DEV_MODE:-}" ]]
    return 0
}

is_locked() {
    local repo_root="$1"
    [[ -f "$repo_root/.locked" ]]
    return 0
}

is_unlocked() {
    local repo_root="$1"
    [[ -d "$repo_root/locker" ]] && [[ -f "$repo_root/locker/.padlock" ]]
    return 0
}

# Mid-level helpers
_get_repo_root() {
    local start_dir="${1:-.}"
    local current_dir
    current_dir=$(realpath "$start_dir")

    while [[ "$current_dir" != "/" ]]; do
        if [[ -d "$current_dir/.git" ]] || [[ -d "$current_dir/.gitsim" ]]; then
            echo "$current_dir"
            return 0
        fi
        current_dir=$(dirname "$current_dir")
    done

    # Check root ('/') directory as a last resort
    if [[ -d "$current_dir/.git" ]] || [[ -d "$current_dir/.gitsim" ]]; then
        echo "$current_dir"
        return 0
    fi

    fatal "Not a git or gitsim repository"
}

_get_lock_state() {
    local repo_root="$1"
    
    # First check if padlock is deployed at all
    if ! is_deployed "$repo_root"; then
        # Check if there's a locker directory without proper deployment
        if [[ -d "$repo_root/locker" ]]; then
            echo "unclamped"
        else
            echo "not-deployed"
        fi
        return
    fi
    
    # Padlock is deployed, check actual lock state
    # Check if unlocked state exists first (locker directory present with .padlock)
    if is_unlocked "$repo_root"; then
        echo "unlocked"
    # Then check for chest mode (chest directory exists)
    elif [[ -d "$repo_root/.chest" ]]; then
        echo "locked"
    # Check for legacy locked state
    elif is_locked "$repo_root"; then
        echo "locked"
    else
        echo "unknown"
    fi
}

_load_crypto_config() {
    local config_file="$1"
    if [[ -f "$config_file" ]]; then
        source "$config_file"
        trace "Loaded crypto config from $config_file"
    else
        # Try environment variables as fallback
        if [[ -z "${AGE_RECIPIENTS:-}${AGE_PASSPHRASE:-}" ]]; then
            error "No crypto config found"
            info "Run: padlock setup"
            return 1
        fi
        trace "Using crypto config from environment"
    fi
}

_validate_age_installation() {
    if ! command -v age >/dev/null 2>&1; then
        error "age not installed"
        info "Installing age..."
        __install_age || fatal "Failed to install age"
    fi
    trace "age available: $(age --version 2>/dev/null | head -1)"
}

_append_gitattributes() {
    local repo_root="$1"
    local gitattributes="$repo_root/.gitattributes"
    
    if [[ -f "$gitattributes" ]]; then
        if ! grep -q "locker.age filter=locker-crypt" "$gitattributes"; then
            {
                echo ""
                echo "# Padlock encryption"
                echo "locker.age filter=locker-crypt"
                echo "locker.age binary"
                echo ""
                echo "# Keep tools plaintext"
                echo "bin/* -filter"
                echo ".githooks/* -filter"
            } >> "$gitattributes"
            trace "Appended to existing .gitattributes"
        else
            trace ".gitattributes already configured"
        fi
    else
        __print_gitattributes "$gitattributes"
        trace "Created new .gitattributes"
    fi
}

_append_gitignore() {
    local repo_root="$1"
    local gitignore="$repo_root/.gitignore"
    
    if [[ -f "$gitignore" ]]; then
        if ! grep -q "^locker/$" "$gitignore"; then
            {
                echo ""
                echo "# Padlock - never commit plaintext locker"
                echo "locker/"
            } >> "$gitignore"
            trace "Appended to existing .gitignore"
        else
            trace ".gitignore already configured"
        fi
    else
        __print_gitignore "$gitignore"
        trace "Created new .gitignore"
    fi
}

# Low-level literal functions
__install_age() {
    trace "Attempting to install age..."
    
    if command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update -qq && sudo apt-get install -y age
    elif command -v brew >/dev/null 2>&1; then
        brew install age
    elif command -v pacman >/dev/null 2>&1; then
        sudo pacman -S age
    elif command -v nix-env >/dev/null 2>&1; then
        nix-env -iA nixpkgs.age
    elif command -v apk >/dev/null 2>&1; then
        sudo apk add age
    else
        __install_age_binary
    fi
    
    command -v age >/dev/null 2>&1
}

__install_age_binary() {
    local os arch download_url secure_temp
    
    os="$(uname -s | tr '[:upper:]' '[:lower:]')"
    arch="$(uname -m)"
    
    case "$arch" in
        x86_64) arch="amd64" ;;
        aarch64|arm64) arch="arm64" ;;
        *) fatal "Unsupported architecture: $arch" ;;
    esac
    
    case "$os" in
        linux|darwin) ;;
        *) fatal "Unsupported OS: $os" ;;
    esac
    
    # Use latest stable version with checksum verification
    local version="v1.2.1"  # Latest stable version (security fix)
    download_url="https://github.com/FiloSottile/age/releases/download/${version}/age-${version}-${os}-${arch}.tar.gz"
    local checksum_url="https://github.com/FiloSottile/age/releases/download/${version}/age-${version}-checksums.txt"
    
    trace "Downloading: $download_url"
    trace "Checksums: $checksum_url"
    
    # Create secure temporary directory
    secure_temp=$(_temp_mktemp_d)
    trap "rm -rf '$secure_temp'" EXIT
    
    # Download binary and checksums
    if ! curl -sL "$download_url" -o "$secure_temp/age.tar.gz"; then
        fatal "Failed to download age binary"
    fi
    
    if ! curl -sL "$checksum_url" -o "$secure_temp/checksums.txt"; then
        warn "Failed to download checksums - proceeding without verification"
        warn "⚠️  This reduces security - consider manual verification"
    else
        # Verify checksum
        local expected_file="age-${version}-${os}-${arch}.tar.gz"
        local expected_checksum
        expected_checksum=$(grep "$expected_file" "$secure_temp/checksums.txt" | awk '{print $1}')
        
        if [[ -n "$expected_checksum" ]]; then
            local actual_checksum
            actual_checksum=$(sha256sum "$secure_temp/age.tar.gz" | awk '{print $1}')
            
            if [[ "$expected_checksum" == "$actual_checksum" ]]; then
                okay "✓ Checksum verification passed"
                trace "Expected: $expected_checksum"
                trace "Actual:   $actual_checksum"
            else
                error "🔒 Checksum verification FAILED"
                error "Expected: $expected_checksum"
                error "Actual:   $actual_checksum"
                fatal "Binary integrity compromised - aborting installation"
            fi
        else
            warn "Could not find checksum for $expected_file in checksums.txt"
            warn "⚠️  Proceeding without checksum verification"
        fi
    fi
    
    # Extract verified binary
    tar xz --strip-components=1 -C "$secure_temp" -f "$secure_temp/age.tar.gz"
    
    if sudo mv "$secure_temp/age" /usr/local/bin/ 2>/dev/null && sudo mv "$secure_temp/age-keygen" /usr/local/bin/ 2>/dev/null; then
        trace "Installed to /usr/local/bin/"
    else
        mkdir -p "$HOME/.local/bin"
        mv "$secure_temp/age" "$HOME/.local/bin/"
        mv "$secure_temp/age-keygen" "$HOME/.local/bin/"
        export PATH="$HOME/.local/bin:$PATH"
        trace "Installed to $HOME/.local/bin/"
    fi
}

__encrypt_stream() {
    if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
        IFS=',' read -ra recips <<< "$AGE_RECIPIENTS"
        local age_args=()
        for recip in "${recips[@]}"; do
            age_args+=("-r" "$recip")
        done
        age "${age_args[@]}"
    elif [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        AGE_PASSPHRASE="$AGE_PASSPHRASE" age -p
    else
        fatal "No encryption method configured"
    fi
}

__decrypt_stream() {
    if [[ -n "${PADLOCK_KEY_FILE:-}" && -f "$PADLOCK_KEY_FILE" ]]; then
        age -d -i "$PADLOCK_KEY_FILE"
    elif [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        AGE_PASSPHRASE="$AGE_PASSPHRASE" age -d
    else
        fatal "No decryption key available"
    fi
}

_calculate_locker_checksum() {
    local locker_dir="$1"

    if [[ ! -d "$locker_dir" ]]; then
        echo "no-locker"
        return 0
    fi

    # Create a deterministic checksum of all files in the locker
    find "$locker_dir" -type f -exec md5sum {} \; 2>/dev/null | \
        sort -k2 | \
        md5sum | \
        cut -d' ' -f1
}

# Display colored padlock logo from header comments
_logo() {
    # Extract figlet logo from script header (original lines 3-8, offset by 4 build lines = 7-12)
    sed -n '7,12s/^# *//p' "$0" 2>/dev/null | while IFS= read -r line; do
        printf "\033[36m%s\033[0m\n" "$line"
    done >&2
    
    # Add subtitle in dim text
    printf "\033[2m%s\033[0m\n" "Git Repository Security Orchestrator" >&2
    echo >&2
}

_validate_clamp_target() {
    local target_path="$1"
    if ! is_git_repo "$target_path"; then
        fatal "Target is not a git repository: $target_path"
    fi
    return 0
}

_setup_crypto_with_master() {
    local key_file="$1"
    local use_ignition="$2"
    local ignition_key="$3"

    PADLOCK_KEY_FILE="$key_file"

    if [[ "$use_ignition" == "true" ]]; then
        AGE_PASSPHRASE="$ignition_key"
    else
        # Ensure the global master key exists to be added as a recipient.
        _ensure_master_key

        # Get the public key of the repo-specific key.
        local repo_recipient
        repo_recipient=$(age-keygen -y "$key_file" 2>/dev/null)

        # Get the public key of the global master key.
        local master_recipient
        master_recipient=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null)

        # Combine them. __encrypt_stream handles comma-separated lists.
        AGE_RECIPIENTS="$repo_recipient,$master_recipient"
        trace "Repo recipient: $repo_recipient"
        trace "Master recipient: $master_recipient"
    fi

    __print_padlock_config "$LOCKER_CONFIG" "$(basename "$REPO_ROOT")"
}

# Guard function for chest mode
is_chest_repo() {
    [[ -d "$1/.chest" ]]
    return 0
}

# State-getter for chest mode
get_chest_state() {
    if is_chest_repo "$REPO_ROOT"; then
        echo "locked"
    elif [[ -d "$REPO_ROOT/locker" ]]; then
        echo "unlocked"
    else
        echo "unknown"
    fi
    return 0
}

# Wrapper for ignition lock process
_lock_chest() {
    if [[ ! -d "$REPO_ROOT/locker" ]]; then
        error "Locker directory not found, cannot lock chest."
        return 1
    fi
    info "🗃️  Securing locker in .chest..."

    # Load config from inside the locker to get recipients/passphrase
    source "$REPO_ROOT/locker/.padlock"

    # Build list of files to include in chest
    local files_to_include=("locker")
    local mapped_count=0
    
    # Check for mapped files
    if [[ -f "$REPO_ROOT/padlock.map" ]]; then
        info "📋 Including mapped files..."
        while IFS='|' read -r src_rel dest_rel; do
            # Skip comments and empty lines
            [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$src_rel" ]] && continue
            
            local src_abs="$REPO_ROOT/$src_rel"
            if [[ -e "$src_abs" ]]; then
                files_to_include+=("$src_rel")
                ((mapped_count++))
                trace "Including: $src_rel"
            else
                warn "Mapped file not found: $src_rel"
            fi
        done < "$REPO_ROOT/padlock.map"
        
        if [[ $mapped_count -gt 0 ]]; then
            info "📁 Including $mapped_count mapped items"
        fi
    fi

    # Encrypt locker and mapped files into the chest
    local chest_blob="$REPO_ROOT/.chest/locker.age"
    mkdir -p "$REPO_ROOT/.chest"
    
    # Create temporary directory for staging
    local temp_chest
    temp_chest=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_chest"' RETURN
    
    # Copy all files to staging area
    for item in "${files_to_include[@]}"; do
        local src_path="$REPO_ROOT/$item"
        local dest_path="$temp_chest/$item"
        
        if [[ -f "$src_path" ]]; then
            mkdir -p "$(dirname "$dest_path")"
            cp "$src_path" "$dest_path"
        elif [[ -d "$src_path" ]]; then
            cp -r "$src_path" "$dest_path"
        fi
    done
    
    # Create chest archive and encrypt
    if tar -czf - -C "$temp_chest" . | __encrypt_stream > "$chest_blob"; then
        # Remove plaintext files after successful encryption
        rm -rf "$REPO_ROOT/locker"
        
        # Remove mapped files if they were included (optional, could be configurable)
        if [[ $mapped_count -gt 0 ]]; then
            info "🗑️  Removing plaintext mapped files..."
            while IFS='|' read -r src_rel dest_rel; do
                [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$src_rel" ]] && continue
                
                local src_abs="$REPO_ROOT/$src_rel"
                if [[ -e "$src_abs" ]]; then
                    rm -rf "$src_abs"
                    trace "Removed: $src_rel"
                fi
            done < "$REPO_ROOT/padlock.map"
        fi
        
        okay "✓ Chest locked with $((${#files_to_include[@]})) items"
        return 0
    else
        error "Failed to encrypt chest."
        rm -f "$chest_blob"
        return 1
    fi
}

# Wrapper for ignition unlock process
_unlock_chest() {
    local encrypted_ignition_key_blob="$REPO_ROOT/.chest/ignition.age"
    local chest_blob="$REPO_ROOT/.chest/locker.age"

    if [[ ! -f "$encrypted_ignition_key_blob" || ! -f "$chest_blob" ]]; then
        error "Chest is incomplete. Cannot unlock. Missing ignition.age or locker.age."
        return 1
    fi

    if [[ -z "${PADLOCK_IGNITION_PASS:-}" ]]; then
        error "Ignition key not found in environment variable PADLOCK_IGNITION_PASS."
        return 1
    fi

    info "🗃️  Unlocking locker from .chest using ignition passphrase..."

    # 1. Decrypt the ignition key into a temporary file.
    local temp_ignition_key
    temp_ignition_key=$(_temp_mktemp)
    trap "trace 'Cleaning up temp key file...'; rm -f -- '$temp_ignition_key'" RETURN

    AGE_PASSPHRASE="${PADLOCK_IGNITION_PASS}" age -d < "$encrypted_ignition_key_blob" > "$temp_ignition_key"
    if [[ $? -ne 0 || ! -s "$temp_ignition_key" ]]; then
        fatal "Failed to decrypt ignition key. Is the passphrase correct?"
    fi
    trace "Decrypted ignition key to temporary file."

    # 2. Use the decrypted ignition key to decrypt the locker.
    export PADLOCK_KEY_FILE="$temp_ignition_key"
    export AGE_RECIPIENTS=""
    export AGE_PASSPHRASE=""

    if __decrypt_stream < "$chest_blob" | tar -xzf - -C "$REPO_ROOT"; then
        # Remove chest *after* successful decryption
        rm -rf "$REPO_ROOT/.chest"
        okay "✓ Chest unlocked. Encrypted chest removed."
        return 0
    else
        error "Failed to decrypt locker from chest using ignition key."
        rm -rf "$REPO_ROOT/locker"
        return 1
    fi
}

_generate_ignition_key() {
    # Generate a memorable, 6-part passphrase from a curated wordlist using cryptographically secure random
    local words=("flame" "rocket" "boost" "spark" "launch" "fire" "power" "thrust" "ignite" "blast" "nova" "comet" "star" "orbit" "galaxy" "nebula")
    local key=""
    for i in {1..6}; do
        # Use shuf with /dev/urandom for cryptographically secure random selection
        local word_index
        if command -v shuf >/dev/null 2>&1; then
            word_index=$(shuf -i 0-$((${#words[@]}-1)) -n 1)
        else
            # Fallback using /dev/urandom directly if shuf not available
            word_index=$(od -An -N1 -tu1 < /dev/urandom | awk -v max=${#words[@]} '{print $1 % max}')
        fi
        key+="${words[$word_index]}"
        [[ $i -lt 6 ]] && key+="-"
    done
    echo "$key"
}

_setup_ignition_system() {
    local ignition_passphrase="${1}" # The memorable phrase for sharing

    info "🔥 Setting up ignition system..."

    # 1. Generate the repository's ignition keypair
    local ignition_key_file="$REPO_ROOT/.chest/ignition.key"
    mkdir -p "$REPO_ROOT/.chest"
    age-keygen -o "$ignition_key_file" 2>/dev/null
    trace "Generated ignition keypair at $ignition_key_file"

    # 2. Get the public key of the ignition key - this will be used to encrypt the locker
    local ignition_public_key
    ignition_public_key=$(age-keygen -y "$ignition_key_file")
    trace "Ignition public key: $ignition_public_key"

    # 3. Store the passphrase and public key mapping for reference
    # This allows the unlock process to verify the correct passphrase
    echo "$ignition_passphrase:$ignition_public_key" > "$REPO_ROOT/.chest/ignition.ref"
    chmod 600 "$REPO_ROOT/.chest/ignition.ref"
    
    # 4. The ignition key itself stays in plaintext but protected by filesystem
    # The security comes from the chest being encrypted with this key's public key
    # Only someone with the passphrase can decrypt the chest and access this key
    chmod 600 "$ignition_key_file"
    
    # 5. Set up the .padlock config to use ignition key as recipient
    export AGE_RECIPIENTS="$ignition_public_key"
    export PADLOCK_KEY_FILE=""  # No key file needed, using recipient mode
    export AGE_PASSPHRASE=""     # Clear any passphrase
    __print_padlock_config "$LOCKER_CONFIG" "$(basename "$REPO_ROOT")"

    okay "✓ Ignition system configured."
    info "🔑 Your ignition passphrase: $ignition_passphrase"
    warn "⚠️  Share this passphrase for AI/automation access. Keep it safe."
    
    # The actual security: when locking, the locker will be encrypted TO the ignition public key
    # When unlocking with the passphrase, we'll use the ignition private key
}

_rotate_ignition_key() {
    local encrypted_ignition_key_blob="$REPO_ROOT/.chest/ignition.age"
    if [[ ! -f "$encrypted_ignition_key_blob" ]]; then
        error "Cannot rotate ignition key: chest is not locked or not an ignition repo."
        return 1
    fi

    # Prompt for the old passphrase
    local old_passphrase
    read -sp "Enter current ignition passphrase: " old_passphrase
    echo

    if [[ -z "$old_passphrase" ]]; then
        error "No passphrase provided. Aborting."
        return 1
    fi

    # Decrypt the key with the old passphrase
    local temp_ignition_key
    temp_ignition_key=$(_temp_mktemp)
    trap "rm -f -- '$temp_ignition_key'" RETURN

    AGE_PASSPHRASE="$old_passphrase" age -d < "$encrypted_ignition_key_blob" > "$temp_ignition_key"
    if [[ $? -ne 0 || ! -s "$temp_ignition_key" ]]; then
        fatal "Failed to decrypt ignition key. Is the passphrase correct?"
    fi

    # Generate a new passphrase
    local new_passphrase
    new_passphrase=$(_generate_ignition_key)

    # Re-encrypt the key with the new passphrase
    AGE_PASSPHRASE="$new_passphrase" age -p < "$temp_ignition_key" > "$encrypted_ignition_key_blob"
    if [[ $? -ne 0 ]]; then
        fatal "Failed to re-encrypt ignition key."
    fi

    okay "✓ Ignition key successfully rotated."
    info "🔑 Your new ignition passphrase is: $new_passphrase"
    warn "⚠️  Update any automated systems with this new passphrase."
}

_ensure_master_key() {
    if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
        info "🔑 Generating global master key..."
        mkdir -p "$(dirname "$PADLOCK_GLOBAL_KEY")"
        age-keygen -o "$PADLOCK_GLOBAL_KEY" >/dev/null
        chmod 600 "$PADLOCK_GLOBAL_KEY"
        okay "✓ Global master key created at: $PADLOCK_GLOBAL_KEY"
        
        # Create passphrase-encrypted skull backup
        _create_skull_backup
        
        warn "⚠️  This key is your ultimate backup. Keep it safe."
    else
        trace "Global master key already exists."
    fi
}

_create_skull_backup() {
    local skull_backup="$PADLOCK_KEYS/skull.age"
    
    # Skip if skull backup already exists
    if [[ -f "$skull_backup" ]]; then
        trace "Ignition backup already exists."
        return 0
    fi
    
    # Skip if not in interactive terminal (automated testing/CI)
    if [[ ! -t 0 ]] || [[ ! -t 1 ]]; then
        trace "Non-interactive environment detected, skipping skull backup creation."
        warn "⚠️  Ignition backup not created (non-interactive environment)"
        info "💡 Run 'padlock setup' interactively to create skull backup"
        return 0
    fi
    
    info "💀 Creating skull key backup system..."
    echo "Enter a memorable passphrase to encrypt your master key backup:"
    echo "(This allows recovery if your master key file is lost)"
    
    local passphrase
    local passphrase_confirm
    
    while true; do
        read -s -p "Passphrase: " passphrase
        echo
        read -s -p "Confirm passphrase: " passphrase_confirm
        echo
        
        if [[ "$passphrase" == "$passphrase_confirm" ]]; then
            if [[ ${#passphrase} -lt 8 ]]; then
                warn "Passphrase must be at least 8 characters. Please try again."
                continue
            fi
            break
        else
            warn "Passphrases don't match. Please try again."
        fi
    done
    
    # Encrypt the master key with the passphrase
    if AGE_PASSPHRASE="$passphrase" age -p < "$PADLOCK_GLOBAL_KEY" > "$skull_backup"; then
        chmod 600 "$skull_backup"
        okay "✓ Skull key backup created: $skull_backup"
        info "💡 To restore master key: padlock key restore"
    else
        error "Failed to create skull backup"
        rm -f "$skull_backup"
        return 1
    fi
    
    # Clear passphrase from memory
    unset passphrase passphrase_confirm
}

_restore_master_key() {
    local skull_backup="$PADLOCK_KEYS/skull.age"
    
    if [[ ! -f "$ignition_backup" ]]; then
        error "No skull backup found at: $skull_backup"
        info "The skull backup is created automatically during initial setup."
        return 1
    fi
    
    if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
        warn "Master key already exists at: $PADLOCK_GLOBAL_KEY"
        echo "This will overwrite the existing master key."
        read -p "Continue? [y/N]: " confirm
        if [[ ! "$confirm" =~ ^[yY]$ ]]; then
            info "Restore cancelled."
            return 1
        fi
    fi
    
    info "💀 Restoring master key from skull backup..."
    echo "Enter the passphrase used during setup:"
    
    local passphrase
    read -s -p "Passphrase: " passphrase
    echo
    
    # Try to decrypt the skull backup
    local temp_key
    temp_key=$(_temp_mktemp)
    trap "rm -f '$temp_key'" EXIT
    
    if AGE_PASSPHRASE="$passphrase" age -d < "$skull_backup" > "$temp_key" 2>/dev/null; then
        # Verify it's a valid age key
        if age-keygen -y "$temp_key" >/dev/null 2>&1; then
            mkdir -p "$(dirname "$PADLOCK_GLOBAL_KEY")"
            mv "$temp_key" "$PADLOCK_GLOBAL_KEY"
            chmod 600 "$PADLOCK_GLOBAL_KEY"
            okay "✓ Master key restored successfully"
            info "Your padlock repositories should now be accessible."
        else
            error "Restored file is not a valid age key"
            rm -f "$temp_key"
            return 1
        fi
    else
        error "Failed to decrypt skull backup"
        info "Please check your passphrase and try again."
        rm -f "$temp_key"
        return 1
    fi
    
    # Clear passphrase from memory
    unset passphrase
}

__print_padlock_config() {
    local file="$1"
    local repo_name="$2"

    cat > "$file" << EOF
#!/bin/bash
# Padlock configuration for $repo_name
# This file is only present when locker is unlocked

export AGE_RECIPIENTS='${AGE_RECIPIENTS:-}'
export PADLOCK_KEY_FILE='${PADLOCK_KEY_FILE:-}'
export AGE_PASSPHRASE='${AGE_PASSPHRASE:-}'
export PADLOCK_REPO='$REPO_ROOT'

# Project-specific settings
export PROJECT_NAME='$repo_name'
EOF
}

################################################################################
# Age TTY Subversion Functions - Core Ignition Implementation
################################################################################

_age_interactive_encrypt() {
    local input_file="$1"
    local output_file="$2" 
    local passphrase="$3"
    
    trace "Age TTY subversion: encrypting with passphrase (secure)"
    
    # Create named pipe for secure passphrase passing - prevents command injection
    local pipe_path="$(_temp_mktemp).pipe"
    mkfifo "$pipe_path" || {
        error "Failed to create named pipe for secure passphrase passing"
        return 1
    }
    
    # Register pipe for cleanup
    _temp_register "$pipe_path"
    
    # Execute TTY subversion with secure pipe
    {
        # Background process: write passphrase to pipe
        printf '%s\n%s\n' "$passphrase" "$passphrase" > "$pipe_path" &
        local writer_pid=$!
        
        # Foreground: TTY subversion with pipe input - no shell interpolation of passphrase
        script -qec "cat '$pipe_path' | age -p -o '$output_file' '$input_file'" /dev/null 2>/dev/null
        local exit_code=$?
        
        # Wait for writer completion
        wait $writer_pid 2>/dev/null || true
        
        if [[ $exit_code -eq 0 ]]; then
            trace "Age TTY subversion successful (secure)"
        else
            error "Age TTY subversion failed (secure method)"
        fi
        
        return $exit_code
    }
    
    return 0  # BashFX 3.0 compliance
}

_age_interactive_decrypt() {
    local input_file="$1"
    local passphrase="$2"
    
    trace "Age TTY subversion: decrypting with passphrase (secure)"
    
    # Create named pipe for secure passphrase passing - prevents command injection
    local pipe_path="$(_temp_mktemp).pipe"
    mkfifo "$pipe_path" || {
        error "Failed to create named pipe for secure passphrase passing"
        return 1
    }
    
    # Register pipe for cleanup
    _temp_register "$pipe_path"
    
    # Execute TTY subversion with secure pipe
    {
        # Background process: write passphrase to pipe
        printf '%s\n' "$passphrase" > "$pipe_path" &
        local writer_pid=$!
        
        # Foreground: TTY subversion with pipe input - no shell interpolation of passphrase
        script -qec "cat '$pipe_path' | age -d '$input_file'" /dev/null 2>/dev/null
        local exit_code=$?
        
        # Wait for writer completion
        wait $writer_pid 2>/dev/null || true
        
        if [[ $exit_code -eq 0 ]]; then
            trace "Age TTY subversion decrypt successful (secure)"
        else
            trace "Age TTY subversion decrypt failed (wrong passphrase?) - secure method"
        fi
        
        return $exit_code
    }
    
    return 0  # BashFX 3.0 compliance
}

_derive_ignition_key() {
    local passphrase="$1"
    local salt="${2:-padlock-ignition}"
    
    # Generate deterministic hash
    local key_hash
    key_hash=$(echo "${salt}:${passphrase}" | sha256sum | cut -d' ' -f1)
    local cache_file="$PADLOCK_DIR/ignition/.derived/${key_hash}.key"
    
    # Create cache directory
    mkdir -p "$(dirname "$cache_file")"
    
    # Generate or retrieve cached key
    if [[ ! -f "$cache_file" ]]; then
        age-keygen > "$cache_file" 2>/dev/null
        trace "Generated new derived key: $cache_file"
    else
        trace "Using cached derived key: $cache_file"
    fi
    
    # Return public key
    age-keygen -y < "$cache_file" 2>/dev/null
    
    return 0  # BashFX 3.0 compliance
}

_create_ignition_metadata() {
    local name="$1"
    local type="$2"
    
    cat <<EOF
{
    "type": "$type",
    "name": "$name",
    "created": "$(date -Iseconds)",
    "authority": "repo-master",
    "approach": "age-native-tty-subversion"
}
EOF
    
    return 0  # BashFX 3.0 compliance
}

_validate_ignition_authority() {
    local key_file="$1"
    local master_private="$(_get_master_private_key)"
    
    # Try to decrypt with master key
    if age -d -i "$master_private" < "$key_file" >/dev/null 2>&1; then
        trace "Ignition key authority validation passed"
        return 0
    else
        error "Key file not encrypted with master authority: $key_file"
        return 1
    fi
}

_cache_derived_key() {
    local passphrase="$1"
    local name="$2"
    
    # Cache the derived key for performance
    local derived_key
    derived_key=$(_derive_ignition_key "$passphrase")
    trace "Cached derived key for ignition: $name"
    echo "$derived_key"
    
    return 0  # BashFX 3.0 compliance
}

################################################################################
# Ignition System Helper Functions
################################################################################

_get_master_private_key() {
    echo "${PADLOCK_GLOBAL_KEY:-$HOME/.local/etc/padlock/keys/global.key}"
    return 0
}

_get_master_public_key() {
    local master_private="$(_get_master_private_key)"
    if [[ -f "$master_private" ]]; then
        age-keygen -y "$master_private" 2>/dev/null
        return 0
    else
        error "Master private key not found: $master_private"
        return 1
    fi
    
    return 0  # BashFX 3.0 compliance (default case)
}

################################################################################
# Ignition Key Creation Functions - Core Implementation
################################################################################

_create_ignition_master_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Creating ignition master key with TTY magic: $name"
    
    # Setup temp file cleanup
    _temp_setup_trap
    
    # Create directory structure
    mkdir -p "$PADLOCK_DIR/ignition/keys"
    mkdir -p "$PADLOCK_DIR/ignition/metadata"
    mkdir -p "$PADLOCK_DIR/ignition/.derived"
    
    # Generate base age key  
    local temp_key="$(_temp_mktemp)"
    age-keygen > "$temp_key"
    
    # Create JSON metadata bundle
    local metadata
    metadata=$(_create_ignition_metadata "$name" "ignition-master")
    
    # Create key bundle (metadata + private key)
    local key_bundle="$(_temp_mktemp)"
    {
        echo "PADLOCK_IGNITION_KEY"
        echo "$metadata" | base64 -w0
        echo "---"
        cat "$temp_key"
    } > "$key_bundle"
    
    # TTY magic: encrypt bundle with passphrase
    local passphrase_encrypted="$(_temp_mktemp)"
    if _age_interactive_encrypt "$key_bundle" "$passphrase_encrypted" "$passphrase"; then
        # Double-encrypt with master key authority
        local master_pubkey
        master_pubkey=$(_get_master_public_key)
        age -r "$master_pubkey" < "$passphrase_encrypted" > "$PADLOCK_DIR/ignition/keys/$name.ikey"
        
        # Store metadata separately for queries
        echo "$metadata" > "$PADLOCK_DIR/ignition/metadata/$name.json"
        
        okay "Ignition master key created with TTY magic: $name"
        return 0
    else
        error "Failed to create ignition master key: $name"
        return 1
    fi
}

_create_ignition_distro_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Creating ignition distributed key with TTY magic: $name"
    
    # Setup temp file cleanup
    _temp_setup_trap
    
    # Generate base age key  
    local temp_key="$(_temp_mktemp)"
    age-keygen > "$temp_key"
    
    # Create JSON metadata bundle
    local metadata
    metadata=$(_create_ignition_metadata "$name" "ignition-distributed")
    
    # Create key bundle (metadata + private key)
    local key_bundle="$(_temp_mktemp)"
    {
        echo "PADLOCK_IGNITION_DISTRO"
        echo "$metadata" | base64 -w0
        echo "---"
        cat "$temp_key"
    } > "$key_bundle"
    
    # TTY magic: encrypt bundle with passphrase
    local passphrase_encrypted="$(_temp_mktemp)"
    if _age_interactive_encrypt "$key_bundle" "$passphrase_encrypted" "$passphrase"; then
        # Double-encrypt with master key authority
        local master_pubkey
        master_pubkey=$(_get_master_public_key)
        age -r "$master_pubkey" < "$passphrase_encrypted" > "$PADLOCK_DIR/ignition/keys/$name.dkey"
        
        # Store metadata separately for queries
        echo "$metadata" > "$PADLOCK_DIR/ignition/metadata/$name.json"
        
        okay "Ignition distributed key created with TTY magic: $name"
        return 0
    else
        error "Failed to create ignition distributed key: $name"
        return 1
    fi
}

_unlock_ignition_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "Unlocking ignition key with TTY magic: $name"
    
    # Setup temp file cleanup
    _temp_setup_trap
    
    # Find key file (master or distro)
    local key_file=""
    if [[ -f "$PADLOCK_DIR/ignition/keys/$name.ikey" ]]; then
        key_file="$PADLOCK_DIR/ignition/keys/$name.ikey"
    elif [[ -f "$PADLOCK_DIR/ignition/keys/$name.dkey" ]]; then
        key_file="$PADLOCK_DIR/ignition/keys/$name.dkey"
    else
        error "No ignition key found: $name"
        return 1
    fi
    
    # Validate master key authority first
    if ! _validate_ignition_authority "$key_file"; then
        return 1
    fi
    
    # Decrypt with master key first  
    local temp_bundle="$(_temp_mktemp)"
    local master_private="$(_get_master_private_key)"
    
    if ! age -d -i "$master_private" < "$key_file" > "$temp_bundle"; then
        error "Cannot decrypt ignition key (master key access denied)"
        return 1
    fi
    
    # Use TTY subversion to decrypt with passphrase
    local decrypted_bundle="$(_temp_mktemp)"
    if _age_interactive_decrypt "$temp_bundle" "$passphrase" > "$decrypted_bundle"; then
        # Extract private key from decrypted bundle
        local private_key
        private_key=$(sed -n '4,$p' "$decrypted_bundle")
        
        # Export for repository access
        export PADLOCK_IGNITION_KEY="$private_key"
        
        okay "Ignition key unlocked with TTY magic: $name"
        return 0
    else
        error "Incorrect passphrase for ignition key: $name"
        return 1
    fi
}

################################################################################
# Ignition System Utility Functions
################################################################################

_list_ignition_keys() {
    echo "Available ignition keys:"
    if [[ -d "$PADLOCK_DIR/ignition/keys" ]]; then
        local found=0
        for key_file in "$PADLOCK_DIR/ignition/keys"/*.{ikey,dkey}; do
            if [[ -f "$key_file" ]]; then
                local basename_file
                basename_file=$(basename "$key_file")
                local name="${basename_file%.*}"
                local type="${basename_file##*.}"
                case "$type" in
                    ikey) echo "  $name (ignition master)" ;;
                    dkey) echo "  $name (distributed)" ;;
                esac
                found=1
            fi
        done
        if [[ $found -eq 0 ]]; then
            info "No ignition keys found"
        fi
    else
        info "No ignition keys directory found"
    fi
    
    return 0
}

_show_ignition_status() {
    local name="$1"
    
    if [[ -n "$name" ]]; then
        # Show specific key status
        local metadata_file="$PADLOCK_DIR/ignition/metadata/$name.json"
        if [[ -f "$metadata_file" ]]; then
            echo "Ignition key status: $name"
            if command -v jq >/dev/null 2>&1; then
                jq -r '. | "Type: \(.type)\nCreated: \(.created)\nAuthority: \(.authority)"' < "$metadata_file"
            else
                # Fallback without jq
                echo "Metadata file: $metadata_file"
                cat "$metadata_file"
            fi
        else
            error "No metadata found for ignition key: $name"
            return 1
        fi
    else
        # Show general ignition system status
        echo "Ignition system status:"
        echo "Keys directory: $PADLOCK_DIR/ignition/keys"
        echo "Available keys:"
        _list_ignition_keys
    fi
    
    return 0
}

_add_ignition_authority() {
    local pubkey="$1"
    
    # Implementation for allowing additional public keys
    # This would extend the authority system beyond just master key
    warn "Ignition authority extension not yet implemented"
    info "Currently only master key authority is supported"
    
    return 0
}

help_ignite() {
    echo "Ignition Key Operations (I & D keys):"
    echo "  create [name]           Create ignition master key (I)"
    echo "  new --name=NAME         Create distributed key (D)"  
    echo "  unlock [name]           Unlock with passphrase"
    echo "  allow <pubkey>          Allow public key access"
    echo "  list                    Show available ignition keys"
    echo "  status [name]           Show key metadata"
    echo ""
    echo "Environment: PADLOCK_IGNITION_PASS for automated unlock"
    echo "For detailed help: padlock help more"
    
    return 0
}