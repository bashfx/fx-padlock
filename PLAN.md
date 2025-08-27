# Padlock Ignition Key System - Complete Implementation Plan

## Summary  
**CRITICAL FINDING**: The current "ignition" system is NOT a third-party API system. It's a master key backup system that has been incorrectly named. The user is correct - there is no functioning ignite key API for third parties and automation.

## Root Cause Analysis

### The Real Problem
The user correctly identified that there is no working ignition key system for AI/automation access. The current implementation has these fatal flaws:

1. **Wrong System**: Current "ignition" is just master key backup (disaster recovery)
2. **No Third-Party Access**: No separate ignition keys for AI/automation  
3. **Naming Confusion**: Master key backup system using "ignition" terminology
4. **Missing API**: No commands to create/manage/use ignition keys for third parties

### What Currently Exists (Master Key Backup System)

**Current System Purpose**: Disaster recovery for master key
- `_create_ignition_backup()` - Encrypts **master key** with passphrase for backup
- `padlock setup ignition` - Creates master key backup at `$PADLOCK_KEYS/ignition.age`
- `padlock key restore` - Restores master key from backup
- **Use Case**: "I lost my master key, need to restore from backup"

### What Should Exist (Third-Party Ignition System)

**Required System Purpose**: Third-party/AI access to repositories
- `padlock ignite --create` - Creates **separate age keypair** for third-party access
- `padlock ignite --unlock` - Unlocks repository using ignition key + passphrase
- `padlock ignite --list` - Lists available ignition keys
- **Use Case**: "AI needs to access my encrypted repository with a simple passphrase"

## Required Implementation: True Ignition Key System

### Design Principles

1. **Separate from Master Key**: Ignition keys are completely independent age keypairs
2. **Repository-Specific**: Each repo can have its own ignition keys  
3. **Passphrase-Based**: Simple `PADLOCK_IGNITION_PASS="phrase"` access
4. **Multiple Keys**: Support multiple named ignition keys per repo
5. **No Security Degradation**: Ignition access shouldn't weaken master key security

### New File Structure

```
.ignite/                          # New ignition key directory (separate from .chest)
├── keys/                        # Ignition keypairs
│   ├── default.key              # Default ignition private key
│   ├── default.key.pub          # Default ignition public key  
│   ├── ai-assistant.key         # Named ignition key
│   └── automation.key           # Another named ignition key
├── passphrases.age             # Encrypted mapping of key names to passphrases
└── config                      # Ignition system config
```

### New API Commands

#### Core Ignition Management
```bash
# Create default ignition key
padlock ignite --create                          # Auto-generated passphrase
padlock ignite --create --passphrase "my-phrase" # Custom passphrase

# Create named ignition key  
padlock ignite --create --name ai-assistant --passphrase "ai-phrase"

# List ignition keys
padlock ignite --list
# Output:
#   default       (created 2025-01-01, last used 2025-01-02)
#   ai-assistant  (created 2025-01-01, never used)

# Remove ignition key
padlock ignite --remove --name ai-assistant
```

#### Ignition Access
```bash  
# Unlock using default ignition key
PADLOCK_IGNITION_PASS="my-phrase" padlock ignite --unlock

# Unlock using named ignition key
PADLOCK_IGNITION_PASS="ai-phrase" padlock ignite --unlock --name ai-assistant

# Lock for ignition access (creates ignition-encrypted copy)
padlock ignite --lock                            # Default key
padlock ignite --lock --name ai-assistant        # Named key

# Status of ignition system
padlock ignite --status
# Output:
#   Ignition keys: 2 available
#   Locker status: unlocked (can be locked for ignition access)  
#   Last ignition unlock: 2025-01-01 14:30 (ai-assistant key)
```

### Implementation Architecture

#### Phase 1: Core Ignition System

**New Functions** (add to `parts/04_helpers.sh`):
```bash
_create_ignition_key()          # Create new ignition age keypair
_encrypt_for_ignition()         # Encrypt locker for ignition key access  
_decrypt_with_ignition()        # Decrypt locker using ignition key
_list_ignition_keys()           # Show available ignition keys
_remove_ignition_key()          # Remove ignition key safely
```

**Enhanced Functions** (update in `parts/06_api.sh`):
```bash
do_ignite()                     # Complete rewrite for true ignition API
_ignition_status()              # Show ignition system status
```

#### Phase 2: Integration Points

**Clamp Integration**:
- `padlock clamp -K` creates default ignition key (not master key backup)
- Stores ignition key in `.ignite/` directory  
- Shows ignition passphrase for sharing

**Git Hook Integration**: 
- Pre-commit hook can auto-lock for ignition access
- Post-checkout hook can auto-unlock with ignition key if available

#### Phase 3: Advanced Features

**Multiple Key Support**:
- Named ignition keys for different use cases
- Key rotation and lifecycle management
- Usage tracking and audit logs

**Security Features**:
- Ignition key expiration  
- Access logging
- Revocation capabilities

## Implementation Plan

### Step 1: Rename Current System (Master Key Backup)
**Goal**: Fix naming confusion
- Rename `_create_ignition_backup()` → `_create_master_backup()`
- Update `padlock setup ignition` → `padlock setup backup`  
- Keep functionality intact but with correct naming
- Update documentation to clarify this is for disaster recovery

### Step 2: Implement True Ignition System
**Goal**: Create actual third-party access system

