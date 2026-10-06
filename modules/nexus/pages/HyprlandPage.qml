pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

// Every Hyprland option, grouped by section. Changes apply live and persist.
PageBase {
    id: root

    property string category: "general"
    property string query
    property list<string> only: [] // A fixed set of options instead of categories and search
    property bool keyboardExtras
    readonly property string kbOptions: String(HyprSettings.current("input:kb_options") ?? "")
    readonly property list<var> shown: only.length > 0 ? only.map(n => HyprSettings.options.find(o => o.name === n)).filter(o => !!o) : HyprSettings.options.filter(o => {
        if (query.length > 0)
            return o.name.toLowerCase().includes(query.toLowerCase()) || o.description.toLowerCase().includes(query.toLowerCase());
        return o.name.split(":")[0] === category;
    }).slice(0, 120)

    function title(o: var): string {
        const parts = o.name.split(":").slice(1).join(" › ").replace(/[_.]/g, " ");
        return parts.charAt(0).toUpperCase() + parts.slice(1);
    }

    function toggleKbOption(opt: string, on: bool, remove: string): void {
        const parts = kbOptions.split(",").map(p => p.trim()).filter(p => p && p !== opt && p !== remove);
        if (on)
            parts.push(opt);
        HyprSettings.set("input:kb_options", parts.join(","));
    }

    title: Tr.tr("Hyprland")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        ToggleRow {
            visible: root.keyboardExtras
            first: true
            text: Tr.tr("Swap left Ctrl and Super")
            checked: root.kbOptions.includes("ctrl:swap_lwin_lctl")
            onToggled: root.toggleKbOption("ctrl:swap_lwin_lctl", checked, "")
        }

        ToggleRow {
            visible: root.keyboardExtras
            last: true
            text: Tr.tr("Caps Lock types capitals")
            subtext: Tr.tr("Instead of acting as the compose key")
            checked: !root.kbOptions.includes("compose:caps")
            onToggled: root.toggleKbOption("compose:caps", !checked, "")
        }

        TextFieldRow {
            visible: root.only.length === 0
            first: true
            last: true
            label: Tr.tr("Search")
            placeholderText: Tr.tr("Option name or description")
            onValueEdited: v => root.query = v
        }

        Flow {
            Layout.fillWidth: true
            Layout.topMargin: Tokens.spacing.medium
            Layout.bottomMargin: Tokens.spacing.medium
            spacing: Tokens.spacing.small
            visible: root.query.length === 0 && root.only.length === 0

            Repeater {
                model: HyprSettings.categories

                TextButton {
                    required property string modelData

                    type: TextButton.Tonal
                    isToggle: true
                    checked: root.category === modelData
                    text: modelData
                    onClicked: root.category = modelData
                }
            }
        }

        StyledText {
            Layout.fillWidth: true
            visible: HyprSettings.lastError.length > 0
            text: HyprSettings.lastError
            color: Colours.palette.m3error
            wrapMode: Text.WordWrap
        }

        Repeater {
            model: root.shown

            Loader {
                id: row

                required property var modelData
                required property int index
                readonly property var value: HyprSettings.current(modelData.name)
                readonly property bool overridden: modelData.name in HyprSettings.overrides
                readonly property string sub: `${modelData.description}${modelData.map ? ` (${modelData.map.map(m => Object.entries(m)[0].reverse().join(" = ")).join(", ")})` : ""}${overridden ? Tr.tr(" · changed") : ""}`

                Layout.fillWidth: true
                sourceComponent: typeof modelData.default === "boolean" ? boolRow : typeof modelData.default === "number" ? numberRow : textRow

                Component {
                    id: boolRow

                    ToggleRow {
                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        text: root.title(row.modelData)
                        subtext: row.sub
                        checked: !!row.value
                        onToggled: HyprSettings.set(row.modelData.name, checked)
                    }
                }

                Component {
                    id: numberRow

                    StepperRow {
                        readonly property bool isFloat: !Number.isInteger(row.modelData.default) || !Number.isInteger(row.modelData.max ?? 1) || (row.modelData.max ?? 2) <= 1

                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        label: root.title(row.modelData)
                        subtext: row.sub
                        value: Number(row.value ?? 0)
                        from: row.modelData.min ?? -10000
                        to: row.modelData.max ?? 10000
                        stepSize: isFloat ? 0.05 : 1
                        onMoved: v => HyprSettings.set(row.modelData.name, isFloat ? Math.round(v * 100) / 100 : Math.round(v))
                    }
                }

                Component {
                    id: textRow

                    TextFieldRow {
                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        label: root.title(row.modelData)
                        subtext: row.sub
                        value: Array.isArray(row.value) ? row.value.join(" ") : String(row.value ?? "")
                        onEditingFinished: v => HyprSettings.set(row.modelData.name, Array.isArray(row.modelData.default) ? v.trim().split(/\s+/).map(Number) : v)
                    }
                }
            }
        }

        TextButton {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Tokens.spacing.large
            visible: Object.keys(HyprSettings.overrides).length > 0
            type: TextButton.Tonal
            text: Tr.tr("Reset %1 changed options").arg(Object.keys(HyprSettings.overrides).length)
            onClicked: {
                for (const name of Object.keys(HyprSettings.overrides))
                    HyprSettings.reset(name);
            }
        }
    }
}
