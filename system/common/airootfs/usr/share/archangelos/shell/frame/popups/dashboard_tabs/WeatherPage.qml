import QtQuick
import Quickshell
import Quickshell.Io
import "../../"
import "../../components"
import qs.arc.components as ArcC
import qs.arc.services as ArcS

Item {
    id: root

    property real localScale: 1.0

    readonly property real u: localScale
    readonly property real gap: Math.round(8 * u)
    readonly property string mono: "JetBrains Mono"

    property bool activated: false
    property bool loading: false
    property string error: ""
    property var data: null
    property var air: null
    property string place: ""
    property real lat: NaN
    property real lon: NaN
    property string geocodedFor: ""
    property date updatedAt: new Date(0)
    property var now: new Date()

    readonly property string city: ArcS.Weather.city || "London"
    readonly property bool ready: data !== null
    readonly property var current: ready ? data.current : ({})
    readonly property var daily: ready ? data.daily : ({})
    readonly property var hourly: ready ? data.hourly : ({})

    onVisibleChanged: if (visible) activated = true
    Component.onCompleted: if (visible) activated = true
    onActivatedChanged: if (activated) refresh()
    onCityChanged: if (activated) refresh()

    Timer {
        interval: 15 * 60 * 1000
        running: root.activated
        repeat: true
        onTriggered: root.refresh()
    }

    Timer {
        interval: 60 * 1000
        running: root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.now = new Date()
    }

    function refresh() {
        if (fetchProc.running) return
        root.loading = true
        root.error = ""
        const known = root.geocodedFor === root.city && !isNaN(root.lat)
        fetchProc.command = ["sh", "-c", fetchProc.script, "sh", root.city,
                             known ? String(root.lat) : "", known ? String(root.lon) : "", known ? root.place : ""]
        fetchProc.running = true
    }

    Process {
        id: fetchProc
        readonly property string script: "set -e\n"
            + "city=\"$1\"; lat=\"$2\"; lon=\"$3\"; name=\"$4\"\n"
            + "if [ -z \"$lat\" ]; then\n"
            + "  q=$(printf %s \"$city\" | jq -sRr @uri)\n"
            + "  g=$(curl -fsS --max-time 10 \"https://geocoding-api.open-meteo.com/v1/search?count=1&name=$q\")\n"
            + "  lat=$(printf %s \"$g\" | jq -r '.results[0].latitude // empty')\n"
            + "  lon=$(printf %s \"$g\" | jq -r '.results[0].longitude // empty')\n"
            + "  name=$(printf %s \"$g\" | jq -r '[.results[0].name, .results[0].country_code] | map(select(. != null)) | join(\", \")')\n"
            + "  [ -n \"$lat\" ] || { echo '{\"error\":\"City not found\"}'; exit 0; }\n"
            + "fi\n"
            + "fc=$(curl -fsS --max-time 12 \"https://api.open-meteo.com/v1/forecast?latitude=$lat&longitude=$lon"
            + "&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,wind_direction_10m,weather_code,is_day,uv_index,pressure_msl"
            + "&hourly=temperature_2m,precipitation_probability,weather_code,is_day"
            + "&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,uv_index_max,precipitation_probability_max"
            + "&timezone=auto&forecast_days=7&forecast_hours=24\")\n"
            + "aq=$(curl -fsS --max-time 10 \"https://air-quality-api.open-meteo.com/v1/air-quality?latitude=$lat&longitude=$lon&current=european_aqi,pm2_5,pm10\" || echo '{}')\n"
            + "jq -cn --argjson fc \"$fc\" --argjson aq \"$aq\" --arg lat \"$lat\" --arg lon \"$lon\" --arg name \"$name\" "
            + "'{fc: $fc, aq: $aq, lat: $lat, lon: $lon, name: $name}'\n"
        stdout: StdioCollector { id: fetchOut }
        onExited: function(code) {
            root.loading = false
            const text = fetchOut.text.trim()
            if (code !== 0 || text === "") {
                root.error = "Couldn't reach the weather service"
                return
            }
            try {
                const res = JSON.parse(text)
                if (res.error) { root.error = res.error; return }
                if (!res.fc || !res.fc.daily || !res.fc.hourly) { root.error = (res.fc && res.fc.reason) || "Forecast unavailable"; return }
                root.lat = parseFloat(res.lat)
                root.lon = parseFloat(res.lon)
                root.place = res.name || root.city
                root.geocodedFor = root.city
                root.air = res.aq && res.aq.current ? res.aq.current : null
                root.data = res.fc
                root.updatedAt = new Date()
            } catch (e) {
                root.error = "Unexpected response from the weather service"
            }
        }
    }

    function codeInfo(code, day) {
        const d = day !== false
        if (code === 0) return { icon: d ? "clear_day" : "clear_night", text: "Clear sky" }
        if (code === 1) return { icon: d ? "partly_cloudy_day" : "partly_cloudy_night", text: "Mainly clear" }
        if (code === 2) return { icon: d ? "partly_cloudy_day" : "partly_cloudy_night", text: "Partly cloudy" }
        if (code === 3) return { icon: "cloud", text: "Overcast" }
        if (code === 45 || code === 48) return { icon: "foggy", text: "Fog" }
        if (code >= 51 && code <= 57) return { icon: "rainy", text: "Drizzle" }
        if (code >= 61 && code <= 67) return { icon: "rainy", text: code >= 65 ? "Heavy rain" : "Rain" }
        if (code >= 71 && code <= 77) return { icon: "weather_snowy", text: "Snow" }
        if (code >= 80 && code <= 82) return { icon: "rainy", text: "Rain showers" }
        if (code === 85 || code === 86) return { icon: "weather_snowy", text: "Snow showers" }
        if (code >= 95) return { icon: "thunderstorm", text: "Thunderstorm" }
        return { icon: "cloud", text: "—" }
    }

    function uvLabel(v) {
        if (v < 3) return "Low"
        if (v < 6) return "Moderate"
        if (v < 8) return "High"
        if (v < 11) return "Very high"
        return "Extreme"
    }

    function aqiInfo(v) {
        if (v <= 20) return { text: "Good", color: "#7ad6a0" }
        if (v <= 40) return { text: "Fair", color: "#b5d67a" }
        if (v <= 60) return { text: "Moderate", color: "#f5c47a" }
        if (v <= 80) return { text: "Poor", color: "#fab387" }
        if (v <= 100) return { text: "Very poor", color: "#f38ba8" }
        return { text: "Extremely poor", color: "#c55a7a" }
    }

    function compass(deg) {
        const dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        return dirs[Math.round(((deg % 360) + 360) % 360 / 45) % 8]
    }

    function moon(date) {
        const synodic = 29.530588853
        const ref = Date.UTC(2000, 0, 6, 18, 14)
        const age = ((date.getTime() - ref) / 86400000 % synodic + synodic) % synodic
        const f = age / synodic
        const names = ["New moon", "Waxing crescent", "First quarter", "Waxing gibbous",
                       "Full moon", "Waning gibbous", "Last quarter", "Waning crescent"]
        const icons = ["brightness_1", "brightness_3", "brightness_2", "brightness_5",
                       "circle", "brightness_5", "brightness_2", "brightness_3"]
        const i = Math.floor(f * 8 + 0.5) % 8
        return { name: names[i], icon: icons[i], illum: Math.round((1 - Math.cos(2 * Math.PI * f)) / 2 * 100) }
    }

    function hourText(iso) {
        return Qt.formatDateTime(new Date(iso), PrefsService.use24HourTime ? "HH:mm" : "h ap")
    }

    readonly property var info: codeInfo(current.weather_code, current.is_day === 1)
    readonly property var moonInfo: moon(now)
    readonly property real dayProgress: {
        if (!ready || !daily.sunrise) return 0
        const rise = new Date(daily.sunrise[0]).getTime()
        const set = new Date(daily.sunset[0]).getTime()
        return Math.max(0, Math.min(1, (now.getTime() - rise) / Math.max(1, set - rise)))
    }
    readonly property real weekMin: ready ? Math.min.apply(null, daily.temperature_2m_min) : 0
    readonly property real weekMax: ready ? Math.max.apply(null, daily.temperature_2m_max) : 1

    component Card: Rectangle {
        radius: Math.round(Theme.cornerRadius * root.u)
        color: Theme.card
        border.color: Theme.border
        border.width: 1
    }

    component Caption: Text {
        color: Theme.subtext
        font.pixelSize: Math.round(10 * root.u)
        font.bold: true
        font.letterSpacing: 1.2
    }

    component Tile: Card {
        id: tile
        property string icon: ""
        property string label: ""
        property string value: ""
        property string sub: ""
        property color accent: Theme.active
        default property alias extra: extraSlot.data

        ArcC.MatIcon {
            id: tileIcon
            anchors { left: parent.left; top: parent.top; leftMargin: Math.round(12 * root.u); topMargin: Math.round(11 * root.u) }
            text: tile.icon
            font.pixelSize: Math.round(15 * root.u)
            color: tile.accent
        }
        Caption {
            anchors { left: tileIcon.right; leftMargin: Math.round(6 * root.u); verticalCenter: tileIcon.verticalCenter }
            text: tile.label
        }
        Text {
            id: tileValue
            anchors { left: parent.left; leftMargin: Math.round(12 * root.u); top: tileIcon.bottom; topMargin: Math.round(8 * root.u) }
            text: tile.value
            color: Theme.text
            font.family: root.mono
            font.pixelSize: Math.round(19 * root.u)
            font.bold: true
        }
        Text {
            anchors { left: parent.left; leftMargin: Math.round(12 * root.u); top: tileValue.bottom; topMargin: Math.round(2 * root.u) }
            text: tile.sub
            color: Theme.subtext
            font.pixelSize: Math.round(11 * root.u)
            elide: Text.ElideRight
            width: tile.width - Math.round(24 * root.u)
        }
        Item {
            id: extraSlot
            anchors { right: parent.right; top: parent.top; margins: Math.round(10 * root.u) }
            width: Math.round(34 * root.u)
            height: width
        }
    }

    Item {
        id: content
        anchors { fill: parent; topMargin: root.gap; bottomMargin: root.gap }
        opacity: root.ready ? 1 : 0
        visible: opacity > 0
        Behavior on opacity { NumberAnimation { duration: 320; easing.type: Easing.OutCubic } }

        Item {
            id: leftCol
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: Math.round(290 * root.u)

            Card {
                id: hero
                anchors { left: parent.left; right: parent.right; top: parent.top }
                height: Math.round(176 * root.u)

                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.16) }
                        GradientStop { position: 1.0; color: "transparent" }
                    }
                }

                Column {
                    anchors { left: parent.left; top: parent.top; leftMargin: Math.round(16 * root.u); topMargin: Math.round(14 * root.u) }
                    spacing: Math.round(2 * root.u)

                    Row {
                        spacing: Math.round(5 * root.u)
                        ArcC.MatIcon {
                            text: "location_on"
                            font.pixelSize: Math.round(13 * root.u)
                            color: Theme.active
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: root.place
                            color: Theme.text
                            font.pixelSize: Math.round(13 * root.u)
                            font.bold: true
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }

                    Text {
                        property real shown: root.ready ? current.temperature_2m : 0
                        Behavior on shown { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }
                        text: Math.round(shown) + "°"
                        color: Theme.text
                        font.family: root.mono
                        font.pixelSize: Math.round(54 * root.u)
                        font.bold: true
                    }

                    Text {
                        text: root.info.text
                        color: Theme.active
                        font.pixelSize: Math.round(14 * root.u)
                        font.bold: true
                    }

                    Text {
                        text: root.ready
                            ? "Feels " + Math.round(current.apparent_temperature) + "°  ·  H " + Math.round(daily.temperature_2m_max[0]) + "°  L " + Math.round(daily.temperature_2m_min[0]) + "°"
                            : ""
                        color: Theme.subtext
                        font.family: root.mono
                        font.pixelSize: Math.round(11 * root.u)
                    }
                }

                ArcC.MatIcon {
                    anchors { right: parent.right; rightMargin: Math.round(18 * root.u); verticalCenter: parent.verticalCenter; verticalCenterOffset: -Math.round(6 * root.u) }
                    text: root.info.icon
                    font.pixelSize: Math.round(76 * root.u)
                    color: Theme.active
                    opacity: 0.9
                }

                Text {
                    anchors { right: refreshBtn.left; rightMargin: Math.round(6 * root.u); verticalCenter: refreshBtn.verticalCenter }
                    text: "Updated " + Qt.formatDateTime(root.updatedAt, PrefsService.use24HourTime ? "HH:mm" : "h:mm ap")
                    color: Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.7)
                    font.pixelSize: Math.round(10 * root.u)
                }

                Rectangle {
                    id: refreshBtn
                    anchors { right: parent.right; bottom: parent.bottom; margins: Math.round(10 * root.u) }
                    width: Math.round(24 * root.u)
                    height: width
                    radius: width / 2
                    color: refreshHov.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.18) : "transparent"
                    Behavior on color { ColorAnimation { duration: 150 } }
                    ArcC.MatIcon {
                        id: refreshIcon
                        anchors.centerIn: parent
                        text: "refresh"
                        font.pixelSize: Math.round(15 * root.u)
                        color: refreshHov.hovered ? Theme.active : Theme.subtext
                        RotationAnimator on rotation {
                            from: 0; to: 360; duration: 900
                            loops: Animation.Infinite
                            running: root.loading
                        }
                    }
                    HoverHandler { id: refreshHov; cursorShape: Qt.PointingHandCursor }
                    TapHandler { onTapped: root.refresh() }
                    Tip { text: root.loading ? "Refreshing…" : "Refresh"; localScale: root.u }
                }
            }

            Card {
                anchors { left: parent.left; right: parent.right; top: hero.bottom; topMargin: root.gap; bottom: parent.bottom }

                Caption {
                    id: weekCap
                    anchors { left: parent.left; top: parent.top; leftMargin: Math.round(14 * root.u); topMargin: Math.round(11 * root.u) }
                    text: "7-DAY FORECAST"
                }

                Column {
                    anchors { left: parent.left; right: parent.right; top: weekCap.bottom; bottom: parent.bottom
                              leftMargin: Math.round(14 * root.u); rightMargin: Math.round(14 * root.u); topMargin: Math.round(4 * root.u) }

                    Repeater {
                        model: root.ready ? daily.time.length : 0
                        delegate: Item {
                            required property int index
                            width: parent.width
                            height: Math.round(32 * root.u)
                            readonly property real lo: daily.temperature_2m_min[index]
                            readonly property real hi: daily.temperature_2m_max[index]
                            readonly property real span: Math.max(1, root.weekMax - root.weekMin)

                            Text {
                                id: dayName
                                anchors.verticalCenter: parent.verticalCenter
                                width: Math.round(40 * root.u)
                                text: index === 0 ? "Today" : Qt.formatDate(new Date(daily.time[index] + "T12:00"), "ddd")
                                color: index === 0 ? Theme.text : Theme.subtext
                                font.pixelSize: Math.round(12 * root.u)
                                font.bold: index === 0
                            }
                            ArcC.MatIcon {
                                id: dayIcon
                                anchors { left: dayName.right; verticalCenter: parent.verticalCenter }
                                text: root.codeInfo(daily.weather_code[index], true).icon
                                font.pixelSize: Math.round(16 * root.u)
                                color: Theme.active
                            }
                            Text {
                                id: dayRain
                                anchors { left: dayIcon.right; leftMargin: Math.round(4 * root.u); verticalCenter: parent.verticalCenter }
                                width: Math.round(30 * root.u)
                                text: (daily.precipitation_probability_max[index] ?? 0) > 0 ? daily.precipitation_probability_max[index] + "%" : ""
                                color: "#89b4fa"
                                font.family: root.mono
                                font.pixelSize: Math.round(9 * root.u)
                            }
                            Text {
                                id: dayLo
                                anchors { left: dayRain.right; verticalCenter: parent.verticalCenter }
                                width: Math.round(28 * root.u)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(lo) + "°"
                                color: Theme.subtext
                                font.family: root.mono
                                font.pixelSize: Math.round(11 * root.u)
                            }
                            Item {
                                id: track
                                anchors { left: dayLo.right; right: dayHi.left; leftMargin: Math.round(8 * root.u); rightMargin: Math.round(8 * root.u); verticalCenter: parent.verticalCenter }
                                height: Math.round(4 * root.u)
                                Rectangle {
                                    anchors.fill: parent
                                    radius: height / 2
                                    color: Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.08)
                                }
                                Rectangle {
                                    x: (lo - root.weekMin) / span * track.width
                                    width: Math.max(height, (hi - lo) / span * track.width)
                                    height: parent.height
                                    radius: height / 2
                                    gradient: Gradient {
                                        orientation: Gradient.Horizontal
                                        GradientStop { position: 0.0; color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.45) }
                                        GradientStop { position: 1.0; color: Theme.active }
                                    }
                                }
                            }
                            Text {
                                id: dayHi
                                anchors { right: parent.right; verticalCenter: parent.verticalCenter }
                                width: Math.round(28 * root.u)
                                horizontalAlignment: Text.AlignRight
                                text: Math.round(hi) + "°"
                                color: Theme.text
                                font.family: root.mono
                                font.pixelSize: Math.round(11 * root.u)
                                font.bold: true
                            }
                        }
                    }
                }
            }
        }

        Item {
            id: rightCol
            anchors { left: leftCol.right; leftMargin: root.gap; right: parent.right; top: parent.top; bottom: parent.bottom }

            Grid {
                id: tiles
                anchors { left: parent.left; right: parent.right; top: parent.top }
                columns: 4
                spacing: root.gap
                readonly property real tileW: (width - spacing * 3) / 4
                readonly property real tileH: Math.round(96 * root.u)

                Tile {
                    width: tiles.tileW; height: tiles.tileH
                    icon: "air"; label: "WIND"
                    value: root.ready ? Math.round(current.wind_speed_10m) + " km/h" : ""
                    sub: root.ready ? "From " + root.compass(current.wind_direction_10m) : ""
                    ArcC.MatIcon {
                        anchors.centerIn: parent
                        text: "navigation"
                        font.pixelSize: Math.round(20 * root.u)
                        color: Theme.active
                        rotation: root.ready ? current.wind_direction_10m + 180 : 0
                        Behavior on rotation { NumberAnimation { duration: 700; easing.type: Easing.OutBack } }
                    }
                }
                Tile {
                    width: tiles.tileW; height: tiles.tileH
                    icon: "humidity_percentage"; label: "HUMIDITY"
                    value: root.ready ? current.relative_humidity_2m + "%" : ""
                    sub: !root.ready ? "" : current.relative_humidity_2m > 70 ? "Humid" : current.relative_humidity_2m < 30 ? "Dry" : "Comfortable"
                }
                Tile {
                    width: tiles.tileW; height: tiles.tileH
                    icon: "wb_sunny"; label: "UV INDEX"
                    value: root.ready ? Math.round(current.uv_index) : ""
                    sub: root.ready ? root.uvLabel(current.uv_index) + " · max " + Math.round(daily.uv_index_max[0]) : ""
                }
                Tile {
                    width: tiles.tileW; height: tiles.tileH
                    icon: "compress"; label: "PRESSURE"
                    value: root.ready ? Math.round(current.pressure_msl) : ""
                    sub: "hPa"
                }
                Tile {
                    width: tiles.tileW; height: tiles.tileH
                    readonly property var aq: root.air ? root.aqiInfo(root.air.european_aqi) : null
                    icon: "eco"; label: "AIR QUALITY"
                    accent: aq ? aq.color : Theme.active
                    value: root.air ? Math.round(root.air.european_aqi) : "—"
                    sub: aq ? aq.text + " · PM2.5 " + Math.round(root.air.pm2_5) : "Unavailable"
                }
                Tile {
                    width: tiles.tileW; height: tiles.tileH
                    icon: "water_drop"; label: "RAIN"
                    value: root.ready ? (daily.precipitation_probability_max[0] ?? 0) + "%" : ""
                    sub: "Chance today"
                }
                Tile {
                    id: sunTile
                    width: tiles.tileW; height: tiles.tileH
                    icon: "wb_twilight"; label: "SUN"
                    value: root.ready ? root.hourText(daily.sunrise[0]) : ""
                    sub: root.ready ? "Sets " + root.hourText(daily.sunset[0]) : ""
                    Canvas {
                        id: sunArc
                        anchors.fill: parent
                        readonly property real p: root.dayProgress
                        onPChanged: requestPaint()
                        onPaint: {
                            const ctx = getContext("2d")
                            ctx.reset()
                            const r = width / 2 - 2
                            ctx.lineWidth = 2
                            ctx.lineCap = "round"
                            ctx.strokeStyle = Qt.rgba(Theme.text.r, Theme.text.g, Theme.text.b, 0.15)
                            ctx.beginPath()
                            ctx.arc(width / 2, height - 4, r, Math.PI, 2 * Math.PI)
                            ctx.stroke()
                            ctx.strokeStyle = Theme.active
                            ctx.beginPath()
                            ctx.arc(width / 2, height - 4, r, Math.PI, Math.PI + Math.PI * p)
                            ctx.stroke()
                            const a = Math.PI + Math.PI * p
                            ctx.fillStyle = Theme.active
                            ctx.beginPath()
                            ctx.arc(width / 2 + r * Math.cos(a), height - 4 + r * Math.sin(a), 3, 0, 2 * Math.PI)
                            ctx.fill()
                        }
                    }
                }
                Tile {
                    width: tiles.tileW; height: tiles.tileH
                    icon: "dark_mode"; label: "MOON"
                    value: root.moonInfo.illum + "%"
                    sub: root.moonInfo.name
                }
            }

            Card {
                anchors { left: parent.left; right: parent.right; top: tiles.bottom; topMargin: root.gap; bottom: parent.bottom }

                Caption {
                    id: hourCap
                    anchors { left: parent.left; top: parent.top; leftMargin: Math.round(14 * root.u); topMargin: Math.round(11 * root.u) }
                    text: "NEXT 24 HOURS"
                }

                ListView {
                    id: hours
                    anchors { left: parent.left; right: parent.right; top: hourCap.bottom; bottom: parent.bottom
                              leftMargin: Math.round(8 * root.u); rightMargin: Math.round(8 * root.u)
                              topMargin: Math.round(6 * root.u); bottomMargin: Math.round(8 * root.u) }
                    orientation: ListView.Horizontal
                    clip: true
                    spacing: Math.round(2 * root.u)
                    boundsBehavior: Flickable.StopAtBounds
                    model: root.ready ? hourly.time.length : 0
                    readonly property real tMin: root.ready ? Math.min.apply(null, hourly.temperature_2m) : 0
                    readonly property real tMax: root.ready ? Math.max.apply(null, hourly.temperature_2m) : 1

                    WheelHandler {
                        onWheel: function(event) {
                            hours.contentX = Math.max(0, Math.min(hours.contentWidth - hours.width,
                                hours.contentX - (event.angleDelta.y || event.angleDelta.x)))
                        }
                    }

                    delegate: Item {
                        required property int index
                        width: Math.round(52 * root.u)
                        height: hours.height
                        readonly property real t: hourly.temperature_2m[index]
                        readonly property real norm: (t - hours.tMin) / Math.max(1, hours.tMax - hours.tMin)

                        Rectangle {
                            anchors.fill: parent
                            radius: Math.round(10 * root.u)
                            color: index === 0 ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.12) : "transparent"
                        }
                        Text {
                            id: hTime
                            anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: Math.round(8 * root.u) }
                            text: index === 0 ? "Now" : root.hourText(hourly.time[index])
                            color: index === 0 ? Theme.text : Theme.subtext
                            font.pixelSize: Math.round(10 * root.u)
                            font.bold: index === 0
                        }
                        ArcC.MatIcon {
                            id: hIcon
                            anchors { horizontalCenter: parent.horizontalCenter; top: hTime.bottom; topMargin: Math.round(6 * root.u) }
                            text: root.codeInfo(hourly.weather_code[index], hourly.is_day[index] === 1).icon
                            font.pixelSize: Math.round(20 * root.u)
                            color: Theme.active
                        }
                        Item {
                            id: barArea
                            anchors { horizontalCenter: parent.horizontalCenter; top: hIcon.bottom; topMargin: Math.round(8 * root.u); bottom: hTemp.top; bottomMargin: Math.round(4 * root.u) }
                            width: Math.round(4 * root.u)
                            Rectangle {
                                anchors.bottom: parent.bottom
                                width: parent.width
                                height: Math.max(width, parent.height * (0.25 + 0.75 * norm))
                                radius: width / 2
                                color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.35 + 0.5 * norm)
                            }
                        }
                        Text {
                            id: hTemp
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: hRain.top; bottomMargin: Math.round(2 * root.u) }
                            text: Math.round(t) + "°"
                            color: Theme.text
                            font.family: root.mono
                            font.pixelSize: Math.round(12 * root.u)
                            font.bold: true
                        }
                        Text {
                            id: hRain
                            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: Math.round(6 * root.u) }
                            text: (hourly.precipitation_probability[index] ?? 0) + "%"
                            color: (hourly.precipitation_probability[index] ?? 0) > 0 ? "#89b4fa" : Qt.rgba(Theme.subtext.r, Theme.subtext.g, Theme.subtext.b, 0.4)
                            font.family: root.mono
                            font.pixelSize: Math.round(9 * root.u)
                        }
                    }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Math.round(12 * root.u)
        visible: !root.ready
        opacity: visible ? 1 : 0

        ArcC.MatIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.error !== "" ? "cloud_off" : "cloud_sync"
            font.pixelSize: Math.round(44 * root.u)
            color: root.error !== "" ? Theme.subtext : Theme.active
            SequentialAnimation on opacity {
                running: root.loading
                loops: Animation.Infinite
                NumberAnimation { from: 1; to: 0.35; duration: 700; easing.type: Easing.InOutSine }
                NumberAnimation { from: 0.35; to: 1; duration: 700; easing.type: Easing.InOutSine }
            }
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.error !== "" ? root.error : "Fetching the forecast…"
            color: Theme.subtext
            font.pixelSize: Math.round(13 * root.u)
        }
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            visible: root.error !== "" && !root.loading
            width: retryText.implicitWidth + Math.round(28 * root.u)
            height: Math.round(30 * root.u)
            radius: height / 2
            color: retryHov.hovered ? Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.25) : Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.14)
            border.color: Qt.rgba(Theme.active.r, Theme.active.g, Theme.active.b, 0.4)
            border.width: 1
            Text {
                id: retryText
                anchors.centerIn: parent
                text: "Retry"
                color: Theme.active
                font.pixelSize: Math.round(12 * root.u)
                font.bold: true
            }
            HoverHandler { id: retryHov; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: root.refresh() }
        }
    }
}
