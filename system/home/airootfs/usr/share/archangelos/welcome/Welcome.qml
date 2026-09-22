import QtQuick
import QtQuick.Window
import QtQuick.Layouts

Window {
    id: win
    width: 660
    height: 700
    visible: true
    color: "transparent"
    flags: Qt.FramelessWindowHint
    title: "archangelos-welcome"

    readonly property string cText:   "#ECEBE8"
    readonly property string cDim:    "#9A9895"
    readonly property string cFaint:  "#5E5D5A"
    readonly property string cAccent: "#C24A52"
    readonly property string cInk:    "#0E0E0D"

    property string edition: "ArchangelOS"
    property string version: ""
    property bool showAtStartup: true

    FontLoader { id: fReg;  source: "file:///usr/share/fonts/archangelos/Quantico-Regular.ttf" }
    FontLoader { id: fBold; source: "file:///usr/share/fonts/archangelos/Quantico-Bold.ttf" }
    FontLoader { id: fSam;  source: "file:///usr/share/fonts/archangelos/ShipporiMincho-SemiBold.ttf" }
    FontLoader { id: fSamL; source: "file:///usr/share/fonts/archangelos/ShipporiMincho-Regular.ttf" }

    Component.onCompleted: {
        var a = Qt.application.arguments
        for (var i = 0; i < a.length; i++) {
            if (a[i].indexOf("edition=") === 0)
                win.edition = a[i].substring(8)
            else if (a[i].indexOf("version=") === 0)
                win.version = a[i].substring(8)
        }
        win.x = Math.round((Screen.width - win.width) / 2)
        win.y = Math.round((Screen.height - win.height) / 2)
        win.requestActivate()
    }

    function finish(code) {
        if (code === 0 && !win.showAtStartup)
            Qt.exit(42)
        else
            Qt.exit(code)
    }

    Rectangle {
        id: panel
        anchors.fill: parent
        radius: 18
        color: "#0C0C0B"
        border.color: "#26FFFFFF"
        border.width: 1

        Image {
            anchors.fill: parent
            source: "file:///usr/share/sddm/themes/archangelos/background.png"
            fillMode: Image.PreserveAspectCrop
            opacity: 0.18
        }

        Rectangle {
            anchors.fill: parent
            radius: 18
            gradient: Gradient {
                GradientStop { position: 0.0; color: "#CC0C0C0B" }
                GradientStop { position: 1.0; color: "#F20C0C0B" }
            }
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton
            onPressed: win.startSystemMove()
        }

        Rectangle {
            id: closeButton
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.topMargin: 14
            anchors.rightMargin: 14
            width: 30
            height: 30
            radius: 15
            color: closeMA.containsMouse ? "#1AFFFFFF" : "transparent"
            z: 2

            Text {
                anchors.centerIn: parent
                text: "✕"
                color: closeMA.containsMouse ? win.cText : win.cFaint
                font.pixelSize: 14
            }

            MouseArea {
                id: closeMA
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: win.finish(0)
            }
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 120
            spacing: 0

            Image {
                Layout.alignment: Qt.AlignHCenter
                source: "file:///usr/share/sddm/themes/archangelos/logo.png"
                sourceSize.width: 210
                fillMode: Image.PreserveAspectFit
                Layout.bottomMargin: 6
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: win.edition
                color: win.cDim
                font.family: fSamL.name
                font.pixelSize: 20
                font.letterSpacing: 6
            }

            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: win.version !== ""
                text: "version " + win.version
                color: win.cFaint
                font.family: fReg.name
                font.pixelSize: 12
                font.letterSpacing: 2
                Layout.topMargin: 6
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 26
                Layout.bottomMargin: 24
                height: 1
                color: "#1EFFFFFF"
            }

            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                text: "Welcome to ArchangelOS. You can close this window and keep exploring, or start the installer to set up ArchangelOS on this computer."
                color: win.cText
                font.family: fReg.name
                font.pixelSize: 14
                lineHeight: 1.25
                opacity: 0.92
            }

            Rectangle {
                Layout.fillWidth: true
                Layout.topMargin: 34
                height: 50
                color: "transparent"
                radius: 3
                border.color: installMA.containsMouse ? win.cAccent : "#33FFFFFF"
                border.width: 1

                Text {
                    anchors.centerIn: parent
                    text: "INSTALL  ARCHANGELOS"
                    color: installMA.containsMouse ? win.cText : win.cDim
                    font.family: fReg.name
                    font.pixelSize: 13
                    font.letterSpacing: 4
                }

                MouseArea {
                    id: installMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Qt.exit(10)
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 26

                Text {
                    text: "◍  Documentation"
                    color: linkMA.containsMouse ? win.cDim : win.cFaint
                    font.family: fReg.name
                    font.pixelSize: 11
                    font.letterSpacing: 1

                    MouseArea {
                        id: linkMA
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://arch.arcangelo.net")
                    }
                }

                Item { Layout.fillWidth: true }

                Text {
                    text: "◈  arcangelo.net"
                    color: siteMA.containsMouse ? win.cDim : win.cFaint
                    font.family: fReg.name
                    font.pixelSize: 11
                    font.letterSpacing: 1

                    MouseArea {
                        id: siteMA
                        anchors.fill: parent
                        anchors.margins: -6
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: Qt.openUrlExternally("https://arcangelo.net")
                    }
                }
            }

            RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 14
                spacing: 9

                Rectangle {
                    width: 14
                    height: 14
                    radius: 2
                    color: win.showAtStartup ? win.cAccent : "transparent"
                    border.color: win.showAtStartup ? win.cAccent : win.cFaint
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        visible: win.showAtStartup
                        text: "✓"
                        color: win.cInk
                        font.pixelSize: 10
                    }
                }

                Text {
                    text: "Show this window at startup"
                    color: win.cFaint
                    font.family: fReg.name
                    font.pixelSize: 11
                }

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: win.showAtStartup = !win.showAtStartup
                }
            }
        }
    }

    Shortcut {
        sequence: "Escape"
        onActivated: win.finish(0)
    }
}
