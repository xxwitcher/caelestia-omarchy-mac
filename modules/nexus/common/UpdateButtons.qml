import QtQuick
import QtQuick.Layouts
import Caelestia.Config
import Caelestia.I18n
import qs.components.controls
import qs.services

// Check again and Update now (UpdatesPage, UpdatesListPage)
RowLayout {
    Layout.alignment: Qt.AlignHCenter
    Layout.bottomMargin: Tokens.spacing.large
    spacing: Tokens.spacing.medium

    TextButton {
        type: TextButton.Tonal
        text: Tr.tr("Check again")
        onClicked: Updates.check()
    }

    TextButton {
        text: Tr.tr("Update now")
        onClicked: Updates.update()
    }
}
