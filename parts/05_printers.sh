################################################################################
# File Printers - Low-Level Content Generation
################################################################################

__print_gitattributes() {
    local file="$1"
    local content
    
    printf -v content "%s\n" \
        "# Padlock encryption" \
        "locker.age filter=locker-crypt" \
        "locker.age binary" \
        "" \
        "# Keep tools plaintext" \
        "bin/* -filter" \
        ".githooks/* -filter"
    
    printf "%s\n" "$content" > "$file"
}

__print_gitignore() {
    local file="$1"
    local content
    
    printf -v content "%s\n" \
        "# Padlock - never commit plaintext locker" \
        "locker/"
    
    printf "%s\n" "$content" > "$file"
}

__print_age_wrapper() {
    local file="$1"
    local repo_root="$2"
    
    cat > "$file" << 'AGE_WRAPPER_EOF'
#!/usr/bin/env bash
set -euo pipefail

_find_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]] || [[ -d "$dir/.gitsim" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    if [[ -d "$dir/.git" ]] || [[ -d "$dir/.gitsim" ]]; then echo "$dir"; return 0; fi
    return 1
}

MODE="${1:-}"
REPO_ROOT="$(_find_root)"
CRYPTO_CONFIG="$REPO_ROOT/locker/.padlock"
LOCKER_DIR="$REPO_ROOT/locker"
LOCKER_BLOB="$REPO_ROOT/locker.age"

load_config() {
    if [[ -f "$CRYPTO_CONFIG" ]]; then
        source "$CRYPTO_CONFIG"
    else
        if [[ -z "${AGE_RECIPIENTS:-}${AGE_PASSPHRASE:-}" ]]; then
            echo "✗ No crypto config. Run: bin/padlock setup" >&2
            exit 1
        fi
    fi
}

encrypt_locker() {
    if [[ ! -d "$LOCKER_DIR" ]]; then
        echo "✗ Locker folder not found: $LOCKER_DIR" >&2
        exit 1
    fi
    
    tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        -C "$REPO_ROOT" -czf - "locker" | encrypt_stream
}

decrypt_locker() {
    [[ -d "$LOCKER_DIR" ]] && rm -rf "$LOCKER_DIR"
    decrypt_stream | tar -C "$REPO_ROOT" -xzf -
}

encrypt_stream() {
    if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
        IFS=',' read -ra RECIPS <<< "$AGE_RECIPIENTS"
        local age_args=()
        for recip in "${RECIPS[@]}"; do
            age_args+=("-r" "$recip")
        done
        age "${age_args[@]}"
    elif [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        AGE_PASSPHRASE="$AGE_PASSPHRASE" age -p
    else
        echo "✗ No encryption method configured" >&2
        exit 1
    fi
}

decrypt_stream() {
    if [[ -n "${AGE_KEY_FILE:-}" && -f "$AGE_KEY_FILE" ]]; then
        age -d -i "$AGE_KEY_FILE"
    elif [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        AGE_PASSPHRASE="$AGE_PASSPHRASE" age -d -p
    else
        echo "✗ No decryption key available" >&2
        exit 1
    fi
}

case "$MODE" in
    "clean") load_config && encrypt_locker ;;
    "smudge") load_config && decrypt_locker >/dev/null ;;
    *) echo "Usage: age-wrapper {clean|smudge}"; exit 1 ;;
esac
AGE_WRAPPER_EOF
    
    chmod +x "$file"
}

__print_hook() {
    local file="$1"
    local hook_type="$2"
    local repo_root="$3"
    
    # Define the finder function once to be used in all hooks
    local finder_func
    finder_func=$(cat << 'FINDER_EOF'
_find_root() {
    local dir="$PWD"
    while [[ "$dir" != "/" ]]; do
        if [[ -d "$dir/.git" ]] || [[ -d "$dir/.gitsim" ]]; then
            echo "$dir"
            return 0
        fi
        dir=$(dirname "$dir")
    done
    if [[ -d "$dir/.git" ]] || [[ -d "$dir/.gitsim" ]]; then echo "$dir"; return 0; fi
    return 1
}
REPO_ROOT="$(_find_root)"
FINDER_EOF
)

    case "$hook_type" in
        "pre-commit")
            cat > "$file" << HOOK_EOF