#### 2.1 Core Data Structures
```bash
# ~/.local/etc/padlock/ignition/
PADLOCK_IGNITION_DIR="$HOME/.local/etc/padlock/ignition"

# Per-repo ignition keys
.ignite/
├── keys/default.key           # Private key
├── keys/default.key.pub       # Public key (age recipient)  
├── passphrases.age           # Encrypted passphrase mapping
└── config                    # Ignition config
```

#### 2.2 New Helper Functions
```bash
_setup_ignition_dir() {
    mkdir -p "$REPO_ROOT/.ignite/keys"
    # Initialize ignition system for repository
}

_create_ignition_key() {
    local key_name="${1:-default}"
    local passphrase="$2"
    
    # Generate age keypair specifically for ignition access
    local private_key="$REPO_ROOT/.ignite/keys/$key_name.key"
    local public_key="$REPO_ROOT/.ignite/keys/$key_name.key.pub"
    
    age-keygen -o "$private_key"
    age-keygen -y "$private_key" > "$public_key"
    
    # Store encrypted passphrase mapping
    echo "$passphrase" | age -r "$(cat "$public_key")" > "$REPO_ROOT/.ignite/passphrases.age"
}

_ignition_encrypt() {
    local key_name="${1:-default}"
    local public_key="$REPO_ROOT/.ignite/keys/$key_name.key.pub"
    
    # Encrypt locker for ignition access
    tar -czf - -C "$REPO_ROOT" locker | age -r "$(cat "$public_key")" > "$REPO_ROOT/.ignite/locker-$key_name.age"
}

_ignition_decrypt() {
    local key_name="${1:-default}"  
    local passphrase="$PADLOCK_IGNITION_PASS"
    local private_key="$REPO_ROOT/.ignite/keys/$key_name.key"
    
    # Decrypt locker using ignition key
    age -d -i "$private_key" < "$REPO_ROOT/.ignite/locker-$key_name.age" | tar -xzf - -C "$REPO_ROOT"
}
```

#### 2.3 New API Implementation
```bash
do_ignite() {
    local action="$1"
    local key_name="default"
    local passphrase=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --create) action="create"; shift ;;
            --unlock) action="unlock"; shift ;;
            --lock) action="lock"; shift ;;
            --list) action="list"; shift ;;
            --remove) action="remove"; shift ;;
            --name) key_name="$2"; shift 2 ;;
            --passphrase) passphrase="$2"; shift 2 ;;
            --help) action="help"; shift ;;
            *) shift ;;
        esac
    done
    
    case "$action" in
        create) _ignition_create "$key_name" "$passphrase" ;;
        unlock) _ignition_unlock "$key_name" ;;
        lock) _ignition_lock "$key_name" ;;
        list) _ignition_list ;;
        remove) _ignition_remove "$key_name" ;;
        help|*) _ignition_help ;;
    esac
}
```

### Step 3: Integration & Testing

#### 3.1 Update Clamp Command
```bash
# In do_clamp(), replace current ignition logic:
if [[ "$use_ignition" == true ]]; then
    _setup_ignition_dir
    _create_ignition_key "default" "$ignition_key"
    info "🔥 Ignition key created for third-party access"
    info "🔑 Passphrase: $ignition_key"
fi
```

#### 3.2 Test Scenarios
```bash
# Basic workflow test
cd /tmp/test-ignite  
git init
padlock clamp . -K "test-automation-key"

# Verify ignition key creation
ls -la .ignite/keys/
# Should show: default.key, default.key.pub

# Test ignition lock/unlock cycle  
echo "secret" > locker/test.txt
padlock ignite --lock
ls locker/  # Should be empty (locked)

PADLOCK_IGNITION_PASS="test-automation-key" padlock ignite --unlock  
ls locker/  # Should show test.txt (unlocked)
```

### Step 4: Documentation & Migration

#### 4.1 Update Help Text
- Fix help text to show correct ignition commands
- Clarify difference between master backup and ignition access
- Update examples to show proper third-party usage

#### 4.2 Migration Strategy  
- Keep old "ignition backup" system for backward compatibility
- Add deprecation warnings for old terminology
- Provide migration path for existing users

## Success Criteria

### Functional Requirements ✅
- ✅ `padlock ignite --create` generates new age keypair for third-party access
- ✅ `PADLOCK_IGNITION_PASS="phrase" padlock ignite --unlock` decrypts locker
- ✅ `padlock ignite --lock` creates ignition-encrypted copy  
- ✅ `padlock ignite --list` shows available ignition keys
- ✅ System is completely separate from master key backup

### User Experience Requirements ✅  
- ✅ AI/automation can access repositories with simple passphrase
- ✅ Multiple ignition keys supported for different use cases
- ✅ Clear error messages and help text
- ✅ No confusion with master key backup system

### Security Requirements ✅
- ✅ Ignition keys don't weaken master key security  
- ✅ Repository owner controls ignition key creation/removal
- ✅ Passphrase-based access is properly encrypted
- ✅ Ignition access can be revoked independently

## Timeline

**Immediate (4-6 hours)**:
- Implement core ignition system with basic create/unlock/lock
- Test with simple passphrase workflow
- Update clamp integration

**Short-term (1-2 days)**:  
- Add named key support and management commands
- Comprehensive testing and error handling
- Documentation updates

**Long-term (optional)**:
- Advanced features (expiration, audit logs, etc.)
- Migration tools for existing users
- Integration with other padlock features

---

**Bottom Line**: The user is absolutely correct. There is no functioning ignition key API for third parties. The current system is a master key backup feature that was incorrectly named. We need to implement a completely separate ignition key system from scratch for true AI/automation access.