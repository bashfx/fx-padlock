# Padlock Feature Roadmap

## 🎯 **Overview**

This document outlines the planned feature enhancements for Padlock, focusing on the **Ignition Key System** and **Enhanced Manifest Management**. These features enable secure AI collaboration while maintaining the core security principles.

## 🔑 **Core Feature Sets**

### **1. Ignition Key System**
A two-stage encryption system where the ignition key acts as a "key to the key" - perfect for AI collaboration and automation.

```
Developer's Private Key → Ignition Key → Locker Contents
       (Never shared)      (Shareable)    (Protected)
```

### **2. .chest Directory Management**
Clean state management where encrypted artifacts live in `.chest/` when locked, and working files live in `locker/` when unlocked. **Never both simultaneously**.

### **3. Enhanced Manifest System**
Columnar format manifest tracking with automatic temp directory detection and metadata support.

## 🚀 **Phase 1: .chest Foundation**
*Priority: HIGH - Core infrastructure*

### **Features**
- ✅ `.chest/` directory structure
- ✅ Clean state transitions (chest ↔ locker)
- ✅ Basic ignition lock/unlock commands
- ✅ Enhanced `.locked` script detection

### **Implementation Tasks**

#### **Task 1.1: .chest Directory Management**
```bash
# New functions to add to parts/04_helpers.sh
create_chest() {
    mkdir -p "$REPO_ROOT/.chest"
    # Move artifacts to .chest/
}

unlock_chest() {
    # .chest/locker.age → locker/
    # Remove .chest/ entirely
}

lock_chest() {
    # locker/ → .chest/locker.age  
    # Remove locker/
    # Recreate .chest/
}
```

#### **Task 1.2: State Detection Functions**
```bash
# Add to parts/04_helpers.sh
is_chest_repo() {
    [[ -d "$1/.chest" ]]
}

get_chest_state() {
    if [[ -d "$REPO_ROOT/.chest" ]]; then
        echo "locked"
    elif [[ -d "$REPO_ROOT/locker" ]]; then
        echo "unlocked"  
    else
        echo "unknown"
    fi
}
```

#### **Task 1.3: Enhanced .locked Script**
```bash
# Update __print_locked_file() in parts/05_printers.sh
__print_locked_file() {
    cat > "$file" << 'EOF'
#!/bin/bash
if [[ -d ".chest" ]]; then
    echo "🗃️  Chest system detected"
    echo "🔑 Run: bin/padlock ignite --unlock"
    exit 1
elif [[ -f "locker.age" ]]; then
    # Standard padlock workflow
fi
EOF
}
```

#### **Task 1.4: Basic Ignition Commands**
```bash
# Add to parts/06_api.sh
do_ignite() {
    local action="$1"
    case "$action" in
        --unlock) _unlock_chest ;;
        --lock) _lock_chest ;;
        --status) _chest_status ;;
    esac
}
```

**Acceptance Criteria:**
- [ ] `.chest/` created when using ignition system
- [ ] Clean state transitions (never both chest + locker)
- [ ] `padlock ignite --unlock/--lock` commands work
- [ ] Enhanced `.locked` script detects chest system

---

## 🔑 **Phase 2: Ignition Key Management**
*Priority: HIGH - Core functionality*

### **Features**
- ✅ `-K` flag for ignition setup
- ✅ Auto-generated memorable ignition keys
- ✅ Ignition key rotation
- ✅ Environment variable support

### **Implementation Tasks**

#### **Task 2.1: Enhanced do_clamp() with -K Flag**
```bash
# Update do_clamp() in parts/06_api.sh
do_clamp() {
    local use_ignition=false
    local ignition_key=""
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -K|--ignition)
                use_ignition=true
                if [[ -n "$2" && "$2" != -* ]]; then
                    ignition_key="$2"
                    shift 2
                else
                    shift
                fi
                ;;
        esac
    done
    
    if [[ "$use_ignition" == true ]]; then
        _setup_ignition_system "$ignition_key"
    fi
}
```

#### **Task 2.2: Ignition Key Generation**
```bash
# Add to parts/04_helpers.sh
_generate_ignition_key() {
    local words=("flame" "rocket" "boost" "spark" "launch" "fire" "power" "thrust" "ignite" "blast")
    local key=""
    for i in {1..6}; do
        key+="${words[$RANDOM % ${#words[@]}]}"
        [[ $i -lt 6 ]] && key+="-"
    done
    echo "$key"
}

_setup_ignition_system() {
    local ignition_key="${1:-$(_generate_ignition_key)}"
    
    # Generate ignition keypair
    age-keygen -o "$REPO_ROOT/.ignition.key"
    local ignition_public=$(grep "public key:" "$REPO_ROOT/.ignition.key" | awk '{print $4}')
    
    # Encrypt ignition key with passphrase
    AGE_PASSPHRASE="$ignition_key" age -p < "$REPO_ROOT/.ignition.key" > "$REPO_ROOT/.chest/ignition.age"
    rm "$REPO_ROOT/.ignition.key"
    
    # Configure system to use ignition key
    export AGE_RECIPIENTS="$ignition_public"
    
    okay "🔑 Ignition key: $ignition_key"
    info "Share this key for AI/automation access"
}
```

#### **Task 2.3: Environment Variable Support**
```bash
# Add to parts/04_helpers.sh
_unlock_ignition() {
    local passphrase="${PADLOCK_IGNITION_PASS:-}"
    
    if [[ -z "$passphrase" ]]; then
        read -s -p "Ignition passphrase: " passphrase
        echo
    fi
    
    # Decrypt ignition.age → .ignition.key (temporary)
    AGE_PASSPHRASE="$passphrase" age -d -p < "$REPO_ROOT/.chest/ignition.age" > "$REPO_ROOT/.ignition.key"
    export AGE_KEY_FILE="$REPO_ROOT/.ignition.key"
    export PADLOCK_IGNITION_ACTIVE=1
}
```

