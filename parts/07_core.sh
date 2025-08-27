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
            case "${1:-}" in
                master)
                    help_master
                    ;;
                sec)
                    help_sec
                    ;;
                rotate)
                    help_rotate
                    ;;
                revoke)
                    help_revoke
                    ;;
                ignite)
                    help_ignite
                    ;;
                more)
                    usage_detailed
                    ;;
                "")
                    usage
                    ;;
                *)
                    error "No help available for: $1"
                    info "Available help topics: master, sec, rotate, revoke, ignite, more"
                    usage
                    ;;
            esac
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

# Simplified usage for AI efficiency
usage() {
    _logo
    cat << 'USAGE_SIMPLE_EOF'
Padlock - Git Repository Security Orchestrator

USAGE:
    padlock <command> [options]

CORE COMMANDS:
    clamp <path>        Deploy padlock to a git repository
    lock                Encrypt locker/ → locker.age
    unlock              Decrypt locker.age → locker/
    status              Show current lock/unlock state
    release <path>      Remove padlock from repository

MANAGEMENT:
    master <action>     Master key operations (generate/show/restore/unlock)
    sec <action>        File security operations (add/remove/auto)
    rotate <type>       Rotate keys (master/ignition/distro)
    revoke <type>       Revoke access (ignition/distro)

HELP:
    help more           Show detailed help with all options
    help <command>      Show help for specific command

EXAMPLES:
    padlock clamp . -K          # Deploy with ignition mode
    padlock status              # Check current state
    padlock help master         # Show master command help

USAGE_SIMPLE_EOF
}

# Detailed usage for human reference
usage_detailed() {
    _logo
    cat << 'USAGE_DETAILED_EOF'
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

    help            Show simplified help
    help more       Show this detailed help
    help <command>  Show help for specific command
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

USAGE_DETAILED_EOF
}

# Contextual help functions
help_master() {
    cat << 'HELP_MASTER_EOF'
MASTER KEY MANAGEMENT:

    padlock master <action> [options]

ACTIONS:
    generate        Generate new global master key
                   WARNING: Invalidates all existing repositories
                   
    show           Display master public key for sharing
                  Use for adding to new repositories
                  
    restore        Restore master key from skull backup
                  Emergency recovery option
                  
    unlock         Emergency unlock using master key
                  Last resort when repo keys are lost

EXAMPLES:
    padlock master generate     # Create new master key
    padlock master show        # Display public key
    padlock master unlock      # Emergency unlock

NOTES:
    Master key operations affect ALL repositories using padlock.
    Always backup before rotating master keys.
HELP_MASTER_EOF
}

help_sec() {
    cat << 'HELP_SEC_EOF'
FILE SECURITY OPERATIONS:

    padlock sec <action> [path]

ACTIONS:
    <path>         Secure file (default: add to mapping)
    add <path>     Add file to security mapping
    remove <path>  Remove file from security mapping
    auto           Auto-secure sensitive files
    
    # Alternative command:
    padlock dec <path>    # De-secure file (same as remove)

EXAMPLES:
    padlock sec config.json        # Secure a file
    padlock sec add *.key         # Secure key files
    padlock sec remove old.conf   # Remove from security
    padlock sec auto              # Auto-secure common files

AUTO-SECURE PATTERNS:
    *.md files, build.sh, parts/, .claude, .gemini, .codex, 
    .priv, .sec, *.local.*, *bak*

NOTES:
    Secured files are automatically included in chest encryption.
    Files are moved to .chest/ directory structure.
HELP_SEC_EOF
}

help_rotate() {
    cat << 'HELP_ROTATE_EOF'
KEY ROTATION OPERATIONS:

    padlock rotate <predicate> [name]

PREDICATES (REQUIRED):
    master         Rotate global master key
                  WARNING: Affects ALL repositories
                  
    ignition [name] Rotate ignition master key
                   Invalidates all distributed keys
                   
    distro <name>  Rotate specific distributed key
                  Affects only named distributed key

EXAMPLES:
    padlock rotate master              # Rotate master key
    padlock rotate ignition            # Rotate default ignition
    padlock rotate ignition myteam    # Rotate named ignition
    padlock rotate distro ai-key      # Rotate specific distributed key

NOTES:
    Rotation is a destructive operation requiring predicates for safety.
    Always ensure backup/recovery methods before rotating keys.
HELP_ROTATE_EOF
}

help_revoke() {
    cat << 'HELP_REVOKE_EOF'
ACCESS REVOCATION OPERATIONS:

    padlock revoke <predicate> [name]

PREDICATES (REQUIRED):
    ignition [name] Revoke ignition key access
                   Prevents distributed key creation
                   
    distro <name>  Revoke specific distributed key
                  Immediate access termination

EXAMPLES:
    padlock revoke ignition            # Revoke default ignition
    padlock revoke ignition myteam    # Revoke named ignition
    padlock revoke distro ai-key      # Revoke specific distributed key

NOTES:
    Revocation is immediate and permanent.
    Revoked keys cannot unlock existing encrypted content.
    Use rotate instead of revoke if you want to maintain access.
HELP_REVOKE_EOF
}

help_ignite() {
    cat << 'HELP_IGNITE_EOF'
IGNITION SYSTEM (Third-Party Access):

    padlock ignite <action> [options]

ACTIONS:
    create [name]  Create repo-ignition master key
    new --name=X   Create distributed key for third parties
    unlock [name]  Unlock using distributed key + PADLOCK_IGNITION_PASS
    allow <pubkey> Grant access to public key
    list           List ignition keys
    status         Show ignition system status

EXAMPLES:
    padlock ignite create              # Create ignition master
    padlock ignite new --name=ai       # Create distributed key
    padlock ignite unlock              # Unlock with passphrase
    padlock ignite status              # Check system status

ENVIRONMENT:
    PADLOCK_IGNITION_PASS    Passphrase for ignition unlock

NOTES:
    Ignition system enables secure third-party access.
    Distributed keys can be safely shared with AI systems.
    Ignition unlock requires both key and passphrase.
HELP_IGNITE_EOF
}
