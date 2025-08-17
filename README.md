# Padlock - Git Repository Security Orchestrator

> **Modern age-based encryption for git repositories with seamless AI collaboration**

Padlock transforms any git repository into a secure vault using the "locker pattern" - providing complete opacity to repository scrapers while maintaining a transparent developer experience.

## 🚀 **Quick Start**

```bash
# Deploy padlock to any git repository
padlock clamp /my/repo --generate

# Work with plaintext locally
echo "SECRET_API_KEY=abc123" > locker/conf_sec/.env
echo "Internal docs" > locker/docs_sec/notes.md

# Commit (auto-encrypts)
git add . && git commit -m "Add secrets"

# Unlock after checkout
source .locked
```

## 🔑 **Core Features**

### **✅ Standard Locker Encryption**
- **Transparent workflow**: Edit plaintext locally, automatic encryption in git
- **Complete opacity**: Single encrypted blob reveals nothing about contents
- **Team-friendly**: Simple public key sharing without GPG complexity
- **Self-contained**: Each repo becomes autonomous

### **🚀 Ignition Key System** *(TBD)*
Revolutionary two-stage encryption perfect for AI collaboration:

```bash
# Deploy with ignition key for AI sharing
padlock clamp /my/repo -K "flame-rocket-boost-spark"

# Share just the ignition phrase with AI assistants
# AI can unlock with: export PADLOCK_IGNITION_PASS="flame-rocket-boost-spark"
```

**Benefits**:
- **AI-friendly**: Share passphrase instead of private keys
- **Instant revocation**: Change ignition key to revoke all access
- **Two-stage security**: Personal key → Ignition key → Content

### **🗃️ .chest Directory Management** *(TBD)*
Clean state management eliminating root directory clutter:

```bash
# LOCKED state: Only .chest/ exists
my-repo/
├── .chest/               # All encrypted artifacts
│   ├── locker.age       # Main content
│   └── ignition.age     # Ignition key
└── bin/padlock          # Tools

# UNLOCKED state: Only locker/ exists  
my-repo/
├── locker/              # Working directory
│   ├── docs_sec/       # Plaintext for editing
│   └── conf_sec/       # API keys, configs
└── bin/padlock         # Tools
```

**Never both simultaneously** - impossible inconsistent states!

### **📋 Enhanced Manifest System** *(TBD)*
Rich repository tracking with namespace organization:

```bash
# Advanced manifest format
# namespace|name|path|type|remote|checksum|created|last_access|metadata
github|myproject|/home/user/myproject|ignition|git@github.com:user/myproject.git|a1b2c3|2025-01-15T10:30:00Z|2025-01-15T14:20:00Z|
local|secrets|/home/user/secrets|standard||f6e5d4|2025-01-15T11:45:00Z|2025-01-15T15:10:00Z|

# List repositories by namespace
padlock list --namespace github
padlock list --ignition
```

### **🔐 Integrity Verification** *(TBD)*
MD5 checksums ensure locker content integrity:

```bash
# Automatic verification during unlock
source .locked
# ✓ Locker integrity verified: a1b2c3d4...
# ⚠️ Warning: Locker contents may have been modified
```

## 🎯 **Command Reference**

### **Deployment**
```bash
padlock clamp <path>              # Deploy to repository
  --generate                      # Generate new key
  --global-key                    # Use global key
  -K, --ignition [phrase]         # Enable ignition system (TBD)
```

### **Daily Operations**
```bash
padlock status                    # Show lock/unlock state
padlock lock                      # Encrypt locker/ → locker.age
padlock unlock                    # Decrypt locker.age → locker/
source .locked                    # Unlock and load environment
```

### **Ignition System** *(TBD)*
```bash
padlock ignite --unlock           # Unlock .chest → locker/
padlock ignite --lock             # Lock locker/ → .chest
padlock rotate -K                 # Rotate ignition key
```

### **Repository Management** *(TBD)*
```bash
padlock list                      # Show managed repositories
padlock list --namespace github   # Filter by namespace
padlock clean-manifest            # Remove temp/stale entries
padlock declamp [--force]         # Safely remove padlock (preserve content)
```

### **Backup & Migration** *(TBD)*
```bash
padlock export backup.tar.age     # Export environment with all keys
padlock import backup.tar.age     # Import on new system
padlock snapshot before-changes   # Create named snapshot
padlock rewind before-changes     # Restore from snapshot
```

### **Advanced Features** *(TBD)*
```bash
# Overdrive: Encrypt entire repository 
padlock overdrive lock            # → Complete "traveling blob"
source .overdrive                 # Restore full repository
```

## 🔧 **Installation**

### **System Requirements**
- **OS**: Linux, macOS (Windows via WSL)
- **Shell**: Bash 4.0+
- **Dependencies**: `age` (auto-installed if missing)

