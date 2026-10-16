#!/usr/bin/env bash
# ArchangelOS: list wallpapers (stills and videos) from the given folders, one path per line,
# sorted. Each video gets a poster frame in the thumbnail cache (<md5 of path>-poster.jpg) the
# first time it is seen, for the picker's cards and as the static wallpaper.
# Usage: list_wallpapers.sh CACHE_DIR DIR...
cache="$1"; shift
mkdir -p "$cache"
find "$@" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' \
    -o -iname '*.gif' -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' -o -iname '*.mkv' \
    -o -iname '*.mov' \) 2>/dev/null | sort | while IFS= read -r f; do
    case "${f,,}" in
        *.mp4|*.webm|*.mkv|*.mov)
            poster="$cache/$(printf '%s' "$f" | md5sum | cut -d' ' -f1)-poster.jpg"
            if [ ! -s "$poster" ] && command -v ffmpeg >/dev/null 2>&1; then
                ffmpeg -nostdin -loglevel error -y -ss 1 -i "$f" -frames:v 1 -vf "scale=1280:-2" -q:v 3 "$poster" \
                    || ffmpeg -nostdin -loglevel error -y -i "$f" -frames:v 1 -vf "scale=1280:-2" -q:v 3 "$poster"
            fi ;;
    esac
    printf '%s\n' "$f"
done
