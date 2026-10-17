pragma Singleton

// ArchangelOS weather. Reads the city from ~/.config/archangelos/weather.conf
// (written at install; "London" on a live boot), fetches wttr.in, and refreshes
// every 30 min. Expands into the dock's weather pane.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    property string city: "London"
    property bool   loading: false
    property bool   ok: false
    property int    tempC: 0
    property int    feelsC: 0
    property int    humidity: 0
    property int    windKph: 0
    property string condition: ""
    property string icon: "cloud"          // material glyph name
    property string observed: ""
    // [{day, label, maxC, minC, condition, icon}]
    property var    forecast: []

    readonly property string _cfgDir: Quickshell.env("HOME") + "/.config/archangelos"
    readonly property string _cfg: _cfgDir + "/weather.conf"

    Component.onCompleted: cityFile.reload()

    FileView {
        id: cityFile
        path: root._cfg
        blockLoading: true; watchChanges: false; printErrors: false
        onLoaded: {
            const c = cityFile.text().trim();
            if (c) root.city = c;
            root.refresh();
        }
        onLoadFailed: root.refresh()   // no config yet → default London
    }

    function setCity(name) {
        const c = (name || "").trim();
        if (!c) return;
        root.city = c;
        saveProc.command = ["sh", "-c",
            "mkdir -p '" + root._cfgDir + "' && printf '%s' \"$1\" > '" + root._cfg + "'",
            "sh", c];
        saveProc.running = true;
        root.refresh();
    }
    Process { id: saveProc }

    Timer { interval: 1800000; running: true; repeat: true; onTriggered: root.refresh() }

    function _glyph(desc) {
        const d = (desc || "").toLowerCase();
        if (d.includes("thunder")) return "thunderstorm";
        if (d.includes("snow") || d.includes("sleet") || d.includes("ice")) return "weather_snowy";
        if (d.includes("rain") || d.includes("drizzle") || d.includes("shower")) return "rainy";
        if (d.includes("fog") || d.includes("mist")) return "foggy";
        if (d.includes("cloud") || d.includes("overcast")) return "cloud";
        if (d.includes("sun") || d.includes("clear")) return "clear_day";
        return "partly_cloudy_day";
    }

    function refresh() {
        if (root.loading) return;
        root.loading = true;
        // one curl, jq shapes it: "tempC|feelsC|humidity|wind|desc\n<day lines>"
        wxProc.command = ["sh", "-c",
            "curl -fsS --max-time 12 \"https://wttr.in/$1?format=j1\" | jq -r '" +
            "(.current_condition[0] | \"\\(.temp_C)|\\(.FeelsLikeC)|\\(.humidity)|\\(.windspeedKmph)|\\(.weatherDesc[0].value)\"), " +
            "(.weather[] | \"\\(.date)|\\(.maxtempC)|\\(.mintempC)|\\(.hourly[4].weatherDesc[0].value)\")'",
            "sh", root.city];
        wxProc.running = true;
    }

    Process {
        id: wxProc
        stdout: StdioCollector {
            id: wxOut
            onStreamFinished: {
                root.loading = false;
                const lines = wxOut.text.trim().split("\n").filter(l => l.length);
                if (lines.length < 1) { root.ok = false; return; }
                const c = lines[0].split("|");
                if (c.length < 5) { root.ok = false; return; }
                root.tempC = Math.round(Number(c[0]));
                root.feelsC = Math.round(Number(c[1]));
                root.humidity = Math.round(Number(c[2]));
                root.windKph = Math.round(Number(c[3]));
                root.condition = c[4];
                root.icon = root._glyph(c[4]);
                const days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"];
                const fc = [];
                for (let i = 1; i < lines.length && i <= 5; i++) {
                    const f = lines[i].split("|");
                    if (f.length < 4) continue;
                    const dt = new Date(f[0] + "T12:00:00");
                    fc.push({
                        day: f[0],
                        label: i === 1 ? "Today" : days[dt.getDay()],
                        maxC: Math.round(Number(f[1])),
                        minC: Math.round(Number(f[2])),
                        condition: f[3],
                        icon: root._glyph(f[3])
                    });
                }
                root.forecast = fc;
                root.observed = Qt.formatDateTime(new Date(), "hh:mm");
                root.ok = true;
            }
        }
    }
}
