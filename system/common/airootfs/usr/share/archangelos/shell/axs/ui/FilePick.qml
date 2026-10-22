// Native file chooser. open() then handle picked(path).
import QtQuick
import QtQuick.Dialogs

Item {
    id: fp
    visible: false
    property string title: "Choose a file"
    property var filters: ["All files (*)"]
    property string folder: ""
    signal picked(string path)
    function open() { dlg.open(); }
    FileDialog {
        id: dlg
        title: fp.title
        nameFilters: fp.filters
        currentFolder: fp.folder !== "" ? "file://" + fp.folder : ""
        onAccepted: fp.picked(decodeURIComponent(String(selectedFile).replace(/^file:\/\//, "")))
    }
}
