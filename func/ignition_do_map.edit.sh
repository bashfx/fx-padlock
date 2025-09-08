# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:do_map | edit:ignition_do_map | orig_sum:b005628bc38a32b896d423f27414f7127b8f21150fa98aa43a1470c5dafec4e8
ignition_do_map() {
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
