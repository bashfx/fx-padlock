# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_is_mapped | edit:ignition__is_mapped | orig_sum:2ca7e6e0a08b7681f80fd26699bf401b3587b29fa03ab9ca2c065dc3fbc25f08
    ignition__is_mapped() {
        local path="$1"
        grep -q "^$path|" "$map_file" 2>/dev/null
    }
