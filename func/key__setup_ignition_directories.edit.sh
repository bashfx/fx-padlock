# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/09_key_api.sh | src_sum:e9fb365ce0c83b8e04e7a60e77f8660efb4e356a770fa7303a2a81d23e8cd466 | orig:_setup_ignition_directories | edit:key__setup_ignition_directories | orig_sum:ad6b9c9fddde44e67dae7a093d22fe3ebfe59be92af8954d7bf064b57bcdcd0f
key__setup_ignition_directories() {
    local repo_root="${1:-$REPO_ROOT}"
    
    if [[ -z "$repo_root" ]]; then
        error "No repository root specified for ignition setup"
        return 1
    fi
    
    local padlock_dir="$repo_root/.padlock"
    local ignition_dir="$padlock_dir/ignition"
    
    # Create ignition directory structure per ROADMAP.md
    trace "Setting up ignition directories in $padlock_dir"
    
    mkdir -p "$ignition_dir/keys" || {
        error "Failed to create ignition keys directory"
        return 1
    }
    
    mkdir -p "$ignition_dir/metadata" || {
        error "Failed to create ignition metadata directory"  
        return 1
    }
    
    mkdir -p "$ignition_dir/metadata/cache" || {
        error "Failed to create ignition cache directory"
        return 1
    }
    
    mkdir -p "$ignition_dir/.derived" || {
        error "Failed to create derived keys directory"
        return 1
    }
    
    # Create ignition manifest if it doesn't exist
    local manifest="$ignition_dir/manifest.json"
    if [[ ! -f "$manifest" ]]; then
        trace "Creating ignition manifest: $manifest"
        cat > "$manifest" << 'EOF'
{
  "version": "1.0",
  "created": "",
  "updated": "",
  "repo_id": "",
  "master_key_fingerprint": "",
  "ignition_keys": {},
  "distro_keys": {}
}
EOF
        # Set creation timestamp
        local timestamp=$(date -Iseconds)
        sed -i "s/\"created\": \"\"/\"created\": \"$timestamp\"/" "$manifest"
        sed -i "s/\"updated\": \"\"/\"updated\": \"$timestamp\"/" "$manifest"
    fi
    
    info "✓ Ignition directories ready: $ignition_dir"
    return 0
}
