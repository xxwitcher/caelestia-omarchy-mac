import QtQuick

QtObject {
    property string currentName
    property bool hasCurrent
    // Kept open while true (a menu opened from it, like the dock's, sits outside it)
    property bool held

    signal detachRequested(mode: string)

    onHasCurrentChanged: {
        if (!hasCurrent)
            held = false;
    }
}