#!/usr/bin/env bash
set -euo pipefail

$finder_func

if [[ -d "\$REPO_ROOT/locker" ]] && [[ -n "\$(find "\$REPO_ROOT/locker" -type f 2>/dev/null)" ]]; then
    echo "🔐 Encrypting locker/ → locker.age"
    if "\$REPO_ROOT/bin/padlock" lock; then
        # This part is tricky because gitsim doesn't have a staging area like git.
        # For real git, this is correct. For gitsim, this command will fail.
        # This is an acceptable limitation for now.
        if [[ -d "\$REPO_ROOT/.git" ]]; then
            git add locker.age
        fi
    else
        echo "✗ Failed to encrypt locker" >&2
        exit 1
    fi
fi
HOOK_EOF
            ;;
        "post-checkout")
            cat > "$file" << HOOK_EOF
#!/usr/bin/env bash
set -euo pipefail

$finder_func

if [[ -f "\$REPO_ROOT/locker.age" ]] && [[ ! -d "\$REPO_ROOT/locker" ]]; then
    echo "🔓 Auto-unlocking locker..."
    if ! "\$REPO_ROOT/bin/padlock" unlock 2>/dev/null; then
        echo "⚠️  Cannot auto-unlock (missing keys?)"
        echo "    Run: source .locked"
    fi
fi
HOOK_EOF
            ;;
        "post-merge")
            cat > "$file" << HOOK_EOF
#!/usr/bin/env bash
set -euo pipefail

$finder_func

# For real git. This will not work for gitsim. Acceptable limitation.
if [[ -d "\$REPO_ROOT/.git" ]] && git diff --name-only HEAD@{1} HEAD 2>/dev/null | grep -q "^locker.age$"; then
    echo "🔄 Locker updated in merge, refreshing..."
    if ! "\$REPO_ROOT/bin/padlock" unlock 2>/dev/null; then
        echo "⚠️  Cannot decrypt updated locker (missing keys?)"
    fi
fi
HOOK_EOF
            ;;
    esac
    
    chmod +x "$file"
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

__print_locked_file() {
    local file="$1"
    
    cat > "$file" << EOF
#!/bin/bash
# Padlock unlock script - source this file to unlock secrets
# Usage: source .locked

if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
    echo "Usage: source .locked (don't execute directly)"
    exit 1
fi

echo "🔓 Unlocking padlock..."

# Set crypto environment from stored config
export AGE_RECIPIENTS='${AGE_RECIPIENTS:-}'
export AGE_KEY_FILE='${AGE_KEY_FILE:-}'  
export AGE_PASSPHRASE='${AGE_PASSPHRASE:-}'

# Unlock the locker
if bin/padlock unlock; then
    echo "✓ Locker unlocked"
    if [[ -f "locker/.padlock" ]]; then
        source locker/.padlock
        export PADLOCK_UNLOCKED=1
        echo "✓ Environment loaded from .padlock"
    fi
else
    echo "✗ Failed to unlock locker"
fi
EOF
}

