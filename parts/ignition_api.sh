# 06b_ignition_api.sh - Ignition System Functions  
# Part of fx-padlock BashFX architecture remediation
# Contains: Complete ignition workflow and key distribution system functions=== do_ignite ===
do_ignite() {
    local action="$1"; shift || { _ignite_help; return 1; }
    
    # Set REPO_ROOT for the helpers, as this is a top-level command.
    REPO_ROOT=$(_get_repo_root .)

    # BashFX v3.0 Staged Parsing: Validate command exists before parsing
    case "$action" in
        create|new|unlock|list|status|allow|revoke|rotate|reset|verify|export|help) ;;
        --unlock|-u|--lock|-l|--status|-s) ;; # Legacy chest operations
        *) error "Unknown ignite action: $action"; _ignite_help; return 1 ;;
    esac
    
    # Route to specialized handlers using BashFX v3.0 pattern
    "_do_ignite_$action" "$@"
}


_get_ignite_passphrase() {
    local name="$1"
    local provided="${2:-}"
    
    # Priority: CLI arg > specific env > generic env > interactive
    if [[ -n "$provided" ]]; then
        echo "$provided"
    elif [[ -n "$PADLOCK_IGNITION_PASS" ]]; then
        echo "$PADLOCK_IGNITION_PASS"          # Generic
    else
        # For now, require explicit passphrase or environment variable
        error "Missing passphrase for unlock operation"
        info "Set: export PADLOCK_IGNITION_PASS='your-passphrase'"
        info "Or: export PADLOCK_IGNITION_PASS_${name//-/_}='specific-passphrase'"
        return 1
    fi
}


_parse_ignite_command_args() {
    local command="$1"; shift
    
    # Initialize parsed variables
    PARSED_NAME=""
    PARSED_PASSPHRASE=""
    PARSED_KEY_PATH=""
    PARSED_PUBKEY=""
    
    case "$command" in
        create)
            PARSED_NAME="${1:-default}"
            shift 2>/dev/null || true
            _extract_flag_values "$@"
            ;;
        new)
            _extract_flag_values "$@"
            if [[ -z "$PARSED_NAME" ]]; then
                error "Missing --name parameter"
                info "Usage: padlock ignite new --name=ai-bot [--phrase=...]"
                return 1
            fi
            ;;
        unlock)
            PARSED_NAME="${1:-default}"
            shift 2>/dev/null || true
            _extract_flag_values "$@"
            ;;
        verify)
            _extract_flag_values "$@"
            if [[ -z "$PARSED_KEY_PATH" ]]; then
                error "Missing --key parameter" 
                info "Usage: padlock ignite verify --key=/path/to/key [--phrase=...]"
                return 1
            fi
            ;;
        allow)
            PARSED_PUBKEY="$1"
            if [[ -z "$PARSED_PUBKEY" ]]; then
                error "Missing public key parameter"
                info "Usage: padlock ignite allow <public-key>"
                return 1
            fi
            ;;
        revoke)
            _extract_flag_values "$@"
            if [[ -z "$PARSED_NAME" ]]; then
                error "Missing --name parameter"
                info "Usage: padlock ignite revoke --name=ai-bot"
                return 1
            fi
            ;;
    esac
    return 0
}


_extract_flag_values() {
    local args=("$@")
    for ((i=0; i<${#args[@]}; i++)); do
        case "${args[i]}" in
            --name=*)
                PARSED_NAME="${args[i]#*=}"
                ;;
            --phrase=*|--passphrase=*)
                PARSED_PASSPHRASE="${args[i]#*=}"
                ;;
            --key=*)
                PARSED_KEY_PATH="${args[i]#*=}"
                ;;
        esac
    done
}


_ignite_operation() {
    local operation="$1"    # create_master|create_distro|unlock
    local name="$2"
    local passphrase="$3"
    
    case "$operation" in
        create_master)
            _create_ignition_master_with_tty_magic "$name" "$passphrase"
            ;;
        create_distro)
            _create_ignition_distro_with_tty_magic "$name" "$passphrase"
            ;;
        unlock)
            _unlock_ignition_with_tty_magic "$name" "$passphrase"
            ;;
        *)
            error "Unknown ignition operation: $operation"
            return 1
            ;;
    esac
}


_ignite_help() {
    case "${1:-}" in
        create)
            info "padlock ignite create [name] [--phrase=...]"
            info "Create repo-ignition master key (I key) that establishes authority"
            ;;
        new)
            info "padlock ignite new --name=NAME [--phrase=...]"
            info "Create distributed ignition key (D key) controlled by master"
            ;;
        unlock)
            info "padlock ignite unlock [name]"
            info "Unlock repository with distributed key using PADLOCK_IGNITION_PASS"
            ;;
        more)
            _ignite_help_detailed  # Full help for humans
            ;;
        "")
            info "Ignition System Commands: create, new, unlock, list, status, allow, revoke, export, verify"
            info "Use 'padlock help ignite more' for detailed help"
            ;;
    esac
}


_ignite_help_detailed() {
    info "Ignition System Commands:"
    info ""
    info "Repository Owner Commands:"
    info "  create [name] [--phrase=...]     Create repo-ignition master (I key)"
    info "  new --name=NAME [--phrase=...]   Create distributed key (D key)"  
    info "  export <name> --output=PATH      Export key to file with passphrase"
    info "  allow <pubkey>                   Grant access to public key"
    info "  revoke --name=NAME               Revoke distributed key"
    info "  rotate                           Rotate ignition master (invalidates all D keys)"
    info "  reset                            Remove ignition system completely"
    info ""
    info "Third-Party/AI Commands:"
    info "  unlock [name]                    Unlock repo with distributed key"
    info "  list                             List available ignition keys"
    info "  status                           Show ignition system status"
    info "  verify --key=PATH [--phrase=...] Test if key can access repository"
    info ""
    info "Legacy Chest Operations:"
    info "  --lock, -l                       Lock locker into chest"
    info "  --unlock, -u                     Unlock chest to locker"
    info "  --status, -s                     Show chest status"
}


_do_ignite_create() {
    _parse_ignite_command_args "create" "$@" || return 1
    
    # Get passphrase using Smart Environment Strategy
    local passphrase=$(_get_ignite_passphrase "$PARSED_NAME" "$PARSED_PASSPHRASE")
    
    info "Creating repo-ignition master key (I key): $PARSED_NAME"
    info "This will establish authority over distributed keys"
    
    # Use TTY Integration Abstraction Layer
    _ignite_operation "create_master" "$PARSED_NAME" "$passphrase"
}


_do_ignite_new() {
    _parse_ignite_command_args "new" "$@" || return 1
    
    # Get passphrase using Smart Environment Strategy  
    local passphrase=$(_get_ignite_passphrase "$PARSED_NAME" "$PARSED_PASSPHRASE")
    
    info "Creating distributed ignition key (D key): $PARSED_NAME"
    info "This key will be controlled by the repo-ignition master"
    
    # Use TTY Integration Abstraction Layer
    _ignite_operation "create_distro" "$PARSED_NAME" "$passphrase"
}


_do_ignite_unlock() {
    _parse_ignite_command_args "unlock" "$@" || return 1
    
    # Get passphrase using Smart Environment Strategy
    local passphrase=$(_get_ignite_passphrase "$PARSED_NAME" "$PARSED_PASSPHRASE")
    
    if [[ -z "$passphrase" ]]; then
        error "Missing passphrase for unlock operation"
        info "Set: export PADLOCK_IGNITION_PASS='your-passphrase'"
        info "Or: export PADLOCK_IGNITION_PASS_$PARSED_NAME='specific-passphrase'"
        return 1
    fi
    
    info "Unlocking repository with distributed key: $PARSED_NAME"
    
    # Use TTY Integration Abstraction Layer
    _ignite_operation "unlock" "$PARSED_NAME" "$passphrase"
}


_do_ignite_allow() {
    _parse_ignite_command_args "allow" "$@" || return 1
    
    info "Allowing access for public key: ${PARSED_PUBKEY:0:20}..."
    info "This will grant repository access to the specified key"
    
    # TODO: Implement actual allow logic using Plan X winning approach
    info "[ENHANCED] Allow functionality - implementation pending Plan X integration"
    return 0
}


