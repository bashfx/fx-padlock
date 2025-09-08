# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/06_master_api.sh | src_sum:2158434627cf43659ef6d04d2a2446b980df50f94b93eddb92a6b1e842ee5855 | orig:do_master | edit:master_do_master | orig_sum:2c7647c20dec56f37ac1ec7baff5a718f8bb7e228d984301eab7cae3b6d19bf2
master_do_master() {
    local action="$1"
    shift || true
    
    case "$action" in
        generate)
            # padlock master generate
            _logo
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]] && [[ "$1" != "--force" ]]; then
                error "Global master key already exists"
                info "Use --force to overwrite"
                return 1
            fi
            
            _ensure_master_key
            okay "✓ Master key generated"
            ;;
            
        show)
            # padlock master show
            if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
                error "No global master key found"
                info "Run: padlock master generate"
                return 1
            fi
            
            local public_key
            public_key=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
            echo "$public_key"
            ;;
            
        restore)
            # padlock master restore
            _logo
            _restore_master_key
            ;;
            
        unlock)
            # padlock master unlock (same as master-unlock)
            do_master_unlock "$@"
            ;;
            
        help|*)
            if [[ "$action" != "help" ]]; then
                error "Unknown master action: $action"
            fi
            info "Master Key Management Commands:"
            info "  generate [--force]   Generate new global master key"
            info "  show                 Display master public key"
            info "  restore              Restore master key from skull backup"
            info "  unlock               Emergency unlock using master key"
            return 0
            ;;
    esac
}
