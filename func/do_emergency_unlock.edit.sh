#!/bin/bash
# FUNCTION_FILE: do_emergency_unlock
# SOURCE_FILE: parts/06_api.sh  
# FUNC_META: func="do_emergency_unlock" src="parts/06_api.sh" timestamp="$(date -Iseconds)"

do_emergency_unlock() {
    error "🚨 EMERGENCY UNLOCK ACTIVATED"
    warn "This bypasses normal security to restore repository access"
    warn "Use only when standard unlock methods fail"
    
    # Force confirmation unless --force is used
    if ! is_force && ! confirm "⚠️  Continue with emergency unlock? This is irreversible"; then
        info "Emergency unlock cancelled"
        return 1
    fi
    
    local repo_root="$(_get_repo_root .)"
    local backup_created=false
    local timestamp=$(date +%Y%m%d_%H%M%S)
    
    # Create emergency backup before any changes
    info "Creating emergency backup..."
    if _backup_repo_artifacts "$repo_root"; then
        backup_created=true
        okay "✓ Emergency backup created"
    else
        warn "⚠️  Backup failed, proceeding anyway"
    fi
    
    # Record current state
    local state="$(_get_lock_state "$repo_root")"
    info "Current repository state: $state"
    
    # Emergency unlock logic - try multiple approaches
    local unlock_method=""
    
    # Method 1: Standard master unlock if possible
    if [[ "$state" != "unlocked" ]] && [[ -f "$repo_root/.padlock/master.key" ]]; then
        info "Attempting standard master unlock..."
        if _master_unlock 2>/dev/null; then
            unlock_method="master"
            okay "✓ Standard master unlock succeeded"
        else
            warn "Standard master unlock failed, trying emergency methods..."
        fi
    fi
    
    # Method 2: Direct chest extraction if master failed
    if [[ -z "$unlock_method" && -d "$repo_root/.chest" ]]; then
        info "Attempting direct chest extraction..."
        if [[ -d "$repo_root/locker" ]]; then
            rm -rf "$repo_root/locker.emergency_backup.$timestamp"
            mv "$repo_root/locker" "$repo_root/locker.emergency_backup.$timestamp"
        fi
        
        if cp -r "$repo_root/.chest/." "$repo_root/locker" 2>/dev/null; then
            unlock_method="chest-extraction"
            okay "✓ Direct chest extraction succeeded"
        else
            warn "Direct chest extraction failed"
            # Restore if backup exists
            if [[ -d "$repo_root/locker.emergency_backup.$timestamp" ]]; then
                mv "$repo_root/locker.emergency_backup.$timestamp" "$repo_root/locker"
            fi
        fi
    fi
    
    # Method 3: Clear all locks and create safe state
    if [[ -z "$unlock_method" ]]; then
        info "Creating safe repository state..."
        
        # Remove lock mechanisms
        [[ -d "$repo_root/.chest" ]] && rm -rf "$repo_root/.chest"
        [[ -d "$repo_root/.padlock/overdrive" ]] && rm -rf "$repo_root/.padlock/overdrive"
        
        # Ensure locker directory exists
        if [[ ! -d "$repo_root/locker" ]]; then
            mkdir -p "$repo_root/locker"
            echo "# Emergency unlock created this directory" > "$repo_root/locker/.emergency_unlock"
            echo "# Original state: $state" >> "$repo_root/locker/.emergency_unlock"
            echo "# Timestamp: $(date -Iseconds)" >> "$repo_root/locker/.emergency_unlock"
        fi
        
        unlock_method="force-unlock"
        okay "✓ Force unlock completed"
    fi
    
    # Final verification
    local new_state="$(_get_lock_state "$repo_root")"
    info "New repository state: $new_state"
    
    # Success message
    okay "🆘 Emergency unlock complete"
    info "Method used: $unlock_method"
    if [[ "$backup_created" == true ]]; then
        info "Backup available in: $PADLOCK_ETC/repos/"
    fi
    
    # Warnings and recommendations
    warn "⚠️  Repository is now in emergency state"
    warn "⚠️  Review and verify all sensitive files"
    warn "⚠️  Consider re-initializing padlock after backup"
    info "💡 Use 'padlock status' to check current state"
    
    return 0
}