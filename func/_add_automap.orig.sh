# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_add_automap | edit:test_extract | orig_sum:b35449b82089a7da05bbf3d49a0d54d166a229a56a813f7944c3e63c21db2bd4
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
