// Every page: breadcrumb caption, title, description, the blade rule, then scrolling content
// laid out in a centred column so wide windows don't stretch rows across the screen.
import QtQuick
import qs.axs

Item {
    id: page
    property string group: ""
    property string title: ""
    property string desc: ""
    property int maxWidth: 880
    property alias header: headerExtra.data       // controls placed beside the title (top-right)
    default property alias content: col.data

    Flickable {
        id: flick
        anchors.fill: parent
        contentWidth: width
        contentHeight: col.y + col.implicitHeight + 48
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Item {
            id: head
            x: Math.max(40, (flick.width - page.maxWidth) / 2)
            width: Math.min(page.maxWidth, flick.width - 80)
            y: 34
            height: 96
            Label { id: crumb; caption: true; text: page.group !== "" ? page.group + "  ·  " + page.title : "Overview" }
            Label { id: ttl; y: 20; text: page.title; font.pixelSize: Ax.fsTitle; font.weight: Font.DemiBold; font.letterSpacing: -0.3 }
            Label { y: 60; width: parent.width - headerExtra.width - 20; text: page.desc; color: Ax.subtext; font.pixelSize: Ax.fsBody }
            Rectangle { y: 88; width: 28; height: 2; radius: 1; color: Ax.accent }
            Row { id: headerExtra; anchors.right: parent.right; y: 22; spacing: 8 }
        }
        Column {
            id: col
            x: head.x
            y: head.y + head.height + 26
            width: head.width
            spacing: 26
        }
    }
    // slim scroll indicator
    Rectangle {
        visible: flick.contentHeight > flick.height
        anchors.right: parent.right; anchors.rightMargin: 5
        width: 3; radius: 1.5
        y: flick.visibleArea.yPosition * flick.height
        height: flick.visibleArea.heightRatio * flick.height
        color: Ax.alpha(Ax.text, 0.18)
    }
}
