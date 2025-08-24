################################################################################
# Helper Functions - Mid and Low-Level
################################################################################

# Guard functions (is_* pattern)
is_git_repo() {
    local target_dir="${1:-.}"
    [[ -d "$target_dir/.git" ]] || [[ -d "$target_dir/.gitsim" ]]
}

is_deployed() {
    local repo_root="$1"
    [[ -f "$repo_root/bin/age-wrapper" ]] && [[ -f "$repo_root/.gitattributes" ]]
}

is_dev() {
    [[ "$opt_dev" -eq 1 ]] || [[ -n "${DEV_MODE:-}" ]]
}

is_locked() {
    local repo_root="$1"
    [[ -f "$repo_root/.locked" ]]
}

is_unlocked() {
    local repo_root="$1"
    [[ -d "$repo_root/locker" ]] && [[ -f "$repo_root/locker/.padlock" ]]
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
    # Prioritize chest state if it exists, as it's the more modern format.
    if [[ -d "$repo_root/.chest" ]]; then
        echo "locked"
    elif is_locked "$repo_root"; then # Standard lock file
        echo "locked"
    elif is_unlocked "$repo_root"; then
        echo "unlocked"
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
    local os arch download_url
    
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
    
    download_url="https://github.com/FiloSottile/age/releases/latest/download/age-v1.1.1-${os}-${arch}.tar.gz"
    trace "Downloading: $download_url"
    
    curl -sL "$download_url" | tar xz --strip-components=1 -C /tmp
    
    if sudo mv /tmp/age /usr/local/bin/ 2>/dev/null && sudo mv /tmp/age-keygen /usr/local/bin/ 2>/dev/null; then
        trace "Installed to /usr/local/bin/"
    else
        mkdir -p "$HOME/.local/bin"
        mv /tmp/age "$HOME/.local/bin/"
        mv /tmp/age-keygen "$HOME/.local/bin/"
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
    if [[ -n "${AGE_KEY_FILE:-}" && -f "$AGE_KEY_FILE" ]]; then
        age -d -i "$AGE_KEY_FILE"
    elif [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        AGE_PASSPHRASE="$AGE_PASSPHRASE" age -d
    else
        fatal "No decryption key available"
    fi
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

    AGE_KEY_FILE="$key_file"

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

    # Encrypt locker directly into the chest
    local chest_blob="$REPO_ROOT/.chest/locker.age"
    mkdir -p "$REPO_ROOT/.chest"
    if tar -czf - -C "$REPO_ROOT" locker | __encrypt_stream > "$chest_blob"; then
        # Remove plaintext locker *after* success
        rm -rf "$REPO_ROOT/locker"
        okay "✓ Chest locked. Plaintext locker removed."
        return 0
    else
        error "Failed to encrypt locker into chest."
        # Cleanup failed attempt
        rm -f "$chest_blob"
        return 1
    fi
}

# Wrapper for ignition unlock process
_unlock_chest() {
    local chest_blob="$REPO_ROOT/.chest/locker.age"
    if [[ ! -f "$chest_blob" ]]; then
        error "Chest blob not found, cannot unlock."
        return 1
    fi
    info "🗃️  Unlocking locker from .chest..."

    # We need the passphrase from the environment for ignition
    if [[ -z "${PADLOCK_IGNITION_PASS:-}" ]]; then
        error "Ignition key not found in environment variable PADLOCK_IGNITION_PASS."
        return 1
    fi
    export AGE_PASSPHRASE="$PADLOCK_IGNITION_PASS"

    # Decrypt from chest into locker
    if __decrypt_stream < "$chest_blob" | tar -xzf - -C "$REPO_ROOT"; then
        # Remove chest *after* success
        rm -rf "$REPO_ROOT/.chest"
        okay "✓ Chest unlocked. Encrypted chest removed."
        return 0
    else
        error "Failed to decrypt locker from chest."
        # Cleanup failed attempt (remove partially extracted locker dir)
        rm -rf "$REPO_ROOT/locker"
        return 1
    fi
}

_generate_ignition_key() {
    # Not implemented
    echo "flame-rocket-boost-spark"
}

_ensure_master_key() {
    if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
        info "🔑 Generating global master key..."
        mkdir -p "$(dirname "$PADLOCK_GLOBAL_KEY")"
        age-keygen -o "$PADLOCK_GLOBAL_KEY" >/dev/null
        chmod 600 "$PADLOCK_GLOBAL_KEY"
        okay "✓ Global master key created at: $PADLOCK_GLOBAL_KEY"
        warn "⚠️  This key is your ultimate backup. Keep it safe."
    else
        trace "Global master key already exists."
    fi
}

__print_padlock_config() {
    local file="$1"
    local repo_name="$2"

    cat > "$file" << EOF
#!/bin/bash
# Padlock configuration for $repo_name
# This file is only present when locker is unlocked

export AGE_RECIPIENTS='${AGE_RECIPIENTS:-}'
export AGE_KEY_FILE='${AGE_KEY_FILE:-}'
export AGE_PASSPHRASE='${AGE_PASSPHRASE:-}'
export PADLOCK_REPO='$REPO_ROOT'

# Project-specific settings
export PROJECT_NAME='$repo_name'
EOF
}