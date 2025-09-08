# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_automap | edit:repo_do_automap | orig_sum:e6ccb40cbd4af82e80a30d669111c05e4d0cc8eefe418bf77b1bedbabe5f9657
repo_do_automap() {
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
