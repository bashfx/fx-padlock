# Simulated .bashrc for testing
export USER="xnull"
export HOME="injection-test/.gitsim/.home"
export SHELL="/bin/bash"
export EDITOR="/usr/bin/nano"
export LANG="en_US.UTF-8"

export PATH="$HOME/.local/bin:$PATH"
export XDG_CONFIG_HOME="$HOME/.config"
export XDG_DATA_HOME="$HOME/.local/share"
export XDG_STATE_HOME="$HOME/.local/state"
export XDG_CACHE_HOME="$HOME/.cache"

# Common aliases for testing
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'

# Simulate common shell functions
cd() { builtin cd "$@" && pwd; }
