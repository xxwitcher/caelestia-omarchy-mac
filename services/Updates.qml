pragma Singleton

import Quickshell
import Quickshell.Io
import Caelestia.Config

// Pending package updates (checkupdates, and yay's AUR ones), for the Updates settings: the page
// in General and its full list share them
Singleton {
    id: root

    property list<string> pending: []
    property bool checking

    function check(): void {
        checking = true;
        proc.running = true;
    }

    // In a terminal: omarchy-update when Omarchy is installed (Omarchy and the system), otherwise
    // yay or pacman
    function update(): void {
        Quickshell.execDetached(["sh", "-c", `exec ${GlobalConfig.general.apps.terminal.join(" ")} -e sh -c 'if command -v omarchy-update >/dev/null; then omarchy-update; elif command -v yay >/dev/null; then yay -Syu; else sudo pacman -Syu; fi; echo; read -p "Done. Press Enter to close" _'`]);
    }

    Process {
        id: proc

        command: ["sh", "-c", "checkupdates 2>/dev/null; command -v yay >/dev/null && yay -Qua 2>/dev/null; true"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.pending = text.split("\n").filter(l => l.trim().length > 0);
                root.checking = false;
            }
        }
    }
}
