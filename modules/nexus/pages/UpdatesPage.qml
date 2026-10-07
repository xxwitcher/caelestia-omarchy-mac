pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.modules.nexus.common

// System updates: pending package count, and an update run in a terminal (omarchy-update when
// Omarchy is installed, which updates Omarchy and the system; otherwise yay or pacman).
PageBase {
    id: root

    property list<string> pending: []
    property bool checking: true

    title: Tr.tr("Updates")

    property Process _process1: Process {
        id: check

        running: true
        command: ["sh", "-c", "checkupdates 2>/dev/null; command -v yay >/dev/null && yay -Qua 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pending = text.split("\n").filter(l => l.trim().length > 0);
                root.checking = false;
            }
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // First, so a long list never pushes them out of reach
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            Layout.bottomMargin: Tokens.spacing.large
            spacing: Tokens.spacing.medium

            TextButton {
                type: TextButton.Tonal
                text: Tr.tr("Check again")
                onClicked: {
                    root.checking = true;
                    check.running = true;
                }
            }

            TextButton {
                text: Tr.tr("Update now")
                onClicked: Quickshell.execDetached(["sh", "-c", `exec ${GlobalConfig.general.apps.terminal.join(" ")} -e sh -c 'if command -v omarchy-update >/dev/null; then omarchy-update; elif command -v yay >/dev/null; then yay -Syu; else sudo pacman -Syu; fi; echo; read -p "Done. Press Enter to close" _'`])
            }
        }

        SectionHeader {
            first: true
            text: root.checking ? Tr.tr("Checking for updates…") : root.pending.length === 0 ? Tr.tr("Everything is up to date") : Tr.tr("%1 updates available").arg(root.pending.length)
        }

        Repeater {
            model: root.pending.slice(0, 60)

            InfoRow {
                required property string modelData
                required property int index

                first: index === 0
                last: index === Math.min(root.pending.length, 60) - 1
                label: modelData.split(" ")[0]
                value: modelData.split(" ").slice(1).join(" ")
            }
        }

    }
}
