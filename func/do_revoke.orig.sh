# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/09_key_api.sh | src_sum:e9fb365ce0c83b8e04e7a60e77f8660efb4e356a770fa7303a2a81d23e8cd466 | orig:do_revoke | edit:key_do_revoke | orig_sum:2ebe8b17e3b1353268a6524b2632ff12e1ee889d13fdcc9700b74a8a4ab2792d
do_revoke() {
    local target="${1:-}"
    shift || true
    
    case "$target" in
        ignition)
            # padlock revoke ignition [name]
            local name="${1:-default}"
            info "[STUB] Revoking ignition key: $name"
            info "This will permanently invalidate the ignition key"
            return 0
            ;;
            
        distro)
            # padlock revoke distro [name]
            local name="$1"
            if [[ -z "$name" ]]; then
                error "Missing distro key name"
                info "Usage: padlock revoke distro <name>"
                return 1
            fi
            info "[STUB] Revoking distributed key: $name"
            info "Third-party access with this key will be terminated"
            return 0
            ;;
            
        # Legacy support
        --local)
            _revoke_local_access "$1"
            ;;
        -K|--ignition)
            _revoke_ignition_access "$1"
            ;;
            
        ""|help|*)
            if [[ -z "$target" ]]; then
                info "Available revocation commands:"
            elif [[ "$target" != "help" ]]; then
                error "Unknown revocation target: $target"
            else
                info "Revocation Commands:"
            fi
            info "  ignition [name]     Revoke ignition key (invalidates D keys)"
            info "  distro <name>       Revoke specific distributed key"
            info ""
            info "Legacy:"
            info "  --local             Revoke local access (WARNING: unrecoverable)"
            info "  --ignition          Revoke legacy ignition access"
            [[ -n "$target" ]] && [[ "$target" != "help" ]] && return 1 || return 0
            ;;
    esac
}
