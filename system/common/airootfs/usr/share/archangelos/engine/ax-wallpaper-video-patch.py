#!/usr/bin/env python3
"""ArchangelOS — teach ArcShell's wallpaper picker about video wallpapers.

ArcShell's stock wallpaper pipeline is image-only: the picker lists png/jpg/webp,
and every selection is pushed through the transactional awww (swww fork) renderer
plus a matugen palette. This patch adds *smart routing* without disturbing that
image path:

  * wallpaperctl.sh `list` now also enumerates mp4/webm/mkv/mov and emits, per
    video, "<video>\\t<poster.png>" (an ffmpeg first-frame still, cached) so the
    gallery can show a thumbnail.
  * a new wallpaperctl.sh `video` subcommand plays the file with mpvpaper via the
    ArchangelOS video backend (archangelos-wallpaper) instead of awww.
  * the awww image paths (`render`/`apply`) first drop any live mpvpaper layer, so
    picking a still after a video reveals the freshly-rendered image.
  * WallpaperService.qml discovers the poster/isVideo columns and, on apply, routes
    videos to the `video` op (no awww transaction, no palette) while images are
    unchanged.
  * WallpaperCard.qml shows a small play badge on video entries.

Run at desktop-bake time against the ArcShell source tree ($1). Idempotent (a marker
guards each file) and strictly non-fatal: an anchor that no longer matches after an
ArcShell update is logged and skipped so the rest of the desktop still bakes.
"""
import os
import sys

MARKER = "ArchangelOS video-wallpaper"


def log(msg):
    print(f"  [arcshell-bake] ax-video: {msg}")


def patch_file(path, replacements, marker=MARKER):
    """Apply (old -> new) replacements to `path`. Returns True on success.

    Skips (returns True) if `marker` is already present. Every `old` must be
    found exactly once, or the file is left untouched (returns False)."""
    try:
        with open(path, "r", encoding="utf-8") as handle:
            text = handle.read()
    except OSError as error:
        log(f"cannot read {path}: {error}")
        return False
    if marker in text:
        log(f"already patched: {os.path.basename(path)}")
        return True
    for old, new in replacements:
        count = text.count(old)
        if count != 1:
            log(f"anchor x{count} (want 1) in {os.path.basename(path)}; skipping")
            return False
        text = text.replace(old, new)
    try:
        with open(path, "w", encoding="utf-8") as handle:
            handle.write(text)
    except OSError as error:
        log(f"cannot write {path}: {error}")
        return False
    log(f"patched {os.path.basename(path)}")
    return True


