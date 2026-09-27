import { Gtk } from "ags/gtk4"
import type { Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { Reveal } from "./Reveal"

interface CollapsibleProps {
    /** Always-visible clickable row. */
    header: JSX.Element
    /** Revealed body when expanded. */
    body: JSX.Element
    /** Controlled state accessor. */
    open: Accessor<boolean>
    /** Called with the new value on toggle (e.g. to keep one row open). */
    onToggle?: (open: boolean) => void
    class?: string
}

/** Expand/collapse container (accordion row); open state is controlled. */
export function Collapsible({ header, body, open, onToggle, class: cls = "" }: CollapsibleProps) {
    return (
        <box class={cls} orientation={Gtk.Orientation.VERTICAL}>
            <button
                onClicked={() => {
                    const next = !open()
                    debugLog("collapsible", "toggle", next ? "open" : "closed")
                    onToggle?.(next)
                }}
            >
                {header}
            </button>
            <Reveal shown={open}>
                <box class="pl-4 py-1 pr-2">{body}</box>
            </Reveal>
        </box>
    )
}
