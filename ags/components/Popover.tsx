import { Gtk } from "ags/gtk4"
import { createState } from "gnim"
import { Card } from "./Card"
import { Reveal } from "./Reveal"
import { debugLog } from "@/lib/log"

/**
 * GTK4 popover anchored to a bar button.
 *
 * Unlike the layer-shell `Popup` (a top-level window toggled by a global bind
 * and positioned by an anchor), a `Popover` is a native GTK bubble attached
 * directly to the trigger button it lives in. It pops up below/above the
 * trigger on click, handles outside-click + Escape dismissal itself, and needs
 * no `ags toggle` bind.
 *
 * Implemented as a `button.card` trigger + a manually anchored `Gtk.Popover`
 * (explicit `popup()`/`popdown()` toggle). The trigger is a real button so
 * the whole card lights up via the existing `button.card` hover/active rules
 * — a `Gtk.MenuButton` carried the surface on the outer `menubutton` node
 * while hover landed on its inner `button` node, and its native toggle proved
 * unreliable in layer-shell (second press never closed the bubble).
 *
 * GTK note: the bubble node itself is transparent (see `_popover.scss`) —
 * the surface comes from the `.card` wrapped around the content below, so
 * popovers reuse the single card default instead of recreating it.
 */

interface PopoverProps {
    /** The button content shown in the bar (icon, label, …). */
    trigger: JSX.Element
    /** Body of the bubble. Wrap multiple widgets in a box. */
    content: JSX.Element
    /** Which side the bubble pops out toward. Default: BOTTOM (below). */
    direction?: Gtk.ArrowType
    /** Fired each time the popover is shown (e.g. to refresh content). */
    onOpen?: () => void
    /** Fired each time the popover is hidden (e.g. to stop background work). */
    onClose?: () => void
    class?: string
}

function positionFor(direction: Gtk.ArrowType): Gtk.PositionType {
    switch (direction) {
        case Gtk.ArrowType.UP:
            return Gtk.PositionType.TOP
        case Gtk.ArrowType.LEFT:
            return Gtk.PositionType.LEFT
        case Gtk.ArrowType.RIGHT:
            return Gtk.PositionType.RIGHT
        case Gtk.ArrowType.DOWN:
        case Gtk.ArrowType.NONE:
        default:
            return Gtk.PositionType.BOTTOM
    }
}

export function Popover({
    trigger,
    content,
    direction = Gtk.ArrowType.DOWN,
    onOpen,
    onClose,
    class: cls = "",
}: PopoverProps) {
    // Appear-only animation: GTK closes the popover natively (outside click /
    // Escape), so the exit stays instant. Popovers live inside the bar layer
    // surface (not their own), so the compositor can't animate them — reuse
    // the fast in-app fade matching the window `popin` feel.
    // GTK note: starts revealed — a GtkRevealer with revealChild=false reports
    // zero natural height, so presenting the popover collapsed first triggers
    // `gdk_popup_present: assertion 'height > 0' failed` and a visible jump
    // when it grows. Collapse only on close instead.
    const [open, setOpen] = createState(true)

    let popover: Gtk.Popover | null = null

    const show = (button: Gtk.Button) => {
        if (popover?.visible) return
        debugLog("popover", "open")
        setOpen(true)
        button.add_css_class("active")
        onOpen?.()
        popover?.popup()
    }

    return (
        <button
            class={`card ${cls}`}
            onClicked={(self: Gtk.Button) => {
                if (popover?.visible) popover.popdown()
                else show(self)
            }}
            $={(self: Gtk.Button) => {
                const bubble = new Gtk.Popover()
                bubble.set_has_arrow(false)
                bubble.set_autohide(true)
                bubble.set_position(positionFor(direction))
                bubble.set_parent(self)
                bubble.set_child(
                    (
                        <box
                            orientation={Gtk.Orientation.VERTICAL}
                            valign={Gtk.Align.START}
                            vexpand
                        >
                            <Reveal shown={open} anim="fade">
                                <Card spacing={4}>
                                    {content}
                                </Card>
                            </Reveal>
                        </box>
                    ) as unknown as Gtk.Widget,
                )
                bubble.connect("closed", () => {
                    debugLog("popover", "close")
                    self.remove_css_class("active")
                    setOpen(false)
                    onClose?.()
                })
                self.connect("destroy", () => {
                    bubble.unparent()
                    if (popover === bubble) popover = null
                })
                popover = bubble
            }}
        >
            {trigger}
        </button>
    )
}
