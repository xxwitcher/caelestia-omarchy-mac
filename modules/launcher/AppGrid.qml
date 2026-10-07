pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Widgets
import Caelestia.Config
import qs.components
import qs.components.containers
import qs.components.controls
import qs.services
import qs.modules.launcher.services

// App drawer: apps as a grid of icons, filtered by the search text
GridView {
    id: root

    // Momentum scrolling for wheels and touchpads
    Glide {
        flickable: root
    }

    required property var search
    required property ScreenState screenState
    readonly property int columns: 6
    readonly property int rows: Math.min(4, Math.ceil(count / columns))

    model: ScriptModel {
        values: Apps.search(root.search.text)
        onValuesChanged: root.currentIndex = 0
    }

    clip: true
    cellWidth: width / columns
    cellHeight: Math.round(cellWidth * 1.05)
    implicitHeight: cellHeight * rows
    keyNavigationWraps: true
    highlightFollowsCurrentItem: false

    highlight: StyledRect {
        radius: Tokens.rounding.large
        color: Colours.palette.m3onSurface
        opacity: 0.08
        x: root.currentItem?.x ?? 0
        y: root.currentItem?.y ?? 0
        implicitWidth: root.cellWidth
        implicitHeight: root.cellHeight

        Behavior on x {
            Anim {}
        }
        Behavior on y {
            Anim {}
        }
    }

    delegate: Item {
        id: app

        required property DesktopEntry modelData
        required property int index

        implicitWidth: root.cellWidth
        implicitHeight: root.cellHeight

        StateLayer {
            radius: Tokens.rounding.large
            onClicked: {
                Apps.launch(app.modelData);
                root.screenState.launcher = false;
            }
        }

        IconImage {
            id: icon

            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: parent.top
            anchors.topMargin: Tokens.padding.medium
            implicitSize: Math.round(root.cellWidth * 0.5)
            source: Quickshell.iconPath(app.modelData.icon, "image-missing")
        }

        StyledText {
            anchors.top: icon.bottom
            anchors.topMargin: Tokens.spacing.small
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Tokens.padding.small
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
            text: app.modelData.name
            font: Tokens.font.label.medium
        }
    }
}
