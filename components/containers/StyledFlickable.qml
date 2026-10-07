import QtQuick
import qs.components

Flickable {
    id: root

    property bool doneFakeFlick

    maximumFlickVelocity: 3000

    // Momentum scrolling for wheels and touchpads
    Glide {
        flickable: root
        horizontal: root.flickableDirection === Flickable.HorizontalFlick
    }

    rebound: Transition {
        onRunningChanged: {
            if (!running && !root.doneFakeFlick) {
                root.doneFakeFlick = true;
                root.flick(1, 1);
                root.flick(-1, -1);
                Qt.callLater(() => root.cancelFlick());
            }
        }

        Anim {
            properties: "x,y"
        }
    }

    Timer {
        running: root.doneFakeFlick
        interval: 10
        onTriggered: root.doneFakeFlick = false
    }
}