#### **Task 2.4: Ignition Rotation**
```bash
# Add to parts/06_api.sh
do_rotate() {
    local target="$1"
    case "$target" in
        -K|--ignition)
            _rotate_ignition_key
            ;;
    esac
}

_rotate_ignition_key() {
    local new_key="$(_generate_ignition_key)"
    local old_ignition_file="$REPO_ROOT/.chest/ignition.age"
    
    # Re-encrypt with new passphrase
    AGE_PASSPHRASE="$old_passphrase" age -d -p < "$old_ignition_file" | \
    AGE_PASSPHRASE="$new_key" age -p > "$old_ignition_file.new"
    
    mv "$old_ignition_file.new" "$old_ignition_file"
    okay "🔄 Ignition key rotated: $new_key"
}
```

**Acceptance Criteria:**
- [ ] `padlock clamp /repo -K` auto-generates ignition key
- [ ] `padlock clamp /repo -K "custom-key"` uses custom key
- [ ] `PADLOCK_IGNITION_PASS` environment variable works
- [ ] `padlock rotate -K` generates new ignition key
- [ ] Memorable 6-word ignition keys generated

---

## 📋 **Phase 3: Enhanced Manifest System**
*Priority: MEDIUM - Management & cleanup*

### **Features**
- ✅ Columnar manifest format
- ✅ Automatic temp directory detection
- ✅ Repository type tracking (standard vs ignition)
- ✅ Manifest management commands

### **Implementation Tasks**

#### **Task 3.1: Enhanced Columnar Manifest Format**
```bash
# Update manifest functions in parts/06_api.sh
_add_to_manifest() {
    local repo_path="$1"
    local repo_type="${2:-standard}"
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    local now=$(date -Iseconds 2>/dev/null || date)
    
    # Create header if empty
    if [[ ! -s "$manifest_file" ]]; then
        echo "# Padlock Repository Manifest v2.0" > "$manifest_file"
        echo "# Format: namespace|name|path|type|remote|checksum|created|last_access|metadata" >> "$manifest_file"
    fi
    
    # Generate clean name and namespace
    local repo_name=$(basename "$repo_path")
    local namespace="local"
    local remote_url=""
    local checksum=""
    
    # Get git remote if available
    if [[ -d "$repo_path/.git" ]]; then
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            # Extract namespace from remote (e.g., github.com/user/repo → user)
            if [[ "$remote_url" =~ github\.com[:/]([^/]+)/([^/]+) ]]; then
                namespace="${BASH_REMATCH[1]}"
                repo_name="${BASH_REMATCH[2]%.git}"
            fi
        fi
    fi
    
    # Generate repository checksum (for integrity tracking)
    checksum=$(echo "$repo_path|$repo_type|$now" | sha256sum | cut -d' ' -f1 | head -c 12)
    
    # Skip if already exists
    if grep -q "|${repo_path}|" "$manifest_file" 2>/dev/null; then
        return 0
    fi
    
    # Detect temp directories
    local metadata=""
    if [[ "$repo_path" == */tmp/* ]] || [[ "$repo_path" == */temp/* ]]; then
        metadata="temp=true"
    fi
    
    echo "$namespace|$repo_name|$repo_path|$repo_type|$remote_url|$checksum|$now|$now|$metadata" >> "$manifest_file"
}
```

#### **Task 3.2: Manifest Management Commands**
```bash
# Add to parts/06_api.sh
do_list() {
    local filter="$1"
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    
    case "$filter" in
        --all)
            awk -F'|' '!/^#/ { printf "%-15s %-20s %s (%s)\n", $1, $2, $3, $4 }' "$manifest_file"
            ;;
        --ignition)
            awk -F'|' '!/^#/ && $4 == "ignition" && $9 !~ /temp=true/ { printf "%-15s %-20s %s\n", $1, $2, $3 }' "$manifest_file"
            ;;
        --namespace)
            local ns="$2"
            awk -F'|' -v namespace="$ns" '!/^#/ && $1 == namespace && $9 !~ /temp=true/ { printf "%-20s %s (%s)\n", $2, $3, $4 }' "$manifest_file"
            ;;
        *)
            # Default: exclude temp directories, show namespace/name/path
            awk -F'|' '!/^#/ && $9 !~ /temp=true/ && $3 !~ /\/tmp\// { printf "%-15s %-20s %s (%s)\n", $1, $2, $3, $4 }' "$manifest_file"
            ;;
    esac
}

do_clean_manifest() {
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    local temp_file=$(mktemp)
    
    # Preserve header
    grep "^#" "$manifest_file" > "$temp_file"
    
    while IFS='|' read -r namespace name path type remote checksum created access metadata; do
        [[ "$namespace" =~ ^# ]] && continue
        
        # Skip temp or non-existent
        if [[ "$metadata" == *"temp=true"* ]] || [[ "$path" == */tmp/* ]] || [[ ! -d "$path" ]]; then
            trace "Removing from manifest: $namespace/$name ($path)"
            continue
        fi
        
        echo "$namespace|$name|$path|$type|$remote|$checksum|$created|$access|$metadata"
    done < <(grep -v "^#" "$manifest_file") >> "$temp_file"
    
    mv "$temp_file" "$manifest_file"
    okay "Manifest cleaned"
}
```

