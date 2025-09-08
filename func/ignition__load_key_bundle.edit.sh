# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_load_key_bundle | edit:ignition__load_key_bundle | orig_sum:84ff4e9f5c2497a945322d2b5e79cc44665d1646e67cbdbee65db7fe8c8913ba
ignition__load_key_bundle() {
    local name="$1"
    local key_type="${2:-auto}"  # "master", "distro", or "auto"
    
    # Auto-detect key type if not specified
    if [[ "$key_type" == "auto" ]]; then
        if [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.ikey" ]]; then
            key_type="master"
        elif [[ -f "$REPO_ROOT/.padlock/ignition/keys/${name}.dkey" ]]; then
            key_type="distro"  
        else
            error "No ignition key found for: $name"
            return 1
        fi
    fi
    
    local key_extension
    case "$key_type" in
        master) key_extension=".ikey" ;;
        distro) key_extension=".dkey" ;;
        *) error "Invalid key type: $key_type"; return 1 ;;
    esac
    
    local key_file="$REPO_ROOT/.padlock/ignition/keys/${name}${key_extension}"
    local metadata_file="$REPO_ROOT/.padlock/ignition/metadata/${name}.json"
    
    if [[ ! -f "$key_file" ]]; then
        error "Key file not found: $key_file"
        return 1
    fi
    
    if [[ ! -f "$metadata_file" ]]; then
        error "Metadata file not found: $metadata_file"
        return 1
    fi
    
    trace "Loading $key_type key bundle: $name"
    
    # Export key data and metadata for caller
    LOADED_KEY_DATA=$(cat "$key_file")
    LOADED_KEY_METADATA=$(cat "$metadata_file")
    LOADED_KEY_TYPE="$key_type"
    
    return 0
}
