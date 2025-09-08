# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_migrate_artifacts_namespace | edit:ignition__migrate_artifacts_namespace | orig_sum:5aa28ca4ce80e60dfd37e6b05e7082b0d1825f94819991bb32bfb3e5c77b3626
ignition__migrate_artifacts_namespace() {
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
