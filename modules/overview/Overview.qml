pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.containers
import qs.components.misc
import qs.services

// Window overview: live previews of the active workspace's windows in a grid, and a
// workspace strip on top. Click a window to focus it, middle click to close it.
// Toggle with the caelestia:overview shortcut or `caelestia-qs -c caelestia ipc call overview toggle`.
Scope {
    id: root

    property bool closing

    function open(): void {
        closing = false;
        loader.activeAsync = true;
    }

    function close(): void {
        closing = true;
        closeTimer.restart();
    }

    function toggle(): void {
        if (loader.active && !closing)
            close();
        else
            open();
    }

    function focusWindow(toplevel: var): void {
        const addr = `address:0x${toplevel.address}`;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "${addr}" })` : `focuswindow ${addr}`);
        close();
    }

    function aspectOf(toplevel: var): real {
        const size = toplevel?.lastIpcObject?.size ?? [16, 10];
        return Math.max(0.2, Math.min(5, size[0] / Math.max(1, size[1])));
    }

    function closeWindow(toplevel: var): void {
        const addr = `address:0x${toplevel.address}`;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "${addr}" })` : `closewindow ${addr}`);
    }

    Timer {
        id: closeTimer

        interval: Tokens.anim.durations.normal
        onTriggered: loader.active = false
    }

    LazyLoader {
        id: loader

        Variants {
            model: Screens.screens

            StyledWindow {
                id: win

                required property ShellScreen modelData
                readonly property HyprlandMonitor monitor: Hypr.monitorFor(modelData)
                readonly property list<var> windows: Hypr.toplevels.values.filter(t => t.workspace?.id === monitor?.activeWorkspace?.id && !Hypr.isToplevelIgnored(t)).sort((a, b) => ((a.lastIpcObject?.at?.[0] ?? 0) - (b.lastIpcObject?.at?.[0] ?? 0)) || ((a.lastIpcObject?.at?.[1] ?? 0) - (b.lastIpcObject?.at?.[1] ?? 0)))
                readonly property list<var> workspaces: Hypr.workspaces.values.filter(w => w.id > 0 && w.monitor === monitor).sort((a, b) => a.id - b.id)
                property int selected: Math.max(0, windows.findIndex(w => w === Hypr.activeToplevel))
                property real shown: root.closing ? 0 : 1

                screen: modelData
                name: "overview"
                color: "transparent"
                WlrLayershell.exclusionMode: ExclusionMode.Ignore
                WlrLayershell.layer: WlrLayer.Overlay
                WlrLayershell.keyboardFocus: root.closing ? WlrKeyboardFocus.None : WlrKeyboardFocus.Exclusive

                anchors.top: true
                anchors.bottom: true
                anchors.left: true
                anchors.right: true

                Component.onCompleted: shown = Qt.binding(() => root.closing ? 0 : 1)

                Behavior on shown {
                    Anim {
                        type: Anim.DefaultSpatial
                    }
                }

                StyledRect {
                    anchors.fill: parent
                    color: Qt.alpha(Colours.palette.m3surface, 0.94)
                    opacity: win.shown

                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.close()
                    }
                }

                Item {
                    id: content

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.extraLarge * 2
                    opacity: win.shown
                    scale: 0.92 + 0.08 * win.shown
                    focus: true

                    Keys.onEscapePressed: root.close()
                    Keys.onLeftPressed: win.selected = Math.max(0, win.selected - 1)
                    Keys.onRightPressed: win.selected = Math.min(win.windows.length - 1, win.selected + 1)
                    Keys.onReturnPressed: {
                        if (win.windows[win.selected])
                            root.focusWindow(win.windows[win.selected]);
                    }

                    // Workspace strip
                    Row {
                        id: strip

                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: Tokens.spacing.medium

                        Repeater {
                            model: win.workspaces

                            StyledRect {
                                id: wsCard

                                required property var modelData
                                readonly property bool active: modelData.id === win.monitor?.activeWorkspace?.id

                                implicitWidth: 180
                                implicitHeight: implicitWidth * (win.height / Math.max(1, win.width))
                                radius: Tokens.rounding.large
                                color: active ? Colours.palette.m3primaryContainer : Colours.tPalette.m3surfaceContainer
                                border.width: active ? 2 : 0
                                border.color: Colours.palette.m3primary

                                StateLayer {
                                    radius: wsCard.radius
                                    onClicked: {
                                        Hypr.focusWorkspace(wsCard.modelData.id);
                                        root.close();
                                    }
                                }

                                Row {
                                    anchors.centerIn: parent
                                    spacing: Tokens.spacing.extraSmall

                                    Repeater {
                                        model: wsCard.modelData.toplevels.values.slice(0, 4)

                                        Image {
                                            required property var modelData

                                            width: 22
                                            height: 22
                                            sourceSize: Qt.size(22, 22)
                                            source: Quickshell.iconPath(DesktopEntries.heuristicLookup(modelData.lastIpcObject?.class ?? "")?.icon ?? "", "image-missing")
                                        }
                                    }
                                }

                                StyledText {
                                    anchors.left: parent.left
                                    anchors.top: parent.top
                                    anchors.margins: Tokens.padding.small
                                    text: wsCard.modelData.name
                                    font: Tokens.font.label.medium
                                    color: wsCard.active ? Colours.palette.m3onPrimaryContainer : Colours.palette.m3onSurfaceVariant
                                }
                            }
                        }
                    }

                    // Window grid: however many rows makes the windows biggest, keeping their
                    // order (left to right) and aspect ratios; each row is centred
                    Item {
                        id: area

                        readonly property int gap: Tokens.spacing.extraLarge
                        readonly property int titleHeight: 28
                        readonly property var grid: {
                            const list = win.windows;
                            const n = list.length;
                            if (n === 0 || width <= 0 || height <= 0)
                                return { height: 0, rows: [] };
                            let best = { height: 0, rows: [] };
                            for (let rowCount = 1; rowCount <= n; rowCount++) {
                                const perRow = Math.ceil(n / rowCount);
                                const rows = [];
                                for (let i = 0; i < n; i += perRow)
                                    rows.push([...Array(Math.min(n, i + perRow) - i).keys()].map(k => k + i));
                                let h = (height - rows.length * titleHeight - (rows.length - 1) * gap) / rows.length;
                                for (const row of rows)
                                    h = Math.min(h, (width - (row.length - 1) * gap) / row.reduce((a, i) => a + root.aspectOf(list[i]), 0));
                                if (h > best.height)
                                    best = { height: h, rows };
                            }
                            best.height = Math.floor(Math.min(best.height, height * 0.8));
                            return best;
                        }

                        anchors.top: strip.bottom
                        anchors.topMargin: Tokens.padding.extraLarge * 2
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom

                        Column {
                            anchors.centerIn: parent
                            spacing: area.gap

                            Repeater {
                                model: area.grid.rows

                                Row {
                                    id: gridRow

                                    required property var modelData

                                    anchors.horizontalCenter: parent.horizontalCenter
                                    spacing: area.gap

                                    Repeater {
                                        model: gridRow.modelData

                                        Item {
                                            id: card

                                            required property int modelData
                                            readonly property var toplevel: win.windows[modelData]
                                            readonly property bool selected: win.selected === modelData

                                            width: Math.round(area.grid.height * root.aspectOf(toplevel))
                                            height: area.grid.height + area.titleHeight

                                            StyledClippingRect {
                                                id: preview

                                                width: parent.width
                                                height: area.grid.height
                                                radius: Tokens.rounding.large
                                                color: Colours.tPalette.m3surfaceContainer
                                                border.width: card.selected ? 3 : 0
                                                border.color: Colours.palette.m3primary
                                                scale: card.selected ? 1.03 : 1

                                                Behavior on scale {
                                                    Anim {}
                                                }

                                                ScreencopyView {
                                                    id: capture

                                                    anchors.fill: parent
                                                    captureSource: card.toplevel?.wayland ?? null
                                                    live: true
                                                    constraintSize: Qt.size(width, height)
                                                }

                                                // Windows the compositor won't hand over show their app icon
                                                Image {
                                                    visible: !capture.hasContent
                                                    anchors.centerIn: parent
                                                    width: Math.min(parent.width, parent.height) * 0.4
                                                    height: width
                                                    sourceSize: Qt.size(width * 2, height * 2)
                                                    fillMode: Image.PreserveAspectFit
                                                    source: Quickshell.iconPath(DesktopEntries.heuristicLookup(card.toplevel?.lastIpcObject?.class ?? "")?.icon ?? "", "image-missing")
                                                }

                                                MouseArea {
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    acceptedButtons: Qt.LeftButton | Qt.MiddleButton
                                                    onEntered: win.selected = card.modelData
                                                    onClicked: event => {
                                                        if (event.button === Qt.MiddleButton)
                                                            root.closeWindow(card.toplevel);
                                                        else
                                                            root.focusWindow(card.toplevel);
                                                    }
                                                }
                                            }

                                            StyledText {
                                                anchors.top: preview.bottom
                                                anchors.topMargin: Tokens.spacing.small
                                                anchors.horizontalCenter: parent.horizontalCenter
                                                width: Math.min(implicitWidth, parent.width)
                                                elide: Text.ElideRight
                                                text: card.toplevel?.title ?? ""
                                                color: card.selected ? Colours.palette.m3primary : Colours.palette.m3onSurface
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    StyledText {
                        anchors.centerIn: area
                        visible: win.windows.length === 0
                        text: Tr.tr("No windows on this workspace")
                        color: Colours.palette.m3onSurfaceVariant
                        font: Tokens.font.title.medium
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "overview"

        function toggle(): void {
            root.toggle();
        }

        function open(): void {
            root.open();
        }

        function close(): void {
            root.close();
        }
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overview"
        description: "Toggle window overview"
        onPressed: root.toggle()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overviewOpen"
        description: "Open window overview"
        onPressed: root.open()
    }

    // qmllint disable unresolved-type
    CustomShortcut {
        // qmllint enable unresolved-type
        name: "overviewClose"
        description: "Close window overview"
        onPressed: {
            if (loader.active)
                root.close();
        }
    }
}