# ── wallpaperctl.sh ──────────────────────────────────────────────────────────
WALLPAPERCTL = [
    (
        """    list)
        shift
        roots=()
        for root in "$@"; do [[ -d $root ]] && roots+=("$root"); done
        ((${#roots[@]})) && find "${roots[@]}" -maxdepth 3 -type f \\
            \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\
                -o -iname '*.webp' \\) -print 2>/dev/null | sort -u
        ;;""",
        """    list)
        # ArchangelOS video-wallpaper: smart image/video routing. Images are
        # emitted as a bare path; videos as "<video>\\t<poster-png>" so the picker
        # can show an ffmpeg first-frame thumbnail while applying the real file.
        shift
        roots=()
        for root in "$@"; do [[ -d $root ]] && roots+=("$root"); done
        poster_dir="${XDG_CACHE_HOME:-$HOME/.cache}/arcshell/video-posters"
        emit_poster() {
            local video=$1 key poster
            command -v ffmpeg >/dev/null 2>&1 || { printf '\\n'; return; }
            mkdir -p "$poster_dir" 2>/dev/null || { printf '\\n'; return; }
            key=$(printf '%s' "$video" | sha256sum | awk '{print $1}')
            poster="$poster_dir/$key.png"
            if [[ ! -f $poster ]]; then
                ffmpeg -y -loglevel error -i "$video" -frames:v 1 -q:v 3 \\
                    "$poster" </dev/null >/dev/null 2>&1 || { printf '\\n'; return; }
            fi
            printf '\\t%s\\n' "$poster"
        }
        if ((${#roots[@]})); then
            while IFS= read -r f; do
                case ${f,,} in
                    *.png|*.jpg|*.jpeg|*.webp) printf '%s\\n' "$f" ;;
                    *.mp4|*.webm|*.mkv|*.mov)  printf '%s' "$f"; emit_poster "$f" ;;
                esac
            done < <(find "${roots[@]}" -maxdepth 3 -type f \\
                \\( -iname '*.png' -o -iname '*.jpg' -o -iname '*.jpeg' \\
                    -o -iname '*.webp' -o -iname '*.mp4' -o -iname '*.webm' \\
                    -o -iname '*.mkv' -o -iname '*.mov' \\) -print 2>/dev/null \\
                | sort -u)
        fi
        ;;""",
    ),
    (
        """        write_request_token "$token"
        start_renderer auto >/dev/null || die 'renderer unavailable'""",
        """        write_request_token "$token"
        pkill -x mpvpaper 2>/dev/null || true   # drop any live video layer
        start_renderer auto >/dev/null || die 'renderer unavailable'""",
    ),
    (
        """        candidate_matches "$image" "$scheme" "$token" "$source_mode" \\
            "$source_color" || die 'stale candidate'
        start_renderer auto >/dev/null || die 'renderer unavailable'
        [[ -n $names ]] || die 'no live outputs'""",
        """        candidate_matches "$image" "$scheme" "$token" "$source_mode" \\
            "$source_color" || die 'stale candidate'
        pkill -x mpvpaper 2>/dev/null || true   # drop any live video layer
        start_renderer auto >/dev/null || die 'renderer unavailable'
        [[ -n $names ]] || die 'no live outputs'""",
    ),
    (
        """    *)
        printf 'usage: %s {list|probe|bootstrap|candidate|theme-source|cancel-candidate|render|palette|apply|scheme|reconcile}\\n' \\
            "$0" >&2
        exit 2
        ;;""",
        """    video)
        # A chosen video is displayed live via mpvpaper (ArchangelOS backend)
        # rather than pushed through the awww still pipeline; it draws above the
        # awww layer, and picking an image again stops mpvpaper (see render/apply).
        video=$(canonical "$2") || die 'wallpaper does not exist'
        [[ -f $video ]] || die 'wallpaper does not exist'
        command -v archangelos-wallpaper >/dev/null 2>&1 \\
            || die 'video wallpaper backend unavailable'
        archangelos-wallpaper set "$video" >/dev/null 2>&1 \\
            || die 'video wallpaper failed'
        say "CURRENT=$video"
        say WALLPAPER=updated
        say COMMITTED=true
        ;;
    *)
        printf 'usage: %s {list|probe|bootstrap|candidate|theme-source|cancel-candidate|render|palette|apply|scheme|reconcile|video}\\n' \\
            "$0" >&2
        exit 2
        ;;""",
    ),
]


