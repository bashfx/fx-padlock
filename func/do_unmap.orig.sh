# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_unmap | edit:repo_do_unmap | orig_sum:16d35e8812778346bcd3d6eb496af16c85c2486f528986942c7880a84bd53c32
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
