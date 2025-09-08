# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:do_key | edit:ignition_do_key | orig_sum:f0a8a2ada4837d6afb3371a588de5ef3753274536f9f566a745102a968957dcc
ignition_do_key() {
    local action="${1:-}"
    shift || true
    
    case "$action" in
        --set-global)
            local key_file="$1"
            if [[ ! -f "$key_file" ]]; then
                fatal "Key file not found: $key_file"
            fi
            
            info "🔑 Setting global master key..."
            mkdir -p "$(dirname "$PADLOCK_GLOBAL_KEY")"
            cp "$key_file" "$PADLOCK_GLOBAL_KEY"
            chmod 600 "$PADLOCK_GLOBAL_KEY"
            okay "✓ Global master key set"
            ;;
        --show-global)
            if [[ ! -f "$PADLOCK_GLOBAL_KEY" ]]; then
                error "No global master key found"
                info "Run: padlock key --generate-global"
                return 1
            fi
            
            local public_key
            public_key=$(age-keygen -y "$PADLOCK_GLOBAL_KEY" 2>/dev/null)
            echo "$public_key"
            ;;
        --generate-global)
            _logo
            if [[ -f "$PADLOCK_GLOBAL_KEY" ]] && [[ "${2:-}" != "--force" ]]; then
                error "Global master key already exists"
                info "Use --force to overwrite"
                return 1
            fi
            
            _ensure_master_key
            okay "✓ Global master key generated"
            ;;
        --add-recipient)
            local recipient="$1"
            if [[ -z "$recipient" ]]; then
                fatal "--add-recipient requires a public key"
            fi
            
            # Check if we're in a repo with locker config
            if [[ ! -f "locker/.padlock" ]]; then
                error "Not in an unlocked padlock repository"
                info "Run 'padlock unlock' first"
                return 1
            fi
            
            # Load current config
            source "locker/.padlock"
            
            # Add recipient to existing list
            if [[ -n "${AGE_RECIPIENTS:-}" ]]; then
                export AGE_RECIPIENTS="$AGE_RECIPIENTS,$recipient"
            else
                export AGE_RECIPIENTS="$recipient"
            fi
            
            # Update config file
            __print_padlock_config "locker/.padlock" "$(basename "$PWD")"
            
            okay "✓ Added recipient: ${recipient:0:20}..."
            info "Re-encrypt with: padlock lock"
            ;;
        restore)
            _logo
            _restore_master_key
            ;;
        
        # New key testing commands
        is)
            # padlock key is <type> --key=/path
            local key_type="$1"
            local key_path=""
            shift || true
            
            # Parse options with BashFX pattern
            local opts=("$@")
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key=*)
                        key_path="${opts[i]#*=}"
                        ;;
                    --path=*)
                        key_path="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key_path" ]]; then
                error "Missing --key or --path parameter"
                info "Usage: padlock key is <type> --key=/path/to/key"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if key at '$key_path' is type '$key_type'"
            info "This feature will analyze key metadata and structure"
            return 0
            ;;
            
        authority)
            # padlock key authority --key1=/path --key2=/path
            local key1="" key2=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key1=*)
                        key1="${opts[i]#*=}"
                        ;;
                    --key2=*)
                        key2="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key1" ]] || [[ -z "$key2" ]]; then
                error "Missing required parameters"
                info "Usage: padlock key authority --key1=/path --key2=/path"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if '$key1' has authority over '$key2'"
            info "This will verify key hierarchy relationships"
            return 0
            ;;
            
        subject)
            # padlock key subject --key1=/path --key2=/path
            local key1="" key2=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key1=*)
                        key1="${opts[i]#*=}"
                        ;;
                    --key2=*)
                        key2="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key1" ]] || [[ -z "$key2" ]]; then
                error "Missing required parameters"
                info "Usage: padlock key subject --key1=/path --key2=/path"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Testing if '$key1' is subject to '$key2'"
            info "This will verify child-parent key relationships"
            return 0
            ;;
            
        type)
            # padlock key type --key=/path
            local key_path=""
            local opts=("$@")
            
            for ((i=0; i<${#opts[@]}; i++)); do
                case "${opts[i]}" in
                    --key=*)
                        key_path="${opts[i]#*=}"
                        ;;
                    --path=*)
                        key_path="${opts[i]#*=}"
                        ;;
                esac
            done
            
            if [[ -z "$key_path" ]]; then
                error "Missing --key parameter"
                info "Usage: padlock key type --key=/path/to/key"
                return 1
            fi
            
            # Stub implementation
            info "[STUB] Identifying key type for: $key_path"
            info "Will return: skull|master|repo|ignition|distro|unknown"
            echo "unknown"  # Placeholder return
            return 0
            ;;
            
        ""|*)
            if [[ -z "$action" ]]; then
                info "Available key management actions:"
            else
                error "Unknown key action: $action"
            fi
            info "  --set-global <key>        Set global master key"
            info "  --show-global             Display global public key"
            info "  --generate-global         Generate new global key"
            info "  --add-recipient <key>     Add recipient to current repo"
            info "  restore                   Restore master key from skull backup"
            info ""
            info "Key Testing Commands:"
            info "  is <type> --key=/path     Test if key is specific type"
            info "  authority --key1=X --key2=Y  Test authority relationship"
            info "  subject --key1=X --key2=Y    Test subject relationship"
            info "  type --key=/path          Identify key type"
            [[ -n "$action" ]] && return 1 || return 0
            ;;
    esac
}
