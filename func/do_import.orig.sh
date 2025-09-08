# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:do_import | edit:repo_do_import | orig_sum:b0b3fc781930522708301f41ea76a3b07a95af14b359dd47bc09faadefba1f9f
do_import() {
    local import_file="$1"
    local merge_mode="${2:---merge}"
    local passphrase="${3:-}" # Accept passphrase as 3rd arg

    if [[ ! -f "$import_file" ]]; then
        fatal "Import file not found: $import_file"
    fi

    if [[ -z "$passphrase" ]]; then
        # Get passphrase from environment, file, or interactive prompt
        if [[ -n "${PADLOCK_PASSPHRASE:-}" ]]; then
            passphrase="$PADLOCK_PASSPHRASE"
        elif [[ -n "${PADLOCK_PASSPHRASE_FILE:-}" ]] && [[ -f "$PADLOCK_PASSPHRASE_FILE" ]]; then
            passphrase=$(cat "$PADLOCK_PASSPHRASE_FILE")
        elif [[ -t 0 ]] && [[ -t 1 ]]; then
            read -sp "Enter passphrase for import file: " passphrase
            echo
        else
            fatal "No passphrase provided. Set PADLOCK_PASSPHRASE environment variable or use PADLOCK_PASSPHRASE_FILE for automation."
        fi
        
        if [[ -z "$passphrase" ]]; then
            fatal "Passphrase cannot be empty."
        fi
    fi

    local temp_dir
    temp_dir=$(_temp_mktemp_d)
    trap 'rm -rf "$temp_dir"' RETURN

    # Decrypt and extract
    if ! AGE_PASSPHRASE="$passphrase" age -d < "$import_file" | tar -C "$temp_dir" -xzf -; then
        fatal "Failed to decrypt import file (wrong passphrase?)"
    fi

    # Validate import
    if [[ ! -f "$temp_dir/export_info.json" || ! -f "$temp_dir/manifest.txt" ]]; then
        fatal "Invalid padlock export file."
    fi

    info "Successfully decrypted export file."

    # Backup current state
    local backup_dir="$PADLOCK_ETC/backup_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$backup_dir"
    if [[ -d "$PADLOCK_ETC" ]]; then
        cp -a "$PADLOCK_ETC"/* "$backup_dir/" 2>/dev/null || true
    fi
    info "Current environment backed up to: $backup_dir"

    # Import based on mode
    case "$merge_mode" in
        --replace)
            warn "Replacing current padlock environment."
            rm -f "$PADLOCK_ETC/manifest.txt"
            rm -rf "$PADLOCK_KEYS"
            rm -rf "$PADLOCK_ETC/repos"
            mkdir -p "$PADLOCK_KEYS"
            cp "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -r "$temp_dir/keys"/* "$PADLOCK_KEYS/"
            # Restore repo artifacts if they exist in the import
            if [[ -d "$temp_dir/repos" ]]; then
                cp -r "$temp_dir/repos" "$PADLOCK_ETC/repos"
            fi
            ;;
        --merge)
            info "Merging with current environment."
            _merge_manifests "$temp_dir/manifest.txt" "$PADLOCK_ETC/manifest.txt"
            cp -rT "$temp_dir/keys" "$PADLOCK_KEYS" 2>/dev/null || true
            # Restore repo artifacts if they exist in the import
            if [[ -d "$temp_dir/repos" ]]; then
                mkdir -p "$PADLOCK_ETC/repos"
                cp -rT "$temp_dir/repos" "$PADLOCK_ETC/repos" 2>/dev/null || true
            fi
            ;;
        *)
            fatal "Unknown import mode: $merge_mode. Use --merge or --replace."
            ;;
    esac

    okay "✓ Import completed successfully."
}
