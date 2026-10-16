// Colour cross-fade animation.
pragma ComponentBehavior: Bound

import QtQuick
import qs.ns
ColorAnimation { duration: Motion.colorDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.colorCurve }
