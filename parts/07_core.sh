# UPDATE the dispatch() function in parts/07_core.sh
# Add these new cases to the existing case statement:

dispatch() {
    local cmd="${1:-help}"
    shift || true
    
    case "$cmd" in
        clamp)
            do_clamp "$@"
            ;;
        setup)
            do_setup "$@"
            ;;
        lock)
            do_lock "$@"
            ;;
        unlock)
            do_unlock "$@"
            ;;
        status)
            do_status "$@"
            ;;
        key)
            do_key "$@"
            ;;
        install)
            do_install "$@"
            ;;
        uninstall)
            do_uninstall "$@"
            ;;
        master-unlock)
            do_master_unlock "$@"
            ;;
        ignite)
            do_ignite "$@"
            ;;
        help|--help|-h)
            usage
            ;;
        version|--version|-v)
            printf "padlock %s\n" "$PADLOCK_VERSION"
            ;;
        dev_test)
            if is_dev; then
                dev_test "$@"
            else
                fatal "Dev command requires -D flag"
            fi
            ;;
        *)
            error "Unknown command: $cmd"
            info "Run 'padlock help' for available commands"
            return 1
            ;;
    esac
}

# UPDATE the usage() function to include new commands:
usage() {
    cat << 'USAGE_EOF'
Padlock - Git Repository Security Orchestrator

USAGE:
    padlock <command> [options]

COMMANDS:
    clamp <path>     Deploy padlock to a git repository
      --global-key   Use or create global key
      --generate     Generate new repo-specific key
      --key <key>    Use explicit key
      -K, --ignition [key]  Enable ignition mode for AI collaboration

    setup           Setup encryption (first time in repo)
    lock            Encrypt locker/ → locker.age
    unlock          Decrypt locker.age → locker/
    status          Show current lock/unlock state with next steps

    master-unlock   Emergency unlock using global master key
    ignite          Ignition key operations
      --unlock       Unlock chest with ignition key
      --lock         Lock locker into chest
      --status       Show chest status

    key             Manage encryption keys
      --set-global <key>      Store global key
      --show-global           Display global key
      --generate-global       Create new global key

    install         Install padlock to your system for global access
    uninstall       Remove padlock from your system

    help            Show this help
    version         Show version

WORKFLOW:
    # Deploy to repository with ignition mode
    padlock clamp /path/to/repo -K

    # Work with secrets locally
    cd /path/to/repo
    echo "secret content" > locker/docs_sec/private.md

    # Commit (auto-encrypts)
    git add . && git commit -m "Add secrets"

    # Share ignition key for AI collaboration
    export PADLOCK_IGNITION_PASS="flame-rocket-boost-spark"
    source .locked

    # Emergency unlock if keys are lost
    padlock master-unlock

EXAMPLES:
    # Standard deployment
    padlock clamp . --generate

    # AI collaboration setup
    padlock clamp . -K "my-custom-ignition-key"

    # Emergency recovery
    padlock master-unlock

    # Check repository state
    padlock status

USAGE_EOF
}
