// The settings map: groups in sidebar order, each page with its icon, search keywords and the
// file that renders it. Pages listed with `editions` only appear on those editions.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // ArchangelOS edition: VARIANT_ID in /etc/os-release, else inferred from what is installed.
    property string edition: "home"
    readonly property string editionName: ({ home: "Home", gaming: "Gaming", fallen: "Fallen", netinstall: "NetInstall" })[edition] ?? "ArchangelOS"
    FileView {
        path: "/etc/os-release"
        onLoaded: {
            const m = text().match(/^VARIANT_ID="?([a-z]+)"?/m);
            if (m) root.edition = m[1];
            else edProbe.running = true;
        }
    }
    Process {
        id: edProbe
        command: ["sh", "-c", "if [ -x /usr/bin/archangelos-wheel ]; then echo fallen; elif command -v steam >/dev/null; then echo gaming; else echo home; fi"]
        stdout: StdioCollector { onStreamFinished: root.edition = text.trim() || "home" }
    }

    readonly property var groups: [
        { name: "", pages: [
            { id: "profile", label: "Profile", icon: "account_circle", page: "ProfilePage",
              desc: "Your machine at a glance", keys: "about system overview hostname specs vitals" } ] },
        { name: "Connectivity", pages: [
            { id: "network", label: "Wi-Fi & Network", icon: "wifi", page: "NetworkPage",
              desc: "Wireless and wired connections", keys: "wifi wireless ethernet lan internet ssid" },
            { id: "bluetooth", label: "Bluetooth", icon: "bluetooth", page: "BluetoothPage",
              desc: "Pair and connect devices", keys: "bt pair headphones controller" },
            { id: "vpn", label: "VPN", icon: "vpn_lock", page: "PlannedPage",
              desc: "Tunnels and providers", keys: "wireguard openvpn tunnel proxy" } ] },
        { name: "Devices", pages: [
            { id: "displays", label: "Displays", icon: "desktop_windows", page: "PlannedPage",
              desc: "Resolution, refresh rate and scale", keys: "monitor screen resolution refresh hz scale night light" },
            { id: "sound", label: "Sound", icon: "volume_up", page: "SoundPage",
              desc: "Output, input and app volumes", keys: "audio volume speaker microphone mic headphones" },
            { id: "input", label: "Keyboard & Mouse", icon: "keyboard", page: "PlannedPage",
              desc: "Layouts, repeat rate, pointer and touchpad", keys: "keyboard layout mouse touchpad pointer speed" },
            { id: "power", label: "Power & Battery", icon: "battery_charging_full", page: "PlannedPage",
              desc: "Battery, power profile and sleep", keys: "battery power profile performance sleep suspend" } ] },
        { name: "Personalize", pages: [
            { id: "appearance", label: "Appearance", icon: "palette", page: "AppearancePage",
              desc: "Accent, panels, corners and type", keys: "theme accent color colour dark light blur opacity font radius" },
            { id: "wallpaper", label: "Wallpaper", icon: "wallpaper", page: "PlannedPage",
              desc: "Images, video wallpapers and colours from them", keys: "background wallpaper video" },
            { id: "desktop", label: "Desktop & Shell", icon: "dashboard_customize", page: "DesktopPage",
              desc: "Bar, island, panels, OSD and motion", keys: "bar dock island hover osd visualiser animations clock" },
            { id: "notifications", label: "Notifications", icon: "notifications", page: "PlannedPage",
              desc: "Do not disturb and per-app rules", keys: "notification dnd do not disturb toast" } ] },
        { name: "System", pages: [
            { id: "datetime", label: "Date & Time", icon: "schedule", page: "DateTimePage",
              desc: "Time zone, clock format and sync", keys: "date time clock timezone ntp 24 hour" },
            { id: "language", label: "Language & Region", icon: "translate", page: "PlannedPage",
              desc: "System language and formats", keys: "language locale region format" },
            { id: "users", label: "Users & Accounts", icon: "group", page: "PlannedPage",
              desc: "Your account, picture and password", keys: "user account password avatar picture admin" },
            { id: "apps", label: "Apps", icon: "apps", page: "PlannedPage",
              desc: "Default apps and startup apps", keys: "default apps autostart startup browser" },
            { id: "storage", label: "Storage", icon: "hard_drive", page: "PlannedPage",
              desc: "Disks, usage and cleanup", keys: "disk storage space cleanup cache" },
            { id: "updates", label: "Updates", icon: "system_update", page: "PlannedPage",
              desc: "System and app updates", keys: "update upgrade pacman packages" } ] },
        { name: "Privacy & Security", pages: [
            { id: "lock", label: "Lock Screen", icon: "lock", page: "PlannedPage",
              desc: "Locking, idle and sign-in", keys: "lock idle screensaver login password" },
            { id: "anonymity", label: "Anonymity", icon: "visibility_off", page: "PlannedPage", editions: ["fallen"],
              desc: "Tor routing, MAC address and traces", keys: "tor anonsurf mac spoof privacy onion" } ] }
    ]

    function visible(p) { return !p.editions || p.editions.indexOf(root.edition) >= 0; }
    function find(id) {
        for (const g of root.groups) for (const p of g.pages) if (p.id === id && root.visible(p)) return Object.assign({ group: g.name }, p);
        return null;
    }
    function search(q) {
        q = q.trim().toLowerCase();
        const out = [];
        for (const g of root.groups) for (const p of g.pages) {
            if (!root.visible(p)) continue;
            if ((p.label + " " + p.desc + " " + p.keys + " " + g.name).toLowerCase().includes(q)) out.push(Object.assign({ group: g.name }, p));
        }
        return out;
    }
}
