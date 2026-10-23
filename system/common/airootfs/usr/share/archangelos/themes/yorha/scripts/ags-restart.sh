#!/bin/sh
# Hard-restart the YoRHa bar (AGS). Uses whichever `ags` is installed (the ArchangelOS
# package puts it in /usr/bin; a hand install may have it in ~/.local/bin).
AGS="$(command -v ags || echo "$HOME/.local/bin/ags")"
"$AGS" quit -i yorha 2>/dev/null
pkill -9 -f '[a]gs.js'
pkill -9 -f '[a]gs run.*themes/yorha'
sleep 1
setsid "$AGS" run --gtk 3 "$HOME/.config/hypr/themes/yorha/components/ags/app.ts" \
    >/tmp/ags-yorha.log 2>&1 </dev/null &
