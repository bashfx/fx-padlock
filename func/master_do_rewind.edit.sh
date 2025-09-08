# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/06_master_api.sh | src_sum:2158434627cf43659ef6d04d2a2446b980df50f94b93eddb92a6b1e842ee5855 | orig:do_rewind | edit:master_do_rewind | orig_sum:efff6693283577842d0bb6a5f23397c7033c51617362e33f0c88ccb35bf0c07a
master_do_rewind() {
    local snapshot_name="$1"
    local snapshots_dir="$PADLOCK_ETC/snapshots"

    if [[ ! -f "$snapshots_dir/${snapshot_name}.tar.age" || ! -f "$snapshots_dir/${snapshot_name}.info" ]]; then
        error "Snapshot not found: $snapshot_name"
        info "Available snapshots:"
        ls -1 "$snapshots_dir"/*.info 2>/dev/null | sed 's/\.info$//' | xargs -I {} basename {} || echo " (none)"
        return 1
    fi

    warn "This will ERASE your current padlock environment and restore the snapshot."
    read -p "Type the snapshot name to confirm: '$snapshot_name': " confirm
    if [[ "$confirm" != "$snapshot_name" ]]; then
        info "Rewind cancelled."
        return 0
    fi

    # Get the passphrase from the metadata file
    local snapshot_pass
    snapshot_pass=$(grep "^passphrase=" "$snapshots_dir/${snapshot_name}.info" | cut -d'=' -f2)

    # Call do_import with the correct arguments for non-interactive restore
    do_import "$snapshots_dir/${snapshot_name}.tar.age" --replace "$snapshot_pass"

    okay "✓ Rewound to snapshot: $snapshot_name"
}