# ── services/WallpaperService.qml ────────────────────────────────────────────
WALLPAPER_SERVICE = [
    (
        """                const rows = []
                const seen = new Set()
                for (const line of text.split("\\n")) {
                    const path = line.trim()
                    if (path && !seen.has(path)) {
                        seen.add(path)
                        rows.push({
                            path: path,
                            name: root.displayName(path),
                            source: root.imageSource(path)
                        })
                    }
                }
                root.wallpapers = rows""",
        """                const rows = []
                const seen = new Set()
                // ArchangelOS video-wallpaper: lines are "<image>" or
                // "<video>\\t<poster-png>". Videos are routed to mpvpaper on apply;
                // their thumbnail is the cached poster still when one exists.
                for (const rawLine of text.split("\\n")) {
                    const parts = rawLine.replace(/[\\r\\n]+$/, "").split("\\t")
                    const path = (parts[0] || "").trim()
                    if (!path || seen.has(path))
                        continue
                    seen.add(path)
                    const poster = parts.length > 1 ? parts[1].trim() : ""
                    const isVideo = /\\.(mp4|webm|mkv|mov)$/i.test(path)
                    rows.push({
                        path: path,
                        name: root.displayName(path),
                        source: root.imageSource(poster || path),
                        isVideo: isVideo
                    })
                }
                root.wallpapers = rows""",
    ),
    (
        """    function applyWallpaper(path: string, monitorName: string): bool {
        if (busy || applying || !wallpapers.some(item => item.path === path))
            return false
        const names = outputNames(monitorName)""",
        """    function applyVideoWallpaper(path: string): bool {
        if (busy || applying)
            return false
        errorMessage = ""
        operationState = "applying"
        // ArchangelOS video-wallpaper: no awww transaction and no matugen palette
        // for a live video; it is displayed as-is by mpvpaper.
        return beginOperation("video", [helperPath, "video", path])
    }

    function applyWallpaper(path: string, monitorName: string): bool {
        if (busy || applying || !wallpapers.some(item => item.path === path))
            return false
        if (wallpapers.some(item => item.path === path && item.isVideo))
            return applyVideoWallpaper(path)
        const names = outputNames(monitorName)""",
    ),
    (
        """    function selectCandidate(path: string): bool {
        if (busy || applying || directPaletteProcess.running
                || queuedPaletteCommand.length > 0
                || !wallpapers.some(item => item.path === path))
            return false""",
        """    function selectCandidate(path: string): bool {
        if (busy || applying || directPaletteProcess.running
                || queuedPaletteCommand.length > 0
                || !wallpapers.some(item => item.path === path))
            return false
        if (wallpapers.some(item => item.path === path && item.isVideo))
            return false""",
    ),
    (
        """        if (kind === "bootstrap") {""",
        """        if (kind === "video") {
            const committed = exitCode === 0 && output.includes("COMMITTED=true")
            operationState = "idle"
            if (committed) {
                errorMessage = ""
                root.wallpaperApplied(root.currentWallpaper, false)
            } else {
                errorMessage = detail || "Video wallpaper failed"
            }
            return
        }

        if (kind === "bootstrap") {""",
    ),
]


# ── panels/WallpaperCard.qml ─────────────────────────────────────────────────
WALLPAPER_CARD = [
    (
        """    HoverHandler { id: cardHover }""",
        """    // ArchangelOS video-wallpaper: mark live-video entries so they are
    // distinguishable from stills (they apply via mpvpaper on tap).
    Rectangle {
        visible: root.wallpaper.isVideo === true
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.margins: Theme.space2
        width: 18
        height: 18
        radius: 9
        color: Qt.alpha(Theme.surface, 0.82)

        Text {
            anchors.centerIn: parent
            text: "▶"
            color: Theme.primary
            font.family: Config.appearance.monoFontFamily
            font.pixelSize: 9
        }
    }

    HoverHandler { id: cardHover }""",
    ),
]


def main():
    if len(sys.argv) < 2:
        log("usage: ax-wallpaper-video-patch.py <arcshell-src>")
        return 0
    src = sys.argv[1]
    targets = [
        (os.path.join(src, "scripts", "wallpaperctl.sh"), WALLPAPERCTL),
        (os.path.join(src, "services", "WallpaperService.qml"), WALLPAPER_SERVICE),
        (os.path.join(src, "panels", "WallpaperCard.qml"), WALLPAPER_CARD),
    ]
    for path, replacements in targets:
        if not os.path.isfile(path):
            log(f"absent, skipping: {path}")
            continue
        try:
            patch_file(path, replacements)
        except Exception as error:  # never abort the desktop bake
            log(f"error patching {os.path.basename(path)}: {error}")
    return 0


if __name__ == "__main__":
    # Strictly non-fatal: always exit 0 so a patch miss can't fail the bake.
    try:
        sys.exit(main())
    except Exception as error:
        log(f"unexpected: {error}")
        sys.exit(0)
