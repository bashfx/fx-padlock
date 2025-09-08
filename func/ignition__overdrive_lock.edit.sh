# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_overdrive_lock | edit:ignition__overdrive_lock | orig_sum:1ba4388408c0b3fe0bee3d29358d595d05614c7a509db8b0d0d2d7099672fcc8
ignition__overdrive_lock() {
    REPO_ROOT=$(_get_repo_root .)

    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        error "Repository already in overdrive mode"
        return 1
    fi

    if [[ ! -d "$REPO_ROOT/locker" ]]; then
        fatal "Locker must be unlocked to engage overdrive mode."
    fi

    lock "🚀 Engaging overdrive mode..."

    # Create super_chest directory for staging
    local super_chest="$REPO_ROOT/.super_chest"
    mkdir -p "$super_chest"

    # Note: cleanup handled explicitly at end of function

    # Use tar to copy files, which is more reliable than rsync for this case
    info "Archiving entire repository..."
    tar -c --exclude-from <(printf "%s\n" \
        ".super_chest" \
        "bin" \
        ".chest" \
        "super_chest.age" \
        ".locked" \
        ".ignition.key" \
        ".git" \
        ".gitsim" \
        ".locker_checksum" \
        "locker.age" \
    ) -C "$REPO_ROOT" . | tar -x -C "$super_chest"

    source "$REPO_ROOT/locker/.padlock"

    local super_checksum
    super_checksum=$(_calculate_locker_checksum "$super_chest")

    tar --sort=name --mtime='@0' --owner=0 --group=0 --numeric-owner \
        -C "$super_chest" -czf - . | __encrypt_stream > "$REPO_ROOT/super_chest.age"

    # Remove everything except padlock infrastructure and super_chest.age
    find "$REPO_ROOT" -maxdepth 1 -mindepth 1 \
        ! -name ".super_chest" \
        ! -name "bin" \
        ! -name ".chest" \
        ! -name ".git" \
        ! -name ".gitsim" \
        ! -name "super_chest.age" \
        -exec rm -rf {} +

    __print_overdrive_file "$REPO_ROOT/.overdrive" "$super_checksum"

    local size
    size=$(du -h "$REPO_ROOT/super_chest.age" | cut -f1)
    okay "🚀 Overdrive engaged! Entire repo → super_chest.age ($size)"
    
    # Clean up staging directory
    rm -rf "$super_chest"
}
