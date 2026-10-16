import QtQuick

// A vertical selection highlight that moves like a drop of liquid: the
// leading edge races to the new spot and the trailing edge catches up, so
// it stretches between items before settling. Set targetY/targetHeight.
Item {
    id: liquid

    property real targetY: 0
    property real targetHeight: 0
    property int fast: 200 * Theme.motion
    property int slow: 480 * Theme.motion

    property real head: targetY
    property real tail: targetY + targetHeight

    // Direction is judged against where the edges are right now, so the
    // durations are correct at the moment each Behavior starts.
    readonly property bool movingDown: targetY > head

    Behavior on head { NumberAnimation { duration: liquid.movingDown ? liquid.slow : liquid.fast; easing.type: Easing.OutCubic } }
    Behavior on tail { NumberAnimation { duration: liquid.movingDown ? liquid.fast : liquid.slow; easing.type: Easing.OutCubic } }

    y: head
    height: Math.max(0, tail - head)
}