### **Install Methods**
```bash
# Package managers (preferred)
apt install age          # Debian/Ubuntu
brew install age         # macOS
pacman -S age           # Arch

# Global installation
padlock install         # Installs to ~/.local/bin/fx/
```

## 🔒 **Security Model**

### **What's Protected**
- ✅ **File contents**: Modern age encryption
- ✅ **Directory structure**: Hidden in single blob
- ✅ **File metadata**: Sizes, counts, timestamps obscured
- ✅ **Access patterns**: No indication of secret types

### **What's Visible**
- ⚠️ **Presence**: That encrypted content exists
- ⚠️ **Size**: Approximate size of encrypted bundle
- ⚠️ **Tool usage**: That padlock is in use

### **Threat Model**
- **✅ Protects against**: Repository scrapers, casual browsing, bot harvesting
- **✅ Suitable for**: Commercial IP, LLM prompts, API keys, internal docs
- **❌ Not suitable for**: Nation-state threats, formal compliance requirements

## 🤖 **AI Collaboration Workflows**

### **Standard Approach**
```bash
# Add AI assistant as recipient
padlock key --add-recipient age1abc123...
# Share private key securely with AI
```

### **Ignition Approach** *(TBD)*
```bash
# Deploy with ignition key
padlock clamp /ai-project -K "shared-access-phrase"

# Share just the phrase with AI
export PADLOCK_IGNITION_PASS="shared-access-phrase"
source .locked  # AI can now access everything
```

## 📁 **Directory Structure**

### **Standard Mode**
```
my-repo/
├── locker/              # Plaintext (unlocked) or absent (locked)
│   ├── docs_sec/       # Secure documentation
│   ├── conf_sec/       # API keys, configs
│   └── .padlock        # Crypto configuration
├── locker.age          # Encrypted blob (locked) or absent (unlocked)
├── .locked             # Unlock script (when locked)
├── bin/padlock         # Self-contained tools
└── SECURITY.md         # Usage guide (optional)
```

### **Ignition Mode** *(TBD)*
```
my-repo/
├── .chest/             # Encrypted storage (locked state)
│   ├── locker.age     # Main content
│   └── ignition.age   # Encrypted ignition key
├── locker/            # Working directory (unlocked state)
├── .ignition.key      # Temporary (during active use)
├── .overdrive         # Overdrive unlock script
└── bin/padlock        # Tools
```

## 🆚 **Comparison with Alternatives**

| Feature | Padlock | git-crypt | git-secret | Vault |
|---------|---------|-----------|------------|-------|
| **Setup** | One command | Multi-step GPG | Manual workflow | Infrastructure |
| **Encryption** | Age (modern) | GPG | GPG | Various |
| **Transparency** | Automatic | Automatic | Manual | External |
| **AI Collaboration** | ✅ Ignition keys | ❌ Complex | ❌ Manual | ⚠️ Depends |
| **Metadata Hiding** | ✅ Complete | ⚠️ Per-file | ⚠️ Per-file | N/A |
| **Team Sharing** | ✅ Public keys | ⚠️ GPG web of trust | ⚠️ GPG keys | ✅ Policies |

## 🛣️ **Roadmap**

### **✅ Completed**
- Core locker encryption with age
- Git integration (hooks, filters)
- Team collaboration via public keys
- Comprehensive test suite
- BASHFX-compliant architecture

### **🚧 In Development** *(TBD)*
- **Phase 1**: Enhanced manifest system with namespace tracking
- **Phase 2**: .chest directory management
- **Phase 3**: Ignition key system for AI collaboration
- **Phase 4**: Integrity verification and safe declamp
- **Phase 5**: Export/import for cross-system migration
- **Phase 6**: Overdrive mode for complete repository encryption

## 📖 **Documentation**

- **[FEATURES.md](docs/FEATURES.md)**: Complete feature roadmap with implementation details
- **[ANALYSIS.md](docs/ANALYSIS.md)**: Technical architecture and design philosophy
- **[SESSION3.md](docs/SESSION3.md)**: Latest development session summary
- **SECURITY.md**: Generated in each repository after deployment

## 🤝 **Contributing**

Padlock follows the BASHFX framework for maintainable bash development:

```bash
# Build from modular parts
./build.sh

# Run comprehensive tests
./test_runner.sh

# Development workflow
source bin/dev.sh
```

## 📄 **License**

GPL v3+ - See LICENSE file for details.

---

**Padlock represents a modern approach to repository security that prioritizes developer experience while providing robust protection for sensitive content. Its transparent workflow and team-friendly architecture make it ideal for protecting commercial IP, LLM prompts, and confidential configuration in git repositories.**

*Features marked (TBD) are designed and documented but not yet implemented.*