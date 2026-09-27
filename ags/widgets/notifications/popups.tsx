import { Astal, Gtk } from "ags/gtk4"
import app from "ags/gtk4/app"
import AstalNotifd from "gi://AstalNotifd?version=0.1"
import { For, createBinding, createComputed, createState } from "gnim"
import { Card, Reveal, Button } from "@/components"
import { icons } from "@/lib/icons"
import { dndEnabled } from "@/services/config"
import { focusedFullscreen, popupTopOffset } from "@/services/hyprland"
import { mainGdk, monitors } from "@/services/monitors"
import { options } from "@/options"
import { NotificationCard } from "./card"

/**
 * Notification toasts — realtime-only widget, **main monitor only**.
 * A single top-right layer-shell window hosts a stack of timed cards.
 *
 * Expiry REMOVES the toast: collapse, then `dismiss()` drops it from the
 * daemon list and the widget unmounts. The saved copy lives in the persisted
 * history store (`history.ts`, fed by `notified`/`resolved`), which is what
 * the center/detail read — toasts never keep entries alive.
 */

const { TOP, RIGHT } = Astal.WindowAnchor

const TOAST_TIMEOUT_MS = 5000

export function NotificationPopups() {
    const notifications = createBinding(AstalNotifd.get_default(), "notifications")
    const visible = createComputed(
        () => notifications().length > 0 && !dndEnabled() && !focusedFullscreen(),
    )

    // Follows the persisted main monitor; a session always has ≥1 output.
    const target = createComputed(() => {
        void monitors() // invalidate when outputs change
        return mainGdk() ?? app.get_monitors()[0]!
    })

    // GTK note: a mapped-but-collapsing toast (Reveal mid-transition) still
    // owns its old input region and eats clicks meant for the app below.
    // Clearing the surface input region once the collapse finishes makes the
    // lingering window fully click-through; it naturally regains input on
    // the next map (fresh surface input). The × buttons keep working while
    // revealed — the region is only cleared after collapse.
    // (GTK4 removed the `size-allocate` signal, so per-frame region tracking
    // is not possible — transition-end is the only hook.)
    const releaseInput = (win: Astal.Window) => {
        try {
            win.get_surface()?.set_input_region(null)
        } catch {
        }
    }

    return (
        <window
            name="notification-toasts"
            namespace="notifications"
            application={app}
            visible={visible}
            gdkmonitor={target}
            anchor={TOP | RIGHT}
            margin_top={popupTopOffset}
            exclusivity={Astal.Exclusivity.IGNORE}
            keymode={Astal.Keymode.NONE}
            layer={Astal.Layer.OVERLAY}
        >
            <box
                class="mr-2"
                orientation={Gtk.Orientation.VERTICAL}
                spacing={8}
            >
                <For each={notifications}>{(n) => <Toast notification={n} onCollapsed={releaseInput} />}</For>
            </box>
        </window>
    )
}

function Toast({ notification, onCollapsed }: { notification: AstalNotifd.Notification; onCollapsed: (win: Astal.Window) => void }) {
    // Honor the daemon's expire_timeout when set, fall back to a sensible default.
    const timeout = createBinding(notification, "expireTimeout")((ms) =>
        ms > 0 ? ms : TOAST_TIMEOUT_MS,
    )

    // Collapse the card first, then dismiss: expiry REMOVES the toast from
    // the daemon list (the saved copy persists in history.ts for the
    // center). The timer keeps running while the window is suppressed
    // (DND/fullscreen) so expiry always lands.
    const [leaving, setLeaving] = createState(false)
    let expireTimer: ReturnType<typeof setTimeout> | null = null
    let dismissTimer: ReturnType<typeof setTimeout> | null = null
    const leave = () => {
        if (leaving.peek()) return
        setLeaving(true)
        if (dismissTimer === null) dismissTimer = setTimeout(() => notification.dismiss(), options.anim.duration)
    }
    expireTimer = setTimeout(leave, timeout())
    notification.connect("notify::resolved", () => {
        if (expireTimer !== null) {
            clearTimeout(expireTimer)
            expireTimer = null
        }
        if (dismissTimer !== null) {
            clearTimeout(dismissTimer)
            dismissTimer = null
        }
    })

    const shown = leaving((l) => !l)
    let row: Gtk.Widget | null = null

    return (
        <Reveal
            shown={shown}
            onCollapsed={() => {
                const win = row?.get_root() as Astal.Window | null
                if (win !== null) onCollapsed(win)
            }}
        >
            <Card spacing={6}>
                <box
                    spacing={8}
                    $={(self: Gtk.Box) => {
                        row = self
                    }}
                >
                    <box hexpand>
                        <NotificationCard notification={notification} iconPixelSize={32} />
                    </box>
                    <Button icon={icons.ui.close} onClicked={() => notification.dismiss()} valign={Gtk.Align.CENTER} tooltipText="Dismiss" />
                </box>
            </Card>
        </Reveal>
    )
}
