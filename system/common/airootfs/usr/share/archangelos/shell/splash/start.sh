#!/bin/sh
shell_dir="$(cd "$(dirname "$0")/.." && pwd)"
export FONTCONFIG_FILE="$shell_dir/fontconfig/fonts.conf"
qs -p "$shell_dir/splash" >/dev/null 2>&1 &
exec qs -p "$shell_dir"
