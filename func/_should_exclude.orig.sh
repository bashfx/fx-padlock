# FUNC_META | src:/home/xnull/repos/code/shell/bashfx/fx-padlock/parts/08_repo_api.sh | src_sum:7653559b97e9662ff834af76ca6be09aada5e9098b294e7bbbb14a4e84c83334 | orig:_should_exclude | edit:repo__should_exclude | orig_sum:9089d7710952caa96f8c1e65de2a59c9a8dbce9776eb80a5e044caba75d92622
    _should_exclude() {
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
