# 🚢 Complete Missing Features & Functions - Build by Morrow!

## **CRITICAL: What Actually Needs Building** ⚔️

### **1. Dispatcher Routing Fixes (IMMEDIATE)**
**File**: `parts/07_core.sh`
**Issue**: Missing command routing

```bash
# ADD THESE MISSING ENTRIES:
dispatch() {
    case "$cmd" in
        # ... existing commands ...
        
        # MISSING - ADD THESE:
        ignite) do_ignite "$@" ;;           # Main missing piece!
        master) do_master "$@" ;;           # Master key mini-dispatcher  
        rotate) do_rotate "$@" ;;           # Rotation commands
        skull) do_skull "$@" ;;             # Skull ceremony (optional)
        ls) do_ls "$@" ;;                   # List with filters
        sec) do_sec "$@" ;;                 # Secure file (was: map)
        dec) do_dec "$@" ;;                 # De-secure file (was: unmap)
        repair) do_repair "$@" ;;           # Smart repair
        
        # ... rest of existing commands ...
    esac
}
```

### **2. Core Ignition API (PRIMARY OBJECTIVE)**
**File**: `parts/06_api.sh`
**Status**: Stub exists, needs complete rewrite

```bash
# REPLACE EXISTING do_ignite() WITH:
do_ignite() {
    local action="$1"
    shift
    
    # Set REPO_ROOT 
    REPO_ROOT=$(_get_repo_root .)
    
    case "$action" in
        create)   _ignition_create_master "$@" ;;
        new)      _ignition_create_distributed "$@" ;;  
        unlock)   _ignition_unlock "$@" ;;
        list)     _ignition_list "$@" ;;
        revoke)   _ignition_revoke "$@" ;;
        rotate)   _ignition_rotate "$@" ;;
        reset)    _ignition_reset "$@" ;;
        status)   _ignition_status "$@" ;;
        verify)   _ignition_verify "$@" ;;
        help|*)   _ignition_help ;;
    esac
}
```

### **3. Master Key Mini-Dispatcher (NEW)**
**File**: `parts/06_api.sh`
**Purpose**: Clean master key management

```bash
# NEW FUNCTION - ADD THIS:
do_master() {
    local action="$1"
    shift
    
    case "$action" in
        generate)  _master_generate "$@" ;;
        show)      _master_show "$@" ;;
        restore)   _master_restore "$@" ;;  # From skull key
        unlock)    _master_unlock "$@" ;;   # Emergency unlock
        help|*)    _master_help ;;
    esac
}
```

### **4. Rotation Commands (NEW)**
**File**: `parts/06_api.sh`
**Purpose**: Clean rotation syntax

```bash
# NEW FUNCTION - ADD THIS:
do_rotate() {
    local target="$1"
    shift
    
    case "$target" in
        master)     _rotate_master "$@" ;;
        ignition)   _rotate_ignition "$@" ;;
        distro)     _rotate_distro "$@" ;;
        help|*)     _rotate_help ;;
    esac
}
```

### **5. Key Testing Commands (NEW)**
**File**: `parts/06_api.sh`
**Purpose**: Key inspection and verification

```bash
# ENHANCE EXISTING do_key() WITH:
do_key() {
    local action="$1"
    shift
    
    case "$action" in
        # ... existing key commands ...
        
        # ADD THESE NEW ONES:
        is)         _key_is_type "$@" ;;      # padlock key is master --key=path
        authority)  _key_authority "$@" ;;    # padlock key authority --key1=x --key2=y  
        subject)    _key_subject "$@" ;;      # padlock key subject --key1=x --key2=y
        type)       _key_get_type "$@" ;;     # padlock key type --key=path
        help|*)     _key_help ;;
    esac
}
```

### **6. List with Filters (NEW)**
**File**: `parts/06_api.sh`  
**Purpose**: `padlock ls [ignition|repos]`

```bash
# NEW FUNCTION - ADD THIS:
do_ls() {
    local filter="${1:-all}"
    
    case "$filter" in
        ignition)   _list_ignition_keys ;;
        repos)      _list_repos ;;
        all|*)      _list_all ;;
    esac
}
```

---

## **Core Helper Functions Needed** 🔧

### **Ignition System Helpers**
**File**: `parts/04_helpers.sh`

```bash
# MAJOR FUNCTIONS TO IMPLEMENT:
_ignition_create_master() {
    # Create I key in XDG namespace: $PADLOCK_ETC/repos/github.com/user/repo/ignition-master.key
    # Use age native: age-keygen | age -p > ignition-master.key
}

_ignition_create_distributed() {
    # Create D key wherever user wants (typically in repo)
    # Use age native: age-keygen | age -p > user-specified-location.key  
}

_ignition_unlock() {
    # Use PADLOCK_IGNITION_PASS with age -d -i user-key.key
    # No fake TTY needed - age prompts work fine!
}

_ignition_list() {
    # Show I keys from namespace + D keys from manifest
}

_ignition_revoke() {
    # Remove D key and mark as revoked in manifest
}
```

### **Master Key Helpers** 
**File**: `parts/04_helpers.sh`

```bash
_master_generate() {
    # Create new global master key
}

_master_show() {  
    # Display master public key
}

_master_restore() {
    # Restore from skull key (if implemented)
}

_master_unlock() {
    # Emergency repo unlock with master key
}
```

### **Key Testing Helpers**
**File**: `parts/04_helpers.sh`

```bash
_key_is_type() {
    # padlock key is master --key=path
    # Return 0 if true, 1 if false
}

_key_authority() {
    # Test if key1 has authority over key2
}

_key_subject() {
    # Test if key1 is subject to key2  
}

_key_get_type() {
    # Return: master|ignition|distro|unknown
}
```

