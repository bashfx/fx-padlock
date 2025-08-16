# Padlock: Locker-Based Encryption Solution
*BASHFX-compliant git repository security orchestrator using age encryption*

## Architecture Overview

Padlock transforms any git repository into a secure vault using the "locker pattern" - a single encrypted container for all sensitive content that provides complete opacity to repository scrapers while maintaining a seamless developer experience.

### Design Philosophy

**Core Principles:**
- **Complete Opacity**: Single `locker.age` blob reveals nothing about contents, structure, or file counts
- **Transparent Workflow**: Edit plaintext locally, automatic encryption in git
- **State Toggle**: Mutually exclusive `.locked` vs `locker/.padlock` files indicate current state
- **Self-Contained**: Each repo becomes autonomous with its own padlock installation
- **Team-Friendly**: Simple public key sharing without GPG complexity

### The Locker Pattern

**Local Development (Unlocked State):**
```
myproject/
├── locker/                    # Plaintext container (never committed)
│   ├── prompts_sec/          # LLM guidance files
│   ├── docs_sec/             # Sensitive documentation  
│   ├── conf_sec/             # API keys, secrets
│   └── .padlock              # Crypto configuration (present when unlocked)
├── bin/
│   ├── padlock               # Self-contained orchestrator
│   └── age-wrapper           # Git filter interface
├── .githooks/               # Auto-encryption triggers
└── .locked                   # Absent (indicates unlocked state)
```

**Git Repository (Locked State):**
```
myproject/
├── locker.age               # Single opaque binary blob
├── bin/
│   ├── padlock              # Self-contained tools (plaintext)
│   └── age-wrapper          # Git filter interface
├── .githooks/              # Auto-encryption triggers
├── .locked                  # Unlock script (present when locked)
└── locker/                  # Absent (all content encrypted)
```

## Implementation Architecture

### Encryption Engine
- **Algorithm**: Age (modern, audited, scriptable alternative to GPG)
- **Format**: Binary encrypted blobs with ~200 bytes overhead per recipient
- **Compression**: Deterministic tar with fixed timestamps for git-friendly diffs
- **Key Types**: Public-key (recommended) or symmetric passphrase

### Git Integration
**Clean Filter (Commit):**
```bash
locker/ → tar + age → locker.age
```

**Smudge Filter (Checkout):**
```bash  
locker.age → age + tar → locker/
```

**Hooks:**
- `pre-commit`: Auto-encrypt if locker/ exists
- `post-checkout`: Auto-decrypt if locker.age exists
- `post-merge`: Refresh locker/ after merges

### State Management
The system uses **mutually exclusive state indicators**:

| State | Indicator File | Locker Directory | Content Access |
|-------|---------------|------------------|----------------|
| **Unlocked** | `locker/.padlock` | `locker/` exists | Plaintext editing |
| **Locked** | `.locked` script | `locker/` absent | Encrypted in git |

## BASHFX Compliance

### XDG+ Architecture
```bash
# Global installation (first-class fx script)
$XDG_LIB_HOME/fx/padlock/padlock.sh
$XDG_BIN_HOME/fx/padlock  # Flattened symlink

# Global key storage
$XDG_ETC_HOME/padlock/keys/global.key
$XDG_ETC_HOME/padlock/config
```

### Function Ordinality
- **High-Order**: `do_clamp()`, `do_lock()`, `do_unlock()` (dispatchable)
- **Mid-Level**: `_validate_repo()`, `_load_crypto_config()` (helpers)
- **Low-Level**: `__encrypt_stream()`, `__print_gitattributes()` (literals)

### Rich Output (stderr)
```bash
# Color palette with BASHFX glyphs
lock "🔐 Encrypting locker..."           # Cyan with unlock glyph
okay "✓ Locker locked → locker.age"     # Green with checkmark  
error "✗ No crypto config found"        # Red with X mark
info "Using global key"                 # Blue (debug mode only)
```

## User Experience

### Deployment Workflow
```bash
# Deploy to any git repository
padlock clamp /path/to/repo --global-key

# Creates complete infrastructure:
# - Copies padlock tools to bin/
# - Configures git filters and hooks
# - Sets up crypto configuration
# - Creates starter template files
```

### Daily Development Workflow
```bash
# Work with plaintext locally
echo "You are an AI expert" > locker/prompts_sec/system.md
echo "API_KEY=secret123" > locker/conf_sec/.env

# Commit (automatic encryption)
git add . && git commit -m "Add secure content"
# → locker/ disappears, locker.age appears, .locked created

# Checkout/pull (automatic decryption)
git pull
# → locker.age decrypted to locker/, .locked removed

# Manual unlock when needed
source .locked
# → Decrypts locker.age, loads environment from .padlock
```

### Team Collaboration
```bash
# Add team member's public key
padlock key --add-recipient age1abc123...

# Share your public key
padlock key --show-global

# Re-encrypt with new recipients (automatic)
git add . && git commit -m "Add team member access"
```

## Command Interface

### Deployment Commands
```bash
padlock clamp <repo> [options]    # Deploy padlock to repository
  --global-key                    # Use/create global key
  --generate                      # Generate repo-specific key  
  --key <pubkey>                  # Use explicit public key
```

