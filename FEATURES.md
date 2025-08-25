# Padlock Features Reference

> **Complete reference for all implemented features with examples and technical details**

## 🎯 **Core Commands**

### **Setup & Configuration**

#### `padlock setup`
Interactive first-time configuration with master key and ignition backup creation.

```bash
# Interactive setup
padlock setup

# Example flow:
# → Creates global master key
# → Prompts for ignition backup passphrase
# → Configures secure storage structure
```

**Features:**
- ✅ Creates global master key automatically
- ✅ Prompts for passphrase-encrypted backup
- ✅ Skips gracefully in non-interactive environments
- ✅ Validates existing configuration

#### `padlock status`
Shows current repository state with next steps.

```bash
padlock status

# Example outputs:
# 🔒 Repository is LOCKED
# 🔓 Repository is UNLOCKED  
# 🚀 Repository in OVERDRIVE mode
```

**Features:**
- ✅ Lock/unlock state detection
- ✅ Next step recommendations  
- ✅ Key information display
- ✅ Error condition reporting

---

### **Repository Management**

#### `padlock clamp <path> [options]`
Deploy padlock security layer to any git repository.

```bash
# Basic deployment with repo-specific key
padlock clamp /my/repo --generate

# Use global master key
padlock clamp /my/repo --global-key

# Enable ignition mode (if supported)
padlock clamp /my/repo -K "my-ignition-phrase"

# Deploy to current directory
padlock clamp . --generate
```

**Options:**
- `--generate`: Create new repository-specific key
- `--global-key`: Use global master key
- `--key <file>`: Use specific key file
- `-K, --ignition [phrase]`: Enable ignition mode

**Creates:**
- `locker/` directory structure
- `bin/padlock` self-contained tools
- `.githooks/` for automatic encryption
- `.gitignore` and `.gitattributes` files
- Repository-specific key (if --generate)
- Manifest entry for tracking

#### `padlock declamp [path] [--force]`
Safely remove padlock infrastructure while preserving data.

```bash
# Safe removal with confirmation
padlock declamp

# Force removal without prompts
padlock declamp --force

# Remove from specific directory
padlock declamp /path/to/repo --force
```

**Features:**
- ✅ Unlocks repository first
- ✅ Removes git hooks and filters
- ✅ Cleans up configuration files
- ✅ Preserves plaintext content
- ✅ Updates manifest

#### `padlock repair [path]`
Intelligent repair of corrupted or incomplete installations.

```bash
# Repair current repository
padlock repair

# Repair specific repository
padlock repair /path/to/repo
```

**Repair Capabilities:**
- ✅ Detects missing `.padlock` files
- ✅ Reconstructs configuration from manifest
- ✅ Determines correct key configuration
- ✅ Handles both repo-specific and global keys
- ✅ Unlocks repository if needed for repair
- ✅ Validates repair success

---

### **Daily Operations**

#### `padlock lock`
Encrypt plaintext locker directory into secure blob.

```bash
padlock lock
```

**Process:**
1. Validates locker directory exists
2. Calculates MD5 checksum for integrity
3. Creates encrypted `locker.age` file
4. Removes plaintext `locker/` directory
5. Creates `.locked` status file
6. Saves checksum to `.locker_checksum`

**Features:**
- ✅ Atomic operation (fails safely)
- ✅ Integrity verification
- ✅ File count reporting
- ✅ Size information display

#### `padlock unlock`
Decrypt secure blob back to plaintext locker directory.

```bash
padlock unlock
```

**Process:**
1. Validates `locker.age` exists
2. Decrypts to temporary location first
3. Verifies integrity against stored checksum
4. Moves to final `locker/` location
5. Removes `locker.age` and `.locked` files

**Features:**
- ✅ Integrity verification on unlock
- ✅ Safe failure handling
- ✅ Checksum validation
- ✅ Atomic operation

---

### **Key Management**

#### `padlock key --generate-global [--force]`
Create new global master key.

```bash
# Create new global key
padlock key --generate-global

# Force overwrite existing key
padlock key --generate-global --force
```

**Features:**
- ✅ Creates ignition backup automatically
- ✅ Prompts for passphrase in interactive mode
- ✅ Skips prompts in non-interactive environments
- ✅ Protects against accidental overwrites

