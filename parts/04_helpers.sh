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
    local target_dir="${1:-.}"
    if [[ -d "$target_dir/.git" ]] || [[ -d "$target_dir/.gitsim" ]]; then
        realpath "$target_dir"
    else
        fatal "Not a git repository: $target_dir"
    fi
}

_get_lock_state() {
    local repo_root="$1"
    if is_locked "$repo_root"; then
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
        AGE_PASSPHRASE="$AGE_PASSPHRASE" age -d -p
    else
        fatal "No decryption key available"
    fi
}