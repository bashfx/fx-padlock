#!/usr/bin/env bash
# build.sh - Assemble script from numbered modular parts (enhanced with build.map)

set -euo pipefail

# Colors for output
readonly green=$'\033[32m';
readonly blue=$'\033[34m';
readonly yellow=$'\033[33m';
readonly red=$'\033[31m';
readonly x=$'\033[38;5;244m';

# Configuration
PARTS_DIR="parts";
OUTPUT_FILE="padlock.sh";
BUILD_MAP="parts/build.map";
USE_BUILD_MAP=false;

# Read build map if it exists
declare -A build_map_targets=()
read_build_map() {
    if [[ ! -f "$BUILD_MAP" ]]; then
        return 1
    fi
    
    printf "%sReading build map: %s%s\n" "$blue" "$BUILD_MAP" "$x"
    
    while IFS= read -r line; do
        # Skip comments and empty lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ -z "${line// }" ]] && continue
        
        # Parse: NN : target_filename.sh
        if [[ "$line" =~ ^([0-9]+)[[:space:]]*:[[:space:]]*(.+)$ ]]; then
            local num="${BASH_REMATCH[1]}"
            local target="${BASH_REMATCH[2]// /}"  # Remove spaces
            build_map_targets["$num"]="$target"
            printf "  %s%s%s → %s\n" "$green" "$num" "$x" "$target"
        fi
    done < "$BUILD_MAP"
    
    if [[ ${#build_map_targets[@]} -gt 0 ]]; then
        USE_BUILD_MAP=true
        return 0
    else
        printf "%sWARN:%s No valid mappings found in %s\n" "$yellow" "$x" "$BUILD_MAP"
        return 1
    fi
}

# Rename files according to build map
rename_from_build_map() {
    if [[ "$USE_BUILD_MAP" != true ]]; then
        return 0
    fi
    
    printf "\n%sRenaming files according to build map...%s\n" "$yellow" "$x"
    
    # Get all .sh files in parts directory
    local all_files=()
    while IFS= read -r -d '' file; do
        all_files+=("$(basename "$file")")
    done < <(find "$PARTS_DIR" -name "*.sh" -print0)
    
    printf "%sDEBUG:%s Found %d files: %s\n" "$blue" "$x" "${#all_files[@]}" "${all_files[*]}"
    
    # Process each build map target
    for num in $(printf '%s\n' "${!build_map_targets[@]}" | sort -n); do
        local target="${build_map_targets[$num]}"
        local found_source=""
        local source_idx=-1

        # Prioritize finding a "raw" part file (e.g., padlock_part_NN.sh)
        for i in "${!all_files[@]}"; do
            local file="${all_files[$i]}"
            if [[ -n "$file" && "$file" != "$target" ]] && ([[ "$file" =~ [^0-9]${num}[^0-9] ]] || [[ "$file" =~ ^${num}[^0-9] ]] || [[ "$file" =~ [^0-9]${num}$ ]]); then
                found_source="$file"
                source_idx=$i
                break
            fi
        done

        # If no raw part found, look for the correctly named target file
        if [[ -z "$found_source" ]]; then
            for i in "${!all_files[@]}"; do
                local file="${all_files[$i]}"
                if [[ -n "$file" && "$file" == "$target" ]]; then
                    found_source="$file"
                    source_idx=$i
                    break
                fi
            done
        fi
        
        if [[ -n "$found_source" ]]; then
            # We found our source file. Remove it from the processing list.
            unset 'all_files[$source_idx]'

            local source_path="$PARTS_DIR/$found_source"
            local target_path="$PARTS_DIR/$target"
            
            if [[ "$source_path" != "$target_path" ]]; then
                # This is a raw part that needs to be renamed.
                # If the target file also exists in the list of all_files, it's an artifact that needs to be ignored in the cleanup.
                for i in "${!all_files[@]}"; do
                    if [[ -n "${all_files[$i]}" && "${all_files[$i]}" == "$target" ]]; then
                        unset 'all_files[$i]'
                        break
                    fi
                done
                mv "$source_path" "$target_path"
                printf "  %s✓%s %s → %s\n" "$green" "$x" "$found_source" "$target"
            else
                # File is already correctly named.
                printf "  %s=%s %s (correct)\n" "$blue" "$x" "$target"
            fi
        else
            printf "  %s✗%s No source for %s (%s)\n" "$red" "$x" "$num" "$target"
        fi
    done
    
    # Clean up unprocessed files with numbers (anything left in all_files is an artifact)
    for file in "${all_files[@]}"; do
        if [[ -n "$file" && "$file" =~ [0-9] ]]; then
            printf "  %s🗑%s  Removing artifact: %s\n" "$red" "$x" "$file"
            rm -f "$PARTS_DIR/$file"
        fi
    done
    
    printf "\n%s✓ Rename complete!%s\n" "$green" "$x"
}

main() {
    printf "%sBuilding script from numbered modular parts%s\n" "$blue" "$x";
    printf "Parts directory: %s\n" "$PARTS_DIR";
    printf "Output file: %s\n\n" "$OUTPUT_FILE";
    
    # Try to read build map
    if read_build_map; then
        printf "\n%sUsing build map for file discovery%s\n" "$green" "$x"
    else
        printf "%sNo build map found, using auto-discovery%s\n" "$yellow" "$x"
    fi
    
    # Verify parts directory exists
    if [[ ! -d "$PARTS_DIR" ]]; then
        printf "%sERROR:%s Parts directory '%s' not found\n" "$red" "$x" "$PARTS_DIR" >&2
        exit 1;
    fi
    
    # Auto-discover numbered modules in order
    local modules=()
    if [[ "$USE_BUILD_MAP" == true ]]; then
        # Use build map for discovery
        for num in $(printf '%s\n' "${!build_map_targets[@]}" | sort -n); do
            local target="${build_map_targets[$num]}"
            if [[ -f "$PARTS_DIR/$target" ]]; then
                modules+=("$target")
            else
                printf "%sERROR:%s Mapped file not found: %s\n" "$red" "$x" "$target" >&2
                exit 1
            fi
        done
    else
        # Original auto-discovery logic
        while IFS= read -r -d '' file; do
            local basename_file
            basename_file=$(basename "$file")
            # Check if file matches pattern: N+_*.sh (where N+ is 1+ digits)
            if [[ "$basename_file" =~ ^[0-9]+_.*\.sh$ ]]; then
                modules+=("$basename_file")
            fi
        done < <(find "$PARTS_DIR" -name "[0-9]*_*.sh" -print0 | sort -z)
    fi
    
    # Verify we found modules
    if [[ ${#modules[@]} -eq 0 ]]; then
        printf "%sERROR:%s No numbered modules found in %s\n" "$red" "$x" "$PARTS_DIR" >&2
        if [[ "$USE_BUILD_MAP" != true ]]; then
            printf "Expected pattern: NN_name.sh (e.g., 01_header.sh, 02_colors.sh)\n" >&2
        fi
        exit 1
    fi
    
    printf "%sDiscovered %d modules:%s\n" "$green" "${#modules[@]}" "$x"
    for module in "${modules[@]}"; do
        local module_path="$PARTS_DIR/$module"
        if [[ -f "$module_path" ]]; then
            printf "%s✓%s %s\n" "$green" "$x" "$module"
        else
            printf "%s✗%s %s (missing)\n" "$red" "$x" "$module"
            exit 1
        fi
    done
    
    printf "\n%sAssembling modules in numeric order...%s\n" "$yellow" "$x"
    
    # Create header with generation info
    cat > "$OUTPUT_FILE" <<-EOF
			#!/usr/bin/env bash
			# Generated by build.sh on $(date)
			# Auto-assembled from numbered modules: ${modules[*]}
		EOF
    
    # Assemble modules in numeric order
    local first_module=true
    for module in "${modules[@]}"; do
        local module_path="$PARTS_DIR/$module"
        printf "  Adding: %s\n" "$module"
        
        # Add module separator comment
        echo "# === $module ===" >> "$OUTPUT_FILE"
        
        # Handle shebang: only include from first module
        if [[ "$first_module" == true ]]; then
            # Include everything from first module including shebang
            cat "$module_path" >> "$OUTPUT_FILE"
            first_module=false
        else
            # Skip shebang line from subsequent modules
            if head -1 "$module_path" | grep -q "^#!/"; then
                tail -n +2 "$module_path" >> "$OUTPUT_FILE"
            else
                # No shebang to skip
                cat "$module_path" >> "$OUTPUT_FILE"
            fi
        fi
        
        # Add spacing between modules
        echo "" >> "$OUTPUT_FILE"
    done
    
    # Make executable
    chmod +x "$OUTPUT_FILE"
    
    printf "\n%s✓ Successfully assembled:%s %s\n" "$green" "$x" "$OUTPUT_FILE"
    
    # Quick syntax check
    printf "%sPerforming syntax check...%s\n" "$yellow" "$x"
    if bash -n "$OUTPUT_FILE"; then
        printf "%s✓ Syntax check passed%s\n" "$green" "$x"
    else
        printf "%s✗ Syntax errors detected%s\n" "$red" "$x" >&2
        exit 1
    fi
    
    # Show file info
    local line_count word_count
    line_count=$(wc -l < "$OUTPUT_FILE")
    word_count=$(wc -w < "$OUTPUT_FILE")
    
    printf "\n%sGenerated script info:%s\n" "$blue" "$x"
    printf "  Modules: %d\n" "${#modules[@]}"
    printf "  Lines: %s\n" "$line_count"
    printf "  Words: %s\n" "$word_count"
    printf "  Size: %s bytes\n" "$(wc -c < "$OUTPUT_FILE")"
    
    printf "\n%sReady for testing:%s\n" "$blue" "$x"
    printf "  Basic test: ./%s --help\n" "$OUTPUT_FILE"
    printf "  Syntax: bash -n %s\n" "$OUTPUT_FILE"
    
    printf "\n%s✓ Build complete!%s\n" "$green" "$x"
}

# Help function  
usage() {
    cat << EOF
build.sh - Assemble script from numbered modular parts (enhanced)

USAGE:
  ./build.sh [OPTIONS]

OPTIONS:
  -h, --help    Show this help
  -o FILE       Output file (default: padlock.sh)
  -p DIR        Parts directory (default: parts)
  -m FILE       Build map file (default: build.map)
  -r            Rename mode: rename source files according to build map
  -v            Verbose mode
  -c            Clean (remove output file before building)
  -l            List discovered modules and exit

EXAMPLES:
  ./build.sh                           # Build with defaults
  ./build.sh -o padlock.sh             # Custom output name
  ./build.sh -p modules -o script      # Custom parts dir and output
  ./build.sh -r                        # Rename source files using build.map
  ./build.sh -c                        # Clean build
  ./build.sh -l                        # List modules only

BUILD MAP:
  If build.map exists, it will be used to map source files to target names.
  Format: NN : target_filename.sh
  
  Example build.map:
    01 : 01_header.sh
    02 : 02_config.sh
    03 : 03_stderr.sh

RENAME MODE (-r):
  Renames downloaded artifacts (e.g., padlock_part_01.sh) to proper 
  numbered format (e.g., 01_header.sh) according to build.map.

MODULE NAMING:
  Modules must follow pattern: NN_name.sh
  Where NN is 2+ digit number (e.g., 01, 02, 99, 100)
EOF
}

# Parse arguments
list_only=false
rename_only=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        (-h|--help)
            usage
            exit 0
            ;;
        (-o)
            [[ $# -ge 2 ]] || { echo "ERROR: -o requires an argument" >&2; exit 1; }
            OUTPUT_FILE="$2"
            shift 2
            ;;
        (-p)
            [[ $# -ge 2 ]] || { echo "ERROR: -p requires an argument" >&2; exit 1; }
            PARTS_DIR="$2"
            shift 2
            ;;
        (-m)
            [[ $# -ge 2 ]] || { echo "ERROR: -m requires an argument" >&2; exit 1; }
            BUILD_MAP="$2"
            shift 2
            ;;
        (-r)
            rename_only=true
            shift
            ;;
        (-c)
            if [[ -f "$OUTPUT_FILE" ]]; then
                printf "%sCleaning:%s Removing existing %s\n" "$yellow" "$x" "$OUTPUT_FILE"
                rm -f "$OUTPUT_FILE"
            fi
            shift
            ;;
        (-l)
            list_only=true
            shift
            ;;
        (-v)
            set -x
            shift
            ;;
        (*)
            printf "%sERROR:%s Unknown option: %s\n" "$red" "$x" "$1" >&2
            usage >&2
            exit 1
            ;;
    esac
done

# Rename mode: just rename files and exit
if [[ "$rename_only" == true ]]; then
    if read_build_map; then
        rename_from_build_map
        printf "\n%s✓ Rename complete!%s\n" "$green" "$x"
    else
        printf "%sERROR:%s No valid build map found\n" "$red" "$x" >&2
        exit 1
    fi
    exit 0
fi

# List mode: just show discovered modules
if [[ "$list_only" == true ]]; then
    printf "%sDiscovering numbered modules in %s:%s\n\n" "$blue" "$PARTS_DIR" "$x"
    
    read_build_map || true  # Don't fail if no build map
    
    if [[ ! -d "$PARTS_DIR" ]]; then
        printf "%sERROR:%s Directory '%s' not found\n" "$red" "$x" "$PARTS_DIR" >&2
        exit 1
    fi
    
    local modules=()
    if [[ "$USE_BUILD_MAP" == true ]]; then
        for num in $(printf '%s\n' "${!build_map_targets[@]}" | sort -n); do
            local target="${build_map_targets[$num]}"
            if [[ -f "$PARTS_DIR/$target" ]]; then
                modules+=("$target")
            fi
        done
    else
        while IFS= read -r -d '' file; do
            local basename_file
            basename_file=$(basename "$file")
            if [[ "$basename_file" =~ ^[0-9]+_.*\.sh$ ]]; then
                modules+=("$basename_file")
            fi
        done < <(find "$PARTS_DIR" -name "[0-9]*_*.sh" -print0 | sort -z)
    fi
    
    if [[ ${#modules[@]} -eq 0 ]]; then
        printf "%sNo numbered modules found%s\n" "$yellow" "$x"
        printf "Expected pattern: NN_name.sh\n"
        exit 1
    fi
    
    printf "%sFound %d modules:%s\n" "$green" "${#modules[@]}" "$x"
    for i in "${!modules[@]}"; do
        printf "%3d. %s\n" $((i+1)) "${modules[$i]}"
    done
    
    exit 0
fi

main "$@"