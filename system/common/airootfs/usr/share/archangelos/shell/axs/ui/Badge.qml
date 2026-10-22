// Small mono status chip: "neutral", "accent", "ok" or "danger".
import QtQuick
import qs.axs

Rectangle {
    property string text: ""
    property string tone: "neutral"
    readonly property color tint: tone === "accent" ? Ax.accent : tone === "ok" ? Ax.ok : tone === "danger" ? Ax.danger : Ax.subtext
    implicitWidth: lbl.implicitWidth + 16; implicitHeight: 20
    radius: 6
    color: Ax.alpha(tint, 0.12)
    border.width: 1; border.color: Ax.alpha(tint, 0.35)
    Label { id: lbl; anchors.centerIn: parent; caption: true; text: parent.text; color: parent.tint; font.letterSpacing: 1 }
}
