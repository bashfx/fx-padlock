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
        rotate)
            do_rotate "$@"
            ;;
        list)
            do_list "$@"
            ;;
        clean-manifest)
            do_clean_manifest "$@"
            ;;
        export)
            do_export "$@"
            ;;
        import)
            do_import "$@"
            ;;
        snapshot)
            do_snapshot "$@"
            ;;
        rewind)
            do_rewind "$@"
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
    rotate          Rotate keys
      --ignition     Rotate the ignition key passphrase

    key             Manage encryption keys
      --set-global <key>      Store global key
      --show-global           Display global key
      --generate-global       Create new global key

    install         Install padlock to your system for global access
    uninstall       Remove padlock from your system

    Manifest Management:
    list [--all|--ignition|--namespace <ns>]
                    List tracked repositories
    clean-manifest  Prune stale entries from the manifest

    Backup and Restore:
    export [file]   Export entire padlock environment to an encrypted file
    import <file>   Import an environment from an export file
    snapshot [name] Create a named backup snapshot of the current environment
    rewind <name>   Restore the environment from a named snapshot

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

options() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -d|--debug)
                opt_debug=1
                trace "Debug mode enabled"
                shift
                ;;
            -t|--trace)
                opt_trace=1
                opt_debug=1  # Trace implies debug
                trace "Trace mode enabled"
                shift
                ;;
            -q|--quiet)
                opt_quiet=1
                shift
                ;;
            -f|--force)
                opt_force=1
                trace "Force mode enabled"
                shift
                ;;
            -y|--yes)
                opt_yes=1
                trace "Auto-yes mode enabled"
                shift
                ;;
            -D|--dev)
                opt_dev=1
                opt_debug=1
                opt_trace=1
                trace "Developer mode enabled"
                shift
                ;;
            -h|--help)
                usage
                exit 0
                ;;
            -v|--version)
                printf "padlock %s\n" "$PADLOCK_VERSION"
                exit 0
                ;;
            --)
                shift
                break
                ;;
            -*)
                error "Unknown option: $1"
                info "Use -h for help"
                exit 1
                ;;
            *)
                # Not an option, break to handle as command
                break
                ;;
        esac
    done

    # Return remaining arguments
    return 0
}

dev_test() {
    if ! is_dev; then
        fatal "dev_test requires developer mode (-D)"
    fi

    lock "🧪 Running developer tests..."

    # Test crypto functions
    info "Testing crypto stream functions..."
    local test_data="test encryption data"

    # Set up test crypto
    AGE_PASSPHRASE="test-passphrase-123"

    # Test encrypt/decrypt cycle
    local encrypted decrypted
    encrypted=$(echo "$test_data" | __encrypt_stream)
    decrypted=$(echo "$encrypted" | __decrypt_stream)

    if [[ "$decrypted" == "$test_data" ]]; then
        okay "Crypto stream test passed"
    else
        error "Crypto stream test failed"
        trace "Expected: $test_data"
        trace "Got: $decrypted"
    fi

    # Test guard functions
    info "Testing guard functions..."

    if is_dev; then
        okay "is_dev() test passed"
    else
        error "is_dev() test failed"
    fi

    # Test repo detection
    info "Testing repo detection..."

    if is_git_repo "."; then
        okay "Git repo detection passed"
    else
        warn "Not in a git repo (expected for isolated testing)"
    fi

    # Test XDG paths
    info "Testing XDG paths..."
    trace "XDG_ETC_HOME: $XDG_ETC_HOME"
    trace "PADLOCK_ETC: $PADLOCK_ETC"
    trace "PADLOCK_KEYS: $PADLOCK_KEYS"

    okay "Developer tests completed"
}
