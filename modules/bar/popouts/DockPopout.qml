pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Dock: pinned and running apps. Left click focuses (cycling windows) or launches, middle click
// opens a new instance, right click opens the app's menu (as in the Witcher's Tweaks dock): its
// windows, Keep in Dock, Open at Login, Show All Windows, then Open, or New Window, Hide and Quit.
ColumnLayout {
    id: root

    required property PopoutState popouts
    readonly property int iconSize: 36

    spacing: Tokens.spacing.small

    ColumnLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.small

        Repeater {
            model: ScriptModel {
                values: Dock.apps
            }

            Item {
                id: app

                required property DesktopEntry modelData
                readonly property int windows: Dock.windowsFor(modelData).length
                readonly property bool active: Dock.entryForToplevel(Hypr.activeToplevel)?.id === modelData.id

                // The menu's rows: { label, icon, action }
                property var menuRows: []

                function openMenu(): void {
                    const entry = modelData;
                    const wins = Dock.windowsFor(entry);
                    const rows = wins.slice(0, 8).map(w => ({
                                label: w.title || entry.name,
                                icon: w === Hypr.activeToplevel ? "radio_button_checked" : Dock.isMinimized(w) ? "minimize" : "web_asset",
                                action: () => Dock.focusWindow(w)
                            }));
                    const pinned = Dock.isPinned(entry.id);
                    rows.push({
                        label: Tr.tr("Keep in Dock"),
                        icon: pinned ? "check_box" : "check_box_outline_blank",
                        action: () => Dock.togglePin(entry.id)
                    });
                    const atLogin = Dock.opensAtLogin(entry);
                    rows.push({
                        label: Tr.tr("Open at Login"),
                        icon: atLogin ? "check_box" : "check_box_outline_blank",
                        action: () => Dock.setOpensAtLogin(entry, !atLogin)
                    });
                    if (wins.length > 0)
                        rows.push({
                            label: Tr.tr("Show All Windows"),
                            icon: "view_quilt",
                            action: () => {
                                root.popouts.hasCurrent = false;
                                Dock.showAllWindows();
                            }
                        });
                    if (wins.length === 0) {
                        rows.push({
                            label: Tr.tr("Open"),
                            icon: "open_in_new",
                            action: () => Dock.launch(entry)
                        });
                    } else {
                        rows.push({
                            label: Tr.tr("New Window"),
                            icon: "add",
                            action: () => Dock.launch(entry)
                        });
                        rows.push({
                            label: Tr.tr("Hide"),
                            icon: "visibility_off",
                            action: () => Dock.minimizeAll(entry)
                        });
                        rows.push({
                            label: Tr.tr("Quit"),
                            icon: "close",
                            action: () => Dock.closeAll(entry)
                        });
                    }
                    Dock.refreshAutostart();
                    menuRows = rows;
                    appMenu.expanded = true;
                }

                implicitWidth: root.iconSize + Tokens.padding.small * 3
                implicitHeight: root.iconSize + Tokens.padding.small * 2

                Variants {
                    id: menuItems

                    model: app.menuRows

                    MenuItem {
                        required property var modelData

                        text: modelData.label
                        icon: modelData.icon
                        onClicked: modelData.action()
                    }
                }

                // Beside the app, keeping the dock open while it's up
                Menu {
                    id: appMenu

                    attachTo: tile
                    attachSideX: Menu.Right
                    thisSideX: Menu.Left
                    attachSideY: Menu.Top
                    thisSideY: Menu.Top
                    marginX: Tokens.spacing.small
                    items: menuItems.instances
                    active: null
                    onExpandedChanged: root.popouts.held = expanded
                }

                StyledRect {
                    id: tile

                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    implicitWidth: parent.implicitHeight
                    implicitHeight: implicitWidth

                    radius: Tokens.rounding.large
                    color: app.active ? Colours.palette.m3secondaryContainer : "transparent"

                    StateLayer {
                        id: tileLayer

                        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                        radius: tile.radius
                        onClicked: event => {
                            if (event.button === Qt.RightButton)
                                app.openMenu();
                            else if (event.button === Qt.MiddleButton)
                                app.modelData.execute();
                            else
                                Dock.activate(app.modelData);
                        }
                    }

                    IconImage {
                        anchors.centerIn: parent
                        implicitSize: root.iconSize
                        source: Quickshell.iconPath(app.modelData.icon, "image-missing")
                        scale: tileLayer.pressed ? 0.85 : 1

                        Behavior on scale {
                            Anim {}
                        }
                    }
                }

                // Running indicator on the left edge: one dot per window, up to three
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    spacing: 2

                    Repeater {
                        model: Math.min(app.windows, 3)

                        StyledRect {
                            implicitWidth: 4
                            implicitHeight: app.active ? 8 : 4
                            radius: 2
                            color: app.active ? Colours.palette.m3primary : Colours.palette.m3onSurfaceVariant

                            Behavior on implicitHeight {
                                Anim {}
                            }
                        }
                    }
                }
            }
        }

        // App drawer shortcut (Settings > Dock can hide it)
        Item {
            visible: Dock.showAppsButton
            implicitWidth: root.iconSize + Tokens.padding.small * 3
            implicitHeight: root.iconSize + Tokens.padding.small * 2

            StyledRect {
                id: drawerTile

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: parent.implicitHeight
                implicitHeight: implicitWidth
                radius: Tokens.rounding.large
                color: Colours.tPalette.m3surfaceContainerHigh

                StateLayer {
                    radius: drawerTile.radius
                    onClicked: {
                        root.popouts.hasCurrent = false;
                        ShellState.forActive().launcher = true;
                    }
                }

                MaterialIcon {
                    anchors.centerIn: parent
                    text: "apps"
                    fontStyle: Tokens.font.icon.large
                    color: Colours.palette.m3onSurfaceVariant
                }
            }
        }
    }
}
