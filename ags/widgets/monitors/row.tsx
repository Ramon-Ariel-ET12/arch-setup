import type AstalHyprland from "gi://AstalHyprland?version=0.1"
import { createComputed } from "gnim"
import { icons } from "@/lib/icons"
import { debugLog } from "@/lib/log"
import { focusedName, isMainConnector, setMain } from "@/services/monitors"

/**
 * One output row: connector name, make/model, mode/scale,
 * a starred/non-starred icon for the default (main) output and a highlight
 * for focus. Clicking sets the persisted default monitor.
 */

interface MonitorRowProps {
    monitor: AstalHyprland.Monitor
}

export function MonitorRow({ monitor }: MonitorRowProps) {
    const isMain = isMainConnector(monitor.name)
    const isFocused = focusedName((name) => name === monitor.name)

    const rowClass = createComputed(() => {
        // `.row` already carries standard padding; `row-selected` is both
        // the focused and the main-monitor ring (single canonical state).
        let cls = "row"
        if (isFocused()) cls += " row-selected"
        if (isMain()) cls += " row-selected"
        return cls
    })

    const makeModel = [monitor.make, monitor.model].filter(Boolean).join(" ")
    const summary = `${makeModel || "Display"} · ${monitor.width}×${monitor.height} @ ${monitor.scale}x`

    return (
        <button
            class={rowClass}
            onClicked={() => {
                debugLog("monitors-ui", "setMain", monitor.name)
                setMain(monitor.name)
            }}
            tooltipText={`Set ${monitor.name} as default monitor`}
        >
            <box spacing={8}>
                <image
                    iconName={isMain((main) => (main ? icons.ui.star : icons.ui.starOutline))}
                />
                <label label={monitor.name} class="bold" />
                <label
                    label={summary}
                    class="muted"
                    hexpand
                    xalign={0}
                    opacity={0.75}
                />
                <label
                    label={isFocused((focused) => (focused ? "focused" : ""))}
                    class="text-caption"
                />
            </box>
        </button>
    )
}
