// Effect motion: non-overshoot curve for opacity/fades.
pragma ComponentBehavior: Bound

import QtQuick
import qs.arc
NumberAnimation { duration: Motion.effectDur; easing.type: Easing.BezierSpline; easing.bezierCurve: Motion.effectCurve }