#### `padlock key --show-global`
Display global master key's public key.

```bash
padlock key --show-global

# Output: age1abc123def456...
```

#### `padlock key --set-global <keyfile>`
Set global master key from file.

```bash
padlock key --set-global /path/to/key.txt
```

#### `padlock key restore`
Restore master key from passphrase-encrypted ignition backup.

```bash
padlock key restore

# Interactive flow:
# → Prompts for ignition passphrase
# → Decrypts backup
# → Validates key integrity
# → Restores master key
```

**Features:**
- ✅ Validates backup exists
- ✅ Confirms overwrite of existing key
- ✅ Verifies restored key is valid
- ✅ Secure passphrase handling

#### `padlock key --add-recipient <public_key>`
Add team member access to current repository.

```bash
# Add team member
padlock key --add-recipient age1xyz789abc123...

# Repository must be unlocked
# Updates .padlock configuration
# Requires re-encryption with: padlock lock
```

---

### **Repository Discovery**

#### `padlock list [options]`
Show tracked repositories with advanced filtering.

```bash
# Show all repositories
padlock list

# Show all with metadata
padlock list --all

# Filter by namespace
padlock list --namespace github
padlock list --namespace local

# Show only ignition-enabled repositories
padlock list --ignition
```

**Manifest Format:**
```
namespace|name|path|type|remote|checksum|created|last_access|metadata
github|myproject|/home/user/proj|standard|git@github.com:user/proj.git|a1b2c3|2025-01-15T10:30:00Z|2025-01-15T14:20:00Z|
local|secrets|/home/user/secrets|ignition||f6e5d4|2025-01-15T11:45:00Z|2025-01-15T15:10:00Z|temp=true
```

#### `padlock clean-manifest`
Remove stale entries from repository tracking.

```bash
padlock clean-manifest
```

**Cleaning Logic:**
- ✅ Removes entries for non-existent paths
- ✅ Preserves header information
- ✅ Filters out temporary repositories
- ✅ Reports removed entries

---

### **Backup & Migration**

#### `padlock export [filename]`
Export complete padlock environment.

```bash
# Export to default filename
padlock export

# Export to specific file
padlock export my-backup.tar.age
```

**Exports:**
- ✅ All repository keys
- ✅ Global master key
- ✅ Manifest with repository tracking
- ✅ Configuration files
- ✅ Passphrase-encrypted bundle

#### `padlock import <filename> [--replace|--merge]`
Import padlock environment from export.

```bash
# Import with merge (default)
padlock import backup.tar.age

# Replace existing configuration
padlock import backup.tar.age --replace

# Merge with existing data
padlock import backup.tar.age --merge
```

#### `padlock snapshot [name]`
Create named backup snapshot.

```bash
# Create snapshot with timestamp
padlock snapshot

# Create named snapshot
padlock snapshot before-migration
```

#### `padlock rewind <name>`
Restore from named snapshot.

```bash
padlock rewind before-migration
```

---

### **Advanced Features**

#### `padlock overdrive lock`
Encrypt entire repository into traveling blob.

```bash
# Engage overdrive mode
padlock overdrive lock

# Creates:
# - super_chest.age (entire repo encrypted)
# - .overdrive (unlock script)
```

**Features:**
- ✅ Archives entire repository
- ✅ Excludes git history and temp files
- ✅ Creates deterministic checksums
- ✅ Generates unlock script
- ⚠️ Some edge cases remain

#### `source .overdrive`
Restore repository from overdrive mode.

```bash
# Disengage overdrive
source .overdrive

# Process:
# → Decrypts super_chest.age
# → Restores all files
# → Verifies integrity
# → Cleans up overdrive files
```

#### `padlock overdrive status`
Show overdrive mode information.

```bash
padlock overdrive status

# Shows:
# - Overdrive engagement status
# - Blob size information
# - Restore instructions
```

#### `padlock revoke`
Revoke encryption access and force re-key.

```bash
padlock revoke
```

**Process:**
- ✅ Removes repository-specific keys
- ✅ Removes encrypted ignition keys
- ✅ Updates manifest
- ✅ Forces key regeneration
- ✅ Provides recovery instructions

---

### **Installation & System**

#### `padlock install`
Install padlock globally for system-wide access.

