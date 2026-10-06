pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

// Windows and Window border, as in the witchers-tweaks settings app. Saved to
// window-style.conf (read by hypr-caelestia.lua), then Hyprland reloads.
PageBase {
    id: root

    readonly property var defaults: ({
            gradient: "1",
            colors: "c4b5fd a855f7 da70d6",
            inactive: "5b3a7a",
            fade: "1",
            swipe: "1",
            titlebars: "1",
            borderresize: "1",
            roundingon: "1",
            rounding: "60",
            gaps: "1",
            columns: "0",
            floatnew: "0"
        })
    property var style: Object.assign({}, defaults)
    readonly property list<string> gradientColours: style.colors.split(/\s+/).filter(c => /^[0-9a-fA-F]{6}$/.test(c)).map(c => `#${c}`)

    function save(changes: var): void {
        style = Object.assign({}, style, changes);
        file.setText(Object.entries(style).map(([k, v]) => `${k}=${v}`).join("\n") + "\n");
        Quickshell.execDetached(["hyprctl", "reload"]);
    }

    function setGradient(i: int, c: color): void {
        const cols = gradientColours.map(x => x.slice(1));
        cols[i] = String(c).slice(1, 7);
        save({
            colors: cols.join(" ")
        });
    }

    title: Tr.tr("Window style")

    property FileView _file: FileView {
        id: file

        path: `${Paths.config}/window-style.conf`
        onLoaded: {
            const s = Object.assign({}, root.defaults);
            for (const line of text().split("\n")) {
                const m = line.match(/^\s*(\w+)\s*=\s*(.*?)\s*$/);
                if (m)
                    s[m[1]] = m[2];
            }
            root.style = s;
        }
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Windows")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Rounded window corners")
            checked: root.style.roundingon === "1"
            onToggled: root.save({
                    roundingon: checked ? "1" : "0"
                })
        }

        StepperRow {
            visible: root.style.roundingon === "1"
            label: Tr.tr("Corner rounding")
            subtext: `${root.style.rounding}%`
            value: Number(root.style.rounding)
            from: 0
            to: 100
            stepSize: 5
            onMoved: v => root.save({
                    rounding: String(Math.round(v))
                })
        }

        ToggleRow {
            text: Tr.tr("Gaps between windows")
            checked: root.style.gaps !== "0"
            onToggled: root.save({
                    gaps: checked ? "1" : "0"
                })
        }

        ToggleRow {
            text: Tr.tr("New windows open floating")
            subtext: root.style.floatnew === "1" ? Tr.tr("Floating") : Tr.tr("Tiled")
            checked: root.style.floatnew === "1"
            onToggled: root.save({
                    floatnew: checked ? "1" : "0"
                })
        }

        ToggleRow {
            text: Tr.tr("Window buttons and drag strip on floating windows")
            checked: root.style.titlebars !== "0"
            onToggled: root.save({
                    titlebars: checked ? "1" : "0"
                })
        }

        ToggleRow {
            text: Tr.tr("Resize floating windows by their border")
            checked: root.style.borderresize !== "0"
            onToggled: root.save({
                    borderresize: checked ? "1" : "0"
                })
        }

        ToggleRow {
            text: Tr.tr("Slide workspaces in with a fade")
            checked: root.style.fade === "1"
            onToggled: root.save({
                    fade: checked ? "1" : "0"
                })
        }

        ToggleRow {
            text: Tr.tr("Swipe between workspaces with three fingers")
            checked: root.style.swipe === "1"
            onToggled: root.save({
                    swipe: checked ? "1" : "0"
                })
        }

        ToggleRow {
            last: true
            text: Tr.tr("One column per screen in the scrolling layout")
            checked: root.style.columns === "1"
            onToggled: root.save({
                    columns: checked ? "1" : "0"
                })
        }

        SectionHeader {
            text: Tr.tr("Window border")
        }

        ToggleRow {
            first: true
            text: Tr.tr("Animated gradient border")
            checked: root.style.gradient === "1"
            onToggled: root.save({
                    gradient: checked ? "1" : "0"
                })
        }

        ColourRow {
            visible: root.style.gradient === "1"
            label: Tr.tr("Gradient colors")

            Repeater {
                model: root.gradientColours

                ColorWell {
                    required property string modelData
                    required property int index

                    color: modelData
                    onPicked: c => root.setGradient(index, c)
                }
            }
        }

        ColourRow {
            visible: root.style.gradient === "1"
            label: Tr.tr("Inactive windows")

            ColorWell {
                color: `#${root.style.inactive}`
                onPicked: c => root.save({
                        inactive: String(c).slice(1, 7)
                    })
            }
        }

        RowButton {
            visible: root.style.gradient === "1"
            last: true
            icon: "restart_alt"
            text: Tr.tr("Default colors")
            onClicked: root.save({
                    colors: root.defaults.colors,
                    inactive: root.defaults.inactive
                })
        }
    }

    // Label on the left, colour swatches on the right
    component ColourRow: ConnectedRect {
        id: colourRow

        property alias label: rowLabel.text
        default property alias swatches: swatchRow.data

        Layout.fillWidth: true
        implicitHeight: Math.max(rowLabel.implicitHeight, swatchRow.implicitHeight) + Tokens.padding.large * 2

        StyledText {
            id: rowLabel

            anchors.left: parent.left
            anchors.leftMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter
        }

        Row {
            id: swatchRow

            anchors.right: parent.right
            anchors.rightMargin: Tokens.padding.large
            anchors.verticalCenter: parent.verticalCenter
            spacing: Tokens.spacing.small
        }
    }
}
