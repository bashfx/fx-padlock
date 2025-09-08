# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/06_master_api.sh | src_sum:2158434627cf43659ef6d04d2a2446b980df50f94b93eddb92a6b1e842ee5855 | orig:do_sec | edit:master_do_sec | orig_sum:a171d6a5161cee0ee5ea8855d62dc133702b759fadc37bb773faaf90fa9efdb4
do_sec() {
    local action="${1:-}"
    
    case "$action" in
        auto)
            # padlock sec auto (was: automap)
            shift || true
            do_automap "$@"
            ;;
            
        add)
            # padlock sec add /path
            shift || true
            local path="${1:-}"
            if [[ -z "$path" ]]; then
                error "Missing file path"
                info "Usage: padlock sec add <path>"
                return 1
            fi
            
            do_map add "$path" "${@:2}"
            ;;
            
        "")
            # padlock sec (no action) - show help
            info "File Security Commands:"
            info "  <path>              Secure file (default: add)"
            info "  add <path>          Add file to security mapping"
            info "  remove <path>       Remove file from security mapping"
            info "  auto                Auto-secure sensitive files (*.md, build.sh, etc.)"
            return 0
            ;;
            
        *)
            # padlock sec /path (treat first arg as path)
            if [[ -z "$action" ]]; then
                error "Missing file path"
                info "Usage: padlock sec <path>"
                return 1
            fi
            
            do_map add "$action" "${@:2}"
            ;;
            
        remove)
            # padlock sec remove /path
            local path="$1"
            if [[ -z "$path" ]]; then
                error "Missing file path"
                info "Usage: padlock sec remove <path>"
                return 1
            fi
            
            do_map remove "$path" "${@:2}"
            ;;
            
        help|*)
            if [[ "$action" != "help" ]] && [[ "$action" != "auto" ]] && [[ -n "$action" ]]; then
                # Treat as path for backward compatibility
                do_map add "$action" "$@"
                return
            fi
            
            if [[ "$action" != "help" ]] && [[ "$action" != "auto" ]]; then
                error "Unknown sec action: $action"
            fi
            info "File Security Commands:"
            info "  <path>              Secure file (default: add)"
            info "  add <path>          Add file to security mapping"
            info "  remove <path>       Remove file from security mapping"
            info "  auto                Auto-secure sensitive files (*.md, build.sh, etc.)"
            return 0
            ;;
    esac
}
