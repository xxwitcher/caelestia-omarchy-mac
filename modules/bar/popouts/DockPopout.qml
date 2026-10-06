pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services

// Dock: pinned and running apps. Left click focuses (cycling windows) or launches,
// middle click opens a new instance, right click pins/unpins.
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

                implicitWidth: root.iconSize + Tokens.padding.small * 3
                implicitHeight: root.iconSize + Tokens.padding.small * 2

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
                                Dock.togglePin(app.modelData.id);
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

        // App drawer shortcut
        Item {
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
