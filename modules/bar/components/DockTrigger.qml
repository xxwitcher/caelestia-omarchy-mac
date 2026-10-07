pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.services

// Bar entry that opens the dock popout on hover: a pill with the first few dock apps, nothing else
StyledRect {
    id: root

    readonly property int iconSize: Math.round(Tokens.font.body.large.pointSize * 1.6)

    implicitWidth: iconSize + Tokens.padding.small * 2
    implicitHeight: column.implicitHeight + Tokens.padding.small * 2

    radius: Tokens.rounding.full
    color: Colours.tPalette.m3surfaceContainer

    Column {
        id: column

        anchors.centerIn: parent
        spacing: Tokens.spacing.small

        Repeater {
            model: ScriptModel {
                values: Dock.apps.slice(0, 4)
            }

            IconImage {
                required property DesktopEntry modelData

                implicitSize: root.iconSize
                source: Quickshell.iconPath(modelData.icon, "image-missing")
            }
        }
    }

    Behavior on implicitHeight {
        Anim {}
    }
}
