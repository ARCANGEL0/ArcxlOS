#!/usr/bin/env bash
set -euo pipefail

expected=${1:-}
shell=${2:-bash}
[[ $expected == /* ]] || {
    printf 'expected arcshell launcher path is invalid\n' >&2
    exit 64
}

case $shell in
  bash) resolved=$(command -v arcshell 2>/dev/null || true) ;;
  fish)
    fish_bin=$(command -v fish) || { printf 'Fish is unavailable\n' >&2; exit 1; }
    resolved=$(env PATH=/usr/bin:/bin "$fish_bin" -c 'command -s arcshell' 2>/dev/null || true)
    ;;
  *) printf 'unsupported shell: %s\n' "$shell" >&2; exit 64 ;;
esac
if [[ -z $resolved ]]; then
    printf 'arcshell is installed at %s but is not available on PATH; add %s to PATH, start a new shell, and rerun ./install.sh\n' \
        "$expected" "$(dirname -- "$expected")" >&2
    exit 1
fi

expected_target=$(readlink -f -- "$expected" 2>/dev/null || true)
resolved_target=$(readlink -f -- "$resolved" 2>/dev/null || true)
if [[ -z $expected_target || $resolved_target != "$expected_target" ]]; then
    printf 'arcshell resolves to %s instead of the installed launcher %s; correct PATH ordering and rerun ./install.sh\n' \
        "$resolved" "$expected" >&2
    exit 1
fi
