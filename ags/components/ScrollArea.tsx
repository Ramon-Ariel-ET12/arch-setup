import { Gtk } from "ags/gtk4"
import type { BoxProps } from "@/lib/props"

interface ScrollAreaProps extends Pick<BoxProps, "class" | "hexpand" | "vexpand" | "spacing" | "children"> {
    /**
     * Viewport height cap (`max-content-height`, px). Lists taller than this
     * scroll instead of growing the card — required inside popovers, which
     * live in the bar layer surface and must never outgrow the monitor.
     * Default -1 (unlimited).
     */
    maxHeight?: number
}

/**
 * Vertical scroll container used by list-based features.
 * `propagateNaturalHeight` lets the popup sizing drive the viewport.
 * When used inside `.card-body` or `.card`, wrap only the scrollable
 * content — keep header/footer as siblings outside this widget so they stay
 * pinned (GTK4 has no CSS flex to do it).
 */
export function ScrollArea({ class: cls = "", vexpand = true, hexpand = true, spacing = 4, maxHeight = -1, children }: ScrollAreaProps) {
    return (
        <scrolledwindow
            class={`scroll-area ${cls}`}
            hexpand={hexpand}
            vexpand={vexpand}
            valign={Gtk.Align.FILL}
            hscrollbarPolicy={Gtk.PolicyType.NEVER}
            vscrollbarPolicy={Gtk.PolicyType.AUTOMATIC}
            overlayScrolling={false}
            propagateNaturalHeight
            maxContentHeight={maxHeight}
        >
            <box orientation={Gtk.Orientation.VERTICAL} spacing={spacing} valign={Gtk.Align.START}>
                {children}
            </box>
        </scrolledwindow>
    )
}
