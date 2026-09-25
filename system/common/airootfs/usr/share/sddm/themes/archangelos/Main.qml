import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import "components"

Rectangle {
    id: root
    width: 1920
    height: 1080
    color: config.colorInk || "#0E0E0D"

    property string cText:   config.colorText   || "#ECEBE8"
    property string cDim:    config.colorDim     || "#9A9895"
    property string cFaint:  config.colorFaint   || "#5E5D5A"
    property string cLine:   config.colorLine    || "#E9E7E3"
    property string cAccent: config.colorAccent  || "#C24A52"
    property string cInk:    config.colorInk     || "#0E0E0D"

    FontLoader { id: fLight;   source: "assets/Quantico-Regular.ttf" }
    FontLoader { id: fBold;    source: "assets/Quantico-Bold.ttf" }
    FontLoader { id: fSamurai; source: "assets/ShipporiMincho-SemiBold.ttf" }
    FontLoader { id: fSamuraiL; source: "assets/ShipporiMincho-Regular.ttf" }

    VideoBackground {
        id: bg
        anchors.fill: parent
        source: Qt.resolvedUrl(config.background || "assets/background.mp4")
        fallbackSource: Qt.resolvedUrl(config.backgroundFallback || "assets/background.png")
        loopVideo: (config.loopBackground || "true") === "true"
        muted: (config.muteBackground || "true") === "true"
        opacity: 0
        Behavior on opacity { NumberAnimation { duration: 1400; easing.type: Easing.InOutQuad } }
        Component.onCompleted: opacity = 1
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0;  color: "#00000000" }
            GradientStop { position: 0.45; color: "#26000000" }
            GradientStop { position: 1.0;  color: "#99000000" }
        }
    }
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0;  color: "#40000000" }
            GradientStop { position: 0.3;  color: "#00000000" }
            GradientStop { position: 0.75; color: "#00000000" }
            GradientStop { position: 1.0;  color: "#59000000" }
        }
    }

    DustLogo {
        id: logo
        source: Qt.resolvedUrl(config.logo || "assets/logo.png")
        active: (config.logoDust || "true") === "true"
        width: 168
        height: width * 0.53
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.leftMargin: 56
        anchors.topMargin: 44
        opacity: 0
        Component.onCompleted: logoFade.start()
        NumberAnimation { id: logoFade; target: logo; property: "opacity"; from: 0; to: 1; duration: 1600; easing.type: Easing.InOutQuad }
    }

    Item {
        id: panel
        width: 360
        height: col.implicitHeight
        anchors.right: parent.right
        anchors.rightMargin: 150
        anchors.verticalCenter: parent.verticalCenter

        opacity: 0
        transform: Translate { id: rise; y: 18 }
        Component.onCompleted: {
            enter.start()
            userField.forceActive()
            if (userField.text.length > 0) passField.forceActive()
        }
        ParallelAnimation {
            id: enter
            NumberAnimation { target: panel; property: "opacity"; from: 0; to: 1; duration: 900; easing.type: Easing.OutCubic }
            NumberAnimation { target: rise; property: "y"; from: 18; to: 0; duration: 900; easing.type: Easing.OutCubic }
        }

        ColumnLayout {
            id: col
            width: parent.width
            spacing: 26

            Text {
                text: "Login"
                color: root.cText
                font.family: fSamurai.name
                font.pixelSize: 40
                font.letterSpacing: 2
            }

            LineField {
                id: userField
                Layout.fillWidth: true
                Layout.topMargin: 6
                label: "USER"
                textColor: root.cText; dim: root.cDim; faint: root.cFaint; line: root.cLine; accent: root.cAccent
                fontFamily: fLight.name
                text: userModel.lastUser
                onAccepted: passField.forceActive()
            }

            LineField {
                id: passField
                Layout.fillWidth: true
                label: "PASSWORD"
                echoMode: TextInput.Password
                textColor: root.cText; dim: root.cDim; faint: root.cFaint; line: root.cLine; accent: root.cAccent
                fontFamily: fLight.name
                onAccepted: doLogin()
            }

            Text {
                id: statusLine
                Layout.fillWidth: true
                text: ""
                color: root.cAccent
                font.family: fLight.name
                font.pixelSize: 12
                font.letterSpacing: 1
                opacity: 0
                wrapMode: Text.WordWrap
                Behavior on opacity { NumberAnimation { duration: 300 } }
            }

            Item {
                id: enterBtn
                Layout.fillWidth: true
                height: 82

                Image {
                    id: ink
                    anchors.centerIn: parent
                    width: parent.width * 1.04
                    height: parent.height
                    source: "assets/ink_button.png"
                    fillMode: Image.Stretch
                    smooth: true
                    opacity: enterMA.pressed ? 1.0 : (enterMA.containsMouse ? 0.9 : 0.72)
                    scale: enterMA.pressed ? 0.98 : (enterMA.containsMouse ? 1.035 : 1.0)
                    Behavior on opacity { NumberAnimation { duration: 420; easing.type: Easing.InOutQuad } }
                    Behavior on scale { NumberAnimation { duration: 440; easing.type: Easing.OutCubic } }
                }
                Text {
                    anchors.centerIn: parent
                    text: "LOGIN"
                    color: root.cText
                    font.family: fSamurai.name
                    font.pixelSize: 19
                    font.letterSpacing: 9
                    opacity: enterMA.containsMouse ? 1.0 : 0.9
                    Behavior on opacity { NumberAnimation { duration: 380 } }
                }
                MouseArea {
                    id: enterMA
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: doLogin()
                }
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 8
                spacing: 0

                ComboBox {
                    id: sessionBox
                    Layout.fillWidth: true
                    Layout.maximumWidth: 200
                    model: sessionModel
                    textRole: "name"
                    currentIndex: sessionModel.lastIndex
                    font.family: fLight.name
                    font.pixelSize: 12
                    visible: (config.showSessionMenu || "true") === "true"

                    contentItem: Row {
                        spacing: 8
                        Text {
                            text: sessionBox.displayText.toUpperCase()
                            color: sessionBox.popup.visible ? root.cText : root.cDim
                            font.family: fLight.name
                            font.pixelSize: 11
                            font.letterSpacing: 2
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 260 } }
                        }
                        Text {
                            text: "▾"
                            color: root.cFaint
                            font.pixelSize: 10
                            anchors.verticalCenter: parent.verticalCenter
                            rotation: sessionBox.popup.visible ? 180 : 0
                            Behavior on rotation { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
                        }
                    }
                    indicator: Item {}
                    background: Rectangle {
                        color: "transparent"
                        border.width: 0
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            width: parent.width
                            height: 1
                            color: sessionBox.popup.visible ? root.cLine : root.cFaint
                            opacity: 0.6
                            Behavior on color { ColorAnimation { duration: 260 } }
                        }
                    }

                    popup: Popup {
                        y: sessionBox.height + 6
                        width: sessionBox.width
                        implicitHeight: Math.min(contentItem.implicitHeight + 12, 260)
                        padding: 6
                        enter: Transition {
                            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 220; easing.type: Easing.OutCubic }
                            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 260; easing.type: Easing.OutCubic }
                        }
                        exit: Transition {
                            NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 160 }
                        }
                        background: Rectangle {
                            color: "#E60C0C0B"
                            border.color: root.cFaint
                            border.width: 1
                            radius: 2
                        }
                        contentItem: ListView {
                            clip: true
                            implicitHeight: contentHeight
                            model: sessionBox.popup.visible ? sessionBox.delegateModel : null
                            currentIndex: sessionBox.highlightedIndex
                            boundsBehavior: Flickable.StopAtBounds
                            ScrollIndicator.vertical: ScrollIndicator {}
                        }
                    }

                    delegate: ItemDelegate {
                        width: sessionBox.popup.width - 12
                        height: 34
                        highlighted: sessionBox.highlightedIndex === index
                        contentItem: Text {
                            text: (model.name || "").toUpperCase()
                            color: highlighted ? root.cText : root.cDim
                            font.family: fLight.name
                            font.pixelSize: 11
                            font.letterSpacing: 2
                            verticalAlignment: Text.AlignVCenter
                            elide: Text.ElideRight
                            Behavior on color { ColorAnimation { duration: 180 } }
                        }
                        background: Rectangle {
                            color: highlighted ? "#1AFFFFFF" : "transparent"
                            Rectangle {
                                anchors.left: parent.left
                                anchors.verticalCenter: parent.verticalCenter
                                width: 2
                                height: parent.height * 0.5
                                color: root.cAccent
                                opacity: highlighted ? 1 : 0
                                Behavior on opacity { NumberAnimation { duration: 180 } }
                            }
                        }
                    }
                }

                Item { Layout.fillWidth: true }

                RowLayout {
                    spacing: 22
                    visible: (config.showPowerButtons || "true") === "true"
                    PowerGlyph { glyph: "⏻"; dim: root.cDim; textColor: root.cText; fontFamily: fLight.name
                        enabled: sddm.canPowerOff === undefined ? true : sddm.canPowerOff; onTriggered: sddm.powerOff() }
                    PowerGlyph { glyph: "↻"; dim: root.cDim; textColor: root.cText; fontFamily: fLight.name
                        enabled: sddm.canReboot === undefined ? true : sddm.canReboot; onTriggered: sddm.reboot() }
                    PowerGlyph { glyph: "☾"; dim: root.cDim; textColor: root.cText; fontFamily: fLight.name
                        enabled: (sddm.canSuspend === undefined ? (typeof sddm.suspend === "function") : sddm.canSuspend)
                        onTriggered: { if (typeof sddm.suspend === "function") sddm.suspend() } }
                }
            }
        }
    }

    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 56
        anchors.bottomMargin: 54
        spacing: 4
        Text {
            id: clock
            color: root.cText
            font.family: fSamurai.name
            font.pixelSize: 66
            font.letterSpacing: 2
            text: Qt.formatTime(new Date(), "HH:mm")
            opacity: 0.96
        }
        Text {
            color: root.cDim
            font.family: fSamuraiL.name
            font.pixelSize: 17
            font.letterSpacing: 3
            text: Qt.formatDate(new Date(), "dddd  ·  dd MMMM yyyy")
        }
    }

    Timer {
        interval: 1000; running: true; repeat: true
        onTriggered: clock.text = Qt.formatTime(new Date(), "HH:mm")
    }

    function doLogin() {
        statusLine.opacity = 0
        sddm.login(userField.text, passField.text, sessionBox.currentIndex)
    }

    Connections {
        target: sddm
        function onLoginSucceeded() {
            statusLine.color = root.cDim
            statusLine.text = "welcome"
            statusLine.opacity = 1
        }
        function onLoginFailed() {
            statusLine.color = root.cAccent
            statusLine.text = "incorrect credentials"
            statusLine.opacity = 1
            passField.text = ""
            passField.forceActive()
        }
    }
}
