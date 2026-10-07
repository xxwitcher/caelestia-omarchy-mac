pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils

// Dock: pinned and running apps, then the Trash, Settings and the apps button at the bottom
// (Settings > Dock shows or hides those three). Left click focuses (cycling windows) or launches, middle click
// opens a new instance, right click opens the app's menu (as in the Witcher's Tweaks dock): its
// windows, Keep in Dock, Open at Login, Show All Windows, then Open, or New Window, Hide and Quit.
// Apps are dragged up and down to rearrange them, in from the app drawer to pin them, and onto
// the Trash to take them out of the dock.
ColumnLayout {
    id: root

    required property PopoutState popouts
    readonly property int iconSize: 36
    readonly property int tileHeight: iconSize + Tokens.padding.small * 2
    readonly property bool trashFull: trashFiles.count > 0

    // Where an app dragged over this dock would land (Dock.dropIndex, Dock.overTrash)
    function updateDrop(): void {
        const win = QsWindow.window as QsWindow;
        if (!Dock.dragApp || !win || Dock.dragWindow !== win)
            return;

        const t = trashTile.mapFromItem(win.contentItem, Dock.dragPos.x, Dock.dragPos.y);
        const overTrash = trashTile.visible && t.x >= 0 && t.y >= 0 && t.x <= trashTile.width && t.y <= trashTile.height;
        // Only an app the dock keeps can be taken out of it
        Dock.overTrash = overTrash && Dock.pinnedApps.some(e => e.id === Dock.dragApp.id);

        const p = appColumn.mapFromItem(win.contentItem, Dock.dragPos.x, Dock.dragPos.y);
        const slack = Tokens.padding.large * 2;
        if (overTrash || p.x < -slack || p.x > appColumn.width + slack || p.y < -slack || p.y > root.height + slack) {
            Dock.dropIndex = -1;
            return;
        }
        // Tiles are all the same height, so the slot under the pointer doesn't move as the dock
        // makes room; below the pinned apps it lands at their end
        const slot = Math.floor(p.y / (root.tileHeight + appColumn.spacing));
        const pins = Dock.pinnedApps.filter(e => e.id !== Dock.dragApp.id).length;
        Dock.dropIndex = Math.max(0, Math.min(slot, pins));
    }

    spacing: Tokens.spacing.small

    Component.onCompleted: updateDrop()
    Component.onDestruction: {
        if (Dock.dragApp && Dock.dragWindow === QsWindow.window) {
            Dock.dropIndex = -1;
            Dock.overTrash = false;
        }
    }

    Connections {
        function onDragPosChanged(): void {
            root.updateDrop();
        }

        function onDragAppChanged(): void {
            root.updateDrop();
        }

        target: Dock
    }

    FolderListModel {
        id: trashFiles

        folder: `file://${Quickshell.env("XDG_DATA_HOME") || `${Paths.home}/.local/share`}/Trash/files`
        showDirs: true
        showHidden: true
        showDotAndDotDot: false
    }

    ColumnLayout {
        id: appColumn

        Layout.alignment: Qt.AlignHCenter
        spacing: Tokens.spacing.small

        Repeater {
            model: ScriptModel {
                values: Dock.apps
            }

            AppTile {}
        }

        // Room for an app dragged in from the app drawer
        Item {
            visible: Dock.previewApps.length > Dock.apps.length
            implicitWidth: 1
            implicitHeight: root.tileHeight
        }


        // Trash: opens in the file manager, and its menu empties it; an app dropped on it leaves
        // the dock (Settings > Dock can hide it)
        Item {
            id: trashItem

            property var menuRows: []

            visible: Dock.showTrash
            implicitWidth: root.iconSize + Tokens.padding.small * 3
            implicitHeight: root.tileHeight

            Variants {
                id: trashMenuItems

                model: trashItem.menuRows

                MenuItem {
                    required property var modelData

                    text: modelData.label
                    icon: modelData.icon
                    onClicked: modelData.action()
                }
            }

            Menu {
                id: trashMenu

                attachTo: trashTile
                attachSideX: Menu.Right
                thisSideX: Menu.Left
                attachSideY: Menu.Top
                thisSideY: Menu.Top
                marginX: Tokens.spacing.small
                items: trashMenuItems.instances
                active: null
                onExpandedChanged: root.popouts.held = expanded
            }

            StyledRect {
                id: trashTile

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: parent.implicitHeight
                implicitHeight: implicitWidth
                radius: Tokens.rounding.large
                color: Dock.overTrash ? Colours.palette.m3errorContainer : "transparent"
                scale: Dock.overTrash ? 1.15 : 1

                Behavior on scale {
                    Anim {}
                }

                StateLayer {
                    id: trashLayer

                    acceptedButtons: Qt.LeftButton | Qt.RightButton
                    radius: trashTile.radius
                    onClicked: event => {
                        if (event.button === Qt.RightButton) {
                            const rows = [
                                {
                                    label: Tr.tr("Open"),
                                    icon: "open_in_new",
                                    action: () => {
                                        root.popouts.hasCurrent = false;
                                        Dock.openTrash();
                                    }
                                }
                            ];
                            if (root.trashFull)
                                rows.push({
                                    label: Tr.tr("Empty Trash"),
                                    icon: "delete_forever",
                                    action: () => Dock.emptyTrash()
                                });
                            trashItem.menuRows = rows;
                            trashMenu.expanded = true;
                        } else {
                            root.popouts.hasCurrent = false;
                            Dock.openTrash();
                        }
                    }
                }

                IconImage {
                    anchors.centerIn: parent
                    implicitSize: root.iconSize
                    source: Quickshell.iconPath(root.trashFull ? "user-trash-full" : "user-trash", "user-trash")
                    scale: trashLayer.pressed ? 0.85 : 1

                    Behavior on scale {
                        Anim {}
                    }
                }
            }
        }

        // Settings in its own place (Settings > Dock can hide it)
        Loader {
            active: Dock.settingsApp !== null
            visible: active

            sourceComponent: AppTile {
                modelData: Dock.settingsApp
                index: -1
            }
        }

        // App drawer shortcut (Settings > Dock can hide it)
        Item {
            visible: Dock.showAppsButton
            implicitWidth: root.iconSize + Tokens.padding.small * 3
            implicitHeight: root.tileHeight

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

    component AppTile: Item {
        id: app

        required property DesktopEntry modelData
        required property int index // -1 for Settings in its own place
        readonly property int windows: Dock.windowsFor(modelData).length
        readonly property bool active: Dock.entryForToplevel(Hypr.activeToplevel)?.id === modelData.id
        readonly property bool dragged: Dock.dragApp?.id === modelData.id
        // Slots this app moves by to make room for an app being dragged: the list itself stays put
        // while dragging (rebuilding it would take the dragged tile, and its drag, away)
        readonly property int shift: {
            const i = Dock.previewApps.indexOf(modelData);
            return index < 0 || i < 0 ? 0 : i - index;
        }

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
            if (index >= 0)
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
        implicitHeight: root.tileHeight
        // The dragged app's place (the app itself follows the pointer)
        opacity: dragged ? 0.35 : 1
        transform: Translate {
            y: app.shift * (root.tileHeight + appColumn.spacing)

            Behavior on y {
                Anim {}
            }
        }

        Behavior on opacity {
            Anim {}
        }

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

            AppDragLayer {
                id: tileLayer

                entry: app.modelData
                draggable: app.index >= 0
                acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
                radius: tile.radius
                onActivated: event => {
                    if (event.button === Qt.RightButton)
                        app.openMenu();
                    else if (event.button === Qt.MiddleButton)
                        app.modelData.execute();
                    else if (app.modelData.id === Dock.settingsId && app.windows === 0)
                        // Settings opens as the overlay over everything (a Settings window
                        // popped out of it is focused like any app's)
                        root.popouts.detachRequested("appearance");
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
