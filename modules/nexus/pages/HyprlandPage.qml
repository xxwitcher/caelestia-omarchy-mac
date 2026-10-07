pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io
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

    // Text options with a known set of values, beyond the ones their description lists
    readonly property var knownChoices: ({
            "master:new_status": ["master", "slave", "inherit"],
            "master:new_on_active": ["none", "before", "after"],
            "master:orientation": ["left", "right", "top", "bottom", "center"],
            "master:center_master_fallback": ["left", "right", "top", "bottom"],
            "scrolling:direction": ["right", "left", "down", "up"]
        })
    readonly property list<string> monitorOptions: ["input:touchdevice:output", "input:tablet:output", "cursor:default_monitor"]
    readonly property list<string> fontOptions: ["misc:font_family", "misc:splash_font_family", "group:groupbar:font_family"]
    readonly property list<string> weightOptions: ["group:groupbar:font_weight_active", "group:groupbar:font_weight_inactive"]
    property list<string> fontFamilies: []

    // The values a text option can take ([{ value, label }]), or [] for free text
    function choicesFor(o: var): var {
        const named = v => ({
                value: v,
                label: v ? v.replace(/_/g, " ") : Tr.tr("Default")
            });
        if (monitorOptions.includes(o.name))
            return [
                {
                    value: "",
                    label: Tr.tr("Automatic")
                }
            ].concat(Hypr.monitors.values.map(m => ({
                        value: m.name,
                        label: m.name
                    })));
        if (fontOptions.includes(o.name))
            return [
                {
                    value: "",
                    label: Tr.tr("Default")
                }
            ].concat(fontFamilies.map(f => ({
                        value: f,
                        label: f
                    })));
        if (weightOptions.includes(o.name))
            return [100, 200, 300, 400, 500, 600, 700, 800, 900].map(w => ({
                        value: String(w),
                        label: String(w)
                    }));
        if (o.name in knownChoices)
            return knownChoices[o.name].map(named);
        // "... [adaptive/flat/custom]": the values, without placeholders like lua:<name>
        const listed = o.description.match(/\[([^\]]+\/[^\]]+)\]/);
        if (listed && typeof o.default === "string") {
            const values = listed[1].split("/").map(v => v.trim()).filter(v => v && !v.includes("<"));
            const empty = String(o.default) === "[[EMPTY]]" || o.default === "";
            return (empty ? [""] : []).concat(values).map(named);
        }
        return [];
    }

    // Gap options ("5 5 5 5" or a number), set as one value for every side
    function isGap(o: var): bool {
        return /gaps/.test(o.name) && /^\d+( \d+){0,3}$/.test(String(o.default));
    }

    // A single colour option's value ("AARRGGBB 0deg", or rgba() once changed here) as { rgb, a }
    function parseColour(value: var): var {
        const s = String(value ?? "");
        let m = s.match(/^([0-9a-f]{2})([0-9a-f]{6})(\s+-?\d+deg)?$/i);
        if (m)
            return {
                rgb: m[2],
                a: m[1]
            };
        m = s.match(/^rgba\(([0-9a-f]{6})([0-9a-f]{2})\)$/i);
        if (m)
            return {
                rgb: m[1],
                a: m[2]
            };
        m = s.match(/^rgb\(([0-9a-f]{6})\)$/i);
        return m ? {
            rgb: m[1],
            a: "ff"
        } : null;
    }

    function isColour(o: var, value: var): bool {
        return /(^|[._])col(or|our)?([._]|$)|color/.test(o.name.split(":").pop()) && (parseColour(value) !== null || String(value) === "-1");
    }

    function toggleKbOption(opt: string, on: bool, remove: string): void {
        const parts = kbOptions.split(",").map(p => p.trim()).filter(p => p && p !== opt && p !== remove);
        if (on)
            parts.push(opt);
        HyprSettings.set("input:kb_options", parts.join(","));
    }

    title: Tr.tr("Hyprland")

    property Process _fonts: Process {
        running: true
        command: ["sh", "-c", "fc-list : family | cut -d, -f1 | sort -u"]
        stdout: StdioCollector {
            onStreamFinished: root.fontFamilies = text.split("\n").filter(f => f)
        }
    }

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
                readonly property var choices: root.choicesFor(modelData)
                readonly property bool ranged: typeof modelData.default === "number" && modelData.min !== undefined && modelData.max !== undefined && modelData.max - modelData.min <= 1000

                sourceComponent: typeof modelData.default === "boolean" ? boolRow : modelData.map ? choiceRow : ranged ? rangeRow : typeof modelData.default === "number" ? numberRow : root.isColour(modelData, value) ? colourRow : root.isGap(modelData) ? gapRow : choices.length > 0 ? textChoiceRow : textRow

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

                // Numbers within a range: a slider
                Component {
                    id: rangeRow

                    RangeRow {
                        readonly property bool isFloat: !Number.isInteger(row.modelData.default) || !Number.isInteger(row.modelData.max) || row.modelData.max - row.modelData.min <= 2

                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        label: root.title(row.modelData)
                        from: row.modelData.min
                        to: row.modelData.max
                        step: isFloat ? (row.modelData.max - row.modelData.min) / 100 : 1
                        current: Number(row.value ?? row.modelData.default)
                        format: v => isFloat ? String(Math.round(v * 100) / 100) : String(Math.round(v))
                        onCommitted: v => HyprSettings.set(row.modelData.name, isFloat ? Math.round(v * 100) / 100 : Math.round(v))
                    }
                }

                // Gaps: one slider for every side
                Component {
                    id: gapRow

                    RangeRow {
                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        label: root.title(row.modelData)
                        from: 0
                        to: 60
                        step: 1
                        current: Number(String(Array.isArray(row.value) ? row.value[0] : row.value ?? 0).split(" ")[0]) || 0
                        format: v => `${Math.round(v)} px`
                        onCommitted: v => HyprSettings.set(row.modelData.name, Math.round(v))
                    }
                }

                // Text options with a known set of values: picked from them
                Component {
                    id: textChoiceRow

                    ChoiceRow {
                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        label: root.title(row.modelData)
                        subtext: row.sub
                        options: row.choices
                        current: ["[[EMPTY]]", "[[Auto]]"].includes(String(row.value ?? "")) ? "" : String(row.value ?? "")
                        onChosen: v => HyprSettings.set(row.modelData.name, v)
                    }
                }

                // Options with named values: picked from them
                Component {
                    id: choiceRow

                    ChoiceRow {
                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        label: root.title(row.modelData)
                        subtext: row.sub
                        options: row.modelData.map.map(m => {
                            const [name, value] = Object.entries(m)[0];
                            return {
                                value: Number(value),
                                label: name.replace(/_/g, " ")
                            };
                        }).sort((a, b) => a.value - b.value)
                        current: Number(row.value ?? 0)
                        onChosen: v => HyprSettings.set(row.modelData.name, v)
                    }
                }

                // Colours: picked, keeping their transparency
                Component {
                    id: colourRow

                    ConnectedRect {
                        id: colourRect

                        readonly property var colour: root.parseColour(row.value)

                        first: row.index === 0
                        last: row.index === root.shown.length - 1
                        implicitHeight: colourLayout.implicitHeight + Tokens.padding.medium * 2

                        RowLayout {
                            id: colourLayout

                            anchors.fill: parent
                            anchors.margins: Tokens.padding.medium
                            anchors.leftMargin: Tokens.padding.largeIncreased
                            anchors.rightMargin: Tokens.padding.largeIncreased
                            spacing: Tokens.spacing.medium

                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                StyledText {
                                    Layout.fillWidth: true
                                    text: root.title(row.modelData)
                                    font: Tokens.font.body.small
                                    elide: Text.ElideRight
                                }

                                StyledText {
                                    Layout.fillWidth: true
                                    text: row.sub
                                    color: Colours.palette.m3outline
                                    font: Tokens.font.label.small
                                    elide: Text.ElideRight
                                }
                            }

                            ColorWell {
                                color: colourRect.colour ? `#${colourRect.colour.rgb}` : Colours.palette.m3outline
                                onPicked: c => HyprSettings.set(row.modelData.name, `rgba(${String(c).slice(1, 7)}${colourRect.colour?.a ?? "ff"})`)
                            }
                        }
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
