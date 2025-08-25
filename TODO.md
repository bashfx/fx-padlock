# Padlock Development TODO

## ✅ **Just Completed**

1. ✅ **Implemented `do_uninstall` Function**
   - Reverses `do_install` operations  
   - Removes symlinks and installation directory
   - Preserves user keys and data

2. ✅ **Export Command Automation**
   - Supports `PADLOCK_PASSPHRASE` environment variable
   - Supports `PADLOCK_PASSPHRASE_FILE` for file-based input
   - Falls back to interactive mode when available

3. ✅ **Import Command Automation**
   - Same automation support as export
   - `PADLOCK_PASSPHRASE` and `PADLOCK_PASSPHRASE_FILE` support

## ⚡ **Still Need Automation**

4. **Snapshot Command** - Needs non-interactive mode
   - Currently requires passphrase for export
   - Should inherit from export automation (uses same pattern)

5. **Rewind Command** - Depends on snapshot automation
   - Should work once snapshot supports same pattern

## 🐛 **Minor Fixes Needed**

6. **Install Function Variable Scoping**
   - Has "help: unbound variable" error
   - Need to check variable references in do_install

7. **Overdrive Mode Edge Cases**
   - "super_chest: unbound variable" in unlock script
   - Tar timestamp warnings (cosmetic)
   - Variable scoping in .overdrive generation

## 🎯 **Implementation Notes**

### **Automation Pattern:**
```bash
# Current (interactive only):
read -sp "Passphrase: " passphrase

# Implemented (automation support):
if [[ -n "${PADLOCK_PASSPHRASE:-}" ]]; then
    passphrase="$PADLOCK_PASSPHRASE"
elif [[ -n "${PADLOCK_PASSPHRASE_FILE:-}" ]]; then
    passphrase=$(cat "$PADLOCK_PASSPHRASE_FILE")
elif [[ -t 0 ]]; then
    read -sp "Passphrase: " passphrase
else
    fatal "No passphrase provided and not interactive"
fi
```

### **Uninstall Implementation:**
```bash
do_uninstall() {
    local install_dir="$XDG_LIB_HOME/fx/padlock"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    
    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        info "Removed symlink: $link_path"
    fi
    
    if [[ -d "$install_dir" ]]; then
        rm -rf "$install_dir"
        info "Removed installation: $install_dir"
    fi
    
    okay "✓ Padlock uninstalled"
}
```

## ✅ **Major Accomplishments This Session**

- ✅ **Passphrase-wrapped ignition backup system** - Complete disaster recovery
- ✅ **Repository repair command** - Intelligent corruption recovery  
- ✅ **Post-commit checksum fix** - Clean git workflow
- ✅ **Test runner improvements** - Robust testing with ceremonious presentation
- ✅ **Interactive setup command** - User-friendly first-time configuration
- ✅ **Complete documentation update** - README.md and FEATURES.md aligned with reality

## 🎯 **Next Session Priority**

1. Implement `do_uninstall` (15 minutes)
2. Add automation support to interactive commands (30 minutes)  
3. Fix variable scoping issues in install and overdrive (15 minutes)
4. Test automation features (15 minutes)

**Status: Core system is production-ready with robust backup/recovery. Only missing uninstall and automation support for CI/CD usage.**