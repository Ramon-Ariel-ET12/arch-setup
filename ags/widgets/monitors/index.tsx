import { Gtk } from "ags/gtk4"
import { For } from "gnim"
import { Popup } from "@/components"
import { monitors } from "@/services/monitors"
import { MonitorRow } from "./row"

/**
 * Monitor manager popup card, centered on the **focused** monitor.
 *
 * Toggle: `ags toggle monitors`
 */
export default function MonitorsPopup() {
    return (
        <Popup
            name="monitors"
            title="Monitors"
            target="focused"
            widthPct={34}
            heightPct={45}
        >
            <box orientation={Gtk.Orientation.VERTICAL} spacing={6} class="min-w-popup">
                <For each={monitors}>{(monitor) => <MonitorRow monitor={monitor} />}</For>
            </box>
        </Popup>
    )
}
