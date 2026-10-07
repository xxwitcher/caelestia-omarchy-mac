pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Dock: show/hide it in the taskbar, and manage pinned apps (unpin, reorder)
PageBase {
    id: root

    readonly property var dockEntry: Config.bar.entries.values.find(e => e.id === "dock")

    title: Tr.tr("Dock")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            first: true
            text: Tr.tr("Show the dock in the taskbar")
            subtext: Tr.tr("Hover it to open; right click an app for its menu")
            checked: root.dockEntry?.enabled ?? false
            onToggled: {
                const e = GlobalConfig.bar.entries.values.find(e => e.id === "dock");
                if (e)
                    e.enabled = checked;
            }
        }

        ToggleRow {
            last: true
            text: Tr.tr("Show the apps button in the dock")
            subtext: Tr.tr("Opens the app launcher")
            checked: Dock.showAppsButton
            onToggled: Dock.setShowAppsButton(checked)
        }

        SectionHeader {
            text: Tr.tr("Pinned apps")
        }

        Repeater {
            model: Dock.pinned

            ConnectedRect {
                id: pin

                required property string modelData
                required property int index
                readonly property DesktopEntry entry: DesktopEntries.byId(modelData) ?? DesktopEntries.heuristicLookup(modelData)

                Layout.fillWidth: true
                first: index === 0
                last: index === Dock.pinned.length - 1
                implicitHeight: pinRow.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: pinRow

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.medium
                    spacing: Tokens.spacing.medium

                    StyledText {
                        Layout.fillWidth: true
                        text: pin.entry?.name ?? pin.modelData
                    }

                    IconButton {
                        icon: "arrow_upward"
                        type: IconButton.Text
                        disabled: pin.index === 0
                        onClicked: Dock.move(pin.modelData, -1)
                    }

                    IconButton {
                        icon: "arrow_downward"
                        type: IconButton.Text
                        disabled: pin.index === Dock.pinned.length - 1
                        onClicked: Dock.move(pin.modelData, 1)
                    }

                    IconButton {
                        icon: "keep_off"
                        type: IconButton.Tonal
                        onClicked: Dock.togglePin(pin.modelData)
                    }
                }
            }
        }

        StyledText {
            visible: Dock.pinned.length === 0
            text: Tr.tr("No pinned apps yet")
            color: Colours.palette.m3onSurfaceVariant
        }
    }
}