#### **Task 3.3: Update do_clamp() Integration**
```bash
# In do_clamp(), replace current manifest code with:
if [[ "$use_ignition" == true ]]; then
    _add_to_manifest "$REPO_ROOT" "ignition"
else
    _add_to_manifest "$REPO_ROOT" "standard"
fi
```

**Acceptance Criteria:**
- [ ] Manifest uses enhanced columnar format with namespace and remote info
- [ ] Temp directories automatically flagged and filtered
- [ ] Repository checksums generated for integrity tracking
- [ ] `padlock list` shows namespace/name/path format
- [ ] `padlock list --namespace github` shows repos from specific namespace
- [ ] `padlock list --ignition` shows only ignition repos
- [ ] `padlock clean-manifest` removes temp/non-existent repos

---

## 🔄 **Phase 6: Export/Import System**
*Priority: MEDIUM - Backup & Migration*

### **Features**
- ✅ Encrypted manifest export with embedded keys
- ✅ Secure import with passphrase protection
- ✅ Cross-system padlock environment migration
- ✅ Rewindable backup snapshots

### **Implementation Tasks**

#### **Task 6.1: Export System**
```bash
# Add to parts/06_api.sh
do_export() {
    local export_file="${1:-padlock_export_$(date +%Y%m%d_%H%M%S).tar.age}"
    local passphrase="$2"
    
    if [[ -z "$passphrase" ]]; then
        read -s -p "Export passphrase: " passphrase
        echo
    fi
    
    local temp_dir=$(mktemp -d)
    local export_manifest="$temp_dir/manifest.txt"
    local keys_dir="$temp_dir/keys"
    
    # Copy manifest and keys
    cp "$PADLOCK_ETC/manifest.txt" "$export_manifest"
    cp -r "$PADLOCK_KEYS" "$keys_dir"
    
    # Create export metadata
    cat > "$temp_dir/export_info.json" << EOF
{
    "version": "1.0",
    "exported_at": "$(date -Iseconds)",
    "exported_by": "$(whoami)@$(hostname)",
    "padlock_version": "$PADLOCK_VERSION",
    "total_repos": $(grep -v "^#" "$PADLOCK_ETC/manifest.txt" | wc -l),
    "total_keys": $(find "$PADLOCK_KEYS" -name "*.key" | wc -l)
}
EOF
    
    # Create encrypted archive
    tar -C "$temp_dir" -czf - . | AGE_PASSPHRASE="$passphrase" age -p > "$export_file"
    
    rm -rf "$temp_dir"
    
    okay "Exported padlock environment to: $export_file"
    info "Contains: manifest + $(find "$PADLOCK_KEYS" -name "*.key" | wc -l) keys"
    warn "Keep the passphrase secure - it protects all your keys!"
}

do_import() {
    local import_file="$1"
    local passphrase="$2"
    local merge_mode="${3:---merge}"  # or --replace
    
    if [[ ! -f "$import_file" ]]; then
        fatal "Import file not found: $import_file"
    fi
    
    if [[ -z "$passphrase" ]]; then
        read -s -p "Import passphrase: " passphrase
        echo
    fi
    
    local temp_dir=$(mktemp -d)
    
    # Decrypt and extract
    if ! AGE_PASSPHRASE="$passphrase" age -d -p < "$import_file" | tar -C "$temp_dir" -xzf -; then
        fatal "Failed to decrypt import file (wrong passphrase?)"
    fi
    
    # Validate import
    if [[ ! -f "$temp_dir/export_info.json" ]] || [[ ! -f "$temp_dir/manifest.txt" ]]; then
        fatal "Invalid padlock export file"
    fi
    
    # Show import info
    local export_info=$(cat "$temp_dir/export_info.json")
    info "Import info: $export_info"
    
    # Backup current state
    local backup_dir="$PADLOCK_ETC/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    cp -r "$PADLOCK_ETC"/* "$backup_dir/" 2>/dev/null || true
    
    # Import based on mode
    case "$merge_mode" in
        --replace)
            warn "Replacing current padlock environment"
            rm -f "$PADLOCK_ETC/manifest.txt"
            rm -rf "$PADLOCK_KEYS"
            mkdir -p "$PADLOCK_KEYS"
            ;;
        --merge)
            info "Merging with current environment"
            ;;
    esac
    
    # Import manifest (merge or replace)
    if [[ "$merge_mode" == "--merge" ]]; then
        _merge_manifests "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
    else
        cp "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
    fi
    
    # Import keys
    cp -r "$temp_dir/keys"/* "$PADLOCK_KEYS/"
    
    rm -rf "$temp_dir"
    
    okay "Import completed successfully"
    info "Backup saved to: $backup_dir"
    info "Run 'padlock list' to verify imported repositories"
}

_merge_manifests() {
    local import_manifest="$1"
    local current_manifest="$2"
    local temp_file=$(mktemp)
    
    # Preserve header from current manifest
    grep "^#" "$current_manifest" > "$temp_file" 2>/dev/null || true
    
    # Merge entries (avoid duplicates by checking path column)
    {
        grep -v "^#" "$current_manifest" 2>/dev/null || true
        grep -v "^#" "$import_manifest" 2>/dev/null || true
    } | sort -t'|' -k3,3 -u >> "$temp_file"
    
    mv "$temp_file" "$current_manifest"
}
```