__print_security_md() {
    local file="$1"
    
    cat > "$file" << 'SECURITY_EOF'
# Repository Security with Padlock

This repository uses **Padlock** for encrypting sensitive files using the `age` encryption tool.

## How It Works

- **Locker Directory**: Sensitive files go in `locker/` (plaintext locally, never committed)
- **Encrypted Storage**: Git stores `locker.age` (encrypted binary blob)
- **State Files**: 
  - `.locked` exists when secrets are encrypted (run `source .locked` to unlock)
  - `locker/.padlock` exists when secrets are accessible (contains crypto config)

## Quick Start

```bash
# Setup encryption (first time)
bin/padlock setup

# Unlock secrets (when .locked file exists)
source .locked

# Lock secrets manually
bin/padlock lock

# Check status
bin/padlock status
```

## Directory Structure

```
locker/
├── docs_sec/           # Secure documentation
├── conf_sec/           # Configuration files, API keys
└── .padlock           # Crypto configuration (unlocked state)
```

## Commands

- `bin/padlock status` - Check lock/unlock state
- `bin/padlock lock` - Encrypt locker/ → locker.age
- `bin/padlock unlock` - Decrypt locker.age → locker/
- `bin/padlock setup` - Initial encryption setup
- `source .locked` - Unlock and source crypto config

## Team Sharing

```bash
# Add team member's public key
bin/padlock key --add-recipient age1abc123...

# Generate your public key to share
bin/padlock key --show-global
```

## Notes

- Files in `locker/` are automatically encrypted on commit
- `locker.age` is automatically decrypted on checkout
- Remove this file once you're familiar with the system
- Never commit the `locker/` directory - it's in `.gitignore`

Created by Padlock v1.0.0
SECURITY_EOF
}

__print_starter_files() {
    local locker_dir="$1"
    
    mkdir -p "$locker_dir/docs_sec" "$locker_dir/conf_sec"
    
    cat > "$locker_dir/docs_sec/AGENT.md" << 'AGENT_EOF'
# AI Agent Instructions

This file contains instructions for AI agents working on this project.

## System Prompt

You are an AI assistant working on this project. This content is encrypted 
and only visible when the repository locker is unlocked.

## Guidelines

- Follow project conventions
- Be helpful and concise
- Ask for clarification when needed

## Context

This file is part of the secure locker and will be encrypted in git.
Add your AI-specific instructions and context here.
AGENT_EOF
    
    cat > "$locker_dir/conf_sec/project.conf" << 'CONF_EOF'
# Project Configuration
# Secure configuration file - encrypted in git

# API Keys (example)
# API_KEY=your-secret-key
# DATABASE_URL=postgresql://user:pass@host/db

# Environment specific settings
ENV=development

# Add your secure configuration here
CONF_EOF
}

# ADD this new function to parts/05_printers.sh:

# Enhanced .locked script generator
__print_enhanced_locked_file() {
    local file="$1"
    cat > "$file" << 'EOF'
#!/bin/bash
# Enhanced .locked script - Auto-generated by padlock
# Usage: source .locked

# Integrity verification
verify_integrity() {
    if [[ ! -f "locker.age" ]]; then
        echo "ERROR: locker.age not found"
        return 1
    fi
    
    local expected_checksum="${EXPECTED_CHECKSUM:-no-locker}"
    if [[ "$expected_checksum" != "no-locker" ]]; then
        local current_checksum
        current_checksum=$(find locker -type f -exec md5sum {} \; 2>/dev/null | sort | md5sum | cut -d' ' -f1)
        
        if [[ "$current_checksum" != "$expected_checksum" ]]; then
            echo "WARNING: Locker contents may have been modified"
            read -p "Continue anyway? (y/N) " -r response
            [[ "$response" =~ ^[Yy] ]] || return 1
        else
            echo "✓ Locker integrity verified"
        fi
    fi
}

# Progress indicator
echo "🔓 Unlocking padlock repository..."

# Main unlock logic
if [[ -d ".chest" ]]; then
    echo "🗃️  Chest system detected"
    echo "🔑 Run: bin/padlock ignite --unlock"
    return 1
elif [[ -f "locker.age" ]]; then
    # Standard padlock workflow
    export AGE_RECIPIENTS='${AGE_RECIPIENTS:-}'
    export AGE_KEY_FILE='${AGE_KEY_FILE:-}'
    
    if bin/padlock unlock; then
        verify_integrity
        if [[ -f "locker/.padlock" ]]; then
            source locker/.padlock
            export PADLOCK_UNLOCKED=1
            echo "✓ Repository unlocked and verified"
        fi
    else
        echo "✗ Failed to unlock"
        return 1
    fi
else
    echo "ERROR: No locker.age file found"
    return 1
fi
EOF
    chmod +x "$file"
}
