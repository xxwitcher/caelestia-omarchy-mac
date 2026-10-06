pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

// Every Hyprland option, from `hyprctl descriptions -j`. Changes apply live through
// `hyprctl eval` and, when Hyprland accepts them, are kept in hypr-settings.json and
// written to hypr-settings.lua, which hyprland.lua loads at the end so they persist.
Singleton {
    id: root

    readonly property string luaPath: `${Paths.config}/hypr-settings.lua`
    property list<var> options: []
    readonly property list<string> categories: [...new Set(options.map(o => o.name.split(":")[0]))]
    property string lastError
    readonly property var overrides: adapter.overrides
    readonly property var monitors: adapter.monitors

    function monitorLua(name: string, m: var): string {
        return `hl.monitor({ output = ${JSON.stringify(name)}, mode = ${JSON.stringify(m.mode ?? "preferred")}, position = ${JSON.stringify(m.position ?? "auto")}, scale = ${m.scale ?? "auto"} })`;
    }

    // values: { mode, position, scale }; applied live and kept in hypr-settings.lua
    function setMonitor(name: string, values: var): void {
        const all = Object.assign({}, adapter.monitors);
        all[name] = Object.assign({}, all[name] ?? {}, values);
        adapter.monitors = all;
        Quickshell.execDetached(["hyprctl", "eval", monitorLua(name, all[name])]);
        writeLua();
    }

    function refresh(): void {
        descProc.running = true;
    }

    function current(name: string): var {
        return name in adapter.overrides ? adapter.overrides[name] : options.find(o => o.name === name)?.current;
    }

    // Lua literal for a value; numeric strings become numbers, "a b c d" becomes a css gap table
    function luaValue(value: var): string {
        if (typeof value === "boolean" || typeof value === "number")
            return String(value);
        if (Array.isArray(value))
            return `{ ${value.map(v => luaValue(v)).join(", ")} }`;
        const s = String(value).trim();
        if (/^-?\d+(\.\d+)?$/.test(s))
            return s;
        const gap = s.match(/^(\d+) (\d+) (\d+) (\d+)$/);
        if (gap)
            return `{ top = ${gap[1]}, right = ${gap[2]}, bottom = ${gap[3]}, left = ${gap[4]} }`;
        return JSON.stringify(s);
    }

    // "a:b.c" with value v -> hl.config({ a = { b = { c = v } } })
    function luaFor(name: string, value: var): string {
        const keys = name.split(/[:.]/);
        let body = luaValue(value);
        for (let i = keys.length - 1; i >= 0; i--)
            body = `{ ${/^[A-Za-z_][A-Za-z0-9_]*$/.test(keys[i]) ? keys[i] : `["${keys[i]}"]`} = ${body} }`;
        return `hl.config(${body})`;
    }

    function set(name: string, value: var): void {
        const proc = applyComp.createObject(root, {
            name,
            value
        });
        proc.running = true;
    }

    function reset(name: string): void {
        const o = options.find(opt => opt.name === name);
        const all = Object.assign({}, adapter.overrides);
        delete all[name];
        adapter.overrides = all;
        if (o)
            Quickshell.execDetached(["hyprctl", "eval", luaFor(name, o.default)]);
        writeLua();
    }

    function writeLua(): void {
        const lines = ["-- Written by Caelestia settings (Hyprland page). Edit there, not here."];
        for (const [name, value] of Object.entries(adapter.overrides))
            lines.push(`pcall(function() ${luaFor(name, value)} end)`);
        for (const [name, m] of Object.entries(adapter.monitors))
            lines.push(`pcall(function() ${monitorLua(name, m)} end)`);
        luaFile.setText(lines.join("\n") + "\n");
    }

    Component.onCompleted: refresh()

    Component {
        id: applyComp

        Process {
            id: proc

            required property string name
            required property var value

            command: ["hyprctl", "eval", root.luaFor(name, value)]
            stdout: StdioCollector {
                onStreamFinished: {
                    if (text.trim() === "ok") {
                        const all = Object.assign({}, adapter.overrides);
                        all[proc.name] = proc.value;
                        adapter.overrides = all;
                        root.lastError = "";
                        root.writeLua();
                    } else {
                        root.lastError = text.trim().replace(/^error: return .*?;:1: /, "");
                    }
                    proc.destroy();
                }
            }
        }
    }

    Process {
        id: descProc

        command: ["hyprctl", "descriptions", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.options = JSON.parse(text);
                } catch (e) {
                    root.options = [];
                }
            }
        }
    }

    FileView {
        id: luaFile

        path: root.luaPath
    }

    FileView {
        path: `${Paths.config}/hypr-settings.json`
        watchChanges: true
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                writeAdapter();
        }

        JsonAdapter {
            id: adapter

            property var overrides: ({})
            property var monitors: ({})
        }
    }
}
