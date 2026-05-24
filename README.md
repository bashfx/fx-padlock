# Padlock - Git Repository Security Orchestrator

> **Modern age-based encryption for git repositories with robust backup and recovery**

Padlock transforms any git repository into a secure vault using the "locker pattern" - providing complete opacity to repository scrapers while maintaining a transparent developer experience.

## ⚠️ **Safety Status**

Padlock mutates repository layout and encrypted/plaintext secret state. Until the
new Ignite/Cage-backed design is fully proven, **do not run Padlock against a
live repository**. Use `gitsim`-backed simulated homes and repositories for all
validation.

The safe proof entrypoint is:

```bash
bin/e2e.sh
```

## 🚀 **Historical Quick Start**

The flow below documents the historical target UX. Treat it as design reference
until the gitsim-only proof suite and Ignite service integration are complete.

```bash
# Interactive setup with master key backup
padlock setup

# Deploy padlock to a simulated/proven repository only
padlock clamp /my/repo --generate

# Work with plaintext locally
echo "SECRET_API_KEY=abc123" > locker/conf_sec/.env
echo "Internal docs" > locker/docs_sec/notes.md

# Commit (auto-encrypts with pre-commit hook)
git add . && git commit -m "Add secrets"
# → Automatically encrypts locker/ → .chest/locker.age
# → Only encrypted files are committed to git

# Unlock after checkout/pull
padlock unlock
# → Decrypts .chest/locker.age → locker/
```

## 🔑 **Core Features**

### **✅ Standard Locker Encryption**
- **Transparent workflow**: Edit plaintext locally, automatic encryption via git hooks
- **Complete opacity**: Single encrypted blob reveals nothing about contents  
- **Team-friendly**: Simple public key sharing without GPG complexity
- **Self-contained**: Each repo becomes autonomous with integrated tooling
- **Integrity verification**: MD5 checksums ensure content integrity
- **Chest pattern**: Encrypted files stored in `.chest/` directory, plaintext in `locker/` (gitignored)

### **✅ Ignition Backup System**
Passphrase-encrypted master key backup for disaster recovery:

```bash
# Setup creates both master key and ignition backup
padlock setup
# Enter passphrase: ********

# If master key is lost, restore from ignition backup
padlock key restore
# Enter the passphrase you created during setup
```

**Benefits**:
- **Disaster recovery**: Never lose access to your repositories
- **Passphrase-based**: Easy to remember, hard to crack
- **Automatic creation**: Set up during initial configuration
- **Secure storage**: Passphrase-encrypted backup of master key

### **✅ Repository Repair System**
Intelligent repair for corrupted or incomplete padlock installations:

```bash
# Repair missing .padlock configuration files
padlock repair

# Automatically detects and fixes:
# - Missing .padlock files
# - Incorrect key configurations  
# - Uses manifest and available evidence
```

### **✅ Enhanced Manifest System**
Rich repository tracking with namespace organization:

```bash
# Advanced manifest format tracks all repositories
# namespace|name|path|type|remote|checksum|created|last_access|metadata
padlock list                      # Show all repositories
padlock list --namespace github   # Filter by namespace
padlock clean-manifest            # Remove stale entries
```

### **✅ Robust Testing Suite**
Comprehensive validation with ceremonious presentation:

```bash
# Run the safe gitsim-only proof
bin/e2e.sh

# Tests include:
# - Build verification
# - Command validation  
# - E2E workflow in gitsim only
# - Repair functionality
# - Ignition backup system (with timeout handling)
# - Map/Unmap & chest pattern functionality
# - Overdrive mode (full repository encryption)
```

### **✅ Overdrive Mode**
Full repository encryption for maximum security:

```bash
# Encrypt entire repository into traveling blob
padlock overdrive lock            # → super_chest.age
padlock overdrive unlock          # Restore full repository
padlock overdrive status          # Check overdrive state
```

## 🎯 **Command Reference**

### **Setup & Management**
```bash
padlock setup                     # Interactive first-time setup
padlock status                    # Show current repository state
padlock repair                    # Fix missing/corrupted files
```

### **Deployment**
```bash
padlock clamp <path>              # Deploy to repository
  --generate                      # Generate new repo-specific key
  --global-key                    # Use global master key
  -K, --ignition [phrase]         # Enable ignition system
```

### **Daily Operations**
```bash
padlock lock                      # Encrypt locker/ → .chest/locker.age
padlock unlock                    # Decrypt .chest/locker.age → locker/
padlock status                    # Show lock/unlock state
# Note: Git hooks automatically handle lock/unlock during commits/checkouts
```

### **Git Integration & Workflow**
Padlock provides seamless git integration with intelligent pre-commit hooks:

```bash
# Recommended workflow (hooks handle everything automatically):
padlock unlock                   # Decrypt secrets for editing
# Edit files in locker/docs_sec/, locker/conf_sec/, etc.
git add . && git commit          # Auto-encrypts before commit
# → Hook encrypts locker/ → .chest/locker.age
# → Only encrypted files are committed
# → Plaintext files are automatically cleaned up

# After checkout/pull:
padlock unlock                   # Decrypt latest encrypted content
```

**Hook Behavior:**
- **When Unlocked** (`locker/` exists): Auto-encrypts before each commit
- **When Locked** (only `.chest/` exists): Prevents committing plaintext secrets
- **Error Guidance**: Provides clear instructions when workflow is incorrect

```bash
# If you accidentally try to commit plaintext while locked:
git commit
# 🚨 ERROR: Attempting to commit plaintext secrets while repository is locked!
# 
# To fix this:
#   1. Run: padlock unlock  
#   2. Make your changes to locker/ directory
#   3. Commit again (auto-encryption will happen)
```