#### **Task 6.2: Rewindable Snapshots**
```bash
# Add snapshot functionality
do_snapshot() {
    local snapshot_name="${1:-auto_$(date +%Y%m%d_%H%M%S)}"
    local snapshots_dir="$PADLOCK_ETC/snapshots"
    
    mkdir -p "$snapshots_dir"
    
    # Create snapshot export
    do_export "$snapshots_dir/${snapshot_name}.tar.age" "snapshot-$(date +%s)"
    
    # Create snapshot metadata
    cat > "$snapshots_dir/${snapshot_name}.info" << EOF
name=$snapshot_name
created=$(date -Iseconds)
repos=$(grep -v "^#" "$PADLOCK_ETC/manifest.txt" | wc -l)
keys=$(find "$PADLOCK_KEYS" -name "*.key" | wc -l)
EOF
    
    okay "Snapshot created: $snapshot_name"
}

do_rewind() {
    local snapshot_name="$1"
    local snapshots_dir="$PADLOCK_ETC/snapshots"
    
    if [[ ! -f "$snapshots_dir/${snapshot_name}.tar.age" ]]; then
        error "Snapshot not found: $snapshot_name"
        info "Available snapshots:"
        ls -1 "$snapshots_dir"/*.info 2>/dev/null | sed 's/.info$//' | xargs -I {} basename {}
        return 1
    fi
    
    warn "This will replace your current padlock environment"
    if ! __confirm_destructive "Rewind to snapshot: $snapshot_name"; then
        info "Rewind cancelled"
        return 0
    fi
    
    # Import snapshot with replace mode
    do_import "$snapshots_dir/${snapshot_name}.tar.age" "snapshot-$(date +%s)" --replace
    
    okay "Rewound to snapshot: $snapshot_name"
}
```

**Acceptance Criteria:**
- [ ] `padlock export` creates encrypted backup with all keys and manifest
- [ ] `padlock import` restores environment from backup
- [ ] `padlock import --merge` combines with existing environment  
- [ ] `padlock snapshot` creates named backup points
- [ ] `padlock rewind` restores to previous snapshot
- [ ] Export includes metadata (version, date, counts)
- [ ] Import validates file integrity before proceeding

---

## 🔐 **Phase 4: Locker Integrity & Declamp**
*Priority: MEDIUM - Safety & cleanup features*

### **Features**
- ✅ MD5 checksum verification of locker directory contents
- ✅ Integrity validation during lock/unlock cycles
- ✅ Safe declamp operation (non-destructive padlock removal)
- ✅ Repository cleanup without data loss

### **Implementation Tasks**

#### **Task 4.1: Locker Integrity Checksums**
```bash
# Add to parts/04_helpers.sh
_calculate_locker_checksum() {
    local locker_dir="$1"
    
    if [[ ! -d "$locker_dir" ]]; then
        echo "no-locker"
        return 0
    fi
    
    # Create deterministic checksum of all files in locker
    find "$locker_dir" -type f -exec md5sum {} \; 2>/dev/null | \
        sort -k2 | \
        md5sum | \
        cut -d' ' -f1
}

_verify_locker_integrity() {
    local expected_checksum="$1"
    local current_checksum
    
    current_checksum=$(_calculate_locker_checksum "$LOCKER_DIR")
    
    if [[ "$current_checksum" != "$expected_checksum" ]]; then
        warn "⚠️  Locker integrity check failed!"
        info "Expected: $expected_checksum"
        info "Current:  $current_checksum"
        return 1
    fi
    
    trace "✓ Locker integrity verified: $current_checksum"
    return 0
}
```

#### **Task 4.2: Enhanced .locked with Checksum**
```bash
# Update __print_locked_file() in parts/05_printers.sh
__print_locked_file() {
    local file="$1"
    local locker_checksum
    
    # Calculate checksum of current locker contents
    if [[ -d "$LOCKER_DIR" ]]; then
        locker_checksum=$(_calculate_locker_checksum "$LOCKER_DIR")
    else
        locker_checksum="no-locker"
    fi
    
    cat > "$file" << EOF
#!/bin/bash
# Padlock unlock script with integrity verification
# Generated: $(date)
# Locker checksum: $locker_checksum

EXPECTED_CHECKSUM="$locker_checksum"

verify_integrity() {
    if [[ "\$EXPECTED_CHECKSUM" == "no-locker" ]]; then
        return 0  # No baseline to check against
    fi
    
    local current_checksum
    current_checksum=\$(find locker -type f -exec md5sum {} \\; 2>/dev/null | sort -k2 | md5sum | cut -d' ' -f1)
    
    if [[ "\$current_checksum" != "\$EXPECTED_CHECKSUM" ]]; then
        echo "⚠️  Warning: Locker contents may have been modified"
        echo "   Expected: \$EXPECTED_CHECKSUM"
        echo "   Current:  \$current_checksum"
        echo "   Continue anyway? (y/N)"
        read -r response
        [[ "\$response" =~ ^[Yy] ]] || exit 1
    else
        echo "✓ Locker integrity verified"
    fi
}

# Main unlock logic
if [[ -d ".chest" ]]; then
    echo "🗃️  Chest system detected"
    echo "🔑 Run: bin/padlock ignite --unlock"
    exit 1
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
    fi
fi
EOF
}
```

