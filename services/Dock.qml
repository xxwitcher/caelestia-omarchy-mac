pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.utils
import qs.modules.launcher.services as Launcher

Singleton {
    id: root

    readonly property list<string> pinned: adapter.pinned
    // The app drawer button at the end of the dock
    readonly property bool showAppsButton: adapter.showAppsButton
    // Desktop ids that open at login (~/.config/autostart)
    property list<string> autostart: []
    // Caelestia's own windows (Settings and its file picker) carry Quickshell's app id, whose desktop
    // entry launches nothing; in the dock they're Caelestia Settings, which opens Settings again
    readonly property string settingsId: "caelestia-settings"

    function setShowAppsButton(show: bool): void {
        adapter.showAppsButton = show;
    }

    function move(id: string, by: int): void {
        const list = [...adapter.pinned];
        const i = list.indexOf(id);
        const j = i + by;
        if (i < 0 || j < 0 || j >= list.length)
            return;
        [list[i], list[j]] = [list[j], list[i]];
        adapter.pinned = list;
    }

    // Pinned apps first, then running apps that aren't pinned
    readonly property list<var> apps: {
        const out = [];
        const seen = new Set();
        const add = e => {
            if (e && !seen.has(e.id)) {
                seen.add(e.id);
                out.push(e);
            }
        };
        for (const id of adapter.pinned)
            add(DesktopEntries.byId(id) ?? DesktopEntries.heuristicLookup(id));
        for (const t of Hypr.toplevels.values)
            add(entryForToplevel(t));
        return out;
    }

    function entryForToplevel(toplevel: var): var {
        const ipc = toplevel?.lastIpcObject;
        if (ipc?.pid === Quickshell.processId)
            return DesktopEntries.byId(settingsId);
        const cls = ipc?.class ?? "";
        return cls ? DesktopEntries.heuristicLookup(cls) : null;
    }

    function windowsFor(entry: DesktopEntry): list<var> {
        return Hypr.toplevels.values.filter(t => entryForToplevel(t)?.id === entry.id);
    }

    function isPinned(id: string): bool {
        return adapter.pinned.includes(id);
    }

    function togglePin(id: string): void {
        adapter.pinned = isPinned(id) ? adapter.pinned.filter(p => p !== id) : [...adapter.pinned, id];
    }

    // Focus the app's next window (cycling), or launch it when it has none
    function activate(entry: DesktopEntry): void {
        const wins = windowsFor(entry);
        if (wins.length === 0) {
            Launcher.Apps.launch(entry);
            return;
        }

        // Minimized windows come back to the current workspace first
        const minimized = wins.find(w => w.workspace?.name === "special:minimized");
        if (minimized) {
            const a = `address:0x${minimized.address}`;
            const ws = Hypr.activeWsId;
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "${a}", workspace = "${ws}", follow = true })` : `movetoworkspace ${ws},${a}`);
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "${a}" })` : `focuswindow ${a}`);
            return;
        }

        const activeIdx = wins.findIndex(w => w === Hypr.activeToplevel);
        const addr = `address:0x${wins[(activeIdx + 1) % wins.length].address}`;
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "${addr}" })` : `focuswindow ${addr}`);
    }

    // A window, brought back first when it's minimized
    function focusWindow(toplevel: var): void {
        const a = `address:0x${toplevel.address}`;
        if (toplevel.workspace?.name === "special:minimized") {
            const ws = Hypr.activeWsId;
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "${a}", workspace = "${ws}", follow = true })` : `movetoworkspace ${ws},${a}`);
        }
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.focus({ window = "${a}" })` : `focuswindow ${a}`);
    }

    function isMinimized(toplevel: var): bool {
        return toplevel?.workspace?.name === "special:minimized";
    }

    // Hide: every window of the app into special:minimized, where the dock brings them back from
    function minimizeAll(entry: DesktopEntry): void {
        for (const w of windowsFor(entry).filter(w => !isMinimized(w))) {
            const a = `address:0x${w.address}`;
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.move({ window = "${a}", workspace = "special:minimized", follow = false })` : `movetoworkspacesilent special:minimized,${a}`);
        }
    }

    function launch(entry: DesktopEntry): void {
        Launcher.Apps.launch(entry);
    }

    function showAllWindows(): void {
        Hypr.dispatch(Hypr.usingLua ? `hl.dsp.global("caelestia:overviewOpen")` : "global caelestia:overviewOpen");
    }

    function opensAtLogin(entry: DesktopEntry): bool {
        return autostart.includes(entry.id.replace(/\.desktop$/, ""));
    }

    // Open at Login: a copy of the app's launcher in ~/.config/autostart, without the keys that
    // would hide it from the session (as the Witcher's Tweaks dock does)
    function setOpensAtLogin(entry: DesktopEntry, on: bool): void {
        const id = entry.id.replace(/\.desktop$/, "");
        autostartSet.command = ["sh", "-c", on ? 'dir="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"; for d in "${XDG_DATA_HOME:-$HOME/.local/share}/applications" /usr/local/share/applications /usr/share/applications /var/lib/flatpak/exports/share/applications "$HOME/.local/share/flatpak/exports/share/applications"; do if [ -f "$d/$1.desktop" ]; then mkdir -p "$dir" && grep -v -E "^(Hidden|NoDisplay)=" "$d/$1.desktop" > "$dir/$1.desktop"; exit; fi; done; exit 1' : 'rm -f "${XDG_CONFIG_HOME:-$HOME/.config}/autostart/$1.desktop"', "sh", id];
        autostartSet.running = true;
    }

    function refreshAutostart(): void {
        autostartGet.running = true;
    }

    function closeAll(entry: DesktopEntry): void {
        for (const w of windowsFor(entry)) {
            const addr = `address:0x${w.address}`;
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "${addr}" })` : `closewindow ${addr}`);
        }
    }

    Process {
        id: autostartGet

        running: true
        command: ["sh", "-c", 'ls "${XDG_CONFIG_HOME:-$HOME/.config}/autostart" 2>/dev/null']
        stdout: StdioCollector {
            onStreamFinished: root.autostart = text.split("\n").filter(f => f.endsWith(".desktop")).map(f => f.slice(0, -8))
        }
    }

    Process {
        id: autostartSet

        onExited: autostartGet.running = true
    }

    FileView {
        path: `${Paths.state}/dock.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoaded: {
            // Settings pinned while its windows went by Quickshell's own entry
            if (adapter.pinned.includes(Quickshell.appId))
                adapter.pinned = [...new Set(adapter.pinned.map(p => p === Quickshell.appId ? root.settingsId : p))];
        }
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property list<string> pinned: []
            property bool showAppsButton: true
        }
    }
}
