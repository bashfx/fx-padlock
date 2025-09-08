# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_install | edit:repo_do_install | orig_sum:d49b30c5b99a29c2940e93a95ddfe6b1d94ad843dacfa472ce811e0c1d393ef4
repo_do_install() {
    local force="$opt_force"
    
    # Parse command-specific arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)
                force=1
                shift
                ;;
            *)
                shift
                ;;
        esac
    done
    
    _logo
    # Check if already installed
    local install_dir="$XDG_LIB_HOME/fx/lib"
    local link_path="$XDG_BIN_HOME/fx/padlock"
    local lib_file="$install_dir/padlock.sh"
    
    if [[ -f "$lib_file" ]] && [[ "$force" -eq 0 ]]; then
        warn "Padlock already installed (use --force to reinstall)"
        return 0
    fi
    
    info "Installing padlock to system..."
    
    # Remove old installation if exists
    if [[ -f "$lib_file" ]]; then
        info "Removing existing installation..."
        rm -f "$lib_file"
    fi
    if [[ -L "$link_path" ]]; then
        rm -f "$link_path"
    fi
    
    # Create installation directories
    mkdir -p "$install_dir" "$(dirname "$link_path")"
    
    # Copy only the built padlock.sh script to lib directory
    cp "$SCRIPT_PATH" "$lib_file"
    chmod +x "$lib_file"
    
    # Create symlink to bin directory
    ln -sf "$lib_file" "$link_path"
    
    # Generate master key on first install
    _ensure_master_key
    
    okay "✓ Padlock installed to: $lib_file"
    info "Available as: $link_path"
    info "🗝️  Global master key configured"
}