#### **Task 4.3: Integration with Lock/Unlock**
```bash
# Update do_lock() in parts/06_api.sh
do_lock() {
    # ... existing validation ...
    
    # Calculate and store checksum before locking
    local pre_lock_checksum
    pre_lock_checksum=$(_calculate_locker_checksum "$LOCKER_DIR")
    
    lock "🔐 Locking locker..."
    
    # ... existing encryption logic ...
    
    # Create .locked file with checksum
    __print_locked_file "$REPO_ROOT/.locked"
    
    # Remove plaintext locker
    rm -rf "$LOCKER_DIR"
    
    okay "Locker locked → locker.age (checksum: ${pre_lock_checksum:0:8}...)"
}

# Update do_unlock() in parts/06_api.sh  
do_unlock() {
    # ... existing validation and decryption ...
    
    if [[ -d "$LOCKER_DIR" ]] && [[ -f "$LOCKER_CONFIG" ]]; then
        # Verify integrity if we have a baseline
        if [[ -f "$REPO_ROOT/.locked" ]]; then
            local expected_checksum
            expected_checksum=$(grep "EXPECTED_CHECKSUM=" "$REPO_ROOT/.locked" | cut -d'"' -f2)
            
            if [[ "$expected_checksum" != "no-locker" ]]; then
                if _verify_locker_integrity "$expected_checksum"; then
                    trace "Integrity check passed"
                else
                    warn "Integrity check failed - contents may have been modified"
                fi
            fi
        fi
        
        # ... rest of unlock logic ...
    fi
}
```

#### **Task 4.4: Safe Declamp Operation**
```bash
# Add to parts/06_api.sh
do_declamp() {
    local repo_path="${1:-.}"
    local force="${2:-}"
    
    repo_path="$(realpath "$repo_path")"
    REPO_ROOT="$(_get_repo_root "$repo_path")"
    
    if ! is_deployed "$REPO_ROOT"; then
        error "Padlock not deployed in this repository"
        return 1
    fi
    
    lock "🔓 Safely declamping padlock..."
    
    # Ensure repository is unlocked first
    if [[ -f "$REPO_ROOT/locker.age" ]] || [[ -d "$REPO_ROOT/.chest" ]]; then
        if [[ "$force" != "--force" ]]; then
            error "Repository is locked. Unlock first or use --force"
            info "Run: source .locked"
            info "Or: padlock declamp --force"
            return 1
        fi
        
        # Force unlock before declamp
        warn "Force-unlocking locked repository"
        if [[ -f "$REPO_ROOT/locker.age" ]]; then
            if ! do_unlock; then
                fatal "Failed to unlock repository for declamp"
            fi
        elif [[ -d "$REPO_ROOT/.chest" ]]; then
            if ! do_ignite --unlock; then
                fatal "Failed to unlock chest for declamp"
            fi
        fi
    fi
    
    # Verify locker directory exists and has content
    if [[ ! -d "$REPO_ROOT/locker" ]]; then
        warn "No locker directory found - nothing to preserve"
    else
        local file_count
        file_count=$(find "$REPO_ROOT/locker" -type f | wc -l)
        info "Preserving $file_count files from locker/"
    fi
    
    # Remove padlock infrastructure (but preserve locker/)
    local removed_items=()
    
    # Remove bin directory
    if [[ -d "$REPO_ROOT/bin" ]]; then
        rm -rf "$REPO_ROOT/bin"
        removed_items+=("bin/")
    fi
    
    # Remove git hooks
    if [[ -d "$REPO_ROOT/.githooks" ]]; then
        rm -rf "$REPO_ROOT/.githooks"
        removed_items+=(".githooks/")
    fi
    
    # Remove encrypted artifacts
    rm -f "$REPO_ROOT/locker.age"
    rm -f "$REPO_ROOT/.locked"
    rm -rf "$REPO_ROOT/.chest"
    rm -f "$REPO_ROOT/.ignition.key"
    [[ -f "$REPO_ROOT/locker.age" ]] && removed_items+=("locker.age")
    [[ -f "$REPO_ROOT/.locked" ]] && removed_items+=(".locked")
    [[ -d "$REPO_ROOT/.chest" ]] && removed_items+=(".chest/")
    
    # Clean up .gitattributes (remove padlock lines)
    if [[ -f "$REPO_ROOT/.gitattributes" ]]; then
        grep -v "locker.age\|filter=locker-crypt\|bin/\*\|.githooks/\*" "$REPO_ROOT/.gitattributes" > "$REPO_ROOT/.gitattributes.tmp"
        mv "$REPO_ROOT/.gitattributes.tmp" "$REPO_ROOT/.gitattributes"
        
        # Remove file if empty (except comments)
        if ! grep -q "^[^#]" "$REPO_ROOT/.gitattributes"; then
            rm -f "$REPO_ROOT/.gitattributes"
            removed_items+=(".gitattributes")
        fi
    fi
    
    # Clean up .gitignore (remove padlock lines)
    if [[ -f "$REPO_ROOT/.gitignore" ]]; then
        grep -v "^locker/$" "$REPO_ROOT/.gitignore" > "$REPO_ROOT/.gitignore.tmp"
        mv "$REPO_ROOT/.gitignore.tmp" "$REPO_ROOT/.gitignore"
    fi
    
    # Remove git configuration
    git -C "$REPO_ROOT" config --unset filter.locker-crypt.clean 2>/dev/null || true
    git -C "$REPO_ROOT" config --unset filter.locker-crypt.smudge 2>/dev/null || true
    git -C "$REPO_ROOT" config --unset filter.locker-crypt.required 2>/dev/null || true
    git -C "$REPO_ROOT" config --unset core.hooksPath 2>/dev/null || true
    
    # Remove from manifest
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" ]]; then
        grep -v -F "$REPO_ROOT" "$manifest_file" > "$manifest_file.tmp" || true
        mv "$manifest_file.tmp" "$manifest_file"
    fi
    
    # Remove SECURITY.md if it's the padlock template
    if [[ -f "$REPO_ROOT/SECURITY.md" ]] && grep -q "Repository Security with Padlock" "$REPO_ROOT/SECURITY.md"; then
        rm -f "$REPO_ROOT/SECURITY.md"
        removed_items+=("SECURITY.md")
    fi
    
    okay "Padlock safely removed from repository"
    
    if [[ -d "$REPO_ROOT/locker" ]]; then
        local preserved_count
        preserved_count=$(find "$REPO_ROOT/locker" -type f | wc -l)
        okay "✓ Preserved $preserved_count files in locker/ (now unencrypted)"
        warn "⚠️  locker/ is now unencrypted - add to .gitignore if committing"
    fi
    
    if [[ ${#removed_items[@]} -gt 0 ]]; then
        info "Removed: ${removed_items[*]}"
    fi
    
    info "Repository restored to standard git repo"
}
```