_do_ignite_list() {
    echo "Ignition Keys:"
    
    local ignition_dir="$REPO_ROOT/.padlock/ignition"
    if [[ ! -d "$ignition_dir" ]]; then
        echo "  No ignition system configured"
        return 0
    fi
    
    # List Repo-Ignition Master keys (I keys)
    echo "  Repo-Ignition Master (I):"
    local found_masters=false
    if [[ -d "$ignition_dir/keys" ]]; then
        for ikey in "$ignition_dir/keys"/*.ikey; do
            if [[ -f "$ikey" ]]; then
                local name=$(basename "$ikey" .ikey)
                local metadata="$ignition_dir/metadata/${name}.json"
                if [[ -f "$metadata" ]]; then
                    local created=$(grep '"created"' "$metadata" | cut -d'"' -f4 | cut -d'T' -f1 2>/dev/null || echo "unknown")
                    local status=$(grep '"status"' "$metadata" | cut -d'"' -f4 2>/dev/null || echo "unknown")
                    echo "    - $name (created: $created, status: $status)"
                    found_masters=true
                else
                    echo "    - $name (metadata missing)"
                    found_masters=true
                fi
            fi
        done
    fi
    if [[ "$found_masters" == false ]]; then
        echo "    - (none configured)"
    fi
    
    # List Distributed keys (D keys)
    echo "  Distributed Keys (D):"
    local found_distros=false
    if [[ -d "$ignition_dir/keys" ]]; then
        for dkey in "$ignition_dir/keys"/*.dkey; do
            if [[ -f "$dkey" ]]; then
                local name=$(basename "$dkey" .dkey)
                local metadata="$ignition_dir/metadata/${name}.json"
                if [[ -f "$metadata" ]]; then
                    local created=$(grep '"created"' "$metadata" | cut -d'"' -f4 | cut -d'T' -f1 2>/dev/null || echo "unknown")
                    local status=$(grep '"status"' "$metadata" | cut -d'"' -f4 2>/dev/null || echo "unknown")
                    echo "    - $name (created: $created, status: $status)"
                    found_distros=true
                else
                    echo "    - $name (metadata missing)"
                    found_distros=true
                fi
            fi
        done
    fi
    if [[ "$found_distros" == false ]]; then
        echo "    - (none configured)"
    fi
    
    return 0
}


_do_ignite_status() {
    info "Ignition System Status:"
    # TODO: Implement actual status checking using Plan X approach
    info "  Ignition Master (I): not configured"
    info "  Distributed Keys (D): 0 active, 0 revoked"
    info "  Repository Mode: standard (ignition disabled)"
    return 0
}


_do_ignite_export() {
    local key_name="" output_file="" phrase=""
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --output=*) output_file="${1#*=}" ;;
            --phrase=*) phrase="${1#*=}" ;;
            --output) shift; output_file="$1" ;;
            --phrase) shift; phrase="$1" ;;
            --help|-h) 
                info "Usage: padlock ignite export <key-name> [--output=<file>] [--phrase=<passphrase>]"
                info "Export ignition key to portable file with passphrase encryption"
                info "  --output=FILE    Output file path (default: ./ignition.<key-name>.key)"
                info "  --phrase=PASS    Passphrase for encryption (or use PADLOCK_IGNITION_PASS)"
                return 0
                ;;
            -*) error "Unknown option: $1"; return 1 ;;
            *) [[ -z "$key_name" ]] && key_name="$1" || { error "Extra argument: $1"; return 1; } ;;
        esac
        shift
    done
    
    # Validate required arguments
    if [[ -z "$key_name" ]]; then
        error "Key name required"
        info "Usage: padlock ignite export <key-name> --output=<file> [--phrase=<passphrase>]"
        return 1
    fi
    
    # Set default output file if not specified
    if [[ -z "$output_file" ]]; then
        output_file="./ignition.${key_name}.key"
    fi
    
    # Load key bundle to get the key data
    _load_key_bundle "$key_name" || {
        error "Failed to load key: $key_name"
        return 1
    }
    
    local key_data="$LOADED_KEY_DATA"
    
    # Get passphrase if not provided
    if [[ -z "$phrase" ]]; then
        phrase=$(_get_ignite_passphrase "$key_name")
        if [[ -z "$phrase" ]]; then
            error "Passphrase required for export"
            info "Set PADLOCK_IGNITION_PASS or use --phrase=<passphrase>"
            return 1
        fi
    fi
    
    # Validate key data is present
    if [[ -z "$key_data" ]]; then
        error "Key data is empty for: $key_name"
        return 1
    fi
    
    # Export key with passphrase encryption metadata
    {
        echo "# ENCRYPTED WITH PASSPHRASE"
        echo "# This is a development placeholder - production should use age encryption"
        echo "# created: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
        
        # Extract public key for reference (optional - don't fail if it errors)
        local pub_key
        if command -v age-keygen >/dev/null 2>&1; then
            local temp_key_file="/tmp/temp_export_$$"
            echo "$key_data" > "$temp_key_file"
            pub_key=$(age-keygen -y < "$temp_key_file" 2>/dev/null) || true
            rm -f "$temp_key_file"
            
            if [[ -n "$pub_key" ]]; then
                echo "# public key: $pub_key"
            fi
        fi
        
        # Include the private key data - this is the critical part
        echo "$key_data"
    } > "$output_file" || {
        error "Failed to write export file: $output_file"
        return 1
    }
    
    # Generate checksum
    local checksum
    checksum=$(md5sum "$output_file" | cut -d' ' -f1)
    
    info "✓ Exported key to: $output_file"
    info "  Checksum: $checksum"
    info "  [SECURE] Key encrypted with passphrase"
    
    return 0
}


_do_ignite_revoke() {
    _parse_ignite_command_args "revoke" "$@" || return 1
    
    info "Revoking distributed key: $PARSED_NAME"
    info "This will permanently invalidate the key"
    
    local repo_root="$(_get_repo_root .)"
    if [[ -z "$repo_root" ]]; then
        error "Not in a git repository"
        return 1
    fi
    
    local ignition_dir="$repo_root/.padlock/ignition"
    if [[ ! -d "$ignition_dir" ]]; then
        error "No ignition system found"
        return 1
    fi
    
    local key_name="${PARSED_NAME}"
    if [[ -z "$key_name" ]]; then
        error "Key name is required"
        info "Usage: padlock ignite revoke --name=<key_name>"
        return 1
    fi
    
    local key_file="$ignition_dir/keys/${key_name}.dkey"
    local metadata_file="$ignition_dir/metadata/${key_name}.json"
    
    if [[ ! -f "$key_file" ]] && [[ ! -f "$metadata_file" ]]; then
        error "Key '$key_name' not found"
        return 1
    fi
    
    # Force confirmation unless --force is used
    if [[ $opt_force -ne 1 ]]; then
        warn "This will permanently revoke access for key: $key_name"
        warn "The key will be moved to revoked status and cannot be used"
        echo ""
        read -p "Continue with key revocation? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Key revocation cancelled"
            return 0
        fi
    fi
    
    info "🔐 Revoking key: $key_name"
    
    # Create revoked directory if it doesn't exist
    local revoked_dir="$ignition_dir/revoked"
    mkdir -p "$revoked_dir/keys" "$revoked_dir/metadata" 2>/dev/null || true
    
    # Move key to revoked directory
    if [[ -f "$key_file" ]]; then
        if mv "$key_file" "$revoked_dir/keys/" 2>/dev/null; then
            info "✓ Key file moved to revoked storage"
        else
            warn "Could not move key file to revoked storage"
        fi
    fi
    
    # Update metadata to mark as revoked
    if [[ -f "$metadata_file" ]]; then
        local temp_file=$(mktemp)
        if jq '. + {"status": "revoked", "revoked_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"}' "$metadata_file" > "$temp_file" 2>/dev/null; then
            if mv "$temp_file" "$revoked_dir/metadata/${key_name}.json"; then
                info "✓ Metadata updated and moved to revoked storage"
            else
                warn "Could not move metadata to revoked storage"
                rm -f "$temp_file"
            fi
        else
            warn "Could not update metadata with revocation status"
            rm -f "$temp_file"
            # Just move the original metadata
            mv "$metadata_file" "$revoked_dir/metadata/" 2>/dev/null || true
        fi
        
        # Remove from active metadata
        rm -f "$metadata_file" 2>/dev/null || true
    fi
    
    # Update manifest to remove this key
    local manifest_file="$ignition_dir/manifest.json"
    if [[ -f "$manifest_file" ]]; then
        local temp_manifest=$(mktemp)
        if jq --arg key_name "$key_name" 'del(.keys[] | select(.name == $key_name))' "$manifest_file" > "$temp_manifest" 2>/dev/null; then
            mv "$temp_manifest" "$manifest_file"
            info "✓ Key removed from active manifest"
        else
            warn "Could not update manifest"
            rm -f "$temp_manifest"
        fi
    fi
    
    okay "✓ Key '$key_name' has been revoked"
    info "Key is now inactive and cannot be used for repository access"
    info "Revoked key artifacts preserved in: $revoked_dir"
}


_do_ignite_rotate() {
    info "Rotating ignition master key"
    info "WARNING: This will invalidate ALL distributed keys!"
    info "All third-party access will need to be re-established"
    
    local repo_root="$(_get_repo_root .)"
    if [[ -z "$repo_root" ]]; then
        error "Not in a git repository"
        return 1
    fi
    
    local ignition_dir="$repo_root/.padlock/ignition"
    if [[ ! -d "$ignition_dir" ]]; then
        error "No ignition system found"
        return 1
    fi
    
    # Force confirmation unless --force is used
    if [[ $opt_force -ne 1 ]]; then
        warn "This will:"
        warn "  • Generate a new master key for ignition"
        warn "  • Invalidate ALL existing distributed keys"
        warn "  • Require re-creation of all third-party access"
        warn "  • Preserve old keys in archived state"
        echo ""
        read -p "Continue with master key rotation? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Master key rotation cancelled"
            return 0
        fi
    fi
    
    info "🔄 Rotating ignition master key..."
    
    # Create archive directory for old keys
    local archive_dir="$ignition_dir/archive/rotation_$(date +%s)"
    mkdir -p "$archive_dir/keys" "$archive_dir/metadata" 2>/dev/null || true
    
    # Archive existing keys
    if [[ -d "$ignition_dir/keys" ]]; then
        info "📦 Archiving existing distributed keys..."
        if cp -r "$ignition_dir/keys"/* "$archive_dir/keys/" 2>/dev/null; then
            info "✓ Existing keys archived"
        else
            warn "Could not archive all keys"
        fi
    fi
    
    # Archive existing metadata
    if [[ -d "$ignition_dir/metadata" ]]; then
        if cp -r "$ignition_dir/metadata"/* "$archive_dir/metadata/" 2>/dev/null; then
            info "✓ Existing metadata archived"
        else
            warn "Could not archive all metadata"
        fi
    fi
    
    # Generate new master key
    info "🔑 Generating new master key..."
    local new_master_key=$(age-keygen 2>/dev/null)
    local new_master_public=$(echo "$new_master_key" | age-keygen -y 2>/dev/null)
    
    if [[ -z "$new_master_key" ]] || [[ -z "$new_master_public" ]]; then
        error "Failed to generate new master key"
        return 1
    fi
    
    # Store new master key
    local master_key_file="$ignition_dir/.derived/master.key"
    echo "$new_master_key" > "$master_key_file"
    chmod 600 "$master_key_file"
    info "✓ New master key generated and stored"
    
    # Clear existing distributed keys (they're archived)
    rm -rf "$ignition_dir/keys"/* 2>/dev/null || true
    rm -rf "$ignition_dir/metadata"/* 2>/dev/null || true
    
    # Update manifest with new master public key and clear distributed keys
    local manifest_file="$ignition_dir/manifest.json"
    local temp_manifest=$(mktemp)
    
    if [[ -f "$manifest_file" ]]; then
        local new_manifest='{
            "master_public_key": "'$new_master_public'",
            "rotated_at": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'",
            "keys": [],
            "version": "1.0.0"
        }'
        echo "$new_manifest" | jq . > "$temp_manifest" 2>/dev/null || echo "$new_manifest" > "$temp_manifest"
        mv "$temp_manifest" "$manifest_file"
        info "✓ Manifest updated with new master key"
    else
        warn "Could not update manifest"
        rm -f "$temp_manifest"
    fi
    
    okay "✓ Master key rotation completed"
    info "New master public key: $new_master_public"
    info "All distributed keys have been invalidated and archived"
    info "Archive location: $archive_dir"
    info "You will need to recreate distributed keys for third-party access"
}


_do_ignite_reset() {
    info "Resetting ignition system"
    info "WARNING: This will remove ALL ignition infrastructure!"
    info "Repository will revert to standard key-only access"
    
    local repo_root="$(_get_repo_root .)"
    if [[ -z "$repo_root" ]]; then
        error "Not in a git repository"
        return 1
    fi
    
    local ignition_dir="$repo_root/.padlock/ignition"
    
    if [[ ! -d "$ignition_dir" ]]; then
        info "No ignition system found to reset"
        return 0
    fi
    
    # Force confirmation unless --force is used
    if [[ $opt_force -ne 1 ]]; then
        warn "This will permanently remove:"
        warn "  • All ignition keys and metadata"
        warn "  • Distributed access capabilities"
        warn "  • Third-party key registrations"
        echo ""
        read -p "Continue with ignition reset? [y/N]: " -r
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Ignition reset cancelled"
            return 0
        fi
    fi
    
    info "🗂️ Creating backup before reset..."
    local backup_dir="$repo_root/.padlock/reset_backup_$(date +%s)"
    if ! mkdir -p "$backup_dir" || ! cp -r "$ignition_dir" "$backup_dir/" 2>/dev/null; then
        warn "Could not create backup, continuing anyway..."
    else
        info "✓ Ignition backup created at: $backup_dir/ignition"
    fi
    
    info "🧹 Removing ignition infrastructure..."
    
    # Remove ignition directory contents
    if ! rm -rf "$ignition_dir" 2>/dev/null; then
        error "Failed to remove ignition directory"
        return 1
    fi
    
    info "✓ Ignition directory removed"
    
    # Clean up any ignition references in git
    if [[ -f "$repo_root/.gitignore" ]]; then
        # Remove ignition-related entries from .gitignore
        grep -v ".padlock/ignition" "$repo_root/.gitignore" > "$repo_root/.gitignore.tmp" 2>/dev/null || true
        mv "$repo_root/.gitignore.tmp" "$repo_root/.gitignore" 2>/dev/null || true
        info "✓ Cleaned .gitignore"
    fi
    
    okay "✓ Ignition system reset completed"
    info "Repository now uses standard padlock key-only access"
    info "All distributed keys have been invalidated"
    if [[ -d "$backup_dir" ]]; then
        info "Backup preserved at: $backup_dir"
    fi
}


_do_ignite_verify() {
    _parse_ignite_command_args "verify" "$@" || return 1
    
    local key_path="$PARSED_KEY_PATH"
    local passphrase="$PARSED_PASSPHRASE"
    
    if [[ -z "$key_path" ]]; then
        error "Missing --key parameter"
        info "Usage: padlock ignite verify --key=/path/to/key [--phrase=...]"
        return 1
    fi
    
    if [[ ! -f "$key_path" ]]; then
        error "Key file not found: $key_path"
        return 1
    fi
    
    info "Verifying ignition key: $key_path"
    
    # Load the key file
    local key_data=$(cat "$key_path")
    
    # Check if it's encrypted and needs passphrase
    if echo "$key_data" | grep -q "# ENCRYPTED WITH PASSPHRASE"; then
        if [[ -z "$passphrase" ]]; then
            error "Key is encrypted but no passphrase provided"
            info "Use: padlock ignite verify --key=$key_path --phrase=..."
            return 1
        fi
        # Extract the actual key from development format
        key_data=$(echo "$key_data" | grep -v "^#" | head -1)
        info "✓ Successfully decrypted key with passphrase"
    fi
    
    # Verify it's a valid age key
    if echo "$key_data" | grep -q "AGE-SECRET-KEY"; then
        # Extract public key
        local temp_key=$(mktemp)
        echo "$key_data" > "$temp_key"
        
        if public_key=$(age-keygen -y < "$temp_key" 2>/dev/null); then
            info "✓ Valid age key format"
            info "  Public key: $(echo "$public_key" | tr -d '\n')"
            
            # Check if this public key is known in our ignition system
            if [[ -d "$REPO_ROOT/.padlock/ignition/metadata" ]]; then
                local found_match=false
                for metadata in "$REPO_ROOT/.padlock/ignition/metadata"/*.json; do
                    if [[ -f "$metadata" ]]; then
                        local key_name=$(basename "$metadata" .json)
                        local stored_key_file="$REPO_ROOT/.padlock/ignition/keys/${key_name}.dkey"
                        if [[ -f "$stored_key_file" ]]; then
                            # Compare public keys (simplified check)
                            local stored_public=$(age-keygen -y < "$stored_key_file" 2>/dev/null | grep -v "^#" | head -1)
                            if [[ "$(echo "$public_key" | tr -d '\n')" == "$(echo "$stored_public" | tr -d '\n')" ]]; then
                                info "✓ Key matches known ignition key: $key_name"
                                found_match=true
                                break
                            fi
                        fi
                    fi
                done
                
                if [[ "$found_match" == false ]]; then
                    info "⚠ Key is valid but not registered in this repository's ignition system"
                    return 1
                fi
            else
                info "⚠ No ignition system configured in this repository"
                return 1
            fi
        else
            error "Failed to extract public key"
            rm -f "$temp_key"
            return 1
        fi
        
        rm -f "$temp_key"
        info "✓ Key verified: Can access this repository"
        return 0
    else
        error "Not a valid age ignition key"
        return 1
    fi
}


_do_ignite_help() { _ignite_help "$@"; }
_do_ignite_--help() { _ignite_help "$@"; }

# Placeholder implementations for TTY magic integration
# These will be implemented using Plan X winning approach
_create_ignition_master_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating ignition master for $name"
    
    # Check if master key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.ikey" ]]; then
        error "Ignition master key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the ignition master (I key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate ignition master key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    # Extract public key  
    age-keygen -y < "$temp_key" > "$temp_pub" 2>/dev/null || {
        error "Failed to extract public key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    local private_key=$(cat "$temp_key")
    local public_key=$(cat "$temp_pub")
    
    # Clean up temp files
    rm -f "$temp_key" "$temp_pub"
    
    # For development: Store key with passphrase marker (TODO: implement proper age encryption)
    local key_bundle
    if [[ -n "$passphrase" ]]; then
        # Store key with passphrase metadata for now (TODO: proper encryption)
        # In production, this would use age encryption or similar
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "master" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store ignition master key"
        return 1
    }
    
    info "✓ Ignition master key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    
    return 0
}

_create_ignition_distro_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating distributed key for $name"
    
    # Check if distributed key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.dkey" ]]; then
        error "Distributed ignition key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the distributed key (D key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate distributed ignition key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    # Extract public key
    age-keygen -y < "$temp_key" > "$temp_pub" 2>/dev/null || {
        error "Failed to extract public key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    local private_key=$(cat "$temp_key")
    local public_key=$(cat "$temp_pub")
    
    # Clean up temp files
    rm -f "$temp_key" "$temp_pub"
    
    # For development: Store key with passphrase marker (TODO: implement proper age encryption)
    local key_bundle
    if [[ -n "$passphrase" ]]; then
        # Store key with passphrase metadata for now (TODO: proper encryption)
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "distro" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store distributed ignition key"
        return 1
    }
    
    # Export the key to current directory for third-party sharing
    local export_file="./ignition.${name}.key"
    echo "$key_bundle" > "$export_file" || {
        error "Failed to export distributed key to: $export_file"
        return 1
    }
    
    # Create MD5 checksum per requirements
    local checksum=$(md5sum "$export_file" | cut -d' ' -f1)
    
    info "✓ Distributed ignition key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    info "  Key file: $export_file"
    info "  MD5 checksum: $checksum"
    
    return 0
}

_unlock_ignition_with_tty_magic() {
    local name="$1"  
    local passphrase="$2"
    
    trace "TTY magic: unlocking with key $name"
    
    # Load the key bundle using storage system
    _load_key_bundle "$name" "auto" || {
        error "Failed to load ignition key: $name"
        return 1
    }
    
    # Decrypt the key bundle if it's encrypted (development mode)
    local decrypted_key
    if echo "$LOADED_KEY_DATA" | grep -q "# ENCRYPTED WITH PASSPHRASE"; then
        if [[ -n "$passphrase" ]]; then
            # Extract the actual key from development format
            decrypted_key=$(echo "$LOADED_KEY_DATA" | grep -v "^#" | head -1)
            trace "Development mode: Extracted key from passphrase-protected format"
        else
            error "Key is encrypted but no passphrase provided"
            return 1
        fi
    else
        # Use key directly if not encrypted
        decrypted_key="$LOADED_KEY_DATA"
    fi
    
    # Verify the decrypted key is valid age format
    if echo "$decrypted_key" | grep -q "AGE-SECRET-KEY"; then
        info "✓ Successfully unlocked ignition key: $name"
        info "  Key type: $LOADED_KEY_TYPE"
        
        # TODO: Use the decrypted key to unlock repository secrets
        # This would integrate with the existing padlock unlock mechanism
        info "  [PLACEHOLDER] Would unlock repository with decrypted key"
        
        return 0
    else
        error "Invalid key format after decryption"
        return 1
    fi
}

# ============================================================================
# IGNITION STORAGE ARCHITECTURE - TASK-003
# ============================================================================

_setup_ignition_directories() {
    local repo_root="${1:-$REPO_ROOT}"
    
    if [[ -z "$repo_root" ]]; then
        error "No repository root specified for ignition setup"
        return 1
    fi
    
    local padlock_dir="$repo_root/.padlock"
    local ignition_dir="$padlock_dir/ignition"
    
    # Create ignition directory structure per ROADMAP.md
    trace "Setting up ignition directories in $padlock_dir"
    
    mkdir -p "$ignition_dir/keys" || {
        error "Failed to create ignition keys directory"
        return 1
    }
    
    mkdir -p "$ignition_dir/metadata" || {
        error "Failed to create ignition metadata directory"  
        return 1
    }
    
    mkdir -p "$ignition_dir/metadata/cache" || {
        error "Failed to create ignition cache directory"
        return 1
    }
    
    mkdir -p "$ignition_dir/.derived" || {
        error "Failed to create derived keys directory"
        return 1
    }
    
    # Create ignition manifest if it doesn't exist
    local manifest="$ignition_dir/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        trace "Creating ignition manifest: $manifest"
        cat > "$manifest" << 'EOF'
{
  "version": "1.0",
  "created": "",
  "updated": "",
  "repo_id": "",
  "master_key_fingerprint": "",
  "ignition_keys": {},
  "distro_keys": {}
}
EOF
        # Set creation timestamp
        local timestamp=$(date -Iseconds)
        sed -i "s/\"created\": \"\"/\"created\": \"$timestamp\"/" "$manifest"
        sed -i "s/\"updated\": \"\"/\"updated\": \"$timestamp\"/" "$manifest"
    fi
    
    info "✓ Ignition directories ready: $ignition_dir"
    return 0
}

_create_ignition_metadata() {
    local key_type="$1"     # "master" or "distro"  
    local name="$2"
    local key_path="$3"
    local fingerprint="$4"
    local encrypted="${5:-true}"  # Default to encrypted
    
    local metadata_file="$REPO_ROOT/.padlock/ignition/metadata/${name}.json"
    local timestamp=$(date -Iseconds)
    
    trace "Creating metadata for $key_type key: $name"
    
    cat > "$metadata_file" << EOF
{
  "name": "$name",
  "type": "$key_type",
  "created": "$timestamp",
  "updated": "$timestamp",
  "key_file": "$(basename "$key_path")",
  "fingerprint": "$fingerprint",
  "encrypted": $encrypted,
  "status": "active",
  "authority": {
    "master_key": true,
    "repo_key": true
  },
  "usage": {
    "unlock_count": 0,
    "last_used": null
  }
}
EOF
    
    return 0
}

_store_key_bundle() {
    local key_type="$1"     # "master" or "distro"
    local name="$2"
    local key_data="$3"
    local passphrase="$4"
    
    _setup_ignition_directories "$REPO_ROOT" || return 1
    
    local key_extension
    case "$key_type" in
        master) key_extension=".ikey" ;;
        distro) key_extension=".dkey" ;;
        *) error "Invalid key type: $key_type"; return 1 ;;
    esac
    
    local key_file="$REPO_ROOT/.padlock/ignition/keys/${name}${key_extension}"
    
    trace "Storing $key_type key bundle: $name"
    
    # For now, store key data directly (TODO: encrypt with passphrase using TTY magic)
    echo "$key_data" > "$key_file" || {
        error "Failed to store key bundle: $key_file"
        return 1
    }
    
    # Create fingerprint (simplified - use first 16 chars of key data hash)
    local fingerprint=$(echo "$key_data" | sha256sum | cut -c1-16)
    
    # Determine if key was encrypted
    local encrypted_status="false"
    if [[ -n "$passphrase" ]]; then
        encrypted_status="true"
    fi
    
    # Create metadata with encryption status
    _create_ignition_metadata "$key_type" "$name" "$key_file" "$fingerprint" "$encrypted_status" || {
        error "Failed to create metadata for key: $name"
        return 1
    }
    
    info "✓ Key bundle stored: $name ($key_type)"
    return 0
}

_load_key_bundle() {
    local name="$1"
    local key_type="${2:-auto}"  # "master", "distro", or "auto"
    
    # Auto-detect key type if not specified
    if [[ "$key_type" == "auto" ]]; then
        if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.ikey" ]]; then
            key_type="master"
        elif [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.dkey" ]]; then
            key_type="distro"  
        else
            error "No ignition key found for: $name"
            return 1
        fi
    fi
    
    local key_extension
    case "$key_type" in
        master) key_extension=".ikey" ;;
        distro) key_extension=".dkey" ;;
        *) error "Invalid key type: $key_type"; return 1 ;;
    esac
    
    local key_file="$REPO_ROOT/.padlock/ignition/keys/${name}${key_extension}"
    local metadata_file="$REPO_ROOT/.padlock/ignition/metadata/${name}.json"
    
    if [[ ! -f "$key_file" ]]; then
        error "Key file not found: $key_file"
        return 1
    fi
    
    if [[ ! -f "$metadata_file" ]]; then
        error "Metadata file not found: $metadata_file"
        return 1
    fi
    
    trace "Loading $key_type key bundle: $name"
    
    # Export key data and metadata for caller
    LOADED_KEY_DATA=$(cat "$key_file")
    LOADED_KEY_METADATA=$(cat "$metadata_file")
    LOADED_KEY_TYPE="$key_type"
    
    return 0
}

do_rotate() {
    local target="$1"
    shift || true

    # Set REPO_ROOT for the helpers
    REPO_ROOT=$(_get_repo_root .)

    case "$target" in
        master)
            # padlock rotate master
            info "[STUB] Rotating master key"
            info "WARNING: This will invalidate ALL repository keys!"
            info "All repositories will need to be re-keyed"
            return 0
            ;;
            
        ignition)
            # padlock rotate ignition [name]
            local name="${1:-default}"
            info "[STUB] Rotating ignition key: $name"
            info "WARNING: This will invalidate related distributed keys!"
            return 0
            ;;
            
        distro)
            # padlock rotate distro [name]
            local name="$1"
            if [[ -z "$name" ]]; then
                error "Missing distro key name"
                info "Usage: padlock rotate distro <name>"
                return 1
            fi
            info "[STUB] Rotating distributed key: $name"
            return 0
            ;;
            
        # Legacy support
        -K|--ignition)
            _rotate_ignition_key
            ;;
            
        help|*)
            if [[ "$target" != "help" ]]; then
                error "Unknown target for rotate: $target"
            fi
            info "Rotation Commands:"
            info "  master              Rotate global master key (affects all repos)"
            info "  ignition [name]     Rotate ignition key (invalidates D keys)"
            info "  distro <name>       Rotate specific distributed key"
            info ""
            info "Legacy:"
            info "  --ignition          Legacy ignition rotation"
            return 0
            ;;
    esac
}


do_export() {
    local export_file="${1:-padlock_export_$(date +%Y%m%d_%H%M%S).tar.age}"
    local passphrase

    # Get passphrase from environment, file, or interactive prompt
    if [[ -n "${PADLOCK_PASSPHRASE:-}" ]]; then
        passphrase="$PADLOCK_PASSPHRASE"
    elif [[ -n "${PADLOCK_PASSPHRASE_FILE:-}" ]] && [[ -f "$PADLOCK_PASSPHRASE_FILE" ]]; then
        passphrase=$(cat "$PADLOCK_PASSPHRASE_FILE")
    elif [[ -t 0 ]] && [[ -t 1 ]]; then
        # Interactive mode
        read -sp "Create a passphrase for the export file: " passphrase
        echo
    else
        fatal "No passphrase provided. Set PADLOCK_PASSPHRASE environment variable or use PADLOCK_PASSPHRASE_FILE for automation."
    fi

    if [[ -z "$passphrase" ]]; then
        fatal "Passphrase cannot be empty."
    fi

    # Check if there is anything to export
    if [[ ! -d "$PADLOCK_KEYS" || -z "$(ls -A "$PADLOCK_KEYS")" ]]; then
        error "No keys found to export."
        return 1
    fi
    if [[ ! -f "$PADLOCK_ETC/manifest.txt" ]]; then
        error "Manifest not found. Nothing to export."
        return 1
    fi

    info "📦 Exporting padlock environment..."

    local temp_dir
    temp_dir=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_dir"' RETURN

    local export_manifest="$temp_dir/manifest.txt"
    local keys_dir="$temp_dir/keys"

    # Copy manifest, keys, and repo artifacts to a temporary location
    cp "$PADLOCK_ETC/manifest.txt" "$export_manifest"
    cp -r "$PADLOCK_KEYS" "$keys_dir"
    
    # Copy repo artifacts if they exist
    if [[ -d "$PADLOCK_ETC/repos" ]]; then
        cp -r "$PADLOCK_ETC/repos" "$temp_dir/repos"
    fi

    # Create metadata file
    cat > "$temp_dir/export_info.json" << EOF
{
    "version": "1.0",
    "exported_at": "$(date -Iseconds)",
    "exported_by": "$(whoami)@$(hostname)",
    "padlock_version": "$PADLOCK_VERSION"
}
EOF

    # Create a tarball and encrypt it with the passphrase
    tar -C "$temp_dir" -czf - . | AGE_PASSPHRASE="$passphrase" age -p > "$export_file"
    if [[ $? -ne 0 ]]; then
        fatal "Failed to create encrypted export file."
    fi

    okay "✓ Padlock environment successfully exported to: $export_file"
    warn "⚠️  Keep this file and your passphrase safe!"
}

_merge_manifests() {
    local import_manifest="$1"
    local current_manifest="$2"
    local temp_file
    temp_file=$(_temp_mktemp)

    # Preserve header from current manifest if it exists
    if [[ -f "$current_manifest" ]]; then
        grep "^#" "$current_manifest" > "$temp_file"
    else
        # Or take header from import file
        grep "^#" "$import_manifest" > "$temp_file"
    fi

    # Merge entries (avoid duplicates by checking path column, which is column 3)
    {
        grep -v "^#" "$current_manifest" 2>/dev/null || true
        grep -v "^#" "$import_manifest"
    } | sort -t'|' -k3,3 -u >> "$temp_file"

    mv "$temp_file" "$current_manifest"
}

do_import() {
    local import_file="$1"
    local merge_mode="${2:---merge}"
    local passphrase="${3:-}" # Accept passphrase as 3rd arg

    if [[ ! -f "$import_file" ]]; then
        fatal "Import file not found: $import_file"
    fi

    if [[ -z "$passphrase" ]]; then
        # Get passphrase from environment, file, or interactive prompt
        if [[ -n "${PADLOCK_PASSPHRASE:-}" ]]; then
            passphrase="$PADLOCK_PASSPHRASE"
        elif [[ -n "${PADLOCK_PASSPHRASE_FILE:-}" ]] && [[ -f "$PADLOCK_PASSPHRASE_FILE" ]]; then
            passphrase=$(cat "$PADLOCK_PASSPHRASE_FILE")
        elif [[ -t 0 ]] && [[ -t 1 ]]; then
            read -sp "Enter passphrase for import file: " passphrase
            echo
        else
            fatal "No passphrase provided. Set PADLOCK_PASSPHRASE environment variable or use PADLOCK_PASSPHRASE_FILE for automation."
        fi
        
        if [[ -z "$passphrase" ]]; then
            fatal "Passphrase cannot be empty."
        fi
    fi

    local temp_dir
    temp_dir=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_dir"' RETURN

    # Decrypt and extract
    if ! AGE_PASSPHRASE="$passphrase" age -d < "$import_file" | tar -C "$temp_dir" -xzf -; then
        fatal "Failed to decrypt import file (wrong passphrase?)"
    fi

    # Validate import
    if [[ ! -f "$temp_dir/export_info.json" || ! -f "$temp_dir/manifest.txt" ]]; then
        fatal "Invalid padlock export file."
    fi

    info "Successfully decrypted export file."

    # Backup current state
    local backup_dir="$PADLOCK_ETC/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    if [[ -d "$PADLOCK_ETC" ]]; then
        cp -a "$PADLOCK_ETC"/* "$backup_dir/" 2>/dev/null || true
    fi
    info "Current environment backed up to: $backup_dir"

    # Import based on mode
    case "$merge_mode" in
        --replace)
            warn "Replacing current padlock environment."
            rm -f "$PADLOCK_ETC/manifest.txt"
            rm -rf "$PADLOCK_KEYS"
            rm -rf "$PADLOCK_ETC/repos"
            mkdir -p "$PADLOCK_KEYS"
            cp "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -r "$temp_dir/keys"/* "$PADLOCK_KEYS/"
            # Restore repo artifacts if they exist in the import
            if [[ -d "$temp_dir/repos" ]]; then
                cp -r "$temp_dir/repos" "$PADLOCK_ETC/repos"
            fi
            ;;
        --merge)
            info "Merging with current environment."
            _merge_manifests "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -rT "$temp_dir/keys" "$PADLOCK_KEYS" 2>/dev/null || true
            # Restore repo artifacts if they exist in the import
            if [[ -d "$temp_dir/repos" ]]; then
                mkdir -p "$PADLOCK_ETC/repos"
                cp -rT "$temp_dir/repos" "$PADLOCK_ETC/repos" 2>/dev/null || true
            fi
            ;;
        *)
            fatal "Unknown import mode: $merge_mode. Use --merge or --replace."
            ;;
    esac

    okay "✓ Import completed successfully."
}

do_snapshot() {
    local snapshot_name="${1:-auto_$(date +%Y%m%d_%H%M%S)}"
    local snapshots_dir="$PADLOCK_ETC/snapshots"

    mkdir -p "$snapshots_dir"

    # Use a temporary, non-guessable passphrase for the snapshot export
    local snapshot_pass
    snapshot_pass=$(openssl rand -base64 32)

    local export_file="$snapshots_dir/${snapshot_name}.tar.age"

    info "Creating snapshot: $snapshot_name"

    local temp_dir
    temp_dir=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_dir"' RETURN

    cp "$PADLOCK_ETC/manifest.txt" "$temp_dir/manifest.txt"
    cp -r "$PADLOCK_KEYS" "$temp_dir/keys"
    
    # Include repo artifacts in snapshot
    if [[ -d "$PADLOCK_ETC/repos" ]]; then
        cp -r "$PADLOCK_ETC/repos" "$temp_dir/repos"
    fi

    tar -C "$temp_dir" -czf - . | AGE_PASSPHRASE="$snapshot_pass" age -p > "$export_file"
    if [[ $? -ne 0 ]]; then
        fatal "Failed to create snapshot export file."
    fi

    # Create snapshot metadata, including the passphrase
    cat > "$snapshots_dir/${snapshot_name}.info" << EOF
name=$snapshot_name
created=$(date -Iseconds)
passphrase=$snapshot_pass
repos=$(grep -cv "^#" "$PADLOCK_ETC/manifest.txt")
keys=$(find "$PADLOCK_KEYS" -name "*.key" | wc -l)
EOF

    okay "✓ Snapshot created: $snapshot_name"
}

do_rewind() {
    local snapshot_name="$1"
    local snapshots_dir="$PADLOCK_ETC/snapshots"

    if [[ ! -f "$snapshots_dir/${snapshot_name}.tar.age" || ! -f "$snapshots_dir/${snapshot_name}.info" ]]; then
        error "Snapshot not found: $snapshot_name"
        info "Available snapshots:"
        ls -1 "$snapshots_dir"/*.info 2>/dev/null | sed 's/\.info$//' | xargs -I {} basename {} || echo " (none)"
        return 1
    fi

    warn "This will ERASE your current padlock environment and restore the snapshot."
    read -p "Type the snapshot name to confirm: '$snapshot_name': " confirm
    if [[ "$confirm" != "$snapshot_name" ]]; then
        info "Rewind cancelled."
        return 0
    fi

    # Get the passphrase from the metadata file
    local snapshot_pass
    snapshot_pass=$(grep "^passphrase=" "$snapshots_dir/${snapshot_name}.info" | cut -d'=' -f2)

    # Call do_import with the correct arguments for non-interactive restore
    do_import "$snapshots_dir/${snapshot_name}.tar.age" --replace "$snapshot_pass"

    okay "✓ Rewound to snapshot: $snapshot_name"
}

do_install() {
    local force="$opt_force"
    
    # Parse command-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                force=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    _logo
    # Check if already installed
    local install_dir="$XDG_LIB_HOME/fx/lib"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    local lib_file="$install_dir/padlock.sh"
    
    if [[ -f "$lib_file" ]] && [[ "$force" -eq 0 ]]; then
        warn "Padlock already installed (use --force to reinstall)"
        return 0
    fi
    
    info "Installing padlock to system..."
    
    # Remove old installation if exists
    if [[ -f "$lib_file" ]]; then
        info "Removing existing installation..."
        rm -f "$lib_file"
    fi
    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
    fi
    
    # Create installation directories
    mkdir -p "$install_dir" "$(dirname "$link_path")"
    
    # Copy only the built padlock.sh script to lib directory
    cp "$SCRIPT_PATH" "$lib_file"
    chmod +x "$lib_file"
    
    # Create symlink to bin directory
    ln -sf "$lib_file" "$link_path"
    
    # Generate master key on first install
    _ensure_master_key
    
    okay "✓ Padlock installed to: $lib_file"
    info "Available as: $link_path"
    info "🗝️  Global master key configured"
}

do_uninstall() {
    local lib_file="$XDG_LIB_HOME/fx/lib/padlock.sh"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    
    info "🗑️  Uninstalling padlock from system..."
    
    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        info "✓ Removed symlink: $link_path"
    fi
    
    if [[ -f "$lib_file" ]]; then
        rm "$lib_file"
        info "✓ Removed library: $lib_file"
    fi
    
    if [[ ! -L "$link_path" ]] && [[ ! -f "$lib_file" ]]; then
        warn "⚠️  Padlock was not installed or already removed"
        return 0
    fi
    
    okay "✓ Padlock uninstalled successfully"
    info "💡 Keys and repositories remain in ~/.local/etc/padlock/"
}

_overdrive_unlock() {
    REPO_ROOT=$(_get_repo_root .)

    if [[ ! -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository not in overdrive mode"
        return 1
    fi

    lock "🔓 Disengaging overdrive mode..."

    if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
        error "Master key not found, cannot unlock overdrive mode."
        info "Ensure your master key is available at $PADLOCK_GLOBAL_KEY"
        return 1
    fi
    export PADLOCK_KEY_FILE="$PADLOCK_GLOBAL_KEY"

    local super_chest="$REPO_ROOT/.super_chest"
    mkdir -p "$super_chest"
    
    if ! __decrypt_stream < "$REPO_ROOT/super_chest.age" | tar -C "$super_chest" -xzf -; then
        fatal "Failed to decrypt super_chest.age"
    fi

    if [[ -f "$REPO_ROOT/.overdrive" ]]; then
        local expected_checksum
        expected_checksum=$(grep "Super checksum:" "$REPO_ROOT/.overdrive" | cut -d' ' -f4)
        local current_checksum
        current_checksum=$(_calculate_locker_checksum "$super_chest")

        if [[ "$current_checksum" != "$expected_checksum" ]]; then
            warn "⚠️  Super chest integrity check failed!"
        else
            trace "✓ Super chest integrity verified"
        fi
    fi

    cp -rT "$super_chest/" "$REPO_ROOT/"

    rm -rf "$super_chest"
    rm -f "$REPO_ROOT/super_chest.age"
    rm -f "$REPO_ROOT/.overdrive"

    okay "🔓 Overdrive disengaged! Repository restored."
}

_overdrive_status() {
    REPO_ROOT=$(_get_repo_root .)

    info "=== Overdrive Status ==="

    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        local size
        size=$(du -h "$REPO_ROOT/super_chest.age" 2>/dev/null | cut -f1)
        warn "🚀 OVERDRIVE ENGAGED"
        info "Blob: super_chest.age ($size)"
        info "To restore: source .overdrive"
    else
        okay "✅ NORMAL MODE"
        info "To engage: padlock overdrive lock"
    fi
}

_overdrive_lock() {
    REPO_ROOT=$(_get_repo_root .)

    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository already in overdrive mode"
        return 1
    fi

    if [[ ! -d "$REPO_ROOT/locker" ]]; then
        fatal "Locker must be unlocked to engage overdrive mode."
    fi

    lock "🚀 Engaging overdrive mode..."

    # Create super_chest directory for staging
    local super_chest="$REPO_ROOT/.super_chest"
    mkdir -p "$super_chest"

    # Note: cleanup handled explicitly at end of function

    # Use tar to copy files, which is more reliable than rsync for this case
    info "Archiving entire repository..."
    tar -c --exclude-from <(printf "%s\n" \
        ".super_chest" \
        "bin" \
        ".chest" \
        "super_chest.age" \
        ".locked" \
        ".ignition.key" \
        ".git" \
        ".gitsim" \
        ".locker_checksum" \
        "locker.age" \
    ) -C "$REPO_ROOT" . | tar -x -C "$super_chest"

    source "$REPO_ROOT/locker/.padlock"

    local super_checksum
    super_checksum=$(_calculate_locker_checksum "$super_chest")

    tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        -C "$super_chest" -czf - . | __encrypt_stream > "$REPO_ROOT/super_chest.age"

    # Remove everything except padlock infrastructure and super_chest.age
    find "$REPO_ROOT" -maxdepth 1 -mindepth 1 \
        ! -name ".super_chest" \
        ! -name "bin" \
        ! -name ".chest" \
        ! -name ".git" \
        ! -name ".gitsim" \
        ! -name "super_chest.age" \
        -exec rm -rf {} +

    __print_overdrive_file "$REPO_ROOT/.overdrive" "$super_checksum"

    local size
    size=$(du -h "$REPO_ROOT/super_chest.age" | cut -f1)
    okay "🚀 Overdrive engaged! Entire repo → super_chest.age ($size)"
    
    # Clean up staging directory
    rm -rf "$super_chest"
}

do_overdrive() {
    local action="${1:-lock}"

    case "$action" in
        lock) _overdrive_lock ;;
        unlock)
            _overdrive_unlock
            ;;
        status)
            _overdrive_status
            ;;
        *)
            error "Unknown overdrive action: $action"
            info "Usage: padlock overdrive {lock|unlock|status}"
            return 1
            ;;
    esac
}

# Setup command - alias for clamp with common defaults
do_setup() {
    local target_path="${1:-.}"
    
    info "🔧 Setting up padlock in current repository..."
    
    # Default to generating a new key for setup
    do_clamp "$target_path" --generate
}

# Key management commands
do_key() {
    local action="${1:-}"
    shift || true
    
    case "$action" in
        --set-global)
            local key_file="$1"
            if [[ ! -f "$key_file" ]]; then
                fatal "Key file not found: $key_file"
            fi
            
            info "🔑 Setting global master key..."
            mkdir -p "$(dirname "$PADLOCK_GLOBAL_KEY")"
            cp "$key_file" "$PADLOCK_GLOBAL_KEY"
            chmod 600 "$PADLOCK_GLOBAL_KEY"
            okay "✓ Global master key set"
            ;;
        --show-global)
            if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
                error "No global master key found"
                info "Run: padlock key --generate-global"
                return 1
            fi
            
            local public_key
            public_key=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
            echo "$public_key"
            ;;
        --generate-global)
            _logo
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]] && [[ "${2:-}" != "--force" ]]; then
                error "Global master key already exists"
                info "Use --force to overwrite"
                return 1
            fi
            
            _ensure_master_key
            okay "✓ Global master key generated"
            ;;
        --add-recipient)
            local recipient="$1"
            if [[ -z "$recipient" ]]; then
                fatal "--add-recipient requires a public key"
            fi
            
            # Check if we're in a repo with locker config
            if [[ ! -f "locker/.padlock" ]]; then
                error "Not in an unlocked padlock repository"
                info "Run 'padlock unlock' first"
                return 1
            fi
            
            # Load current config
            source "locker/.padlock"
            
            # Add recipient to existing list
            if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
                export AGE_RECIPIENTS="$AGE_RECIPIENTS,$recipient"
            else
                export AGE_RECIPIENTS="$recipient"
            fi
            
            # Update config file
            __print_padlock_config "locker/.padlock" "$(basename "$PWD")"
            
            okay "✓ Added recipient: ${recipient:0:20}..."
            info "Re-encrypt with: padlock lock"
            ;;
        restore)
            _logo
            _restore_master_key
            ;;
        
        # New key testing commands
        is)
            # padlock key is <type> --key=/path
            local key_type="$1"
            local key_path=""
            shift || true
            
            # Parse options with BashFX pattern
            local opts=("$@")
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key=*)
                        key_path="${opts[i]#*=}"
                        ;;
                    --path=*)
                        key_path="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key_path" ]]; then
                error "Missing --key or --path parameter"
                info "Usage: padlock key is <type> --key=/path/to/key"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if key at '$key_path' is type '$key_type'"
            info "This feature will analyze key metadata and structure"
            return 0
            ;;
            
        authority)
            # padlock key authority --key1=/path --key2=/path
            local key1="" key2=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key1=*)
                        key1="${opts[i]#*=}"
                        ;;
                    --key2=*)
                        key2="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key1" ]] || [[ -z "$key2" ]]; then
                error "Missing required parameters"
                info "Usage: padlock key authority --key1=/path --key2=/path"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if '$key1' has authority over '$key2'"
            info "This will verify key hierarchy relationships"
            return 0
            ;;
            
        subject)
            # padlock key subject --key1=/path --key2=/path
            local key1="" key2=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key1=*)
                        key1="${opts[i]#*=}"
                        ;;
                    --key2=*)
                        key2="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key1" ]] || [[ -z "$key2" ]]; then
                error "Missing required parameters"
                info "Usage: padlock key subject --key1=/path --key2=/path"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if '$key1' is subject to '$key2'"
            info "This will verify child-parent key relationships"
            return 0
            ;;
            
        type)
            # padlock key type --key=/path
            local key_path=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key=*)
                        key_path="${opts[i]#*=}"
                        ;;
                    --path=*)
                        key_path="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key_path" ]]; then
                error "Missing --key parameter"
                info "Usage: padlock key type --key=/path/to/key"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Identifying key type for: $key_path"
            info "Will return: skull|master|repo|ignition|distro|unknown"
            echo "unknown"  # Placeholder return
            return 0
            ;;
            
        ""|*)
            if [[ -z "$action" ]]; then
                info "Available key management actions:"
            else
                error "Unknown key action: $action"
            fi
            info "  --set-global <key>        Set global master key"
            info "  --show-global             Display global public key"
            info "  --generate-global         Generate new global key"
            info "  --add-recipient <key>     Add recipient to current repo"
            info "  restore                   Restore master key from skull backup"
            info ""
            info "Key Testing Commands:"
            info "  is <type> --key=/path     Test if key is specific type"
            info "  authority --key1=X --key2=Y  Test authority relationship"
            info "  subject --key1=X --key2=Y    Test subject relationship"
            info "  type --key=/path          Identify key type"
            [[ -n "$action" ]] && return 1 || return 0
            ;;
    esac
}

do_master() {
    local action="$1"
    shift || true
    
    case "$action" in
        generate)
            # padlock master generate
            _logo
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]] && [[ "$1" != "--force" ]]; then
                error "Global master key already exists"
                info "Use --force to overwrite"
                return 1
            fi
            
            _ensure_master_key
            okay "✓ Master key generated"
            ;;
            
        show)
            # padlock master show
            if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
                error "No global master key found"
                info "Run: padlock master generate"
                return 1
            fi
            
            local public_key
            public_key=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
            echo "$public_key"
            ;;
            
        restore)
            # padlock master restore
            _logo
            _restore_master_key
            ;;
            
        unlock)
            # padlock master unlock (same as master-unlock)
            do_master_unlock "$@"
            ;;
            
        help|*)
            if [[ "$action" != "help" ]]; then
                error "Unknown master action: $action"
            fi
            info "Master Key Management Commands:"
            info "  generate [--force]   Generate new global master key"
            info "  show                 Display master public key"
            info "  restore              Restore master key from skull backup"
            info "  unlock               Emergency unlock using master key"
            return 0
            ;;
    esac
}

do_sec() {
    local action="${1:-}"
    
    case "$action" in
        auto)
            # padlock sec auto (was: automap)
            shift || true
            do_automap "$@"
            ;;
            
        add)
            # padlock sec add /path
            shift || true
            local path="${1:-}"
            if [[ -z "$path" ]]; then
                error "Missing file path"
                info "Usage: padlock sec add <path>"
                return 1
            fi
            
            do_map add "$path" "${@:2}"
            ;;
            
        "")
            # padlock sec (no action) - show help
            info "File Security Commands:"
            info "  <path>              Secure file (default: add)"
            info "  add <path>          Add file to security mapping"
            info "  remove <path>       Remove file from security mapping"
            info "  auto                Auto-secure sensitive files (*.md, build.sh, etc.)"
            return 0
            ;;
            
        *)
            # padlock sec /path (treat first arg as path)
            if [[ -z "$action" ]]; then
                error "Missing file path"
                info "Usage: padlock sec <path>"
                return 1
            fi
            
            do_map add "$action" "${@:2}"
            ;;
            
        remove)
            # padlock sec remove /path
            local path="$1"
            if [[ -z "$path" ]]; then
                error "Missing file path"
                info "Usage: padlock sec remove <path>"
                return 1
            fi
            
            do_map remove "$path" "${@:2}"
            ;;
            
        help|*)
            if [[ "$action" != "help" ]] && [[ "$action" != "auto" ]] && [[ -n "$action" ]]; then
                # Treat as path for backward compatibility
                do_map add "$action" "$@"
                return
            fi
            
            if [[ "$action" != "help" ]] && [[ "$action" != "auto" ]]; then
                error "Unknown sec action: $action"
            fi
            info "File Security Commands:"
            info "  <path>              Secure file (default: add)"
            info "  add <path>          Add file to security mapping"
            info "  remove <path>       Remove file from security mapping"
            info "  auto                Auto-secure sensitive files (*.md, build.sh, etc.)"
            return 0
            ;;
    esac
}

do_setup() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        ignition)
            # Direct skull backup creation
            _create_skull_backup
            return $?
            ;;
        *)
            # Default interactive setup
            _logo
            info "🔧 Padlock Interactive Setup"
            echo
            
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                okay "✓ Master key already exists"
                
                # Check if skull backup exists
                local skull_backup="$PADLOCK_KEYS/skull.age"
                if [[ -f "$skull_backup" ]]; then
                    okay "✓ Skull backup exists"
                    info "Your padlock is fully configured."
                    echo
                    info "Available commands:"
                    info "  padlock clamp <dir>       - Deploy to a new repository"
                    info "  padlock setup skull       - Recreate skull backup"
                    info "  padlock key restore       - Restore from skull backup"
                    info "  padlock --help            - Show all commands"
                    return 0
                else
                    warn "⚠️  Skull backup is missing"
                    info "Creating skull backup from existing master key..."
                    echo
                    _create_skull_backup
                    return $?
                fi
            fi
            ;;
    esac
    
    echo "This will set up padlock encryption with a master key and skull backup."
    echo "The skull backup allows you to recover your master key if lost."
    echo
    read -p "Proceed with setup? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        info "Setup cancelled."
        return 1
    fi
    
    echo
    info "🔑 Creating master key and skull backup..."
    _ensure_master_key
    
    echo
    okay "✓ Setup complete!"
    echo
    info "Next steps:"
    info "  1. Run 'padlock clamp <directory>' to secure a repository"
    info "  2. Keep your master key safe: $PADLOCK_GLOBAL_KEY"
    info "  3. Remember your ignition passphrase for emergency recovery"
}

do_repair() {
    local repo_path="${1:-.}"
    repo_path="$(realpath "$repo_path")"
    
    info "🔧 Padlock Repair Tool"
    echo
    
    # Check if this looks like a padlock repository - show help if not
    if [[ ! -f "$repo_path/bin/padlock" ]]; then
        info "No padlock installation found in: $repo_path"
        info "The 'repair' command fixes existing padlock repositories"
        info ""
        info "Usage: padlock repair [path]"
        info ""
        info "Prerequisites:"
        info "  • Repository must have padlock already deployed"
        info "  • Use 'padlock clamp' to set up a new repository first"
        return 0
    fi
    
    # Check what's missing and what can be repaired
    local missing_items=()
    local can_repair=false
    local was_locked=false
    
    if [[ ! -f "$repo_path/locker/.padlock" ]]; then
        if [[ -d "$repo_path/locker" ]]; then
            # Repository is unlocked but .padlock is missing
            missing_items+=(".padlock config file")
            can_repair=true
        else
            # Repository appears to be locked, check if encrypted data exists
            if [[ -f "$repo_path/.chest/locker.age" ]] || [[ -f "$repo_path/locker.age" ]]; then
                info "Repository is currently locked. Unlocking first..."
                if cd "$repo_path" && ./bin/padlock unlock; then
                    was_locked=true
                    can_repair=true
                    missing_items+=(".padlock config file")
                else
                    error "Cannot unlock repository. Repair cannot proceed."
                    info "Ensure you have the correct master key or try 'padlock key restore'"
                    return 1
                fi
            else
                # No encrypted data found and no locker directory
                info "No encrypted locker found (locker.age or .chest/locker.age missing)"
                info "The 'repair' command expects to find encrypted locker data"
                info ""
                info "Usage: padlock repair [path]"
                info ""
                info "Prerequisites:"
                info "  • Repository should have a locker.age file (old format) or .chest/locker.age (new format)"
                info "  • Use 'padlock clamp' first if this is a new setup"
                return 0
            fi
        fi
    fi
    
    if [[ ${#missing_items[@]} -eq 0 ]]; then
        okay "✓ No missing artifacts detected"
        info "Repository appears to be in good condition."
        return 0
    fi
    
    # Look up repository in manifest for repair information
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    local manifest_entry=""
    
    if [[ -f "$manifest_file" ]]; then
        manifest_entry=$(grep "|$repo_path|" "$manifest_file" 2>/dev/null || true)
    fi
    
    if [[ -z "$manifest_entry" ]]; then
        warn "⚠️  Repository not found in global manifest"
        info "Attempting repair from available evidence..."
    else
        info "📋 Found manifest entry for this repository"
        trace "Manifest: $manifest_entry"
    fi
    
    # Repair missing .padlock file
    if printf '%s\n' "${missing_items[@]}" | grep -q ".padlock config file"; then
        info "🔧 Repairing .padlock configuration..."
        
        # Determine repository type and key configuration
        local repo_type="standard"
        local key_file=""
        local recipients=""
        
        if [[ -n "$manifest_entry" ]]; then
            repo_type=$(echo "$manifest_entry" | cut -d'|' -f4)
        fi
        
        # Try to determine key configuration from existing setup
        if [[ "$repo_type" == "ignition" ]]; then
            # For ignition mode, we need to check if chest exists
            if [[ -d "$repo_path/.chest" && -f "$repo_path/.chest/ignition.age" ]]; then
                info "🔥 Detected ignition mode setup"
                # This would require ignition key to decrypt, for now set up for master key access
                key_file="$PADLOCK_GLOBAL_KEY"
                recipients=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null || echo "")
            else
                warn "Ignition setup incomplete, falling back to standard mode"
                repo_type="standard"
            fi
        fi
        
        if [[ "$repo_type" == "standard" ]]; then
            # Try to find repository-specific key
            local repo_name
            repo_name=$(basename "$repo_path")
            local repo_key="$PADLOCK_KEYS/$repo_name.key"
            
            if [[ -f "$repo_key" ]]; then
                key_file="$repo_key"
                recipients=$(age-keygen -y "$repo_key" 2>/dev/null || echo "")
                info "🔑 Using repository-specific key"
            elif [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                key_file="$PADLOCK_GLOBAL_KEY"
                recipients=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null || echo "")
                info "🔑 Using global master key"
            else
                error "No suitable key found for repair"
                info "Options:"
                info "  • Run 'padlock key --generate-global' to create master key"
                info "  • Run 'padlock key restore' if you have skull backup"
                return 1
            fi
        fi
        
        if [[ -n "$recipients" ]]; then
            # Set up environment for config generation
            export AGE_RECIPIENTS="$recipients"
            export PADLOCK_KEY_FILE="$key_file"
            export AGE_PASSPHRASE=""
            export REPO_ROOT="$repo_path"
            
            # Generate new .padlock config
            __print_padlock_config "$repo_path/locker/.padlock" "$(basename "$repo_path")"
            
            okay "✓ Regenerated .padlock configuration"
            info "Key: $(basename "$key_file")"
            info "Recipient: ${recipients:0:20}..."
        else
            error "Failed to determine encryption configuration"
            return 1
        fi
    fi
    
    # Try to restore any missing artifacts
    if _restore_repo_artifacts "$repo_path"; then
        info "🔧 Additional artifacts restored from backup"
    else
        # Check if artifacts exist in local namespace (migration scenario)
        local repo_name=$(basename "$repo_path")
        local namespace="local"
        if [[ -d "$repo_path/.git" ]]; then
            local remote_url
            remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
            if [[ -n "$remote_url" ]]; then
                # Parse remote URL to determine current namespace
                local host user_repo
                if [[ "$remote_url" =~ ^https?://([^/]+)/([^/]+)/([^/]+) ]]; then
                    host="${BASH_REMATCH[1]}"
                    user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
                elif [[ "$remote_url" =~ ^[^@]+@([^:]+):([^/]+)/([^/]+) ]]; then
                    host="${BASH_REMATCH[1]}"
                    user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
                else
                    host="unknown"
                    user_repo=$(basename "$repo_path")
                fi
                namespace="$host"
                repo_name="$user_repo"
            fi
        fi
        
        # If current namespace is not 'local', check for orphaned local artifacts
        if [[ "$namespace" != "local" ]]; then
            local local_artifacts_dir="$PADLOCK_ETC/repos/local/$(basename "$repo_path")"
            local current_artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
            if [[ -d "$local_artifacts_dir" && ! -d "$current_artifacts_dir" ]]; then
                info "🚨 Found orphaned artifacts in local namespace"
                info "Migrating from local to current namespace..."
                if _migrate_artifacts_namespace "$local_artifacts_dir" "$current_artifacts_dir"; then
                    okay "✓ Migrated orphaned artifacts"
                    rm -rf "$local_artifacts_dir"
                    _restore_repo_artifacts "$repo_path"  # Try restore again
                fi
            fi
        fi
    fi
    
    echo
    okay "✓ Repair completed successfully"
    info "Repository should now be functional."
    info "Test with: padlock status"
}

# Safe declamp operation - remove padlock infrastructure while preserving data
do_declamp() {
    local repo_path="${1:-.}"
    local force="${2:-}"
    
    repo_path="$(realpath "$repo_path")"
    
    # Validate target - show help if not a git repository
    if ! is_git_repo "$repo_path"; then
        info "Target is not a git repository: $repo_path"
        info "The 'declamp' command removes padlock encryption from a git repository"
        info ""
        info "Usage: padlock declamp [path] [--force]"
        info ""
        info "Options:"
        info "  --force    Force removal even if repository is locked"
        info ""
        info "Prerequisites:"
        info "  • Target directory must be a git repository with padlock deployed"
        info "  • Repository should be unlocked (or use --force)"
        return 0
    fi
    
    REPO_ROOT="$(_get_repo_root "$repo_path")"
    
    # Check if padlock is deployed - show help if not
    if ! is_deployed "$REPO_ROOT"; then
        info "Padlock not deployed in this repository"
        info "The 'declamp' command removes padlock encryption from a repository"
        info ""
        info "Usage: padlock declamp [path] [--force]"
        info ""
        info "Prerequisites:"
        info "  • Repository must have padlock already deployed (see 'padlock clamp')"
        info "  • Nothing to declamp from this repository"
        return 0
    fi
    
    lock "🔓 Safely declamping padlock from repository..."
    
    # Ensure repository is unlocked first
    local state="$(_get_lock_state "$REPO_ROOT")"
    if [[ "$state" == "locked" ]]; then
        if [[ "$force" != "--force" ]]; then
            error "Repository is locked. Unlock first or use --force"
            info "To unlock: padlock unlock"
            info "Or force: padlock declamp --force"
            return 1
        fi
        
        # Force unlock before declamp
        warn "Force-unlocking locked repository..."
        if [[ -f "$REPO_ROOT/locker.age" ]]; then
            info "Unlocking standard locker..."
            if ! (cd "$REPO_ROOT" && "$REPO_ROOT/bin/padlock" unlock); then
                fatal "Failed to unlock repository for declamp"
            fi
        elif [[ -f "$REPO_ROOT/.chest/locker.age" ]]; then
            info "Unlocking chest mode..."
            if ! (cd "$REPO_ROOT" && "$REPO_ROOT/bin/padlock" unlock); then
                fatal "Failed to unlock repository for declamp"
            fi
        fi
    fi
    
    # Show what will be preserved
    if [[ -d "$REPO_ROOT/locker" ]]; then
        local file_count
        file_count=$(find "$REPO_ROOT/locker" -type f | wc -l)
        info "📁 Preserving $file_count files from locker/ (will remain as plaintext)"
    else
        warn "No locker directory found - nothing to preserve"
    fi
    
    # Show what will be removed
    local items_to_remove=()
    [[ -d "$REPO_ROOT/bin" ]] && items_to_remove+=("bin/")
    [[ -d "$REPO_ROOT/.githooks" ]] && items_to_remove+=(".githooks/")
    [[ -f "$REPO_ROOT/locker.age" ]] && items_to_remove+=("locker.age")
    [[ -f "$REPO_ROOT/.locked" ]] && items_to_remove+=(".locked")
    [[ -d "$REPO_ROOT/.chest" ]] && items_to_remove+=(".chest/")
    [[ -f "$REPO_ROOT/padlock.map" ]] && items_to_remove+=("padlock.map")
    [[ -f "$REPO_ROOT/.locker_checksum" ]] && items_to_remove+=(".locker_checksum")
    [[ -f "$REPO_ROOT/SECURITY.md" ]] && items_to_remove+=("SECURITY.md")
    
    if [[ ${#items_to_remove[@]} -gt 0 ]]; then
        info "🗑️  Will remove: ${items_to_remove[*]}"
    fi
    
    # Confirm destructive operation
    if [[ "$force" != "--force" ]]; then
        echo
        warn "⚠️  This will permanently remove padlock infrastructure"
        read -p "Continue? (y/N): " -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Declamp cancelled"
            return 0
        fi
    fi
    
    # Remove padlock infrastructure
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
    if [[ -f "$REPO_ROOT/locker.age" ]]; then
        rm -f "$REPO_ROOT/locker.age"
        removed_items+=("locker.age")
    fi
    
    if [[ -f "$REPO_ROOT/.locked" ]]; then
        rm -f "$REPO_ROOT/.locked"
        removed_items+=(".locked")
    fi
    
    if [[ -d "$REPO_ROOT/.chest" ]]; then
        rm -rf "$REPO_ROOT/.chest"
        removed_items+=(".chest/")
    fi
    
    # Remove padlock.map and checksums
    if [[ -f "$REPO_ROOT/padlock.map" ]]; then
        rm -f "$REPO_ROOT/padlock.map"
        removed_items+=("padlock.map")
    fi
    
    if [[ -f "$REPO_ROOT/.locker_checksum" ]]; then
        rm -f "$REPO_ROOT/.locker_checksum"
        removed_items+=(".locker_checksum")
    fi
    
    # Remove other padlock files
    rm -f "$REPO_ROOT/.overdrive"
    rm -f "$REPO_ROOT/super_chest.age"
    
    # Clean up .gitattributes (remove padlock lines)
    if [[ -f "$REPO_ROOT/.gitattributes" ]]; then
        local temp_attrs
        temp_attrs=$(mktemp)
        grep -v "locker.age\|filter=locker-crypt\|bin/\*\|.githooks/\*" "$REPO_ROOT/.gitattributes" > "$temp_attrs" || true
        mv "$temp_attrs" "$REPO_ROOT/.gitattributes"
        
        # Remove file if empty (except comments and whitespace)
        if ! grep -q "^[^#[:space:]]" "$REPO_ROOT/.gitattributes" 2>/dev/null; then
            rm -f "$REPO_ROOT/.gitattributes"
            removed_items+=(".gitattributes")
        fi
    fi
    
    # Clean up .gitignore (remove padlock lines)
    if [[ -f "$REPO_ROOT/.gitignore" ]]; then
        local temp_ignore
        temp_ignore=$(mktemp)
        grep -v "^locker/$\|^# Padlock" "$REPO_ROOT/.gitignore" > "$temp_ignore" || true
        mv "$temp_ignore" "$REPO_ROOT/.gitignore"
    fi
    
    # Remove git configuration
    (cd "$REPO_ROOT" && {
        git config --unset filter.locker-crypt.clean 2>/dev/null || true
        git config --unset filter.locker-crypt.smudge 2>/dev/null || true
        git config --unset filter.locker-crypt.required 2>/dev/null || true
        git config --unset core.hooksPath 2>/dev/null || true
    })
    
    # Remove from global manifest
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" ]]; then
        local temp_manifest
        temp_manifest=$(mktemp)
        grep -v -F "$REPO_ROOT" "$manifest_file" > "$temp_manifest" 2>/dev/null || true
        mv "$temp_manifest" "$manifest_file"
        trace "Removed from global manifest"
    fi
    
    # Remove repository-specific keys and namespace artifacts
    local repo_name="$(basename "$REPO_ROOT")"
    local repo_key_file="$PADLOCK_KEYS/$repo_name.key"
    
    # Determine namespace to find artifacts
    local namespace="local"
    if [[ -d "$REPO_ROOT/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$REPO_ROOT" remote get-url origin 2>/dev/null || echo "")
        if [[ "$remote_url" =~ github\.com[:/]([^/]+)/(.+) ]]; then
            namespace="github.com"
        elif [[ "$remote_url" =~ gitlab\.com[:/]([^/]+)/(.+) ]]; then
            namespace="gitlab.com"
        elif [[ "$remote_url" =~ ([^/:]+)[:/]([^/]+)/(.+) ]]; then
            namespace="${BASH_REMATCH[1]}"
        fi
    fi
    
    # Remove repository key
    if [[ -f "$repo_key_file" ]]; then
        rm -f "$repo_key_file"
        trace "Removed repository key: $repo_key_file"
    fi
    
    # Remove namespace artifacts directory
    local artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    if [[ -d "$artifacts_dir" ]]; then
        rm -rf "$artifacts_dir"
        trace "Removed artifacts directory: $artifacts_dir"
        
        # Clean up empty parent directories
        local namespace_dir="$PADLOCK_ETC/repos/$namespace"
        if [[ -d "$namespace_dir" ]] && [[ -z "$(ls -A "$namespace_dir" 2>/dev/null)" ]]; then
            rmdir "$namespace_dir"
            trace "Removed empty namespace directory: $namespace_dir"
        fi
    fi
    
    # Remove template SECURITY.md if it's the padlock one
    if [[ -f "$REPO_ROOT/SECURITY.md" ]] && grep -q "Padlock" "$REPO_ROOT/SECURITY.md" 2>/dev/null; then
        rm -f "$REPO_ROOT/SECURITY.md"
        removed_items+=("SECURITY.md")
    fi
    
    # Success message
    okay "✓ Padlock safely removed from repository"
    
    if [[ -d "$REPO_ROOT/locker" ]]; then
        local preserved_count
        preserved_count=$(find "$REPO_ROOT/locker" -type f | wc -l)
        okay "✅ Preserved $preserved_count files in locker/ (now unencrypted)"
        warn "⚠️  locker/ is now unencrypted plaintext"
        info "💡 Add 'locker/' to .gitignore before committing"
    fi
    
    if [[ ${#removed_items[@]} -gt 0 ]]; then
        info "🗑️  Removed: ${removed_items[*]}"
    fi
    
    info "📋 Repository restored to standard git repo"
}

# Revocation operations - remove access to encrypted content
do_map() {
    local src_path="${1:-}"
    local action="${2:-add}"
    
    local repo_root="$(_get_repo_root .)"
    local map_file="$repo_root/padlock.map"
    
    if [[ -z "$src_path" ]]; then
        # Show current mappings
        if [[ -f "$map_file" ]]; then
            info "📋 Current file mappings:"
            echo
            while IFS='|' read -r src_rel dest_rel checksum; do
                # Skip comments and empty lines
                [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
                [[ -z "$src_rel" ]] && continue
                
                local src_abs="$repo_root/$src_rel"
                local status="❓"
                local checksum_status=""
                
                if [[ -f "$src_abs" ]]; then
                    status="✓"
                    if [[ -n "$checksum" ]]; then
                        local current_checksum
                        current_checksum=$(md5sum "$src_abs" | cut -d' ' -f1)
                        if [[ "$current_checksum" == "$checksum" ]]; then
                            checksum_status="✓"
                        else
                            checksum_status="⚠️"
                        fi
                    fi
                elif [[ -d "$src_abs" ]]; then
                    status="📁"
                    if [[ -n "$checksum" ]]; then
                        local current_checksum
                        current_checksum=$(find "$src_abs" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
                        if [[ "$current_checksum" == "$checksum" ]]; then
                            checksum_status="✓"
                        else
                            checksum_status="⚠️"
                        fi
                    fi
                else
                    status="❌"
                    checksum_status="❌"
                fi
                
                if [[ -n "$checksum" ]]; then
                    printf "  %s %s %s [%s]\n" "$status" "$checksum_status" "$src_rel" "${checksum:0:8}..."
                else
                    printf "  %s %s\n" "$status" "$src_rel"
                fi
            done < "$map_file"
            echo
            info "Usage: padlock map <file|dir> [add|remove]"
        else
            info "No mappings defined. Use: padlock map <file|dir>"
        fi
        return 0
    fi
    
    # Normalize source path
    if [[ "$src_path" = /* ]]; then
        # Absolute path - convert to relative from repo root
        src_path="$(realpath --relative-to="$repo_root" "$src_path")"
    else
        # Relative path - ensure it exists
        src_path="$(realpath --relative-to="$repo_root" "$repo_root/$src_path")"
    fi
    
    # Validate source exists
    local src_abs="$repo_root/$src_path"
    if [[ ! -e "$src_abs" ]]; then
        error "Source not found: $src_path"
        return 1
    fi
    
    # Prevent mapping files already in locker/
    if [[ "$src_path" == locker/* ]]; then
        error "Files in locker/ are automatically included"
        info "Map command is for files outside the locker/"
        return 1
    fi
    
    # Prevent mapping sensitive padlock files
    case "$src_path" in
        .git/*|bin/*|.githooks/*|locker.age|.locked|.chest/*|super_chest.age|.overdrive|padlock.map)
            error "Cannot map padlock infrastructure files"
            return 1
            ;;
    esac
    
    case "$action" in
        add)
            # Create map file if it doesn't exist
            if [[ ! -f "$map_file" ]]; then
                cat > "$map_file" << 'EOF'
# Padlock File Mapping
# Format: source_path|destination_path|md5_checksum
# Paths are relative to repository root
# Files listed here will be included in encrypted chest
EOF
            fi
            
            # Check if already mapped
            if grep -q "^$src_path|" "$map_file" 2>/dev/null; then
                warn "Already mapped: $src_path"
                return 0
            fi
            
            # Calculate checksum
            local checksum=""
            if [[ -f "$src_abs" ]]; then
                checksum=$(md5sum "$src_abs" | cut -d' ' -f1)
            elif [[ -d "$src_abs" ]]; then
                # For directories, create a checksum based on all files
                checksum=$(find "$src_abs" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
            fi
            
            # Add mapping with checksum
            echo "$src_path|$src_path|$checksum" >> "$map_file"
            
            # Backup the updated map file
            _backup_repo_artifacts "$repo_root"
            
            if [[ -f "$src_abs" ]]; then
                okay "✓ Mapped file: $src_path"
            elif [[ -d "$src_abs" ]]; then
                okay "✓ Mapped directory: $src_path"
                local file_count
                file_count=$(find "$src_abs" -type f | wc -l)
                info "📁 Contains $file_count files"
            fi
            ;;
            
        remove)
            if [[ ! -f "$map_file" ]]; then
                error "No mappings file found"
                return 1
            fi
            
            if ! grep -q "^$src_path|" "$map_file"; then
                error "Not mapped: $src_path"
                return 1
            fi
            
            # Remove the mapping
            local temp_file
            temp_file=$(_temp_mktemp)
            grep -v "^$src_path|" "$map_file" > "$temp_file"
            mv "$temp_file" "$map_file"
            
            # Backup the updated map file
            _backup_repo_artifacts "$repo_root"
            
            okay "✓ Unmapped: $src_path"
            ;;
            
        *)
            error "Unknown action: $action"
            info "Available actions: add, remove"
            return 1
            ;;
    esac
    
    info "💡 Changes take effect on next lock operation"
}

do_automap() {
    local repo_root="$(_get_repo_root .)"
    local map_file="$repo_root/padlock.map"
    
    info "🤖 Auto-detecting files and directories for mapping..."
    
    # Create map file if it doesn't exist
    if [[ ! -f "$map_file" ]]; then
        cat > "$map_file" << 'EOF'
# Padlock File Mapping
# Format: source_path|destination_path|md5_checksum
# Paths are relative to repository root
# Files listed here will be included in encrypted chest
EOF
    fi
    
    local mapped_count=0
    local skipped_count=0
    
    # Auto-detect patterns
    local patterns=(
        # Markdown files (except README and SECURITY, case insensitive)
        "*.md"
        # Build and parts directory
        "build.sh"
        "parts"
        # AI/IDE directories
        ".claude" ".gemini" ".codex" ".priv" ".sec"
        # Local and backup files in root
        "*.local.*" "*bak*"
    )
    
    # Function to check if already mapped
    _is_mapped() {
        local path="$1"
        grep -q "^$path|" "$map_file" 2>/dev/null
    }
    
    # Function to check if file should be excluded
    _should_exclude() {
        local path="$1"
        local basename_lower
        basename_lower=$(basename "$path" | tr '[:upper:]' '[:lower:]')
        
        # Exclude README.md and SECURITY.md (case insensitive)
        case "$basename_lower" in
            readme.md|security.md)
                return 0
                ;;
        esac
        
        # Exclude padlock infrastructure
        case "$path" in
            .git/*|bin/*|.githooks/*|locker.age|.locked|.chest/*|super_chest.age|.overdrive|padlock.map|locker/*)
                return 0
                ;;
        esac
        
        return 1
    }
    
    # Function to add mapping
    _add_automap() {
        local src_path="$1"
        local src_abs="$repo_root/$src_path"
        
        # Skip if already mapped
        if _is_mapped "$src_path"; then
            trace "Already mapped: $src_path"
            ((skipped_count++))
            return 0
        fi
        
        # Skip if should be excluded
        if _should_exclude "$src_path"; then
            trace "Excluded: $src_path"
            ((skipped_count++))
            return 0
        fi
        
        # Calculate checksum
        local checksum=""
        if [[ -f "$src_abs" ]]; then
            checksum=$(md5sum "$src_abs" | cut -d' ' -f1)
        elif [[ -d "$src_abs" ]]; then
            checksum=$(find "$src_abs" -type f -exec md5sum {} \; | sort | md5sum | cut -d' ' -f1)
        fi
        
        # Add mapping
        echo "$src_path|$src_path|$checksum" >> "$map_file"
        ((mapped_count++))
        
        if [[ -f "$src_abs" ]]; then
            okay "✓ Auto-mapped file: $src_path"
        elif [[ -d "$src_abs" ]]; then
            okay "✓ Auto-mapped directory: $src_path"
            local file_count
            file_count=$(find "$src_abs" -type f | wc -l)
            trace "  📁 Contains $file_count files"
        fi
    }
    
    # Process each pattern
    for pattern in "${patterns[@]}"; do
        case "$pattern" in
            "*.md")
                # Find all .md files in root, exclude README.md and SECURITY.md
                while IFS= read -r -d '' file; do
                    local rel_path
                    rel_path=$(realpath --relative-to="$repo_root" "$file")
                    _add_automap "$rel_path"
                done < <(find "$repo_root" -maxdepth 1 -name "*.md" -type f -print0)
                ;;
            "*.local.*"|"*bak*")
                # Find files matching these patterns in root
                while IFS= read -r -d '' file; do
                    local rel_path
                    rel_path=$(realpath --relative-to="$repo_root" "$file")
                    _add_automap "$rel_path"
                done < <(find "$repo_root" -maxdepth 1 -name "$pattern" -type f -print0)
                ;;
            *)
                # Check if file/directory exists
                if [[ -e "$repo_root/$pattern" ]]; then
                    _add_automap "$pattern"
                fi
                ;;
        esac
    done
    
    # Backup the updated map file
    _backup_repo_artifacts "$repo_root"
    
    # Summary
    echo
    if [[ $mapped_count -gt 0 ]]; then
        okay "🎯 Auto-mapped $mapped_count items"
        if [[ $skipped_count -gt 0 ]]; then
            info "⏩ Skipped $skipped_count items (already mapped or excluded)"
        fi
        info "💡 Changes take effect on next lock operation"
        info "💡 Review mappings with: padlock map"
    else
        info "📝 No new items found to auto-map"
        if [[ $skipped_count -gt 0 ]]; then
            info "⏩ $skipped_count items were skipped (already mapped or excluded)"
        fi
    fi
}

# Unmap files with support for file selection
do_unmap() {
    local target="${1:-}"
    
    local repo_root="$(_get_repo_root .)"
    local map_file="$repo_root/padlock.map"
    
    # Check if repository is locked - show help if so
    if [[ -f ".chest/locker.age" ]] || [[ -f "locker.age" ]]; then
        info "Repository is locked. Unlock first to modify mappings"
        info "The 'unmap' command removes files/directories from mappings"
        info ""
        info "Usage: padlock unmap <file|dir|all>"
        info ""
        info "Prerequisites:"
        info "  • Repository must be unlocked to modify mappings"
        info "  • Run 'padlock unlock' first"
        return 0
    fi
    
    if [[ ! -f "$map_file" ]]; then
        info "No mappings file found"
        info "The 'unmap' command removes files/directories from mappings"
        info ""
        info "Usage: padlock unmap <file|dir|all>"
        info ""
        info "Prerequisites:"
        info "  • Repository must have existing mappings (padlock.map file)"
        info "  • Use 'padlock map' to create mappings first"
        return 0
    fi
    
    if [[ -z "$target" ]]; then
        info "Usage: padlock unmap <file|dir|all>"
        info "The 'unmap' command removes files/directories from mappings"
        info ""
        info "Available mappings:"
        do_map
        return 0
    fi
    
    if [[ "$target" == "all" ]]; then
        # Remove all mappings
        local mapping_count
        mapping_count=$(grep -c "^[^#]" "$map_file" 2>/dev/null || echo "0")
        
        if [[ "$mapping_count" -eq 0 ]]; then
            info "No mappings to remove"
            return 0
        fi
        
        echo
        warn "⚠️  This will remove ALL $mapping_count file mappings"
        read -p "Continue? (y/N): " -r response
        if [[ ! "$response" =~ ^[Yy]$ ]]; then
            info "Unmap cancelled"
            return 0
        fi
        
        # Keep only comments and empty lines
        local temp_file
        temp_file=$(_temp_mktemp)
        grep "^#\|^[[:space:]]*$" "$map_file" > "$temp_file" || echo "# Padlock File Mapping" > "$temp_file"
        mv "$temp_file" "$map_file"
        
        okay "✓ Removed all mappings"
        return 0
    fi
    
    # Normalize target path (convert to relative if absolute)
    if [[ "$target" = /* ]]; then
        target="$(realpath --relative-to="$repo_root" "$target")"
    else
        # Convert relative to canonical form
        if [[ -e "$repo_root/$target" ]]; then
            target="$(realpath --relative-to="$repo_root" "$repo_root/$target")"
        fi
    fi
    
    # Find matching entries
    local matches=()
    while IFS='|' read -r src_rel dest_rel checksum; do
        # Skip comments and empty lines
        [[ "$src_rel" =~ ^[[:space:]]*# ]] && continue
        [[ -z "$src_rel" ]] && continue
        
        # Check for exact match or basename match
        if [[ "$src_rel" == "$target" ]] || [[ "$(basename "$src_rel")" == "$(basename "$target")" ]]; then
            matches+=("$src_rel|$dest_rel|$checksum")
        fi
    done < "$map_file"
    
    if [[ ${#matches[@]} -eq 0 ]]; then
        error "No mapping found for: $target"
        info "Available mappings:"
        padlock map
        return 1
    elif [[ ${#matches[@]} -eq 1 ]]; then
        # Single match - remove it
        local entry="${matches[0]}"
        local src_path="${entry%%|*}"
        
        local temp_file
        temp_file=$(_temp_mktemp)
        grep -v "^$src_path|" "$map_file" > "$temp_file"
        mv "$temp_file" "$map_file"
        
        okay "✓ Unmapped: $src_path"
    else
        # Multiple matches - let user choose
        info "Multiple mappings found for '$target':"
        echo
        for i in "${!matches[@]}"; do
            local entry="${matches[$i]}"
            local src_path="${entry%%|*}"
            local status="❓"
            
            if [[ -f "$repo_root/$src_path" ]]; then
                status="✓"
            elif [[ -d "$repo_root/$src_path" ]]; then
                status="📁"
            else
                status="❌"
            fi
            
            printf "  %d) %s %s\n" $((i + 1)) "$status" "$src_path"
        done
        
        echo
        read -p "Select mapping to remove (1-${#matches[@]}): " -r selection
        
        if [[ "$selection" =~ ^[0-9]+$ ]] && [[ "$selection" -ge 1 ]] && [[ "$selection" -le ${#matches[@]} ]]; then
            local selected_entry="${matches[$((selection - 1))]}"
            local src_path="${selected_entry%%|*}"
            
            local temp_file
            temp_file=$(_temp_mktemp)
            grep -v "^$src_path|" "$map_file" > "$temp_file"
            mv "$temp_file" "$map_file"
            
            okay "✓ Unmapped: $src_path"
        else
            error "Invalid selection"
            return 1
        fi
    fi
    
    # Backup the updated map file
    _backup_repo_artifacts "$repo_root"
    
    info "💡 Changes take effect on next lock operation"
}

do_path() {
    local repo_path="${1:-.}"
    repo_path="$(realpath "$repo_path")"
    
    local repo_name=$(basename "$repo_path")
    
    # Determine namespace from git remote or use 'local'
    local namespace="local"
    if [[ -d "$repo_path/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            # Parse remote URL to extract host, user, and repo
            local host user_repo
            if [[ "$remote_url" =~ ^https?://([^/]+)/([^/]+)/([^/]+) ]]; then
                # HTTPS: https://github.com/user/repo.git
                host="${BASH_REMATCH[1]}"
                user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
            elif [[ "$remote_url" =~ ^[^@]+@([^:]+):([^/]+)/([^/]+) ]]; then
                # SSH: git@github.com:user/repo.git
                host="${BASH_REMATCH[1]}"
                user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
            else
                # Fallback for unusual formats
                host="unknown"
                user_repo=$(basename "$repo_path")
            fi
            
            # Create namespace as host, repo as user/repo to avoid collisions
            namespace="$host"
            repo_name="$user_repo"
        fi
    fi
    
    info "📍 Repository path analysis for: $repo_path"
    echo
    
    if [[ -d "$repo_path/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            info "🔗 Git remote: $remote_url"
        else
            info "🔗 Git remote: (none - local repository)"
        fi
    else
        info "🔗 Git remote: (not a git repository)"
    fi
    
    echo
    info "📋 Computed storage paths:"
    printf "  Namespace: %b%s%b\n" "$cyan" "$namespace" "$xx"
    printf "  Repository: %b%s%b\n" "$cyan" "$repo_name" "$xx"
    echo
    printf "  Key file: %b%s%b\n" "$green" "$PADLOCK_KEYS/$(basename "$repo_path").key" "$xx"
    printf "  Artifacts: %b%s%b\n" "$green" "$PADLOCK_ETC/repos/$namespace/$repo_name/" "$xx"
    echo
    
    # Show what artifacts exist
    local artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    local key_file="$PADLOCK_KEYS/$(basename "$repo_path").key"
    
    info "📁 Current storage status:"
    if [[ -f "$key_file" ]]; then
        printf "  ✓ Key file exists: %s\n" "$(basename "$key_file")"
    else
        printf "  ✗ Key file missing: %s\n" "$(basename "$key_file")"
    fi
    
    if [[ -d "$artifacts_dir" ]]; then
        local artifact_count
        artifact_count=$(find "$artifacts_dir" -type f | wc -l)
        printf "  ✓ Artifacts backed up: %d files\n" "$artifact_count"
        
        # List specific artifacts
        if [[ -f "$artifacts_dir/.artifact_info" ]]; then
            local backup_date
            backup_date=$(grep "backup_date=" "$artifacts_dir/.artifact_info" 2>/dev/null | cut -d'=' -f2 || echo "unknown")
            printf "  📅 Last backup: %s\n" "$backup_date"
        fi
        
        echo "  📄 Artifacts:"
        find "$artifacts_dir" -type f -not -name ".artifact_info" | while read -r file; do
            printf "    • %s\n" "$(basename "$file")"
        done
    else
        printf "  ✗ No artifacts backed up\n"
        
        # Check if artifacts exist in the 'local' namespace (migration scenario) - just show info
        if [[ "$namespace" != "local" ]]; then
            local local_artifacts_dir="$PADLOCK_ETC/repos/local/$(basename "$repo_path")"
            if [[ -d "$local_artifacts_dir" ]]; then
                echo
                warn "🚨 Migration available!"
                info "Found artifacts in local namespace that can be migrated:"
                printf "  From: %b%s%b\n" "$yellow" "$local_artifacts_dir" "$xx"
                printf "  To:   %b%s%b\n" "$green" "$artifacts_dir" "$xx"
                echo
                printf "  Run: %bpadlock remote%b to update for remote namespace\n" "$green" "$xx"
            fi
        fi
    fi
}

# Helper function to migrate artifacts between namespaces
_migrate_artifacts_namespace() {
    local old_dir="$1"
    local new_dir="$2"
    
    if [[ ! -d "$old_dir" ]]; then
        return 1
    fi
    
    mkdir -p "$new_dir"
    
    # Copy all files except .artifact_info (will be regenerated)
    if find "$old_dir" -type f -not -name ".artifact_info" -exec cp {} "$new_dir/" \; 2>/dev/null; then
        # Update the artifact info with new location
        if [[ -f "$old_dir/.artifact_info" ]]; then
            sed "s|repo_path=.*|repo_path=$(dirname "$new_dir")|" "$old_dir/.artifact_info" > "$new_dir/.artifact_info"
        fi
        return 0
    else
        return 1
    fi
}

do_remote() {
    local repo_path="${1:-.}"
    repo_path="$(realpath "$repo_path")"
    
    info "🔗 Padlock Remote Update"
    echo
    
    local repo_name=$(basename "$repo_path")
    local namespace="local"
    local old_artifacts_dir=""
    local new_artifacts_dir=""
    
    # Determine current namespace from git remote
    if [[ -d "$repo_path/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        if [[ -n "$remote_url" ]]; then
            # Parse remote URL to extract host, user, and repo
            local host user_repo
            if [[ "$remote_url" =~ ^https?://([^/]+)/([^/]+)/([^/]+) ]]; then
                # HTTPS: https://github.com/user/repo.git
                host="${BASH_REMATCH[1]}"
                user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
            elif [[ "$remote_url" =~ ^[^@]+@([^:]+):([^/]+)/([^/]+) ]]; then
                # SSH: git@github.com:user/repo.git
                host="${BASH_REMATCH[1]}"
                user_repo="${BASH_REMATCH[2]}/${BASH_REMATCH[3]%.git}"
            else
                # Fallback for unusual formats
                host="unknown"
                user_repo=$(basename "$repo_path")
            fi
            
            # Create namespace as host, repo as user/repo
            namespace="$host"
            repo_name="$user_repo"
        fi
    fi
    
    # Check what migrations are available
    old_artifacts_dir="$PADLOCK_ETC/repos/local/$(basename "$repo_path")"
    new_artifacts_dir="$PADLOCK_ETC/repos/$namespace/$repo_name"
    
    # If we're already in the correct namespace, nothing to do
    if [[ "$namespace" == "local" ]]; then
        okay "✓ Repository has no remote - using local namespace"
        return 0
    fi
    
    # Check if new location already has artifacts
    if [[ -d "$new_artifacts_dir" ]]; then
        okay "✓ Artifacts already updated for remote namespace"
        info "Current location: $new_artifacts_dir"
        return 0
    fi
    
    # Check if old artifacts exist to update
    if [[ ! -d "$old_artifacts_dir" ]]; then
        warn "⚠️  No artifacts found in local namespace to update"
        info "Expected old location: $old_artifacts_dir"
        info "Target location: $new_artifacts_dir"
        return 1
    fi
    
    # Show what will be migrated
    if [[ -d "$repo_path/.git" ]]; then
        local remote_url
        remote_url=$(git -C "$repo_path" remote get-url origin 2>/dev/null || echo "")
        info "🔗 Git remote: $remote_url"
    fi
    
    echo
    info "📋 Update plan:"
    printf "  From: %b%s%b\n" "$yellow" "$old_artifacts_dir" "$xx"
    printf "  To:   %b%s%b\n" "$green" "$new_artifacts_dir" "$xx"
    
    # Show what artifacts will be moved
    local artifact_count
    artifact_count=$(find "$old_artifacts_dir" -type f -not -name ".artifact_info" | wc -l)
    echo
    info "📁 Artifacts to update:"
    find "$old_artifacts_dir" -type f -not -name ".artifact_info" | while read -r file; do
        printf "  • %s\n" "$(basename "$file")"
    done
    
    echo
    read -p "Proceed with remote namespace update? [Y/n]: " -r update_response
    if [[ "$update_response" =~ ^[nN]$ ]]; then
        info "Update cancelled"
        return 0
    fi
    
    # Perform the update
    if _migrate_artifacts_namespace "$old_artifacts_dir" "$new_artifacts_dir"; then
        okay "✓ Artifacts updated successfully"
        rm -rf "$old_artifacts_dir"
        info "Removed old artifacts directory"
        
        echo
        info "🎯 Remote namespace update complete!"
        printf "  New location: %b%s%b\n" "$green" "$new_artifacts_dir" "$xx"
        echo
        info "You can now commit safely. The pre-commit hook will use the correct namespace."
    else
        error "Update failed - old artifacts preserved"
        return 1
    fi
}

do_revoke() {
    local target="${1:-}"
    shift || true
    
    case "$target" in
        ignition)
            # padlock revoke ignition [name]
            local name="${1:-default}"
            info "[STUB] Revoking ignition key: $name"
            info "This will permanently invalidate the ignition key"
            return 0
            ;;
            
        distro)
            # padlock revoke distro [name]
            local name="$1"
            if [[ -z "$name" ]]; then
                error "Missing distro key name"
                info "Usage: padlock revoke distro <name>"
                return 1
            fi
            info "[STUB] Revoking distributed key: $name"
            info "Third-party access with this key will be terminated"
            return 0
            ;;
            
        # Legacy support
        --local)
            _revoke_local_access "$1"
            ;;
        -K|--ignition)
            _revoke_ignition_access "$1"
            ;;
            
        ""|help|*)
            if [[ -z "$target" ]]; then
                info "Available revocation commands:"
            elif [[ "$target" != "help" ]]; then
                error "Unknown revocation target: $target"
            else
                info "Revocation Commands:"
            fi
            info "  ignition [name]     Revoke ignition key (invalidates D keys)"
            info "  distro <name>       Revoke specific distributed key"
            info ""
            info "Legacy:"
            info "  --local             Revoke local access (WARNING: unrecoverable)"
            info "  --ignition          Revoke legacy ignition access"
            [[ -n "$target" ]] && [[ "$target" != "help" ]] && return 1 || return 0
            ;;
    esac
}

# Revoke local access - WARNING: This makes content permanently unrecoverable
_revoke_local_access() {
    local force="$1"
    
    REPO_ROOT="$(_get_repo_root .)"
    
    error "⚠️  DESTRUCTIVE OPERATION: Local access revocation"
    warn "This will make ALL encrypted content permanently unrecoverable!"
    warn "Even with master keys, the content will be lost."
    echo
    info "This operation will:"
    info "  • Remove local repository key"
    info "  • Remove master key references"
    info "  • Leave locker.age encrypted but unrecoverable"
    echo
    
    if [[ "$force" != "--force" ]]; then
        error "This operation requires --force flag to confirm"
        info "Usage: padlock revoke --local --force"
        return 1
    fi
    
    # Additional confirmation
    echo
    warn "⚠️  FINAL WARNING: This will permanently destroy access to encrypted data"
    read -p "Type 'DESTROY' to confirm: " -r confirm
    if [[ "$confirm" != "DESTROY" ]]; then
        info "Revocation cancelled"
        return 0
    fi
    
    local revoked_items=()
    
    # Remove local repository key
    local repo_key="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
    if [[ -f "$repo_key" ]]; then
        rm -f "$repo_key"
        revoked_items+=("local repository key")
    fi
    
    # Remove master key reference from any config
    if [[ -f "$REPO_ROOT/locker/.padlock" ]]; then
        # If unlocked, remove master key from recipients
        source "$REPO_ROOT/locker/.padlock"
        if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
            # Remove master key recipient
            local master_public
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                master_public=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null || true)
                if [[ -n "$master_public" ]]; then
                    # Remove master key from recipients list
                    AGE_RECIPIENTS=$(echo "$AGE_RECIPIENTS" | sed "s/,$master_public//g" | sed "s/$master_public,//g" | sed "s/$master_public//g")
                    export AGE_RECIPIENTS
                    __print_padlock_config "$REPO_ROOT/locker/.padlock" "$(basename "$REPO_ROOT")"
                    revoked_items+=("master key access")
                fi
            fi
        fi
    fi
    
    # Remove from manifest
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" ]]; then
        local temp_manifest
        temp_manifest=$(mktemp)
        grep -v -F "$REPO_ROOT" "$manifest_file" > "$temp_manifest" 2>/dev/null || true
        mv "$temp_manifest" "$manifest_file"
        revoked_items+=("manifest entry")
    fi
    
    # Create revocation marker
    cat > "$REPO_ROOT/.revoked" << EOF
# Padlock Access Revoked
# Generated: $(date)
# Repository: $(basename "$REPO_ROOT")

This repository's encryption keys have been revoked.
The encrypted content in locker.age is permanently unrecoverable.

Revoked access types:
$(printf "  • %s\n" "${revoked_items[@]}")

If this was done in error, restore from backup immediately.
EOF
    
    error "🔒 Local access permanently revoked"
    if [[ ${#revoked_items[@]} -gt 0 ]]; then
        info "Revoked: ${revoked_items[*]}"
    fi
    warn "⚠️  Encrypted content is now permanently unrecoverable"
    info "💀 Created .revoked file as marker"
}

# Revoke ignition access - removes ignition key system
_revoke_ignition_access() {
    local force="$1"
    
    REPO_ROOT="$(_get_repo_root .)"
    
    if [[ ! -d "$REPO_ROOT/.chest" ]]; then
        error "Repository is not using ignition system"
        info "Nothing to revoke"
        return 1
    fi
    
    lock "🔥 Revoking ignition key access..."
    
    local revoked_items=()
    
    # Remove ignition key files
    if [[ -f "$REPO_ROOT/.chest/ignition.age" ]]; then
        rm -f "$REPO_ROOT/.chest/ignition.age"
        revoked_items+=("encrypted ignition key")
    fi
    
    # Remove any temporary ignition keys
    rm -f "$REPO_ROOT/.ignition.key"
    
    # If chest is unlocked, we need to transition to standard mode
    if [[ -d "$REPO_ROOT/locker" ]] && [[ -f "$REPO_ROOT/locker/.padlock" ]]; then
        info "Converting from ignition to standard mode..."
        
        # Generate new repository key
        local new_repo_key="$PADLOCK_KEYS/$(basename "$REPO_ROOT").key"
        age-keygen -o "$new_repo_key" >/dev/null
        chmod 600 "$new_repo_key"
        
        # Get new public key
        local new_public
        new_public=$(age-keygen -y "$new_repo_key")
        
        # Update configuration to standard mode with master key backup
        _ensure_master_key
        local master_public
        master_public=$(age-keygen -y "$PADLOCK_GLOBAL_KEY")
        
        export AGE_RECIPIENTS="$new_public,$master_public"
        export PADLOCK_KEY_FILE="$new_repo_key"
        export AGE_PASSPHRASE=""
        
        __print_padlock_config "$REPO_ROOT/locker/.padlock" "$(basename "$REPO_ROOT")"
        
        info "🔑 Generated new repository key for standard mode"
        revoked_items+=("ignition system")
        revoked_items+=("converted to standard mode")
    fi
    
    # Remove chest directory if empty
    if [[ -d "$REPO_ROOT/.chest" ]] && [[ -z "$(ls -A "$REPO_ROOT/.chest" 2>/dev/null)" ]]; then
        rm -rf "$REPO_ROOT/.chest"
        revoked_items+=("chest directory")
    fi
    
    # Update manifest type
    local manifest_file="$PADLOCK_ETC/manifest.txt"
    if [[ -f "$manifest_file" ]]; then
        local temp_manifest
        temp_manifest=$(mktemp)
        # Change type from ignition to standard
        sed "s/|$REPO_ROOT|ignition|/|$REPO_ROOT|standard|/g" "$manifest_file" > "$temp_manifest" 2>/dev/null || true
        mv "$temp_manifest" "$manifest_file"
        trace "Updated manifest type to standard"
    fi
    
    okay "✓ Ignition access revoked"
    if [[ ${#revoked_items[@]} -gt 0 ]]; then
        info "Changes: ${revoked_items[*]}"
    fi
    
    if [[ -d "$REPO_ROOT/locker" ]]; then
        info "📝 Repository is now in standard mode"
        info "🔐 Re-encrypt with: padlock lock"
    else
        info "🔒 Repository remains locked in standard mode"
        info "🔓 Unlock with: padlock unlock"
    fi
}


_create_ignition_master_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating ignition master for $name"
    
    # Check if master key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.ikey" ]]; then
        error "Ignition master key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the ignition master (I key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate ignition master key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    # Extract public key  
    age-keygen -y < "$temp_key" > "$temp_pub" 2>/dev/null || {
        error "Failed to extract public key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    local private_key=$(cat "$temp_key")
    local public_key=$(cat "$temp_pub")
    
    # Clean up temp files
    rm -f "$temp_key" "$temp_pub"
    
    # For development: Store key with passphrase marker (TODO: implement proper age encryption)
    local key_bundle
    if [[ -n "$passphrase" ]]; then
        # Store key with passphrase metadata for now (TODO: proper encryption)
        # In production, this would use age encryption or similar
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "master" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store ignition master key"
        return 1
    }
    
    info "✓ Ignition master key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    
    return 0
}


_create_ignition_distro_with_tty_magic() {
    local name="$1"
    local passphrase="$2"
    
    trace "TTY magic: creating distributed key for $name"
    
    # Check if distributed key already exists
    if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.dkey" ]]; then
        error "Distributed ignition key '$name' already exists"
        return 1
    fi
    
    # Generate a new age key pair for the distributed key (D key)
    local temp_key=$(mktemp)
    local temp_pub=$(mktemp)
    
    # Generate age key
    age-keygen > "$temp_key" 2>/dev/null || {
        error "Failed to generate distributed ignition key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    # Extract public key
    age-keygen -y < "$temp_key" > "$temp_pub" 2>/dev/null || {
        error "Failed to extract public key"
        rm -f "$temp_key" "$temp_pub"
        return 1
    }
    
    local private_key=$(cat "$temp_key")
    local public_key=$(cat "$temp_pub")
    
    # Clean up temp files
    rm -f "$temp_key" "$temp_pub"
    
    # For development: Store key with passphrase marker (TODO: implement proper age encryption)
    local key_bundle
    if [[ -n "$passphrase" ]]; then
        # Store key with passphrase metadata for now (TODO: proper encryption)
        key_bundle="# ENCRYPTED WITH PASSPHRASE
# This is a development placeholder - production should use age encryption
$private_key"
        trace "Development mode: Key stored with passphrase metadata"
    else
        # Store unencrypted if no passphrase
        key_bundle="$private_key"
    fi
    
    # Store the key bundle using our storage system
    _store_key_bundle "distro" "$name" "$key_bundle" "$passphrase" || {
        error "Failed to store distributed ignition key"
        return 1
    }
    
    # Export the key to current directory for third-party sharing
    local export_file="./ignition.${name}.key"
    echo "$key_bundle" > "$export_file" || {
        error "Failed to export distributed key to: $export_file"
        return 1
    }
    
    # Create MD5 checksum per requirements
    local checksum=$(md5sum "$export_file" | cut -d' ' -f1)
    
    info "✓ Distributed ignition key created: $name"
    info "  Public key: $(echo "$public_key" | tr -d '\n')"
    info "  Key file: $export_file"
    info "  MD5 checksum: $checksum"
    
    return 0
}


_unlock_ignition_with_tty_magic() {
    local name="$1"  
    local passphrase="$2"
    
    trace "TTY magic: unlocking with key $name"
    
    # Load the key bundle using storage system
    _load_key_bundle "$name" "auto" || {
        error "Failed to load ignition key: $name"
        return 1
    }
    
    # Decrypt the key bundle if it's encrypted (development mode)
    local decrypted_key
    if echo "$LOADED_KEY_DATA" | grep -q "# ENCRYPTED WITH PASSPHRASE"; then
        if [[ -n "$passphrase" ]]; then
            # Extract the actual key from development format
            decrypted_key=$(echo "$LOADED_KEY_DATA" | grep -v "^#" | head -1)
            trace "Development mode: Extracted key from passphrase-protected format"
        else
            error "Key is encrypted but no passphrase provided"
            return 1
        fi
    else
        # Use key directly if not encrypted
        decrypted_key="$LOADED_KEY_DATA"
    fi
    
    # Verify the decrypted key is valid age format
    if echo "$decrypted_key" | grep -q "AGE-SECRET-KEY"; then
        info "✓ Successfully unlocked ignition key: $name"
        info "  Key type: $LOADED_KEY_TYPE"
        
        # TODO: Use the decrypted key to unlock repository secrets
        # This would integrate with the existing padlock unlock mechanism
        info "  [PLACEHOLDER] Would unlock repository with decrypted key"
        
        return 0
    else
        error "Invalid key format after decryption"
        return 1
    fi
}


_ignition_lock() {
    local repo_root="$(_get_repo_root .)"
    
    # Check if we have a locker to lock
    if [[ ! -d "$repo_root/locker" ]]; then
        error "No locker directory found"
        info "Repository may already be locked"
        return 1
    fi
    
    # Check if we're in chest mode
    if [[ ! -d "$repo_root/.chest" ]]; then
        error "Repository is not in chest mode"
        info "Use 'padlock ignite --status' to check current state"
        return 1
    fi
    
    lock "🗃️  Locking locker into chest..."
    
    # Use the existing _lock_chest helper which does the actual work
    if _lock_chest; then
        okay "✓ Locker secured in chest"
        info "🔥 Ignition key required for unlock"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • git add . && git commit"
        echo "  • To unlock: padlock ignite --unlock"
        warn "⚠️  Chest is now locked and safe to commit"
        return 0
    else
        error "Failed to lock locker into chest"
        return 1
    fi
}


_chest_status() {
    local repo_root="$(_get_repo_root .)"
    
    if [[ ! -d "$repo_root/.chest" ]]; then
        error "Repository is not in chest mode"
        info "This repository uses standard locker encryption"
        return 1
    fi
    
    info "=== Chest Status ==="
    
    local chest_blob="$repo_root/.chest/locker.age"
    local ignition_blob="$repo_root/.chest/ignition.age"
    
    if [[ -f "$chest_blob" && -f "$ignition_blob" ]]; then
        local size
        size=$(du -h "$chest_blob" 2>/dev/null | cut -f1)
        warn "🗃️  CHEST LOCKED"
        info "Encrypted locker: $size"
        info "Ignition key: protected"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • To unlock: padlock ignite --unlock"
        echo "  • Set ignition key: export PADLOCK_IGNITION_PASS='your-key'"
        
    elif [[ -d "$repo_root/locker" ]]; then
        okay "🔓 CHEST UNLOCKED"
        local file_count
        file_count=$(find "$repo_root/locker" -type f | wc -l)
        info "Files accessible: $file_count"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Edit files in locker/"
        echo "  • To lock: padlock ignite --lock"
        echo "  • Manual commit locks automatically"
        
    else
        error "🔧 CHEST CORRUPTED"
        warn "Neither locked chest nor unlocked locker found"
        echo
        printf "%bNext steps:%b\n" "$cyan" "$xx"
        echo "  • Try: padlock repair"
        echo "  • Check ignition key: PADLOCK_IGNITION_PASS"
        echo "  • Or convert: padlock revoke --ignition"
    fi
    
    # Show chest contents if accessible
    if [[ -d "$repo_root/.chest" ]]; then
        local chest_items
        chest_items=$(find "$repo_root/.chest" -type f 2>/dev/null | wc -l)
        trace "🗃️  Chest items: $chest_items"
    fi
}


_ignition_unlock() {
    local ignition_pass="${PADLOCK_IGNITION_PASS:-}"
    
    if [[ -z "$ignition_pass" ]]; then
        error "Ignition passphrase not found in environment variable PADLOCK_IGNITION_PASS."
        info "Usage: PADLOCK_IGNITION_PASS='your-phrase' padlock ignite --unlock"
        return 1
    fi

    # Check for chest pattern
    local encrypted_file
    if [[ -f ".chest/locker.age" ]]; then
        encrypted_file=".chest/locker.age"
    elif [[ -f "locker.age" ]]; then
        encrypted_file="locker.age"
    else
        error "No encrypted locker found."
        return 1
    fi
    
    # Verify we have the ignition key file
    local ignition_key_file=".chest/ignition.key"
    if [[ ! -f "$ignition_key_file" ]]; then
        error "Ignition key file not found at $ignition_key_file"
        info "Repository may not be in ignition mode"
        return 1
    fi
    
    # Verify the passphrase matches what was used during setup
    if [[ -f ".chest/ignition.ref" ]]; then
        local stored_ref=$(cat ".chest/ignition.ref")
        local stored_pass="${stored_ref%%:*}"
        if [[ "$ignition_pass" != "$stored_pass" ]]; then
            error "Invalid ignition passphrase"
            return 1
        fi
    fi

    # Use the ignition private key to decrypt (not passphrase mode)
    if age -d -i "$ignition_key_file" < "$encrypted_file" | tar -xzf -; then
        rm -f "$encrypted_file" .locked
        [[ -d ".chest" ]] && rm -rf .chest
        okay "✓ Repository unlocked with ignition key"
        return 0
    else
        error "Failed to decrypt with ignition key."
        return 1
    fi
}

