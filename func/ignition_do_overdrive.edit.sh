# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:do_overdrive | edit:ignition_do_overdrive | orig_sum:da2b92efaa28ec0ece35245f35e640e4bad7c61c49bcf5870ab8cf86f64d3079
ignition_do_overdrive() {
    local action="${1:-lock}"

    case "$action" in
        lock) _overdrive_lock ;;
        unlock)
            _overdrive_unlock
            ;;
        status)
            _overdrive_status
            ;;
        *)
            error "Unknown overdrive action: $action"
            info "Usage: padlock overdrive {lock|unlock|status}"
            return 1
            ;;
    esac
}
