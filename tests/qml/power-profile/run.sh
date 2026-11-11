#!/bin/sh
set -eu
here="$(cd "$(dirname "$0")" && pwd)"
repo="$(cd "$here/../../.." && pwd)"
subject="${1:-$repo/system/common/airootfs/usr/share/archangelos/shell/arc/modules/bar/PowerProfile.qml}"
state="$(mktemp -d)"
trap 'rm -rf "$state"' EXIT
mkdir "$state/cfg"
cp "$here/shell.qml" "$state/cfg/"
cp "$subject" "$state/cfg/PowerProfile.qml"
echo balanced > "$state/profile"
FAKE_PPCTL_DIR="$state" FAKE_PPCTL="$here/fake-ppctl" \
  timeout 30 qs -p "$state/cfg" --no-color > "$state/log" 2>&1 || true
grep -E 'qml: (PASS|FAIL|ALL PASSED|[0-9]+ FAILED)| ERROR' "$state/log" | sed 's/^.*qml: //' || true
grep -q 'qml: ALL PASSED' "$state/log"
