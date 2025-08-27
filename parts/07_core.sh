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
        master)
            do_master "$@"
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
        ls)
            do_ls "$@"
            ;;
        clean-manifest)
            do_clean_manifest "$@"
            ;;
        declamp)
            do_declamp "$@"
            ;;
        release)
            do_declamp "$@"  # Alias for declamp
            ;;
        map)
            do_map "$@"
            ;;
        sec)
            do_sec "$@"  # File security mini-dispatcher
            ;;
        automap)
            do_automap "$@"
            ;;
        autosec)
            do_automap "$@"  # Auto-secure (new name for automap)
            ;;
        unmap)
            do_unmap "$@"
            ;;
        dec)
            do_unmap "$@"  # De-secure file (new name for unmap)
            ;;
        path)
            do_path "$@"
            ;;
        remote)
            do_remote "$@"
            ;;
        revoke)
            do_revoke "$@"
            ;;
        repair)
            do_repair "$@"
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

        overdrive)
            do_overdrive "$@"
            ;;

        help|--help|-h)
            usage
            ;;
        version|--version|-v)
            _logo
            printf "padlock %s\n" "$PADLOCK_VERSION"
            printf "PADLOCK (c) 2025 Qodeninja for BASHFX\n"
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
    _logo
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

    # Daily Operations
    lock            Encrypt locker/ → locker.age
    unlock          Decrypt locker.age → locker/
    status          Show current lock/unlock state with next steps
    release <path>  Remove padlock from repository (same as declamp)

    # Master Key Management
    master          Master key operations
      generate       Generate new global master key
      show           Display master public key  
      restore        Restore master key from skull backup
      unlock         Emergency unlock using master key

    # Key Testing & Management
    key             Advanced key operations
      is <type> --key=PATH          Test if key is specific type
      authority --key1=X --key2=Y   Test authority relationship
      subject --key1=X --key2=Y     Test subject relationship
      type --key=/path              Identify key type
      --set-global <key>            Store global key (legacy)
      --show-global                 Display global key (legacy)

    # File Security
    sec             File security operations
      <path>         Secure file (default: add to mapping)
      add <path>     Add file to security mapping
      remove <path>  Remove file from security mapping  
      auto           Auto-secure sensitive files
    dec <path>      De-secure file (remove from mapping)

    # Access Management
    rotate          Rotate keys (requires predicate)
      master         Rotate global master key (affects all repos)
      ignition [name] Rotate ignition key (invalidates distributed keys)
      distro <name>  Rotate specific distributed key

    revoke          Revoke access (requires predicate)  
      ignition [name] Revoke ignition key
      distro <name>   Revoke specific distributed key

    # Ignition System (Third-Party Access)
    ignite          Ignition key operations
      create [name]  Create repo-ignition master key
      new --name=X   Create distributed key for third parties
      unlock [name]  Unlock using distributed key + PADLOCK_IGNITION_PASS
      allow <pubkey> Grant access to public key
      list           List ignition keys
      status         Show ignition system status

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


    Advanced:
    map <path>      Map additional files/dirs for inclusion in chest
      add|remove    Add or remove path from mappings (default: add)
    automap         Automatically map common sensitive files and directories
                    (*.md files, build.sh, parts/, .claude, .gemini, .codex, .priv, .sec, *.local.*, *bak*)
    unmap <path|all> Remove files/dirs from mappings (with selection support)
    path [repo]     Show computed storage paths for keys and artifacts
    remote [repo]   Update artifacts for remote namespace (after adding git remote)
    overdrive       Engage overdrive mode (encrypts entire repo)
    declamp         Remove padlock from a repository
    revoke          Revoke encryption access (removes keys and forces re-key)
    repair          Repair missing padlock artifacts from manifest

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
                _logo
                printf "padlock %s\n" "$PADLOCK_VERSION"
                printf "PADLOCK (c) 2025 Qodeninja for BASHFX\n"
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