### **Key Management**
```bash
padlock key --generate-global     # Create new global master key
padlock key --show-global         # Display global public key
padlock key --set-global <key>    # Set global master key
padlock key restore               # Restore from ignition backup
padlock key --add-recipient <key> # Add team member access
```

### **Repository Management**
```bash
padlock list                      # Show managed repositories
padlock list --namespace github   # Filter by namespace
padlock clean-manifest            # Remove temp/stale entries
padlock declamp [--force]         # Safely remove padlock
padlock revoke                    # Revoke encryption access
```

### **Backup & Migration**
```bash
padlock export backup.tar.age     # Export environment with all keys
padlock import backup.tar.age     # Import on new system
padlock snapshot before-changes   # Create named snapshot
padlock rewind before-changes     # Restore from snapshot
```

## 🔧 **Installation**

### **System Requirements**
- **OS**: Linux, macOS (Windows via WSL)
- **Shell**: Bash 4.0+
- **Dependencies**: `age` and `age-keygen` installed ahead of time

### **Install Methods**
```bash
# Package managers (for age dependency)
apt install age          # Debian/Ubuntu
brew install age         # macOS
pacman -S age           # Arch

# Optional/explicit only:
# PADLOCK_ALLOW_AGE_INSTALL=1 allows Padlock to attempt installation.

# Global installation
padlock install         # Installs to ~/.local/bin/
```

## 🔒 **Security Model**

### **What's Protected**
- ✅ **File contents**: Modern age encryption
- ✅ **Directory structure**: Hidden in single blob  
- ✅ **File metadata**: Sizes, counts, timestamps obscured
- ✅ **Access patterns**: No indication of secret types
- ✅ **Master key backup**: Passphrase-encrypted ignition system

### **What's Visible**
- ⚠️ **Presence**: That encrypted content exists
- ⚠️ **Size**: Approximate size of encrypted bundle
- ⚠️ **Tool usage**: That padlock is in use

### **Recovery Options**
- ✅ **Master key file**: Primary access method
- ✅ **Ignition backup**: Passphrase-encrypted recovery
- ✅ **Repository repair**: Reconstruct from manifest
- ✅ **Export/import**: Full environment backup

## 📁 **Directory Structure**

### **Standard Mode**
```
my-repo/
├── locker/              # Plaintext (unlocked) - .gitignored
│   ├── docs_sec/       # Secure documentation  
│   ├── conf_sec/       # API keys, configs
│   └── .padlock        # Crypto configuration
├── .chest/              # Encrypted storage (committed to git)
│   ├── locker.age      # Encrypted blob
│   ├── .locked         # Lock status indicator  
│   └── .locker_checksum # Integrity verification
├── bin/padlock         # Self-contained tools
└── .githooks/          # Automatic encryption hooks
    ├── pre-commit      # Auto-lock before commits
    ├── post-checkout   # Auto-unlock after checkout  
    ├── post-merge      # Refresh after merge
    └── post-commit     # Verify encryption
```

### **Global Configuration**
```
~/.local/etc/padlock/
├── keys/
│   ├── global.key      # Master key (primary)
│   ├── ignition.age    # Passphrase backup
│   └── <repo>.key      # Repository-specific keys
└── manifest.txt        # Repository tracking
```

## 🆚 **Comparison with Alternatives**

| Feature | Padlock | git-crypt | git-secret | Vault |
|---------|---------|-----------|------------|-------|
| **Setup** | One command | Multi-step GPG | Manual workflow | Infrastructure |
| **Encryption** | Age (modern) | GPG | GPG | Various |
| **Transparency** | Automatic | Automatic | Manual | External |
| **Backup/Recovery** | ✅ Multiple options | ❌ Manual | ❌ Manual | ⚠️ Depends |
| **Metadata Hiding** | ✅ Complete | ⚠️ Per-file | ⚠️ Per-file | N/A |
| **Team Sharing** | ✅ Public keys | ⚠️ GPG web of trust | ⚠️ GPG keys | ✅ Policies |
| **Repair Tools** | ✅ Automatic | ❌ Manual | ❌ Manual | ⚠️ Depends |

## 🛣️ **Implementation Status**

### **✅ Completed**
- Core locker encryption with age
- Git integration (hooks, filters, chest pattern)
- Master key and ignition backup system
- Repository repair and recovery tools
- Interactive setup and key management
- Enhanced manifest system with namespace tracking
- Team collaboration via public key sharing
- Comprehensive test suite (all tests passing)
- Export/import for cross-system migration
- Repository declamp and access revocation
- Overdrive mode (full repository encryption)
- Map/unmap functionality for external file handling

### **📋 Planned**
- Web interface for repository management
- Integration with CI/CD systems
- Advanced backup strategies
- Enhanced team collaboration features

## 📖 **Documentation**

- **[FEATURES.md](FEATURES.md)**: Complete feature reference with examples
- **[TODO.md](TODO.md)**: Current development priorities  
- **SECURITY.md**: Generated in each repository after deployment

## 🤝 **Contributing**

Padlock follows the BASHFX framework for maintainable bash development:

```bash
# Build from modular parts
./build.sh

# Run the safe gitsim-only proof
bin/e2e.sh

# Development workflow
func ls parts/06_api.sh           # List functions
func spy do_setup parts/06_api.sh # Examine function
```

## 📄 **License**

GPL v3+ - See LICENSE file for details.

---

**Padlock represents a modern approach to repository security that prioritizes developer experience while providing robust protection and recovery options for sensitive content. Its transparent workflow, comprehensive backup system, and intelligent repair capabilities make it ideal for protecting commercial IP, configuration secrets, and confidential documentation in git repositories.**
