# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_export | edit:repo_do_export | orig_sum:4bb02b6e52d9c970eb6d8948ec7fbf0bb3a02d982af63a14a659305888336c3e
repo_do_export() {
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
