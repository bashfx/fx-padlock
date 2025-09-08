# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:_migrate_artifacts_namespace | edit:repo__migrate_artifacts_namespace | orig_sum:5aa28ca4ce80e60dfd37e6b05e7082b0d1825f94819991bb32bfb3e5c77b3626
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
