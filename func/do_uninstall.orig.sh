# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_uninstall | edit:repo_do_uninstall | orig_sum:3512d4073b10745fe90343b40ee4eea56f1f5918be53e67fe73785c5195ddbab
do_uninstall() {
    local lib_file="$XDG_LIB_HOME/fx/lib/padlock.sh"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    
    info "🗑️  Uninstalling padlock from system..."
    
    if [[ -L "$link_path" ]]; then
        rm "$link_path"
        info "✓ Removed symlink: $link_path"
    fi
    
    if [[ -f "$lib_file" ]]; then
        rm "$lib_file"
        info "✓ Removed library: $lib_file"
    fi
    
    if [[ ! -L "$link_path" ]] && [[ ! -f "$lib_file" ]]; then
        warn "⚠️  Padlock was not installed or already removed"
        return 0
    fi
    
    okay "✓ Padlock uninstalled successfully"
    info "💡 Keys and repositories remain in ~/.local/etc/padlock/"
}
