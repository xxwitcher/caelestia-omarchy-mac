// Copyright (C) 2026 George Dobreff ("Witcher") and contributors
// SPDX-License-Identifier: GPL-3.0-only

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Taris.Config
import Taris.I18n
import qs.components
import qs.modules.nexus.common

// Security: lock screen behaviour, fingerprint unlock (enrolment in a terminal) and password
PageBase {
    id: root

    property bool hasFprint
    property list<string> fingers: []

    function inTerminal(cmd: string): void {
        Quickshell.execDetached(["sh", "-c", `exec ${GlobalConfig.general.apps.terminal.join(" ")} -e sh -c '${cmd}; echo; read -p "Press Enter to close" _'`]);
    }

    title: Tr.tr("Security")

    // Remote login: whether sshd is installed, and running
    property bool hasSshd
    property bool sshd

    property Process _sshdGet: Process {
        id: sshdGet

        running: true
        command: ["sh", "-c", "systemctl list-unit-files sshd.service --no-legend | grep -q . && echo installed; systemctl is-active --quiet sshd && echo active"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.hasSshd = text.includes("installed");
                root.sshd = text.includes("active");
            }
        }
    }

    property Process _sshdSet: Process {
        id: sshdSet

        onExited: sshdGet.running = true
    }

    property Process _process1: Process {
        running: true
        command: ["sh", "-c", "command -v fprintd-list >/dev/null && fprintd-list \"$USER\" 2>/dev/null | sed -n 's/^ *- #[0-9]*: //p'; command -v fprintd-list >/dev/null && echo __fprint__"]
        stdout: StdioCollector {
            onStreamFinished: {
                const lines = text.split("\n").filter(l => l.trim());
                root.hasFprint = lines.includes("__fprint__");
                root.fingers = lines.filter(l => l !== "__fprint__");
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Lock screen")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Use the wallpaper as the lock screen background")
            checked: Config.lock.useWallpaper
            onToggled: GlobalConfig.lock.useWallpaper = checked
        }

        ToggleRow {
            text: Tr.tr("Hide notifications on the lock screen")
            checked: Config.lock.hideNotifs
            onToggled: GlobalConfig.lock.hideNotifs = checked
        }

        ToggleRow {
            last: true
            text: Tr.tr("Power buttons on the lock screen")
            subtext: Tr.tr("Shut down, restart and sleep without unlocking")
            checked: GlobalConfig.lock.enableSessionControls
            onToggled: GlobalConfig.lock.enableSessionControls = checked
        }

        SectionHeader {
            text: Tr.tr("Fingerprint")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Unlock with fingerprint")
            subtext: root.hasFprint ? (root.fingers.length > 0 ? Tr.tr("Enrolled: %1").arg(root.fingers.join(", ")) : Tr.tr("No fingers enrolled yet")) : Tr.tr("Install fprintd to use a fingerprint reader")
            checked: GlobalConfig.lock.enableFprint
            onToggled: GlobalConfig.lock.enableFprint = checked
        }

        RowButton {
            last: true
            icon: "fingerprint"
            text: Tr.tr("Enrol a finger")
            disabled: !root.hasFprint
            onClicked: root.inTerminal("fprintd-enroll")
        }

        SectionHeader {
            visible: root.hasSshd
            text: Tr.tr("Access")
        }

        ToggleRow {
            visible: root.hasSshd
            first: true
            last: true
            text: Tr.tr("Remote login (SSH)")
            subtext: Tr.tr("Let other computers sign in to this one over the network")
            checked: root.sshd
            onToggled: {
                sshdSet.command = ["pkexec", "systemctl", checked ? "enable" : "disable", "--now", "sshd.service"];
                sshdSet.running = true;
            }
        }

        SectionHeader {
            text: Tr.tr("Account")
        }

        RowButton {
            first: true
            last: true
            icon: "password"
            text: Tr.tr("Change password")
            onClicked: root.inTerminal("passwd")
        }
    }
}
