// Displays: one row per output, and a detail page that edits it.
//
// The detail page stages changes and applies them together: a mode switch blanks the screen, so
// applying per change would make picking a resolution a strobe show, and a wrong scale taking
// effect on highlight would be hard to undo.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.arc
import qs.arc.services
import qs.arc.components
import qs.arc.modules.settings.common
StackView {
    id: stack
    clip: true
    initialItem: mainPage

    // Poll only while this page is alive.
    Component.onCompleted: Display.active = true
    Component.onDestruction: Display.active = false

    Component {
        id: mainPage
        PageBase {
            title: "Displays"

            SectionHeader { first: true; text: "Outputs" }
            ItemList {
                id: outputs
                model: Display.monitors
                placeholderIcon: "monitor"
                placeholderText: "No outputs reported"
                delegate: Item {
                    id: mon
                    required property var modelData
                    required property int index
                    width: ListView.view.width
                    implicitHeight: 62
                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: 16; anchors.rightMargin: 12
                        spacing: 12
                        MatIcon {
                            text: mon.modelData.disabled ? "desktop_access_disabled" : "monitor"
                            color: mon.modelData.disabled ? Config.dim : Config.fg
                            font.pixelSize: 22
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 1
                            RowLayout {
                                spacing: 6
                                Text {
                                    text: mon.modelData.name
                                    color: Config.fg; font.family: Config.textFont
                                    font.pixelSize: 13; font.bold: true
                                }
                                Rectangle {
                                    visible: mon.modelData.focused
                                    implicitHeight: 16; radius: 8
                                    implicitWidth: focusLabel.implicitWidth + 12
                                    color: Config.accentContainer
                                    Text {
                                        id: focusLabel
                                        anchors.centerIn: parent
                                        text: "Focused"; color: Config.accent
                                        font.family: Config.textFont; font.pixelSize: 9; font.bold: true
                                    }
                                }
                            }
                            Text {
                                text: mon.modelData.disabled
                                      ? "Disabled"
                                      : Display.modeText(mon.modelData)
                                        + " · scale " + Display.trim(mon.modelData.scale, 2)
                                        + " · at " + Math.round(mon.modelData.x) + ", " + Math.round(mon.modelData.y)
                                color: Config.dim; font.family: Config.textFont; font.pixelSize: 11
                                Layout.fillWidth: true; elide: Text.ElideRight
                            }
                        }
                        MatIcon { text: "chevron_right"; color: Config.dim; font.pixelSize: 20 }
                    }
                    StateLayer {
                        ovTopRadius: outputs.rowTop(mon.index)
                        ovBottomRadius: outputs.rowBottom(mon.index)
                        onTapped: stack.push(detailPage, { name: mon.modelData.name })
                    }
                }
            }

            SectionHeader { text: "Brightness" }
            SliderRow {
                first: true; last: true
                visible: Brightness.available
                icon: "brightness_medium"
                label: "External monitor (DDC/CI)"
                value: Brightness.brightness / 100
                onMoved: v => Brightness.set(v * 100)
            }
            InfoRow {
                first: true; last: true
                visible: !Brightness.available
                icon: "brightness_medium"; label: "Brightness"
                value: "No DDC/CI monitor detected"
            }
        }
    }

    Component {
        id: detailPage
        PageBase {
            id: detail
            property string name: ""
            readonly property var m: Display.byName(detail.name)

            // --- Staged edits; null means "unchanged". ---
            property string pendingRes: ""
            property real pendingRate: 0
            property real pendingScale: 0
            property int pendingTransform: -1
            property int pendingVrr: -1
            property string pendingMirror: ""     // sentinel: no pending change
            property int pendingX: -100000
            property int pendingY: -100000

            readonly property string resKey: detail.pendingRes || (detail.m ? detail.m.width + "x" + detail.m.height : "")
            readonly property real rate: detail.pendingRate || (detail.m?.refreshRate ?? 0)
            readonly property real scaleVal: detail.pendingScale || (detail.m?.scale ?? 1)
            readonly property int transformVal: detail.pendingTransform >= 0 ? detail.pendingTransform : (detail.m?.transform ?? 0)
            readonly property bool vrrVal: detail.pendingVrr >= 0 ? detail.pendingVrr === 1 : (detail.m?.vrr ?? false)
            readonly property string mirrorVal: detail.pendingMirror !== "" ? detail.pendingMirror : (detail.m?.mirrorOf ?? "none")
            readonly property int posX: detail.pendingX !== -100000 ? detail.pendingX : Math.round(detail.m?.x ?? 0)
            readonly property int posY: detail.pendingY !== -100000 ? detail.pendingY : Math.round(detail.m?.y ?? 0)

            readonly property bool dirty: detail.pendingRes !== "" || detail.pendingRate !== 0
                                          || detail.pendingScale !== 0 || detail.pendingTransform >= 0
                                          || detail.pendingVrr >= 0 || detail.pendingMirror !== ""
                                          || detail.pendingX !== -100000 || detail.pendingY !== -100000

            function reset() {
                detail.pendingRes = ""; detail.pendingRate = 0; detail.pendingScale = 0;
                detail.pendingTransform = -1; detail.pendingVrr = -1; detail.pendingMirror = "";
                detail.pendingX = -100000; detail.pendingY = -100000;
            }
            function applyAll() {
                if (!detail.m) return;
                const parts = detail.resKey.split("x");
                Display.apply(detail.name, {
                    width: parseInt(parts[0]), height: parseInt(parts[1]),
                    refreshRate: detail.rate, scale: detail.scaleVal,
                    x: detail.posX, y: detail.posY,
                    transform: detail.transformVal, vrr: detail.vrrVal,
                    mirrorOf: detail.mirrorVal
                });
                detail.reset();
            }

            title: detail.name
            isSubPage: true
            onBack: stack.pop()

            SectionHeader { first: true; text: "Hardware" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                InfoRow { first: true;  last: false; icon: "label"; label: "Model"
                          value: (detail.m?.make ?? "") + " " + (detail.m?.model ?? "") }
                InfoRow { first: false; last: false; icon: "tag"; label: "Serial"; value: detail.m?.serial || "-" }
                InfoRow { first: false; last: true;  icon: "palette"; label: "Colour"
                          value: (detail.m?.currentFormat ?? "-") + " · " + (detail.m?.colorManagementPreset ?? "-") }
            }

            SectionHeader { text: "Mode" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                SelectRow {
                    first: true; last: false
                    label: "Resolution"
                    options: Display.resolutions(detail.m).map(r => ({ value: r.key, label: r.w + " × " + r.h }))
                    value: detail.resKey
                    onSelected: v => {
                        detail.pendingRes = v;
                        // The old rate may not exist at the new size; fall back to the fastest.
                        const rs = Display.rates(detail.m, v);
                        if (rs.indexOf(detail.rate) < 0) detail.pendingRate = rs[0] ?? detail.rate;
                    }
                }
                SelectRow {
                    first: false; last: false
                    label: "Refresh rate"
                    options: Display.rates(detail.m, detail.resKey).map(hz => ({ value: hz, label: Display.trim(hz, 2) + " Hz" }))
                    value: detail.rate
                    onSelected: v => detail.pendingRate = v
                }
                SelectRow {
                    first: false; last: false
                    label: "Scale"
                    subtext: "Fractional scales can force a slower rendering path"
                    options: [
                        { value: 1.0, label: "100%" },
                        { value: 1.25, label: "125%" },
                        { value: 1.5, label: "150%" },
                        { value: 1.75, label: "175%" },
                        { value: 2.0, label: "200%" }
                    ]
                    value: Math.round(detail.scaleVal * 100) / 100
                    onSelected: v => detail.pendingScale = v
                }
                SelectRow {
                    first: false; last: true
                    label: "Orientation"
                    options: [
                        { value: 0, label: "Landscape" },
                        { value: 1, label: "Portrait", subtext: "90° right" },
                        { value: 2, label: "Landscape flipped", subtext: "180°" },
                        { value: 3, label: "Portrait", subtext: "90° left" }
                    ]
                    value: detail.transformVal
                    onSelected: v => detail.pendingTransform = v
                }
            }

            SectionHeader { text: "Position" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                StepperRow {
                    first: true; last: false
                    label: "X"; value: detail.posX
                    from: -20000; to: 20000; step: 160
                    valueText: detail.posX + " px"
                    onChanged: v => detail.pendingX = v
                }
                StepperRow {
                    first: false; last: Display.monitors.length < 2
                    label: "Y"; value: detail.posY
                    from: -20000; to: 20000; step: 160
                    valueText: detail.posY + " px"
                    onChanged: v => detail.pendingY = v
                }
                // Relative placement, so a second monitor does not have to be positioned by hand.
                Repeater {
                    model: Display.monitors.filter(o => o.name !== detail.name && !o.disabled)
                    delegate: ButtonRow {
                        id: rel
                        required property var modelData
                        required property int index
                        first: false
                        last: rel.index === Display.monitors.filter(o => o.name !== detail.name && !o.disabled).length - 1
                        icon: "align_horizontal_right"
                        label: "Place to the right of " + rel.modelData.name
                        subtext: "Aligns the top edges"
                        onClicked: {
                            detail.pendingX = Math.round(rel.modelData.x + rel.modelData.width / rel.modelData.scale);
                            detail.pendingY = Math.round(rel.modelData.y);
                        }
                    }
                }
            }

            SectionHeader { text: "Options" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                ToggleRow {
                    first: true; last: false
                    text: "Variable refresh rate"
                    subtext: "FreeSync / G-Sync"
                    checked: detail.vrrVal
                    onToggled: detail.pendingVrr = detail.vrrVal ? 0 : 1
                }
                SelectRow {
                    first: false; last: false
                    visible: Display.monitors.length > 1
                    label: "Mirror"
                    options: [{ value: "none", label: "Off" }].concat(
                        Display.monitors.filter(o => o.name !== detail.name).map(o => ({ value: o.name, label: o.name })))
                    value: detail.mirrorVal
                    onSelected: v => detail.pendingMirror = v
                }
                ToggleRow {
                    first: false; last: false
                    text: "Enabled"
                    subtext: Display.monitors.filter(o => !o.disabled).length <= 1 && !(detail.m?.disabled ?? false)
                             ? "The only active output cannot be turned off" : ""
                    checked: !(detail.m?.disabled ?? false)
                    onToggled: {
                        const activeCount = Display.monitors.filter(o => !o.disabled).length;
                        if (!(detail.m?.disabled ?? false) && activeCount <= 1) return;
                        Display.setDisabled(detail.name, !(detail.m?.disabled ?? false));
                    }
                }
                // A toggle, not a one-way button: this was "Turn this display off" with no way
                // back through the UI, on the assumption that input wakes a blanked output. It
                // reads the real state (`dpmsStatus` off `hyprctl monitors`) and can restore it,
                // so the assumption no longer has to hold.
                ToggleRow {
                    first: false; last: true
                    text: "Display on"
                    subtext: (detail.m?.dpmsStatus ?? true) ? "Turn off to blank this output"
                                                            : "Blanked - turn on to restore it"
                    checked: detail.m?.dpmsStatus ?? true
                    onToggled: Display.setDpms(detail.name, !(detail.m?.dpmsStatus ?? true))
                }
            }

            SectionHeader { visible: detail.dirty; text: "Pending changes" }
            ColumnLayout {
                Layout.fillWidth: true
                visible: detail.dirty
                spacing: 3
                ButtonRow {
                    first: true; last: false
                    icon: "check"; label: "Apply"
                    subtext: detail.resKey.replace("x", " × ") + " @ " + Display.trim(detail.rate, 2)
                             + " Hz · scale " + Display.trim(detail.scaleVal, 2)
                    onClicked: detail.applyAll()
                }
                ButtonRow {
                    first: false; last: true
                    icon: "undo"; label: "Discard"; destructive: true
                    onClicked: detail.reset()
                }
            }
        }
    }
}
