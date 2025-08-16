################################################################################
# stderr - BASHFX-Compliant Output Functions
################################################################################

# Color palette
red=$'\x1B[31m'
orange=$'\x1B[38;5;214m'
yellow=$'\x1B[33m'
green=$'\x1B[32m'
blue=$'\x1B[38;5;39m'
cyan=$'\x1B[38;5;14m'
magenta=$'\x1B[35m'
purple=$'\x1B[38;5;213m'
white=$'\x1B[38;5;15m'
grey=$'\x1B[38;5;249m'
grey2=$'\x1B[38;5;240m'
xx=$'\x1B[0m'

# Respect NO_COLOR environment
if [[ -n "${NO_COLOR:-}" ]]; then
    red="" orange="" yellow="" green="" blue="" cyan=""
    magenta="" purple="" white="" grey="" grey2="" xx=""
fi

# Glyphs
fail=$'\u2715'        # ✕
pass=$'\u2713'        # ✓
recv=$'\u27F2'        # ⟲
delta=$'\u25B3'       # △
boto=$'\u232C'        # ⌬
star=$'\xE2\x98\x85'  # ★
lambda=$'\xCE\xBB'    # λ
idots=$'\xE2\x80\xA6' # …
bolt=$'\xE2\x86\xAF'  # ↯
redo=$'\xE2\x86\xBB'  # ↻
spark=$'\u273B'       # ✻
unlock=$'\u26BF'      # ⚿

# Core printer function
__printx() {
    local text="$1" color="$2" prefix="$3" stream="${4:-2}"
    local color_code="${!color:-$white}"
    [[ -n "$text" ]] && printf "%b" "${color_code}${prefix}${text}${xx}" >&"$stream"
}

# Log dispatcher
__log() {
    local type="$1" text="$2" force="${3:-0}" stream=2
    
    # Respect global quiet mode
    if [[ "$opt_quiet" -eq 0 && "$force" -eq 1 ]]; then
        [[ "$type" == "fatal" || "$type" == "error" ]] || return 0
    fi
    
    case "$type" in
        fatal) __printx "$text\n" "red" "$fail " "$stream"; exit 1 ;;
        error) __printx "$text\n" "red" "$fail " "$stream" ;;
        warn)  [[ $force -eq 0 || $opt_debug -eq 0 ]] && __printx "$text\n" "orange" "$delta " "$stream" ;;
        okay)  [[ $force -eq 0 || $opt_debug -eq 0 ]] && __printx "$text\n" "green" "$pass " "$stream" ;;
        info)  [[ $opt_debug -eq 0 ]] && __printx "$text\n" "blue" "$recv " "$stream" ;;
        trace) [[ $opt_trace -eq 0 ]] && __printx "$text\n" "grey" "$idots " "$stream" ;;
        think) [[ $opt_trace -eq 0 ]] && __printx "$text\n" "purple" "$lambda " "$stream" ;;
        lock)  __printx "$text\n" "cyan" "$unlock " "$stream" ;;
    esac
}

# Public interface
fatal() { __log fatal "$1" "${2:-0}"; }
error() { __log error "$1" "${2:-0}"; }
warn()  { __log warn  "$1" "${2:-0}"; }
okay()  { __log okay  "$1" "${2:-0}"; }
info()  { __log info  "$1" "${2:-0}"; }
trace() { __log trace "$1" "${2:-0}"; }
think() { __log think "$1" "${2:-0}"; }
lock()  { __log lock  "$1" "${2:-0}"; }