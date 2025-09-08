# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_merge_manifests | edit:ignition__merge_manifests | orig_sum:216f04ce619a92575e091b0a892337c0dfeed5730ac22283f21bd1c46e3efa5a
ignition__merge_manifests() {
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
