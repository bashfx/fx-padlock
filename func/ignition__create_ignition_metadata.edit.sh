# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_create_ignition_metadata | edit:ignition__create_ignition_metadata | orig_sum:22ee5a2f103be609122e1881f7715ba58f31ea9a2880ab5468581d660d3ec111
ignition__create_ignition_metadata() {
    local key_type="$1"     # "master" or "distro"  
    local name="$2"
    local key_path="$3"
    local fingerprint="$4"
    local encrypted="${5:-true}"  # Default to encrypted
    
    local metadata_file="$REPO_ROOT/.padlock/ignition/metadata/${name}.json"
    local timestamp=$(date -Iseconds)
    
    trace "Creating metadata for $key_type key: $name"
    
    cat > "$metadata_file" << EOF
{
  "name": "$name",
  "type": "$key_type",
  "created": "$timestamp",
  "updated": "$timestamp",
  "key_file": "$(basename "$key_path")",
  "fingerprint": "$fingerprint",
  "encrypted": $encrypted,
  "status": "active",
  "authority": {
    "master_key": true,
    "repo_key": true
  },
  "usage": {
    "unlock_count": 0,
    "last_used": null
  }
}
EOF
    
    return 0
}
