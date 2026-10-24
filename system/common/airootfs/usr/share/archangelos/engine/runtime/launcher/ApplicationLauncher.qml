import QtQuick
import "../services"

LauncherView {
    provider: CommandPaletteService
    placeholderText: "Search ArcShell"
    emptyText: "No matching ArcShell results"

    onActiveChanged: {
        if (active) {
            ClipboardService.refresh()
            KeybindService.refresh()
        }
    }
}
