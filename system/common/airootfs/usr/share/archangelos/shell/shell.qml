// ArchangelOS shell — Quickshell entry point.
//   qs -p /usr/share/archangelos/shell
//   qs -p /usr/share/archangelos/shell ipc call shell launcher|session|close
import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    Variants {
        model: Quickshell.screens
        Bar {}
    }

    IpcHandler {
        target: "shell"
        function launcher(): void { ShellState.openLauncher() }
        function session(): void { ShellState.toggle("session") }
        function close(): void { ShellState.close() }
    }
}
