# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:_overdrive_unlock | edit:repo__overdrive_unlock | orig_sum:7fa2835d7eaecb7548c03b1625be33faac64fd1e798d521ef6893bd65a155383
_overdrive_unlock() {
    REPO_ROOT=$(_get_repo_root .)

    if [[ ! -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository not in overdrive mode"
        return 1
    fi

    lock "🔓 Disengaging overdrive mode..."

    if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
        error "Master key not found, cannot unlock overdrive mode."
        info "Ensure your master key is available at $PADLOCK_GLOBAL_KEY"
        return 1
    fi
    export PADLOCK_KEY_FILE="$PADLOCK_GLOBAL_KEY"

    local super_chest="$REPO_ROOT/.super_chest"
    mkdir -p "$super_chest"
    
    if ! __decrypt_stream < "$REPO_ROOT/super_chest.age" | tar -C "$super_chest" -xzf -; then
        fatal "Failed to decrypt super_chest.age"
    fi

    if [[ -f "$REPO_ROOT/.overdrive" ]]; then
        local expected_checksum
        expected_checksum=$(grep "Super checksum:" "$REPO_ROOT/.overdrive" | cut -d' ' -f4)
        local current_checksum
        current_checksum=$(_calculate_locker_checksum "$super_chest")

        if [[ "$current_checksum" != "$expected_checksum" ]]; then
            warn "⚠️  Super chest integrity check failed!"
        else
            trace "✓ Super chest integrity verified"
        fi
    fi

    cp -rT "$super_chest/" "$REPO_ROOT/"

    rm -rf "$super_chest"
    rm -f "$REPO_ROOT/super_chest.age"
    rm -f "$REPO_ROOT/.overdrive"

    okay "🔓 Overdrive disengaged! Repository restored."
}
