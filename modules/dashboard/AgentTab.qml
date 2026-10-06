pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import QMLTermWidget
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services

// Agent tab: a real terminal running your agent. Uses omarchy-agent when present,
// otherwise claude, otherwise your shell. The session survives closing the dashboard.
Item {
    id: root

    property bool running

    implicitWidth: 760
    implicitHeight: 460

    ColumnLayout {
        anchors.fill: parent
        spacing: Tokens.spacing.small

        RowLayout {
            Layout.fillWidth: true

            MaterialIcon {
                text: "smart_toy"
                color: Colours.palette.m3primary
                fontStyle: Tokens.font.icon.large
            }

            StyledText {
                Layout.fillWidth: true
                text: root.running ? Tr.tr("Agent") : Tr.tr("Agent session ended")
                font: Tokens.font.title.small
            }

            IconButton {
                icon: "restart_alt"
                type: IconButton.Tonal
                onClicked: {
                    terminalLoader.active = false;
                    terminalLoader.active = true;
                }
            }
        }

        StyledClippingRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Tokens.rounding.large
            color: Colours.tPalette.m3surfaceContainerLowest

            Loader {
                id: terminalLoader

                anchors.fill: parent
                anchors.margins: Tokens.padding.medium

                sourceComponent: QMLTermWidget {
                    id: terminal

                    font.family: "CaskaydiaCove NF"
                    font.pointSize: Tokens.font.body.medium.pointSize
                    colorScheme: "DarkPastels"
                    blinkingCursor: true
                    enableBold: true
                    antialiasText: true
                    focus: true

                    session: QMLTermSession {
                        id: agentSession

                        initialWorkingDirectory: Quickshell.env("HOME")
                        shellProgram: "sh"
                        shellProgramArgs: ["-c", "if command -v omarchy-agent >/dev/null; then exec omarchy-agent --inline --pick; elif command -v claude >/dev/null; then exec claude; else exec \"${SHELL:-bash}\"; fi"]
                        onFinished: root.running = false
                    }

                    Component.onCompleted: {
                        agentSession.startShellProgram();
                        root.running = true;
                        forceActiveFocus();
                    }

                    QMLTermScrollbar {
                        terminal: terminal
                        width: 6

                        StyledRect {
                            anchors.fill: parent
                            radius: width / 2
                            color: Colours.palette.m3onSurfaceVariant
                            opacity: 0.35
                        }
                    }
                }
            }
        }
    }
}
