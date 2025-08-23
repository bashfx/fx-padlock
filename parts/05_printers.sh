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
        echo "No locker directory found" >&2
        exit 1
    fi
    
    load_config
    
    if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
        tar -czf - -C "$REPO_ROOT" locker | age -r "$AGE_RECIPIENTS"
    elif [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        tar -czf - -C "$REPO_ROOT" locker | age -p
    else
        echo "No encryption method configured" >&2
        exit 1
    fi
}

decrypt_locker() {
    load_config
    
    if [[ -n "${AGE_KEY_FILE:-}" ]]; then
        age -d -i "$AGE_KEY_FILE" | tar -xzf - -C "$REPO_ROOT"
    elif [[ -n "${AGE_PASSPHRASE:-}" ]]; then
        age -d -p | tar -xzf - -C "$REPO_ROOT"
    else
        echo "No decryption method available" >&2
        exit 1
    fi
}

case "$MODE" in
    encrypt)
        encrypt_locker
        ;;
    decrypt)
        decrypt_locker
        ;;
    *)
        echo "Usage: $0 {encrypt|decrypt}" >&2
        exit 1
        ;;
esac
AGE_WRAPPER_EOF

    chmod +x "$file"
}

__print_hook() {
    local file="$1"
    local hook_type="$2"
    local repo_root="$3"
    
    case "$hook_type" in
        pre-commit)
            cat > "$file" << 'PRE_COMMIT_EOF'
#!/usr/bin/env bash
# Pre-commit hook: Auto-encrypt locker if it exists

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
LOCKER_DIR="$REPO_ROOT/locker"

if [[ -d "$LOCKER_DIR" ]]; then
    echo "🔒 Auto-encrypting locker before commit..."
    if "$REPO_ROOT/bin/padlock" lock; then
        echo "✓ Locker encrypted successfully"
        git add locker.age .locked 2>/dev/null || true
    else
        echo "✗ Failed to encrypt locker" >&2
        exit 1
    fi
fi

exit 0
PRE_COMMIT_EOF
            ;;
        post-checkout)
            cat > "$file" << 'POST_CHECKOUT_EOF'
#!/usr/bin/env bash
# Post-checkout hook: Auto-decrypt locker.age if it exists

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
LOCKER_BLOB="$REPO_ROOT/locker.age"

if [[ -f "$LOCKER_BLOB" ]] && [[ ! -d "$REPO_ROOT/locker" ]]; then
    echo "🔓 Auto-decrypting locker after checkout..."
    if "$REPO_ROOT/bin/padlock" unlock 2>/dev/null; then
        echo "✓ Locker decrypted successfully"
    else
        echo "ⓘ Locker remains encrypted (use: source .locked)"
    fi
fi

exit 0
POST_CHECKOUT_EOF
            ;;
        post-merge)
            cat > "$file" << 'POST_MERGE_EOF'
#!/usr/bin/env bash
# Post-merge hook: Refresh locker after merge

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
LOCKER_BLOB="$REPO_ROOT/locker.age"

if [[ -f "$LOCKER_BLOB" ]] && [[ -d "$REPO_ROOT/locker" ]]; then
    echo "🔄 Refreshing locker after merge..."
    if "$REPO_ROOT/bin/padlock" unlock 2>/dev/null; then
        echo "✓ Locker refreshed successfully"
    else
        echo "ⓘ Manual refresh needed (use: source .locked)"
    fi
fi

exit 0
POST_MERGE_EOF
            ;;
    esac
    
    chmod +x "$file"
}

__print_locked_file() {
    local file="$1"
    local age_key_file="$2"
    
    cat > "$file" << EOF
#!/bin/bash
set -e
# Padlock unlock script
# Generated: $(date)
# Usage: source .locked

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
    export AGE_KEY_FILE="$age_key_file"
    
    if bin/padlock unlock; then
        if [[ -f "locker/.padlock" ]]; then
            source locker/.padlock
            export PADLOCK_UNLOCKED=1
            echo "✓ Repository unlocked successfully"
        fi
    else
        echo "✗ Failed to unlock"
        return 1
    fi
else
    echo "ERROR: No locker.age file found"
    echo "Repository may already be unlocked, or padlock not set up"
    return 1
fi
EOF
    chmod +x "$file"
}

__print_enhanced_locked_file() {
    local file="$1"
    local age_key_file="$2"
    local checksum="$3"
    cat > "$file" << EOF
#!/bin/bash
# Enhanced .locked script - Auto-generated by padlock
# Usage: source .locked

# Integrity verification
verify_integrity() {
    if [[ ! -f "locker.age" ]]; then
        echo "ERROR: locker.age not found"
        return 1
    fi
    
    local expected_checksum="$checksum"
    if [[ "\$expected_checksum" != "no-locker" ]]; then
        local current_checksum
        current_checksum=\$(find locker -type f -exec md5sum {} \\; 2>/dev/null | sort | md5sum | cut -d' ' -f1)
        
        if [[ "\$current_checksum" != "\$expected_checksum" ]]; then
            echo "WARNING: Locker contents may have been modified"
            read -p "Continue anyway? (y/N) " -r response
            [[ "\$response" =~ ^[Yy] ]] || return 1
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
    export AGE_KEY_FILE="$age_key_file"
    
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

__print_security_readme() {
    local file="$1"
    
    cat > "$file" << 'SECURITY_EOF'
# Security Information

This repository uses **Padlock** for transparent encryption of sensitive files.

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

## Master Key Emergency Access

This repository includes a master key backup recipient. If you lose access to your 
regular keys, you can unlock using:

```bash
padlock master-unlock
```

## Ignition Keys (AI Collaboration)

If this repository uses ignition mode, you can share the ignition passphrase 
with AI assistants for automated access:

```bash
export PADLOCK_IGNITION_PASS="your-ignition-key"
source .locked
```

## Notes

- Files in `locker/` are automatically encrypted on commit
- `locker.age` is automatically decrypted on checkout
- Remove this file once you're familiar with the system
- Never commit the `locker/` directory - it's in `.gitignore`

Created by Padlock v1.0.0
SECURITY_EOF
}
