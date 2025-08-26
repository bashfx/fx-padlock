################################################################################
# Main Function - Primary Entrypoint
################################################################################

main() {
    local ret=0
    
    # Early environment checks
    if [[ "${BASH_VERSION%%.*}" -lt 4 ]]; then
        fatal "Bash 4.0+ required (found: $BASH_VERSION)"
    fi
    
    # Handle no arguments
    if [[ $# -eq 0 ]]; then
        usage
        return 0
    fi
    
    # Parse options first (modifies opt_* variables)
    options "$@"
    
    # Strip all flags from arguments (they're already processed in opt_* variables)
    local clean_args=()
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --)
                shift
                # Add all remaining args after --
                clean_args+=("$@")
                break
                ;;
            -*)
                # Skip all flags (already processed by options())
                if [[ "$1" == "--key" || "$1" == "-K" || "$1" == "--ignition" ]] && [[ $# -gt 1 && "${2:-}" != -* ]]; then
                    # Skip flag with value
                    shift 2
                else
                    # Skip flag without value
                    shift
                fi
                ;;
            *)
                # Keep non-flag arguments
                clean_args+=("$1")
                shift
                ;;
        esac
    done
    
    # Set positional parameters to clean arguments
    set -- "${clean_args[@]}"
    
    # Show startup info in dev mode
    if is_dev; then
        trace "Padlock v$PADLOCK_VERSION starting..."
        trace "Script: $SCRIPT_PATH"
        trace "PID: $$"
        trace "Args: $*"
        trace "XDG_ETC_HOME: $XDG_ETC_HOME"
    fi
    
    # Dispatch to command handlers
    if [[ $# -gt 0 ]]; then
        dispatch "$@" || ret=$?
    else
        # No command provided after parsing options
        usage
    fi
    
    # Clean exit
    if is_dev; then
        trace "Padlock exiting with status: $ret"
    fi
    
    return $ret
}