# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/07_ignition_api.sh | src_sum:ac6942ec5db5698ee7c01994f4c90857267326c2f3357757f50d88e537f8e6d7 | orig:_should_exclude | edit:ignition__should_exclude | orig_sum:9089d7710952caa96f8c1e65de2a59c9a8dbce9776eb80a5e044caba75d92622
    ignition__should_exclude() {
        local path="$1"
        local basename_lower
        basename_lower=$(basename "$path" | tr '[:upper:]' '[:lower:]')
        
        # Exclude README.md and SECURITY.md (case insensitive)
        case "$basename_lower" in
            readme.md|security.md)
                return 0
                ;;
        esac
        
        # Exclude padlock infrastructure
        case "$path" in
            .git/*|bin/*|.githooks/*|locker.age|.locked|.chest/*|super_chest.age|.overdrive|padlock.map|locker/*)
                return 0
                ;;
        esac
        
        return 1
    }
