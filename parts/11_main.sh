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
    
    # Skip processed options to get to command
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--debug|-t|--trace|-q|--quiet|-f|--force|-y|--yes|-D|--dev)
                shift
                ;;
            -h|--help|-v|--version)
                # These are handled in options() and exit
                shift
                ;;
            --)
                shift
                break
                ;;
            -*)
                shift  # Skip unknown options (already handled in options())
                ;;
            *)
                # Found command
                break
                ;;
        esac
    done
    
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