// Fast spatial motion: stronger overshoot, shorter.
pragma ComponentBehavior: Bound

import QtQuick
import qs.arc
NumberAnimation { duration: Motion.spatialFastDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialFastCurve }
