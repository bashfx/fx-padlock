#!/usr/bin/env bash
# Padlock gitsim-only end-to-end proof.
#
# Safety rule: never exercise padlock against the caller's live repository.
# This harness requires gitsim and runs only inside a simulated HOME/project.

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v gitsim >/dev/null 2>&1; then
    echo "SKIP: gitsim is required for safe Padlock e2e" >&2
    exit 0
fi

if ! command -v age >/dev/null 2>&1 || ! command -v age-keygen >/dev/null 2>&1; then
    echo "SKIP: age and age-keygen are required for Padlock e2e" >&2
    exit 0
fi

lab="$(mktemp -d "${TMPDIR:-/tmp}/padlock-gitsim-e2e.XXXXXX")"
cleanup() {
    rm -rf "$lab"
}
trap cleanup EXIT

cd "$lab"
gitsim home-init padlock-e2e >/dev/null
cd padlock-e2e

sim_home="$(gitsim home-path)"
export HOME="$sim_home"
export XDG_ETC_HOME="$sim_home/.local/etc"
export XDG_CACHE_HOME="$sim_home/.cache"
export TMPDIR="$sim_home/.cache/tmp"
mkdir -p "$XDG_ETC_HOME" "$TMPDIR"

cd "$sim_home/projects/testproject"
gitsim init >/dev/null

if [[ -d .git ]]; then
    echo "FAIL: e2e harness created a real .git repository" >&2
    exit 1
fi
if [[ ! -d .gitsim ]]; then
    echo "FAIL: e2e harness did not create a .gitsim repository" >&2
    exit 1
fi

"$repo_root/padlock.sh" help >/dev/null
"$repo_root/padlock.sh" status >/dev/null
"$repo_root/padlock.sh" clamp . -K testphrase >/dev/null

[[ -x bin/padlock ]] || { echo "FAIL: bin/padlock missing" >&2; exit 1; }
[[ -d locker ]] || { echo "FAIL: locker missing" >&2; exit 1; }
[[ -f locker/.padlock ]] || { echo "FAIL: locker/.padlock missing" >&2; exit 1; }
[[ -d .chest ]] || { echo "FAIL: .chest missing" >&2; exit 1; }
[[ -f .chest/ignition.key ]] || { echo "FAIL: ignition key missing" >&2; exit 1; }

echo "PASS: padlock gitsim e2e"
