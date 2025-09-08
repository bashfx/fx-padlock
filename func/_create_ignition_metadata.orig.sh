# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/04_helpers.sh | src_sum:006090cb5331df867a9c820b7a6fc3a1eb87cc667567a92afca45282d7d9a760 | orig:_create_ignition_metadata | edit:helpers__create_ignition_metadata | orig_sum:2cefda8195ac1ec48a6f0c72cbf9a1922e93ff1cd422ef500c78ca13e759500b
_create_ignition_metadata() {
    local name="$1"
    local type="$2"
    
    cat <<EOF
{
    "type": "$type",
    "name": "$name",
    "created": "$(date -Iseconds)",
    "authority": "repo-master",
    "approach": "age-native-tty-subversion"
}
EOF
    
    return 0  # BashFX 3.0 compliance
}
