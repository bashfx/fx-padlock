# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:_overdrive_status | edit:repo__overdrive_status | orig_sum:b2191cfef252cf8f7ff54a3d36c939bfaeb4da6afce5f3ddb35d0f9effeb60ae
repo__overdrive_status() {
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
