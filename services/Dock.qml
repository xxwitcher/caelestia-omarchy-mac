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
        const cls = toplevel?.lastIpcObject?.class ?? "";
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

    function closeAll(entry: DesktopEntry): void {
        for (const w of windowsFor(entry)) {
            const addr = `address:0x${w.address}`;
            Hypr.dispatch(Hypr.usingLua ? `hl.dsp.window.close({ window = "${addr}" })` : `closewindow ${addr}`);
        }
    }

    FileView {
        path: `${Paths.state}/dock.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property list<string> pinned: []
        }
    }
}
