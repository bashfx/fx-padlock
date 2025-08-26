################################################################################
# Configuration & Bootstrap
################################################################################

# XDG+ Environment (use env first, fallback to local)
XDG_ETC_HOME="${XDG_ETC_HOME:-$HOME/.local/etc}"
XDG_LIB_HOME="${XDG_LIB_HOME:-$HOME/.local/lib}"
XDG_BIN_HOME="${XDG_BIN_HOME:-$HOME/.local/bin}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/data}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# Script identity
readonly SCRIPT_PATH="$(realpath "${BASH_SOURCE[0]}")"
readonly SCRIPT_NAME="$(basename "$SCRIPT_PATH")"
readonly SCRIPT_DIR="$(dirname "$SCRIPT_PATH")"

# Padlock configuration - extract version from header
readonly PADLOCK_VERSION="$(grep "^# version:" "$SCRIPT_PATH" 2>/dev/null | sed 's/^# version:[[:space:]]*//' || echo "unknown")"
readonly PADLOCK_ETC="$XDG_ETC_HOME/padlock"
readonly PADLOCK_KEYS="$PADLOCK_ETC/keys"
readonly PADLOCK_GLOBAL_KEY="$PADLOCK_KEYS/global.key"
readonly PADLOCK_CONFIG="$PADLOCK_ETC/config"

# Runtime paths (determined at execution)
REPO_ROOT=""
LOCKER_DIR=""
LOCKER_BLOB=""
LOCKER_CONFIG=""

# Options (set by options() function)
opt_debug=0
opt_trace=0
opt_quiet=0
opt_force=0
opt_yes=0
opt_dev=0

# Command-specific options
opt_global_key=0
opt_generate=0
opt_key=""
opt_ignition=0
opt_ignition_key=""

# Bootstrap - ensure critical directories exist
mkdir -p "$PADLOCK_ETC" "$PADLOCK_KEYS"