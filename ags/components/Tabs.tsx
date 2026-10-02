import { Gtk } from "ags/gtk4"
import type { Accessor } from "gnim"
import { debugLog } from "@/lib/log"

export interface TabDef<T extends string = string> {
    id: T
    label: string
}

interface TabsProps<T extends string> {
    tabs: readonly TabDef<T>[]
    active: Accessor<T>
    onChange: (id: T) => void
    /**
     * Homogeneous sizing (every tab the same width). Turn off for long /
     * numerous tab lists wrapped in a horizontal scrolled row, where each
     * tab keeps its natural width and the row scrolls instead of squeezing.
     */
    homogeneous?: boolean
    /** Row alignment; defaults to FILL when homogeneous, START otherwise. */
    halign?: Gtk.Align
}

/** Simple tab bar (see `_tabs.scss`). */
export function Tabs<T extends string>({ tabs, active, onChange, homogeneous = true, halign }: TabsProps<T>) {
    return (
        <box class="tabs" homogeneous={homogeneous} halign={halign ?? (homogeneous ? Gtk.Align.FILL : Gtk.Align.START)}>
            {tabs.map((tab) => (
                <button class={active((id) => (id === tab.id ? "tab px-3 py-1 active" : "tab px-3 py-1"))} onClicked={() => {
                    debugLog("tabs", "switch", tab.id)
                    onChange(tab.id)
                }}>
                    <label label={tab.label} />
                </button>
            ))}
        </box>
    )
}
