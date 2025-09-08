# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/09_key_api.sh | src_sum:e9fb365ce0c83b8e04e7a60e77f8660efb4e356a770fa7303a2a81d23e8cd466 | orig:_load_key_bundle | edit:key__load_key_bundle | orig_sum:84ff4e9f5c2497a945322d2b5e79cc44665d1646e67cbdbee65db7fe8c8913ba
key__load_key_bundle() {
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