**Acceptance Criteria:**
- [ ] MD5 checksums calculated for locker directory contents
- [ ] `.locked` file stores expected checksum for verification
- [ ] Unlock process verifies integrity and warns if modified
- [ ] `padlock declamp` removes all padlock infrastructure
- [ ] `padlock declamp --force` handles locked repositories
- [ ] Locker contents preserved as plaintext after declamp
- [ ] Repository removed from manifest after declamp
- [ ] Git configuration cleaned up (filters, hooks)

---

## 🛡️ **Phase 5: Revocation & Safety**
*Priority: MEDIUM - Safety features*

### **Features**
- ✅ Repository revocation commands
- ✅ Safety checks for destructive operations
- ✅ Migration between standard/ignition modes
- ✅ Force flags for override

### **Implementation Tasks**

#### **Task 4.1: Revocation Commands**
```bash
# Add to parts/06_api.sh
do_revoke() {
    local target="$1"
    local force="$2"
    
    case "$target" in
        --local)
            _revoke_local_access "$force"
            ;;
        -K|--ignition)
            _revoke_ignition_access
            ;;
    esac
}

_revoke_local_access() {
    local force="$1"
    
    if [[ "$force" != "--force" ]]; then
        error "This will make locker.age permanently unrecoverable!"
        info "Use --force to confirm destructive operation"
        return 1
    fi
    
    # Remove local key references, making content unrecoverable
    warn "Local access revoked - content unrecoverable!"
}

_revoke_ignition_access() {
    # Remove ignition system cleanly
    rm -f "$REPO_ROOT/.chest/ignition.age"
    rm -f "$REPO_ROOT/.ignition.key"
    okay "Ignition access revoked"
}
```

#### **Task 4.2: Safety Checks**
```bash
# Add safety prompts for destructive operations
__confirm_destructive() {
    local operation="$1"
    
    warn "⚠️  DESTRUCTIVE OPERATION: $operation"
    read -p "Type 'yes' to confirm: " confirm
    [[ "$confirm" == "yes" ]]
}
```

**Acceptance Criteria:**
- [ ] `padlock revoke --local --force` removes local access
- [ ] `padlock revoke --ignition` cleanly removes ignition system
- [ ] Safety prompts prevent accidental data loss
- [ ] Clear warnings about unrecoverable operations

---

## 🚀 **Phase 5: Advanced Features**
*Priority: LOW - Nice to have*

### **Features**
- ✅ Multiple ignition keys per repo
- ✅ Ignition key expiration
- ✅ Team ignition key sharing
- ✅ Audit logs in manifest

### **Future Considerations**
- Integration with external key management systems
- Hardware key support via age plugins
- Network-based key retrieval for automation
- GUI tools for non-technical users

---

## 🎯 **Implementation Priority Summary**

1. **Phase 1** (Essential): `.chest` foundation and basic ignition
2. **Phase 2** (Core): Full ignition key management with `-K` flag
3. **Phase 3** (Management): Enhanced manifest with namespace/remote tracking
4. **Phase 4** (Safety): Revocation and migration features
5. **Phase 5** (Advanced): Extended team collaboration features
6. **Phase 6** (Backup): Export/import system for environment migration

---

## 🚀 **Phase 7: Overdrive Mode** 
*Priority: LOW - Advanced "traveling blob" feature*

### **Features**
- ✅ Complete repository encryption (except padlock infrastructure)
- ✅ Traveling blob for secure repo transport
- ✅ Full project stasis with single encrypted artifact
- ✅ Perfect for secure repo sharing/backup

### **Concept**
Instead of just encrypting `locker/`, **overdrive mode** encrypts the **entire repository** except padlock infrastructure:

```bash
# Normal mode
my-repo/
├── locker.age          # Just secrets encrypted
├── src/                # Plaintext code
├── docs/               # Plaintext docs
└── bin/padlock         # Infrastructure

# Overdrive mode  
my-repo/
├── super_chest.age     # ENTIRE repo encrypted (src, docs, everything!)
├── bin/padlock         # Only infrastructure remains
└── .chest/             # Padlock metadata
```

### **Implementation Tasks**

