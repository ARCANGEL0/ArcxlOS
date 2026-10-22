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
            { id: "vpn", label: "VPN", icon: "vpn_lock", page: "VpnPage",
              desc: "Tunnels and providers", keys: "wireguard openvpn tunnel proxy" } ] },
        { name: "Devices", pages: [
            { id: "displays", label: "Displays", icon: "desktop_windows", page: "DisplaysPage",
              desc: "Resolution, refresh rate and scale", keys: "monitor screen resolution refresh hz scale night light" },
            { id: "sound", label: "Sound", icon: "volume_up", page: "SoundPage",
              desc: "Output, input and app volumes", keys: "audio volume speaker microphone mic headphones" },
            { id: "input", label: "Keyboard & Mouse", icon: "keyboard", page: "InputPage",
              desc: "Layouts, repeat rate, pointer and touchpad", keys: "keyboard layout mouse touchpad pointer speed" },
            { id: "power", label: "Power & Battery", icon: "battery_charging_full", page: "PowerPage",
              desc: "Battery, power profile and sleep", keys: "battery power profile performance sleep suspend" } ] },
        { name: "Personalize", pages: [
            { id: "appearance", label: "Appearance", icon: "palette", page: "AppearancePage",
              desc: "Accent, panels, corners and type", keys: "theme accent color colour dark light blur opacity font radius" },
            { id: "wallpaper", label: "Wallpaper", icon: "wallpaper", page: "WallpaperPage",
              desc: "Images, video wallpapers and colours from them", keys: "background wallpaper video" },
            { id: "desktop", label: "Desktop & Shell", icon: "dashboard_customize", page: "DesktopPage",
              desc: "Bar, island, panels, OSD and motion", keys: "bar dock island hover osd visualiser animations clock" },
            { id: "notifications", label: "Notifications", icon: "notifications", page: "NotificationsPage",
              desc: "Do not disturb and per-app rules", keys: "notification dnd do not disturb toast" } ] },
        { name: "System", pages: [
            { id: "datetime", label: "Date & Time", icon: "schedule", page: "DateTimePage",
              desc: "Time zone, clock format and sync", keys: "date time clock timezone ntp 24 hour" },
            { id: "language", label: "Language & Region", icon: "translate", page: "LanguagePage",
              desc: "System language and formats", keys: "language locale region format" },
            { id: "users", label: "Users & Accounts", icon: "group", page: "UsersPage",
              desc: "Accounts, pictures and passwords", keys: "user account password avatar picture admin add remove people" },
            { id: "apps", label: "Apps", icon: "apps", page: "AppsPage",
              desc: "Installed, default and startup apps", keys: "default apps autostart startup browser uninstall remove packages" },
            { id: "storage", label: "Storage", icon: "hard_drive", page: "StoragePage",
              desc: "Disks, usage and cleanup", keys: "disk storage space cleanup cache" },
            { id: "updates", label: "Updates", icon: "system_update", page: "UpdatesPage",
              desc: "System and app updates", keys: "update upgrade pacman packages" } ] },
        { name: "Privacy & Security", pages: [
            { id: "security", label: "Security overview", icon: "health_and_safety", page: "SecurityPage",
              desc: "How protected this computer is", keys: "security score check status overview protection" },
            { id: "firewall", label: "Firewall", icon: "local_fire_department", page: "FirewallPage",
              desc: "What may connect in", keys: "firewall firewalld zone port open block incoming" },
            { id: "ports", label: "Services & Ports", icon: "settings_ethernet", page: "PortsPage",
              desc: "What's listening, and the services behind it", keys: "ports listening services daemons systemd open sockets netstat ss" },
            { id: "ssh", label: "Remote access", icon: "terminal", page: "SshPage",
              desc: "SSH server, keys and logins", keys: "ssh sshd remote login keys authorized password" },
            { id: "permissions", label: "App permissions", icon: "privacy_tip", page: "PermissionsPage",
              desc: "Microphone, camera and screen", keys: "microphone mic camera webcam screen sharing permissions recording" },
            { id: "usb", label: "USB devices", icon: "usb", page: "UsbPage",
              desc: "Which USB devices may connect", keys: "usb usbguard badusb devices block allow" },
            { id: "encryption", label: "Encryption", icon: "enhanced_encryption", page: "EncryptionPage",
              desc: "Disks, USB drives, files and vaults", keys: "encryption luks cryptsetup disk usb drive encrypt decrypt vault gpg" },
            { id: "encryption-files", label: "Files, folders & vaults", icon: "folder_zip", page: "EncFilesPage", hidden: true, parent: "encryption",
              desc: "Encrypt files and folders", keys: "" },
            { id: "encryption-hash", label: "Checksums", icon: "fingerprint", page: "EncHashPage", hidden: true, parent: "encryption",
              desc: "Hashes of files", keys: "" },
            { id: "toolkit", label: "Crypto toolkit", icon: "construction", page: "ToolkitPage", hidden: true, parent: "encryption",
              desc: "Encode, hash, passwords, keys", keys: "" },
            { id: "encryption-advanced", label: "Advanced", icon: "tune", page: "EncAdvancedPage", hidden: true, parent: "encryption",
              desc: "Ciphers, hashing, GPG keys", keys: "" },
            { id: "privacy", label: "Privacy & history", icon: "history_toggle_off", page: "PrivacyPage",
              desc: "Recent files, clipboard, traces", keys: "privacy history recent clipboard thumbnails trash clear traces" },
            { id: "lock", label: "Lock Screen", icon: "lock", page: "LockPage",
              desc: "Locking, idle and sign-in", keys: "lock idle screensaver login password" },
            { id: "ghostwired", label: "GhostWired", icon: "shield_lock", page: "GhostPage",
              desc: "Send every packet through Tor", keys: "tor onion onionlayer anonymity anonsurf tunnel bridges obfs4 snowflake meek kill switch mac privacy proxy exit invisible" },
            { id: "ghostwired-exclude", label: "Excluded apps", icon: "apps_outage", page: "GhostExcludePage", hidden: true, parent: "ghostwired",
              desc: "Apps that skip the Tor tunnel", keys: "" },
            { id: "ghostwired-advanced", label: "Tor configuration", icon: "tune", page: "GhostAdvancedPage", hidden: true, parent: "ghostwired",
              desc: "Ports, exits and raw torrc", keys: "" },
            { id: "hardening", label: "Hardening", icon: "security", page: "HardeningPage",
              desc: "AppArmor, kernel and boot", keys: "hardening apparmor sysctl kernel secure boot root ptrace" },
            { id: "audit", label: "Audit", icon: "fact_check", page: "AuditPage",
              desc: "Lynis and rootkit scans", keys: "audit lynis rkhunter rootkit scan vulnerability" } ] }
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
            if (!root.visible(p) || p.hidden) continue;
            if ((p.label + " " + p.desc + " " + p.keys + " " + g.name).toLowerCase().includes(q)) out.push(Object.assign({ group: g.name }, p));
        }
        return out;
    }
}
