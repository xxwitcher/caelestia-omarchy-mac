pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

// Per monitor: scale, resolution/refresh rate and position. Applied live, kept in hypr-settings.lua.
PageBase {
    id: root

    title: Tr.tr("Displays")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        Repeater {
            model: Hypr.monitors.values

            ColumnLayout {
                id: mon

                required property var modelData
                readonly property var ipc: modelData.lastIpcObject ?? ({})
                readonly property var saved: HyprSettings.monitors[modelData.name] ?? ({})

                Layout.fillWidth: true
                spacing: Tokens.spacing.extraSmall / 2

                SectionHeader {
                    first: true
                    text: `${mon.modelData.name} · ${mon.ipc.make ?? ""} ${mon.ipc.model ?? ""}`
                }

                StepperRow {
                    first: true
                    label: Tr.tr("Scale")
                    subtext: Tr.tr("Logical size: %1×%2").arg(Math.round((mon.ipc.width ?? 0) / (mon.ipc.scale || 1))).arg(Math.round((mon.ipc.height ?? 0) / (mon.ipc.scale || 1)))
                    value: mon.ipc.scale ?? 1
                    from: 0.5
                    to: 3
                    stepSize: 0.25
                    onMoved: v => HyprSettings.setMonitor(mon.modelData.name, {
                            scale: v
                        })
                }

                Repeater {
                    model: mon.ipc.availableModes ?? []

                    ToggleRow {
                        required property string modelData
                        required property int index

                        text: modelData.replace("Hz", " Hz")
                        subtext: index === 0 ? Tr.tr("Resolution and refresh rate") : ""
                        checked: modelData.startsWith(`${mon.ipc.width}x${mon.ipc.height}@${Number(mon.ipc.refreshRate).toFixed(2)}`)
                        onToggled: HyprSettings.setMonitor(mon.modelData.name, {
                                mode: modelData.replace("Hz", "")
                            })
                    }
                }

                TextFieldRow {
                    last: true
                    label: Tr.tr("Position")
                    subtext: Tr.tr("XxY in logical pixels, or auto")
                    value: mon.saved.position ?? `${mon.ipc.x ?? 0}x${mon.ipc.y ?? 0}`
                    onEditingFinished: v => HyprSettings.setMonitor(mon.modelData.name, {
                            position: v.trim() || "auto"
                        })
                }
            }
        }
    }
}
