#!/usr/bin/env bash
path="$1"; poster="$2"; mode="${3:-apply}"
[ -f "$path" ] || exit 1
awww_up() {
    pgrep -x awww-daemon >/dev/null 2>&1 || setsid -f awww-daemon >/dev/null 2>&1
    local i
    for i in 1 2 3 4 5 6 7 8 9 10; do
        awww query >/dev/null 2>&1 && return 0
        sleep 0.15
    done
    return 1
}
case "${path,,}" in
    *.mp4|*.webm|*.mkv|*.mov)
        pkill -x mpvpaper 2>/dev/null
        setsid -f mpvpaper -o "no-audio loop panscan=1.0" '*' "$path" >/dev/null 2>&1
        static="$poster" ;;
    *)
        awww_up || exit 1
        if [ "$mode" = preview ]; then
            awww img --transition-type fade --transition-duration 0.7 "$path" || exit 1
        else
            awww img --transition-type grow --transition-step 200 --transition-duration 1.2 \
                --transition-fps 60 --transition-pos bottom "$path" || exit 1
        fi
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