### Repository Operations
```bash
padlock setup                     # Initial crypto configuration
padlock lock                      # Manual encrypt: locker/ → locker.age
padlock unlock                    # Manual decrypt: locker.age → locker/
padlock status                    # Show current lock/unlock state
```

### Key Management
```bash
padlock key --set-global <key>    # Store global key
padlock key --show-global         # Display global key
padlock key --generate-global     # Create new global key
```

### State Management
```bash
source .locked                    # Unlock and load crypto environment
export PADLOCK_UNLOCKED=1         # Set by successful unlock
```

## Security Characteristics

### Information Hiding
**✅ Completely Hidden:**
- File contents (encrypted with modern age algorithm)
- Directory structure (single tar archive)
- File names and paths (archived within blob)
- File counts and sizes (compressed blob)
- Access patterns (no indication of secret types)

**⚠️ Visible Metadata:**
- Existence of encrypted content (locker.age file)
- Approximate size of encrypted bundle
- Tool usage (padlock scripts visible)
- Git commit timing (when secrets were modified)

### Threat Model
**✅ Protects Against:**
- Repository scrapers and bots
- Casual browsing of git history
- Accidental exposure in forks/clones
- Social engineering via commit messages

**❌ Not Designed For:**
- Nation-state level threats
- Formal compliance requirements (SOX, HIPAA)
- Sophisticated targeted attacks
- Perfect forward secrecy

## Technical Implementation

### File Generation Templates
The system automatically creates:

**Git Configuration:**
```gitattributes
locker.age filter=locker-crypt
locker.age binary
bin/* -filter
.githooks/* -filter
```

**Crypto Configuration (`locker/.padlock`):**
```bash
export AGE_RECIPIENTS='age1abc123...'
export AGE_KEY_FILE='/path/to/private/key'
export PADLOCK_REPO='/path/to/repo'
export PROJECT_NAME='myproject'
```

**Unlock Script (`.locked`):**
```bash
#!/bin/bash
# Usage: source .locked
export AGE_RECIPIENTS='age1abc123...'
export AGE_KEY_FILE='/path/to/key'

if bin/padlock unlock; then
    source locker/.padlock
    export PADLOCK_UNLOCKED=1
    echo "✓ Environment loaded"
fi
```

### Cross-Platform Installation
```bash
# Package managers (preferred)
apt install age          # Debian/Ubuntu
brew install age         # macOS  
pacman -S age           # Arch Linux
nix-env -iA nixpkgs.age # NixOS

# Binary fallback (automatic)
curl -sL github.com/FiloSottile/age/releases/latest/download/...
```

## Advanced Features

### Automation Compatibility
- **CI/CD Integration**: Works with GitHub Actions, GitLab CI, Jenkins
- **LLM Development**: Compatible with Claude, Cursor, Copilot environments
- **Container Support**: Binary download fallback for restricted environments

### Development Tools
- **Status Monitoring**: Visual state indicators with colors and glyphs
- **Debug Modes**: Trace-level logging for troubleshooting
- **Health Checks**: Validation of crypto configuration and key accessibility
- **Modular Build**: Component-based development with build.sh

### Recovery Procedures
- **Key Loss**: Unrecoverable by design (encourage backup procedures)
- **Filter Failures**: Repository remains functional, crypto can be reconfigured
- **Merge Conflicts**: Automatic re-encryption with conflict resolution guidance

## Comparison with Alternatives

| Feature | Padlock | git-crypt | git-secret | Vault |
|---------|---------|-----------|------------|-------|
| **Setup Complexity** | One command | Multi-step GPG | Manual workflow | Infrastructure |
| **Encryption** | Age (modern) | GPG | GPG | Various |
| **Transparency** | Automatic | Automatic | Manual | External |
| **Team Sharing** | Public keys | GPG web of trust | GPG keys | Vault policies |
| **Metadata Hiding** | Complete (single blob) | Per-file | Per-file | N/A |
| **LLM Compatible** | Yes | Partial | No | Depends |

## Best Practices

### Repository Organization
```
locker/
├── prompts_sec/         # AI/LLM instructions and examples
├── docs_sec/           # Internal documentation and guides  
├── conf_sec/           # API keys, database URLs, tokens
└── research_sec/       # Competitive analysis, strategies
```

### Key Management
- **Global Key**: For personal projects and consistent access
- **Project Keys**: For team projects with specific access control
- **Backup Strategy**: Store private keys securely outside repository
- **Rotation Policy**: Regular key updates for long-term projects

### Team Workflows
- **Onboarding**: Share public keys via secure channels
- **Access Control**: Use multiple recipients for role-based access
- **Documentation**: Keep SECURITY.md updated with team procedures

## Future Roadmap

### Planned Enhancements
- **Selective Encryption**: File-level rather than folder-level encryption
- **Hardware Keys**: YubiKey support via age plugins
- **Audit Logging**: Track access patterns and key usage
- **Integration**: Native support for Vault, AWS Secrets Manager

### Experimental Features
- **Remote Unlock**: Network-based key retrieval for automation
- **Mobile Support**: Git client compatibility improvements
- **Performance**: Lazy loading for large encrypted repositories

---

**Padlock represents a modern approach to repository security that prioritizes developer experience while providing robust protection for sensitive content. Its transparent workflow and team-friendly architecture make it ideal for protecting commercial IP, LLM prompts, and confidential configuration in git repositories.**