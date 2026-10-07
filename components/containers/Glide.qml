import QtQuick

// Momentum scrolling, as the Witcher's Tweaks app drawer and settings do it: a touchpad scroll
// follows the fingers and keeps gliding once they lift (the compositor sends no momentum of its
// own), slowing with friction; a mouse wheel notch pushes the view into the same glide, adding up
// when spun. At an edge the scroll goes on to whatever scrolls around it.
// Declare one inside a Flickable or ListView (StyledFlickable and StyledListView have one): it sits
// behind the content, so items and nested scroll views get the wheel first, and it only takes the
// wheel (clicks and hover go through).
MouseArea {
    id: root

    required property Flickable flickable
    property bool horizontal

    property real velocity
    property double lastAt
    readonly property real friction: 3.4
    readonly property real speed: 1.4

    function lowest(): real {
        return horizontal ? flickable.originX - flickable.leftMargin : flickable.originY - flickable.topMargin;
    }

    function highest(): real {
        const end = horizontal ? flickable.originX + flickable.contentWidth + flickable.rightMargin - flickable.width : flickable.originY + flickable.contentHeight + flickable.bottomMargin - flickable.height;
        return Math.max(lowest(), end);
    }

    function position(): real {
        return horizontal ? flickable.contentX : flickable.contentY;
    }

    // Moves by d pixels within the bounds; false when it couldn't move at all
    function moveBy(d: real): bool {
        const to = Math.max(lowest(), Math.min(highest(), position() + d));
        if (Math.abs(to - position()) < 0.01)
            return false;
        if (horizontal)
            flickable.contentX = to;
        else
            flickable.contentY = to;
        return true;
    }

    anchors.fill: parent
    z: -1
    enabled: flickable.interactive
    acceptedButtons: Qt.NoButton

    onWheel: event => {
        const along = horizontal ? Math.abs(event.angleDelta.x) >= Math.abs(event.angleDelta.y) || flickable.contentHeight <= flickable.height : Math.abs(event.angleDelta.y) >= Math.abs(event.angleDelta.x);
        const pixels = horizontal ? (event.pixelDelta.x || event.pixelDelta.y) : event.pixelDelta.y;
        const angle = horizontal ? (event.angleDelta.x || event.angleDelta.y) : event.angleDelta.y;
        const now = Date.now();

        // The touchpad marks a scroll's start and end with events that move nothing; the end one
        // means the fingers lifted
        if (pixels === 0 && angle === 0) {
            if (event.phase === Qt.ScrollEnd) {
                lift.stop();
                glide.running = Math.abs(velocity) > 60;
            } else if (event.phase === Qt.ScrollBegin) {
                glide.running = false;
                velocity = 0;
            }
            return;
        }

        if (!along) {
            event.accepted = false;
            return;
        }

        if (pixels !== 0 || angle % 120 !== 0) {
            // Fingers on the touchpad: follow them, and track their speed
            const d = (pixels !== 0 ? -pixels : -angle / 3) * speed;
            const dt = Math.max(4, now - lastAt);
            const v = d * 1000 / dt;
            velocity = now - lastAt > 120 ? v : velocity * 0.5 + v * 0.5;
            lastAt = now;
            glide.running = false;
            if (!moveBy(d)) {
                event.accepted = false;
                return;
            }
            lift.restart();
        } else {
            // A mouse wheel notch: a push into the glide (none at the edge it pushes against)
            const push = -angle / 120 * 1400;
            if ((push < 0 && position() <= lowest() + 0.5) || (push > 0 && position() >= highest() - 0.5)) {
                event.accepted = false;
                return;
            }
            velocity = glide.running && Math.sign(push) === Math.sign(velocity) ? velocity + push : push;
            glide.running = true;
        }
    }

    // The fingers lifted (no events for a moment): glide
    property Timer _lift: Timer {
        id: lift

        interval: 50
        onTriggered: glide.running = Math.abs(root.velocity) > 60
    }

    property FrameAnimation _glide: FrameAnimation {
        id: glide

        onTriggered: {
            if (!root.moveBy(root.velocity * frameTime)) {
                running = false;
                return;
            }
            root.velocity *= Math.exp(-root.friction * frameTime);
            if (Math.abs(root.velocity) < 20)
                running = false;
        }
    }
}
