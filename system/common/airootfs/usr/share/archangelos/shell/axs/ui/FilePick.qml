// Native file chooser. open() then handle picked(path). `save` asks for a new file name,
// `folder` picks a directory.
import QtQuick
import QtQuick.Dialogs

Item {
    id: fp
    visible: false
    property string title: "Choose a file"
    property var filters: ["All files (*)"]
    property string folder: ""
    property bool save: false
    property bool pickFolder: false
    property string suggested: ""
    signal picked(string path)
    function open() {
        if (fp.pickFolder) { dirDlg.open(); return; }
        if (fp.save && fp.suggested !== "") dlg.selectedFile = "file://" + fp.folder + "/" + fp.suggested;
        dlg.open();
    }
    function local(u) { return decodeURIComponent(String(u).replace(/^file:\/\//, "")); }
    FileDialog {
        id: dlg
        title: fp.title
        nameFilters: fp.filters
        fileMode: fp.save ? FileDialog.SaveFile : FileDialog.OpenFile
        currentFolder: fp.folder !== "" ? "file://" + fp.folder : ""
        onAccepted: fp.picked(fp.local(selectedFile))
    }
    FolderDialog {
        id: dirDlg
        title: fp.title
        currentFolder: fp.folder !== "" ? "file://" + fp.folder : ""
        onAccepted: fp.picked(fp.local(selectedFolder))
    }
}
