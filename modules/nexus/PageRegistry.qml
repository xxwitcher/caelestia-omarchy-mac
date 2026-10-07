pragma Singleton

import QtQuick
import Caelestia.I18n

QtObject {
    id: root

    // id: what the Settings overlay is opened on (WindowFactory.open, a popout's "Open settings")
    readonly property list<var> pages: [
        // Appearance
        {
            id: "appearance",
            label: Tr.tr("Wallpaper & style"),
            icon: "palette",
            description: Tr.tr("Wallpaper, fonts, colours"),
            category: "appearance"
        },
        {
            id: "windowstyle",
            label: Tr.tr("Window style"),
            icon: "border_style",
            description: Tr.tr("Borders, gaps, corners, workspace animation, swipes"),
            category: "appearance"
        },

        // Connectivity
        // TODO
        // {
        //     label: Tr.tr("Display"),
        //     icon: "monitor",
        //     description: Tr.tr("Output configuration"),
        //     category: "connectivity"
        // },
        {
            id: "network",
            label: Tr.tr("Network"),
            icon: "wifi",
            description: Tr.tr("Wi-Fi, ethernet, VPN"),
            category: "connectivity"
        },
        {
            id: "bluetooth",
            label: Tr.tr("Connected devices"),
            icon: "devices_other",
            description: Tr.tr("Bluetooth, pairing"),
            category: "connectivity",
            noFill: true
        },
        {
            id: "audio",
            label: Tr.tr("Audio"),
            icon: "volume_up",
            description: Tr.tr("App volumes, sound devices"),
            category: "connectivity"
        },

        // System
        {
            id: "updates",
            label: Tr.tr("Updates"),
            icon: "update",
            description: Tr.tr("System updates"),
            category: "system"
        },
        {
            id: "plugins",
            label: Tr.tr("Plugins"),
            icon: "extension",
            description: Tr.tr("Manage plugins"),
            category: "system"
        },
        {
            id: "displays",
            label: Tr.tr("Displays"),
            icon: "monitor",
            description: Tr.tr("Scale, resolution, arrangement"),
            category: "system"
        },
        {
            id: "power",
            label: Tr.tr("Power"),
            icon: "battery_charging_full",
            description: Tr.tr("Power profile, idle, sleep, battery"),
            category: "system"
        },
        {
            id: "security",
            label: Tr.tr("Security"),
            icon: "lock",
            description: Tr.tr("Lock screen, fingerprint, password"),
            category: "system"
        },
        {
            id: "keyboard",
            label: Tr.tr("Keyboard & trackpad"),
            icon: "keyboard",
            description: Tr.tr("Layout, repeat, Ctrl/Super swap, Caps Lock, scrolling, tapping"),
            category: "system"
        },

        // Shell
        {
            id: "panels",
            label: Tr.tr("Panels"),
            icon: "dock_to_bottom",
            description: Tr.tr("Dashboard, taskbar, launcher, sidebar"),
            category: "shell"
        },
        {
            id: "dock",
            label: Tr.tr("Dock"),
            icon: "dock_to_left",
            description: Tr.tr("Pinned apps, show or hide"),
            category: "shell"
        },
        {
            id: "apps",
            label: Tr.tr("Apps"),
            icon: "apps",
            description: Tr.tr("Default apps, favourites, hidden apps"),
            category: "shell"
        },
        {
            id: "services",
            label: Tr.tr("Services"),
            icon: "build",
            description: Tr.tr("Poll intervals, lyrics backend"),
            category: "shell"
        },
        {
            id: "language",
            label: Tr.tr("Language & region"),
            icon: "globe",
            description: Tr.tr("UI language, weather location, display units"),
            category: "shell"
        },

        // About
        {
            id: "about",
            label: Tr.tr("About"),
            icon: "info",
            description: Tr.tr("System information, credits"),
            category: "about"
        },
    ]
}
