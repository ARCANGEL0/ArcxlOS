// Spatial motion: springy overshoot curve for movement/size/position.
pragma ComponentBehavior: Bound

import QtQuick
import qs.arc
NumberAnimation { duration: Motion.spatialDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.spatialCurve }
