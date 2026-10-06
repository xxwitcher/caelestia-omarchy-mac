pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
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