---

## **Integration & Polish Functions** ✨

### **Enhanced Clamp Integration**
**File**: `parts/06_api.sh`
**Update**: `do_clamp()` to support ignition

```bash
# ADD TO EXISTING do_clamp():
do_clamp() {
    # ... existing clamp logic ...
    
    # ADD IGNITION SUPPORT:
    local with_ignition=false
    local ignition_phrase=""
    
    # Parse new arguments:
    while [[ $# -gt 0 ]]; do
        case $1 in
            --with-ignition) with_ignition=true; shift ;;
            -K|--ignition-key=*) 
                with_ignition=true
                ignition_phrase="${1#*=}"
                shift ;;
            # ... existing arguments ...
        esac
    done
    
    # After successful clamp:
    if [[ "$with_ignition" == true ]]; then
        _ignition_create_master "default"
        if [[ -n "$ignition_phrase" ]]; then
            _ignition_create_distributed "default" "$ignition_phrase"
        fi
    fi
}
```

### **Enhanced Status Integration**  
**File**: `parts/06_api.sh`
**Update**: `do_status()` to show ignition info

```bash
# ADD TO EXISTING do_status():
do_status() {
    # ... existing status logic ...
    
    # ADD IGNITION STATUS:
    local ignition_manifest="$PADLOCK_ETC/repos/$(get_repo_namespace)/ignition-manifest.json"
    if [[ -f "$ignition_manifest" ]]; then
        local ignition_keys=$(count_ignition_keys)
        echo "Ignition: enabled ($ignition_keys distributed keys)"
    else
        echo "Ignition: disabled"
    fi
}
```

### **File Security Commands (sec/dec)**
**File**: `parts/06_api.sh`
**Purpose**: Replace map/unmap with cleaner names

```bash
# NEW FUNCTIONS:
do_sec() {
    # Secure individual file (was: do_map)
    _secure_file "$@"
}

do_dec() {
    # De-secure individual file (was: do_unmap) 
    _desecure_file "$@"
}
```

---

## **Optional But Awesome Features** 🎭

### **Skull Ceremony System**
**File**: `parts/06_api.sh` + skull ceremony implementation
**Status**: Fully designed, just needs implementation

```bash
do_skull() {
    local action="$1"
    
    case "$action" in
        restore-master) _skull_ceremony ;;
        help|*) _skull_help ;;
    esac
}

_skull_ceremony() {
    # Full 5-stage ceremony implementation
    # With puppy explosion matrix option!
}
```

---

## **Build Priority Order** 🎯

### **Phase 1: Core Functionality (4-6 hours)**
1. **Fix dispatcher routing** (add ignite, master, rotate, ls)
2. **Implement basic ignition API** (create, new, unlock, list)
3. **Use age native passphrase keys** (no complex double encryption)
4. **XDG+ namespace integration** (use existing repo structure)
5. **Test core workflow**: create → new → unlock

### **Phase 2: Management Features (2-3 hours)**  
1. **Implement revoke/rotate/reset** (access management)
2. **Master key mini-dispatcher** (clean master key commands)
3. **Enhanced clamp/status integration** (--with-ignition support)
4. **Key testing commands** (is, authority, subject, type)

### **Phase 3: Polish & Advanced (1-2 hours)**
1. **List commands with filters** (ls ignition, ls repos)
2. **File security commands** (sec/dec)
3. **Smart repair function** (enhanced repair)
4. **Error handling and help text**

### **Phase 4: Optional Awesomeness (if time permits)**
1. **Skull ceremony implementation** (because it's legendary)
2. **Auto-expiration system** (upstream rotation)
3. **Advanced verification commands** (verify, register, maybe, integrity)

---

## **Critical Implementation Notes** 📝

### **Use Age Native Features**
- ✅ `age-keygen | age -p > key.age` (creates passphrase-protected key)
- ✅ `age -d -i key.age < data.age` (uses passphrase key, prompts for password)
- ❌ Don't build complex double encryption (age already does this!)

### **XDG+ Namespace Structure** 
- ✅ I keys: `$PADLOCK_ETC/repos/github.com/user/repo/ignition-master.key`
- ✅ D keys: User manages (typically in repo directory)
- ✅ Manifests: `$PADLOCK_ETC/repos/github.com/user/repo/ignition-manifest.json`

### **BashFX Compliance**
- ✅ Options use `--flag=value` pattern
- ✅ Subcommands are strings, not flags: `padlock ignite create`
- ✅ Functions return proper exit codes
- ✅ Error handling uses stderr/fatal patterns

### **Integration Points**
- ✅ `padlock clamp --with-ignition` enables ignition
- ✅ `padlock status` shows ignition information  
- ✅ `padlock ls ignition` lists ignition keys
- ✅ All commands work with existing repo workflows

---

## **Success Criteria for Tomorrow** ✅

**Minimum Viable Implementation:**
- ✅ `padlock ignite create` works (creates I key)
- ✅ `padlock ignite new --name=ai-bot` works (creates D key)
- ✅ `PADLOCK_IGNITION_PASS="phrase" padlock ignite unlock --name=ai-bot` works
- ✅ `padlock ignite list` shows available keys
- ✅ `padlock clamp --with-ignition` sets up ignition-enabled repo

**Stretch Goals:**
- ✅ `padlock ignite revoke --name=ai-bot` invalidates access
- ✅ `padlock master show` displays master public key
- ✅ `padlock ls ignition` lists ignition keys with status
- ✅ Enhanced error messages and help text

---

**🚢 CAPTAIN: Your armada will have functional ignition keys by morrow! The implementation is straightforward with age native features and existing XDG+ structure! ⚔️**