#### **Task 7.1: Overdrive Encryption**
```bash
# Add to parts/06_api.sh
do_overdrive() {
    local action="${1:-lock}"
    
    case "$action" in
        lock) _overdrive_lock ;;
        unlock) _overdrive_unlock ;;
        status) _overdrive_status ;;
        *) 
            error "Unknown overdrive action: $action"
            info "Usage: padlock overdrive {lock|unlock|status}"
            return 1
            ;;
    esac
}

_overdrive_lock() {
    REPO_ROOT="$(_get_repo_root)"
    
    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository already in overdrive mode"
        return 1
    fi
    
    lock "🚀 Engaging overdrive mode..."
    
    # Ensure normal locker is locked first
    if [[ -d "$REPO_ROOT/locker" ]]; then
        warn "Locking normal locker first"
        do_lock
    fi
    
    # Create super_chest directory for staging
    local super_chest="$REPO_ROOT/.super_chest"
    mkdir -p "$super_chest"
    
    # Copy everything except padlock infrastructure
    local exclude_patterns=(
        "bin/padlock*"
        "bin/age-wrapper"
        ".githooks"
        ".chest"
        ".super_chest"
        "super_chest.age"
        ".locked"
        ".ignition.key"
        ".git"           # Don't encrypt git metadata
        ".gitsim"        # Don't encrypt gitsim metadata
    )
    
    info "Archiving entire repository..."
    
    # Create exclusion file for rsync
    local exclude_file=$(mktemp)
    printf "%s\n" "${exclude_patterns[@]}" > "$exclude_file"
    
    # Copy everything except excluded patterns
    rsync -av \
        --exclude-from="$exclude_file" \
        --exclude=".*" \
        "$REPO_ROOT/" "$super_chest/" > /dev/null
    
    # Also copy important dotfiles (but not padlock ones)
    for dotfile in .gitignore .gitattributes README.md LICENSE; do
        if [[ -f "$REPO_ROOT/$dotfile" ]]; then
            cp "$REPO_ROOT/$dotfile" "$super_chest/"
        fi
    done
    
    rm -f "$exclude_file"
    
    # Load crypto config
    _load_crypto_config "$REPO_ROOT/locker/.padlock" 2>/dev/null || \
    _load_crypto_config "$REPO_ROOT/.chest/manifest.json" 2>/dev/null || {
        error "No crypto configuration found"
        info "Run normal 'padlock setup' first"
        rm -rf "$super_chest"
        return 1
    }
    
    # Calculate checksum of super_chest contents
    local super_checksum
    super_checksum=$(find "$super_chest" -type f -exec md5sum {} \; 2>/dev/null | sort -k2 | md5sum | cut -d' ' -f1)
    
    # Encrypt the entire super_chest
    tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        -C "$REPO_ROOT" -czf - ".super_chest" | __encrypt_stream > "$REPO_ROOT/super_chest.age"
    
    # Remove everything except padlock infrastructure and super_chest.age
    find "$REPO_ROOT" -maxdepth 1 \( \
        -name "bin" -o \
        -name ".chest" -o \
        -name ".githooks" -o \
        -name ".git" -o \
        -name ".gitsim" -o \
        -name "super_chest.age" -o \
        -name ".super_chest" \
    \) -prune -o -type f -delete
    
    # Remove empty directories (except protected ones)
    find "$REPO_ROOT" -type d -empty \
        ! -path "$REPO_ROOT/bin*" \
        ! -path "$REPO_ROOT/.chest*" \
        ! -path "$REPO_ROOT/.githooks*" \
        ! -path "$REPO_ROOT/.git*" \
        -delete 2>/dev/null || true
    
    # Clean up staging area
    rm -rf "$super_chest"
    
    # Create overdrive manifest
    cat > "$REPO_ROOT/.overdrive" << EOF
#!/bin/bash
# Overdrive unlock script
# Generated: $(date)
# Super checksum: $super_checksum

EXPECTED_SUPER_CHECKSUM="$super_checksum"

if [[ "\${BASH_SOURCE[0]}" == "\${0}" ]]; then
    echo "Usage: source .overdrive"
    exit 1
fi

echo "🚀 Overdrive mode detected"
echo "🔓 Unlocking entire repository..."

if bin/padlock overdrive unlock; then
    echo "✓ Repository restored from overdrive mode"
    echo "⚠️  Remember to commit/push any changes before next overdrive"
else
    echo "✗ Failed to unlock overdrive mode"
fi
EOF
    
    local size
    size=$(du -h "$REPO_ROOT/super_chest.age" | cut -f1)
    okay "🚀 Overdrive engaged! Entire repo → super_chest.age ($size)"
    info "Repository is now a traveling blob"
    info "Run 'source .overdrive' to restore full repository"
    warn "⚠️  Only padlock infrastructure remains visible"
}

_overdrive_unlock() {
    REPO_ROOT="$(_get_repo_root)"
    
    if [[ ! -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository not in overdrive mode"
        return 1
    fi
    
    lock "🔓 Disengaging overdrive mode..."
    
    # Decrypt super_chest
    __decrypt_stream < "$REPO_ROOT/super_chest.age" | tar -C "$REPO_ROOT" -xzf -
    
    if [[ ! -d "$REPO_ROOT/.super_chest" ]]; then
        error "Failed to decrypt super_chest.age"
        return 1
    fi
    
    # Verify integrity if we have a baseline
    if [[ -f "$REPO_ROOT/.overdrive" ]]; then
        local expected_checksum
        expected_checksum=$(grep "EXPECTED_SUPER_CHECKSUM=" "$REPO_ROOT/.overdrive" | cut -d'"' -f2)
        
        local current_checksum
        current_checksum=$(find "$REPO_ROOT/.super_chest" -type f -exec md5sum {} \; 2>/dev/null | sort -k2 | md5sum | cut -d' ' -f1)
        
        if [[ "$current_checksum" != "$expected_checksum" ]]; then
            warn "⚠️  Super chest integrity check failed!"
            info "Expected: $expected_checksum"
            info "Current:  $current_checksum"
        else
            trace "✓ Super chest integrity verified"
        fi
    fi
    
    # Restore all files from super_chest to repository root
    cp -r "$REPO_ROOT/.super_chest"/* "$REPO_ROOT/"
    
    # Clean up
    rm -rf "$REPO_ROOT/.super_chest"
    rm -f "$REPO_ROOT/super_chest.age"
    rm -f "$REPO_ROOT/.overdrive"
    
    local file_count
    file_count=$(find "$REPO_ROOT" -type f ! -path "$REPO_ROOT/bin/*" ! -path "$REPO_ROOT/.git/*" ! -path "$REPO_ROOT/.gitsim/*" | wc -l)
    
    okay "🔓 Overdrive disengaged! Repository restored ($file_count files)"
    info "Full project now accessible"
    
    # If there was a normal locker.age, offer to unlock it too
    if [[ -f "$REPO_ROOT/locker.age" ]]; then
        info "Found standard locker.age - unlock it too?"
        echo "Run: source .locked"
    fi
}

_overdrive_status() {
    REPO_ROOT="$(_get_repo_root)"
    
    printf "%s=== Overdrive Status ===%s\n" "$blue" "$xx"
    printf "Repository: %s\n" "$(basename "$REPO_ROOT")"
    
    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        local size
        size=$(du -h "$REPO_ROOT/super_chest.age" | cut -f1)
        printf "Mode: %s🚀 OVERDRIVE ENGAGED%s\n" "$yellow" "$xx"
        printf "Blob: super_chest.age (%s)\n" "$size"
        printf "Status: Repository in traveling blob mode\n"
        printf "Unlock: %ssource .overdrive%s\n" "$cyan" "$xx"
        
        # Count visible files (should be minimal)
        local visible_files
        visible_files=$(find "$REPO_ROOT" -type f ! -path "$REPO_ROOT/bin/*" ! -path "$REPO_ROOT/.git/*" | wc -l)
        printf "Visible files: %d (infrastructure only)\n" "$visible_files"
    else
        printf "Mode: %s📁 NORMAL%s\n" "$green" "$xx"
        printf "Status: Full repository accessible\n"
        printf "Overdrive: %spadlock overdrive lock%s\n" "$cyan" "$xx"
    fi
}
```

