// Dropdown. `model` is a list of strings (or objects with `label`); `current` is the shown index.
import QtQuick
import QtQuick.Controls as QQC
import qs.axs

Rectangle {
    id: sel
    property var model: []
    property int current: -1
    property string placeholder: "Select…"
    property bool searchable: model.length > 12
    signal picked(int index)
    implicitWidth: 220; implicitHeight: 32
    radius: Ax.radiusSm
    color: ma.containsMouse ? Ax.mix(Ax.raised, Ax.text, 0.04) : Ax.raised
    border.width: 1; border.color: pop.opened ? Ax.accentLine : Ax.border
    function labelOf(i) { const m = sel.model[i]; return m === undefined ? "" : (typeof m === "object" ? (m.label ?? "") : String(m)); }

    Label {
        anchors.left: parent.left; anchors.leftMargin: 12
        anchors.right: arrow.left; anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        text: sel.current >= 0 ? sel.labelOf(sel.current) : sel.placeholder
        font.pixelSize: Ax.fsSmall
        color: sel.current >= 0 ? Ax.text : Ax.faint
    }
    Icon {
        id: arrow
        anchors.right: parent.right; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        name: "expand_more"; size: 18
        rotation: pop.opened ? 180 : 0
        Behavior on rotation { NumberAnimation { duration: Ax.dur } }
    }
    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor; onClicked: pop.opened ? pop.close() : pop.open() }

    QQC.Popup {
        id: pop
        y: sel.height + 6
        width: Math.max(sel.width, 220)
        height: Math.min(320, list.contentHeight + (filter.visible ? 50 : 10))
        padding: 5
        onOpened: { filter.text = ""; if (filter.visible) filter.focusIn(); }
        background: Rectangle { radius: Ax.radius - 2; color: Ax.panel; border.width: 1; border.color: Ax.border }
        contentItem: Column {
            spacing: 5
            AxField { id: filter; visible: sel.searchable; width: parent.width; icon: "search"; placeholder: "Filter…"
                      onAccepted: if (list.count) { sel.picked(list.model[0].i); pop.close(); } }
            ListView {
                id: list
                width: parent.width
                height: pop.height - (filter.visible ? 50 : 10)
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                model: {
                    const q = filter.text.trim().toLowerCase(); const out = [];
                    for (let i = 0; i < sel.model.length; i++) { const l = sel.labelOf(i); if (!q || l.toLowerCase().includes(q)) out.push({ i: i, l: l }); }
                    return out;
                }
                delegate: Rectangle {
                    required property var modelData
                    width: list.width; height: 32; radius: Ax.radiusSm - 2
                    color: dm.containsMouse ? Ax.hover : (modelData.i === sel.current ? Ax.accentSoft : "transparent")
                    Label { anchors.left: parent.left; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 28
                            anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.l; font.pixelSize: Ax.fsSmall }
                    Icon { visible: parent.modelData.i === sel.current; anchors.right: parent.right; anchors.rightMargin: 8
                           anchors.verticalCenter: parent.verticalCenter; name: "check"; size: 16; color: Ax.accent }
                    MouseArea { id: dm; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                                onClicked: { sel.picked(parent.modelData.i); pop.close(); } }
                }
            }
        }
    }
}
