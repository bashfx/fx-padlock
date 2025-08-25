# Security Information

This repository uses **Padlock** for transparent encryption of sensitive files.

## How It Works

- **Locker Directory**: Sensitive files go in `locker/` (plaintext locally, never committed)
- **Encrypted Storage**: Git stores `locker.age` (encrypted binary blob)
- **State Files**: 
  - `.locked` exists when secrets are encrypted (run `bin/padlock unlock` to decrypt)
  - `locker/.padlock` exists when secrets are accessible (contains crypto config)

## Quick Start

```bash
# Setup encryption (first time)
bin/padlock setup

# Unlock secrets
bin/padlock unlock

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
bin/padlock unlock
```

## Notes

- Files in `locker/` are automatically encrypted on commit
- `locker.age` is automatically decrypted on checkout
- Remove this file once you're familiar with the system
- Never commit the `locker/` directory - it's in `.gitignore`

Created by Padlock v1.0.0
