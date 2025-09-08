# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/06_master_api.sh | src_sum:2158434627cf43659ef6d04d2a2446b980df50f94b93eddb92a6b1e842ee5855 | orig:do_snapshot | edit:master_do_snapshot | orig_sum:b14763d25140fb652107698bad0784895eaa04d8a5943fa31645738d8d011fd1
master_do_snapshot() {
    local snapshot_name="${1:-auto_$(date +%Y%m%d_%H%M%S)}"
    local snapshots_dir="$PADLOCK_ETC/snapshots"

    mkdir -p "$snapshots_dir"

    # Use a temporary, non-guessable passphrase for the snapshot export
    local snapshot_pass
    snapshot_pass=$(openssl rand -base64 32)

    local export_file="$snapshots_dir/${snapshot_name}.tar.age"

    info "Creating snapshot: $snapshot_name"

    local temp_dir
    temp_dir=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_dir"' RETURN

    cp "$PADLOCK_ETC/manifest.txt" "$temp_dir/manifest.txt"
    cp -r "$PADLOCK_KEYS" "$temp_dir/keys"
    
    # Include repo artifacts in snapshot
    if [[ -d "$PADLOCK_ETC/repos" ]]; then
        cp -r "$PADLOCK_ETC/repos" "$temp_dir/repos"
    fi

    tar -C "$temp_dir" -czf - . | AGE_PASSPHRASE="$snapshot_pass" age -p > "$export_file"
    if [[ $? -ne 0 ]]; then
        fatal "Failed to create snapshot export file."
    fi

    # Create snapshot metadata, including the passphrase
    cat > "$snapshots_dir/${snapshot_name}.info" << EOF
name=$snapshot_name
created=$(date -Iseconds)
passphrase=$snapshot_pass
repos=$(grep -cv "^#" "$PADLOCK_ETC/manifest.txt")
keys=$(find "$PADLOCK_KEYS" -name "*.key" | wc -l)
EOF

    okay "✓ Snapshot created: $snapshot_name"
}