```bash
padlock install
```

**Installation:**
- ✅ Copies to `~/.local/bin/`
- ✅ Creates necessary directories
- ✅ Sets up global configuration
- ✅ Validates age dependency

#### `padlock uninstall`
Remove global padlock installation.

```bash
padlock uninstall
```

#### `padlock version`
Show version information.

```bash
padlock version
# Output: padlock 1.0.0
```

#### `padlock help`
Show comprehensive command help.

```bash
padlock help
padlock --help
padlock -h
```

---

## 🔧 **Technical Implementation**

### **Security Architecture**

**Encryption Chain:**
```
User Content → Age Encryption → Git Storage
                ↑
     Master Key ← Ignition Backup (Passphrase)
```

**Key Hierarchy:**
1. **Master Key** (`global.key`): Primary encryption key
2. **Ignition Backup** (`ignition.age`): Passphrase-encrypted master key backup
3. **Repository Keys** (`<repo>.key`): Per-repository keys (optional)

### **File Structure**

**Repository Files:**
```
.
├── locker/              # Plaintext when unlocked
│   ├── docs_sec/       # Secure documentation
│   ├── conf_sec/       # Configuration secrets
│   └── .padlock        # Crypto configuration
├── locker.age          # Encrypted blob when locked
├── .locked             # Lock status indicator
├── .locker_checksum    # MD5 integrity hash
├── .githooks/          # Git automation
└── bin/padlock         # Self-contained tooling
```

**Global Configuration:**
```
~/.local/etc/padlock/
├── keys/
│   ├── global.key      # Master private key
│   ├── ignition.age    # Passphrase backup
│   └── *.key          # Repository keys
└── manifest.txt        # Repository tracking
```

### **Git Integration**

**Hooks:**
- **pre-commit**: Auto-encrypt locker, add checksum to commit
- **post-checkout**: Auto-decrypt after checkout
- **post-merge**: Refresh locker after merge
- **post-commit**: Verify encryption integrity

**Filters:**
- **clean**: Encrypt on git add
- **smudge**: Decrypt on git checkout

### **Integrity Verification**

**Checksum System:**
```bash
# Calculate during lock
find locker -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1

# Verify during unlock
# Compare stored vs. calculated checksum
```

---

## 🧪 **Testing Framework**

### **Test Categories**

1. **Build Verification**: Modular assembly validation
2. **Command Validation**: All commands respond correctly
3. **E2E Workflows**: Complete encryption cycles
4. **Repair Testing**: Corruption recovery scenarios
5. **Backup Systems**: Ignition and export/import
6. **Git Integration**: Hook and filter behavior
7. **Edge Cases**: Error conditions and recovery

### **Test Execution**

```bash
# Run comprehensive test suite
./test_runner.sh

# Test output format:
┌─ Test 01: Build Verification ──────────────────────────────────────────────────────────────┐
│ Building padlock.sh from modular components...
│ ✓ Build successful
└──────────────────────────────────────────────────────────────────────────────────────┘
```

**Features:**
- ✅ Ceremonious presentation with box drawing
- ✅ Tests both git and gitsim environments
- ✅ Validates new features comprehensively
- ✅ Uses `$HOME/.cache/tmp` for isolation
- ✅ Cleans up test environments automatically

---

## 📊 **Implementation Status**

### **Fully Implemented ✅**
- Standard locker encryption/decryption
- Git hooks and filter integration
- Master key generation and management
- Ignition backup system with passphrase protection
- Repository repair and recovery tools
- Interactive setup and configuration
- Manifest-based repository tracking
- Team collaboration via public keys
- Export/import for environment migration
- Comprehensive testing framework
- Integrity verification with checksums
- Safe repository declamp and cleanup

### **Partially Implemented 🚧**
- **Overdrive Mode**: Core functionality works, some edge cases remain
  - ✅ Repository archiving and encryption
  - ✅ Basic unlock script generation
  - ⚠️ Variable scoping issues in unlock
  - ⚠️ Some tar timestamp warnings

### **Planned 📋**
- Web interface for repository management
- CI/CD integration helpers
- Advanced backup rotation strategies
- Multi-user permission systems
- Cloud storage integration

---

**This document represents the complete feature set as implemented. All ✅ marked features are fully functional and tested.**