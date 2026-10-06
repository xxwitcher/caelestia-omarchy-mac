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
import qs.modules.launcher.services as Launcher

// Colours: light/dark mode, M3 variant, every scheme and flavour (or dynamic from the
// wallpaper), transparency and UI scale.
PageBase {
    id: root

    function setScheme(args: list<string>): void {
        Quickshell.execDetached(["caelestia", "scheme", "set", ...args]);
        reloadTimer.restart();
    }

    title: Tr.tr("Colours")
    isSubPage: true

    Component.onCompleted: Launcher.Schemes.reload()

    property Timer _timer1: Timer {
        id: reloadTimer

        interval: 500
        onTriggered: Launcher.Schemes.reload()
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Mode")
        }

        ToggleRow {
            first: true
            last: true
            text: Tr.tr("Light mode")
            checked: Colours.currentLight
            onToggled: root.setScheme(["-m", checked ? "light" : "dark"])
        }

        SectionHeader {
            text: Tr.tr("Variant")
        }

        Flow {
            Layout.fillWidth: true
            spacing: Tokens.spacing.small

            Repeater {
                model: Launcher.M3Variants.list

                TextButton {
                    required property var modelData

                    type: TextButton.Tonal
                    isToggle: true
                    checked: Launcher.Schemes.currentVariant === modelData.variant
                    text: modelData.name
                    onClicked: root.setScheme(["-v", modelData.variant])
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Scheme")
        }

        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(2, Math.floor(width / 170))
            columnSpacing: Tokens.spacing.small
            rowSpacing: Tokens.spacing.small

            // Dynamic: generated from the wallpaper
            SchemeCard {
                name: "dynamic"
                flavour: "default"
                label: Tr.tr("From wallpaper")
                swatches: [Colours.palette.m3primary, Colours.palette.m3secondary, Colours.palette.m3tertiary, Colours.palette.m3surface]
            }

            Repeater {
                model: Launcher.Schemes.list.filter(s => s.name !== "dynamic")

                SchemeCard {
                    required property var modelData

                    name: modelData.name
                    flavour: modelData.flavour
                    label: `${modelData.name} ${modelData.flavour}`
                    swatches: ["primary", "secondary", "tertiary", "surface"].map(k => `#${modelData.colours[k] ?? "000000"}`)
                }
            }
        }

        SectionHeader {
            text: Tr.tr("Transparency & scale")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Transparency")
            checked: Tokens.transparency.enabled
            onToggled: GlobalConfig.appearance.transparency.enabled = checked
        }

        StepperRow {
            label: Tr.tr("Panel opacity")
            value: Tokens.transparency.base
            from: 0.3
            to: 1
            stepSize: 0.05
            onMoved: v => GlobalConfig.appearance.transparency.base = Math.round(v * 100) / 100
        }

        StepperRow {
            label: Tr.tr("Layer opacity")
            value: Tokens.transparency.layers
            from: 0
            to: 1
            stepSize: 0.05
            onMoved: v => GlobalConfig.appearance.transparency.layers = Math.round(v * 100) / 100
        }

        StepperRow {
            last: true
            label: Tr.tr("Interface scale")
            subtext: Tr.tr("Fonts, padding, spacing and rounding together")
            value: Config.appearance.font.scale
            from: 0.5
            to: 1.5
            stepSize: 0.05
            onMoved: v => {
                const s = Math.round(v * 100) / 100;
                GlobalConfig.appearance.font.scale = s;
                GlobalConfig.appearance.padding.scale = s;
                GlobalConfig.appearance.spacing.scale = s;
                GlobalConfig.appearance.rounding.scale = s;
            }
        }
    }

    component SchemeCard: StyledRect {
        id: card

        required property string name
        required property string flavour
        required property string label
        required property list<color> swatches
        readonly property bool current: Launcher.Schemes.currentScheme === `${name} ${flavour}` || (name === "dynamic" && Colours.scheme === "dynamic")

        Layout.fillWidth: true
        implicitHeight: 64
        radius: Tokens.rounding.large
        color: current ? Colours.palette.m3secondaryContainer : Colours.tPalette.m3surfaceContainer

        StateLayer {
            radius: card.radius
            onClicked: root.setScheme(card.name === "dynamic" ? ["-n", "dynamic"] : ["-n", card.name, "-f", card.flavour])
        }

        Row {
            id: swatchRow

            anchors.left: parent.left
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            spacing: -6

            Repeater {
                model: card.swatches

                StyledRect {
                    required property color modelData

                    implicitWidth: 20
                    implicitHeight: 20
                    radius: 10
                    color: modelData
                    border.width: 2
                    border.color: card.color
                }
            }
        }

        StyledText {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.margins: Tokens.padding.medium
            text: card.label
            elide: Text.ElideRight
            font: Tokens.font.label.medium
            color: card.current ? Colours.palette.m3onSecondaryContainer : Colours.palette.m3onSurface
        }

        MaterialIcon {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: Tokens.padding.medium
            visible: card.current
            text: "check_circle"
            color: Colours.palette.m3primary
            fill: 1
        }
    }
}
