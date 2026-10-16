#!/usr/bin/env bash
# ArchangelOS: put a wallpaper on the desktop — stills through awww, videos live through
# mpvpaper (as the ISO's wallpaper setup does), dropping whichever layer is not needed.
# Usage: show_wallpaper.sh PATH POSTER MODE
#   MODE preview : quick fade, nothing remembered (the picker while browsing)
#   MODE apply   : the grow transition, and ~/.curr_wall / ~/.curr_wall_static.jpg updated
path="$1"; poster="$2"; mode="${3:-apply}"
[ -f "$path" ] || exit 1
case "${path,,}" in
    *.mp4|*.webm|*.mkv|*.mov)
        pkill -x mpvpaper 2>/dev/null
        setsid -f mpvpaper -o "no-audio loop panscan=1.0" '*' "$path" >/dev/null 2>&1
        static="$poster" ;;
    *)
        if [ "$mode" = preview ]; then
            awww img --transition-type fade --transition-duration 0.7 "$path" || exit 1
        else
            awww img --transition-type grow --transition-step 200 --transition-duration 1.2 \
                --transition-fps 60 --transition-pos bottom "$path" || exit 1
        fi
        # the still is up: now drop a live video layer above it
        pkill -x mpvpaper 2>/dev/null
        static="$path" ;;
esac
[ "$mode" = apply ] || exit 0
ln -sf "$path" ~/.curr_wall
if [[ "${path,,}" == *.gif ]]; then
    rm -f ~/.curr_wall_static.jpg; magick "$path[0]" ~/.curr_wall_static.jpg 2>/dev/null || true
else
    ln -sf "$static" ~/.curr_wall_static.jpg
fi
