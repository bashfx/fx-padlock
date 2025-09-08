# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_overdrive | edit:repo_do_overdrive | orig_sum:da2b92efaa28ec0ece35245f35e640e4bad7c61c49bcf5870ab8cf86f64d3079
do_overdrive() {
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
