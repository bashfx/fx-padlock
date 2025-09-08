# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_overdrive_status | edit:ignition__overdrive_status | orig_sum:b2191cfef252cf8f7ff54a3d36c939bfaeb4da6afce5f3ddb35d0f9effeb60ae
ignition__overdrive_status() {
    REPO_ROOT=$(_get_repo_root .)

    info "=== Overdrive Status ==="

    if [[ -f "$REPO_ROOT/super_chest.age" ]]; then
        local size
        size=$(du -h "$REPO_ROOT/super_chest.age" 2>/dev/null | cut -f1)
        warn "🚀 OVERDRIVE ENGAGED"
        info "Blob: super_chest.age ($size)"
        info "To restore: source .overdrive"
    else
        okay "✅ NORMAL MODE"
        info "To engage: padlock overdrive lock"
    fi
}
