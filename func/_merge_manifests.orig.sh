# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:_merge_manifests | edit:repo__merge_manifests | orig_sum:216f04ce619a92575e091b0a892337c0dfeed5730ac22283f21bd1c46e3efa5a
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
