# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:_is_mapped | edit:repo__is_mapped | orig_sum:2ca7e6e0a08b7681f80fd26699bf401b3587b29fa03ab9ca2c065dc3fbc25f08
    repo__is_mapped() {
        local path="$1"
        grep -q "^$path|" "$map_file" 2>/dev/null
    }
