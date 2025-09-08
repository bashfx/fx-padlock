# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/06_master_api.sh | src_sum:2158434627cf43659ef6d04d2a2446b980df50f94b93eddb92a6b1e842ee5855 | orig:do_setup | edit:master_do_setup | orig_sum:333b2b82ba83ef4a30360a162a3d6173d65342dbe285500c54b29e01dca1c9b3
master_do_setup() {
    local target_path="${1:-.}"
    
    info "🔧 Setting up padlock in current repository..."
    
    # Default to generating a new key for setup
    do_clamp "$target_path" --generate
}
do_setup() {
    local subcommand="${1:-}"
    
    case "$subcommand" in
        ignition)
            # Direct skull backup creation
            _create_skull_backup
            return $?
            ;;
        *)
            # Default interactive setup
            _logo
            info "🔧 Padlock Interactive Setup"
            echo
            
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]]; then
                okay "✓ Master key already exists"
                
                # Check if skull backup exists
                local skull_backup="$PADLOCK_KEYS/skull.age"
                if [[ -f "$skull_backup" ]]; then
                    okay "✓ Skull backup exists"
                    info "Your padlock is fully configured."
                    echo
                    info "Available commands:"
                    info "  padlock clamp <dir>       - Deploy to a new repository"
                    info "  padlock setup skull       - Recreate skull backup"
                    info "  padlock key restore       - Restore from skull backup"
                    info "  padlock --help            - Show all commands"
                    return 0
                else
                    warn "⚠️  Skull backup is missing"
                    info "Creating skull backup from existing master key..."
                    echo
                    _create_skull_backup
                    return $?
                fi
            fi
            ;;
    esac
    
    echo "This will set up padlock encryption with a master key and skull backup."
    echo "The skull backup allows you to recover your master key if lost."
    echo
    read -p "Proceed with setup? [Y/n]: " confirm
    if [[ "$confirm" =~ ^[nN]$ ]]; then
        info "Setup cancelled."
        return 1
    fi
    
    echo
    info "🔑 Creating master key and skull backup..."
    _ensure_master_key
    
    echo
    okay "✓ Setup complete!"
    echo
    info "Next steps:"
    info "  1. Run 'padlock clamp <directory>' to secure a repository"
    info "  2. Keep your master key safe: $PADLOCK_GLOBAL_KEY"
    info "  3. Remember your ignition passphrase for emergency recovery"
}