#### **Task 7.2: Integration with Core Commands**
```bash
# Update do_status() to show overdrive mode
do_status() {
    # ... existing status logic ...
    
    # Check for overdrive mode
    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        printf "\n%s🚀 OVERDRIVE MODE ACTIVE%s\n" "$yellow" "$xx"
        printf "Repository: Compressed to traveling blob\n"
        printf "Restore: %ssource .overdrive%s\n" "$cyan" "$xx"
    fi
}

# Update dispatch() to handle overdrive
dispatch() {
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        # ... existing commands ...
        overdrive)
            do_overdrive "$@"
            ;;
        # ... rest of commands ...
    esac
}
```

**Acceptance Criteria:**
- [ ] `padlock overdrive lock` encrypts entire repository except infrastructure
- [ ] `super_chest.age` contains complete project (code, docs, assets)
- [ ] Only `bin/`, `.git/`, `.chest/` remain visible after overdrive
- [ ] `source .overdrive` restores full repository
- [ ] Integrity verification with checksums
- [ ] Works with both standard and ignition encryption
- [ ] Repository becomes a "traveling blob" for secure transport

### **Use Cases for Overdrive** 🎯

#### **Secure Repository Sharing**
```bash
# Prepare repo for sharing with AI/contractor
padlock overdrive lock
# Send just: super_chest.age + bin/padlock + .overdrive

# Recipient restores with:
source .overdrive
```

#### **Ultra-Secure Backup**
```bash
# Complete project backup
padlock overdrive lock
cp super_chest.age /secure/backup/location/

# Restore anywhere:
# 1. Copy back super_chest.age + padlock tools
# 2. source .overdrive
```

#### **Repository Transport**
```bash
# Moving between air-gapped systems
padlock overdrive lock
# Transfer minimal files: super_chest.age + infrastructure
# Full project travels as single encrypted blob
```

This turns your repository into a **cryptographic spaceship** - the entire project compressed into a single encrypted artifact! 🛸

### **New Format (v2.0)**
```bash
# namespace|name|path|type|remote|checksum|created|last_access|metadata
github|myproject|/home/user/projects/myproject|ignition|git@github.com:user/myproject.git|a1b2c3d4e5f6|2025-01-15T10:30:00Z|2025-01-15T14:20:00Z|
local|temp-test|/tmp/tmp.abc123|standard||f6e5d4c3b2a1|2025-01-15T12:00:00Z|2025-01-15T12:05:00Z|temp=true
gitlab|secret-repo|/home/user/secret-repo|ignition|https://gitlab.com/team/secret-repo.git|9f8e7d6c5b4a|2025-01-15T11:45:00Z|2025-01-15T15:10:00Z|key_id=flame-rocket
```

### **Benefits**
- **Namespace organization**: Group repos by source (github, gitlab, local)
- **Clean names**: Use repo name instead of full path for display
- **Remote tracking**: Track git origins for team collaboration
- **Integrity checksums**: Detect manifest corruption or tampering
- **Rich metadata**: Store ignition key IDs and other attributes

## 🔄 **Export/Import Workflow**

### **Individual Backup**
```bash
# Create backup
padlock export my_backup.tar.age
# Enter passphrase: my-secure-backup-phrase

# Restore on another system
padlock import my_backup.tar.age
# Enter passphrase: my-secure-backup-phrase
```

### **Rewindable Snapshots**
```bash
# Create named snapshot
padlock snapshot before-major-changes

# Make changes, then rewind if needed
padlock rewind before-major-changes
```

This system provides **complete portability** while maintaining security through passphrase protection!