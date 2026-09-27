import Gdk from "gi://Gdk?version=4.0"
import { Astal, Gtk } from "ags/gtk4"
import app from "ags/gtk4/app"
import type { Accessor } from "gnim"
import { attachKeymap } from "@/lib/keyboard"
import { debugLog } from "@/lib/log"
import { pct } from "@/lib/ui"
import { icons } from "@/lib/icons"
import { options } from "@/options"
import { closePopup } from "@/services/popups"
import { popupTopOffset } from "@/services/hyprland"
import { focusedGdk, hyprDimensions, mainGdk } from "@/services/monitors"
import type { PopupName } from "@/services/popups"
import { Card } from "./Card"
import { Button } from "./Button"

/**
 * The single popup component: layer-shell window + card chrome.
 *
 * - Registers an `Astal.Window` with a unique `name` (`ags toggle <name>`).
 * - Re-resolves its `gdkmonitor` on every open, so cards follow the focused
 *   monitor ("focused") or live on the default one ("main").
 * - Card body: optional header (title + close button), `children`, optional
 *   `footer`. Escape dismisses (see `options.popups`).
 *
 * NOTE (gnim): children are not reactive here; visibility/monitor/size are.
 * Conditional content belongs inside feature components via `With`.
 */

const CENTER_ANCHOR = Astal.WindowAnchor.NONE

export interface PopupProps {
    /** Unique window name — also the `ags toggle <name>` id. */
    name: PopupName
    namespace?: string
    /**
     * Which monitor hosts the card. Default: focused.
     * Can also be a live `Accessor<Gdk.Monitor | null>` to fully decouple
     * Popup from services/monitors (pass a monitor binding from the caller).
     */
    target?: "focused" | "main" | Accessor<Gdk.Monitor | null>
    /** WindowAnchor bitmask. Default: centered (no anchor). */
    anchor?: number
    layer?: Astal.Layer
    /** Requested size as a percentage of the target monitor geometry; `null` = natural size. */
    widthPct?: number | null
    heightPct?: number | null
    /** Header title; the header renders when a title or close button is shown. */
    title?: string
    /** Render the header close button (default true when a title exists). */
    showCloseButton?: boolean
    /** Horizontal alignment of the title label (0 = left, 0.5 = center, 1 = right). */
    titleXAlign?: number
    /** Optional slot rendered below the body. */
    footer?: JSX.Element
    /** Called every time the popup becomes visible. */
    onShow?: () => void
    /** Called every time the popup hides (any close path). */
    onHide?: () => void
    /**
     * Custom close-button + Escape handler. Default: `closePopup(name)`.
     * Pass to run cleanup (e.g. revert a preview) before closing.
     */
    onClose?: () => void
    /** Extra keys handled while the popup is open (Enter/arrows). */
    keymap?: Parameters<typeof attachKeymap>[1]
    /** Extra class on the card. */
    class?: string
    // Loose for the same reason as `Card` (runtime flattens JSX children).
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    children?: any
}

export function Popup({
    name,
    namespace = name,
    target = "focused",
    anchor = CENTER_ANCHOR,
    layer = Astal.Layer.TOP,
    widthPct = options.popups.widthPct,
    heightPct = options.popups.heightPct,
    title,
    showCloseButton,
    titleXAlign = 0,
    footer,
    onShow,
    onHide,
    onClose,
    keymap,
    class: cls = "",
    children,
}: PopupProps) {
    const hasHeader = title !== undefined || showCloseButton === true
    const handleClose = () => {
        if (onClose) onClose()
        else closePopup(name)
    }

    return (
        <window
            name={name}
            namespace={namespace}
            application={app}
            visible={false}
            anchor={anchor}
            layer={layer}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.ON_DEMAND}
            $={(self: Astal.Window) =>
                setupPopup(self, name, anchor, target, widthPct, heightPct, onShow, onHide, onClose, keymap)
            }
        >
            <Card class={cls}>
                {hasHeader && (
                    <box class="card-header mb-1" valign={Gtk.Align.START}>
                        {title !== undefined && (
                            <label
                                label={title}
                                class="card-title"
                                hexpand
                                xalign={titleXAlign}
                            />
                        )}
                        {(showCloseButton ?? true) && (
                            <Button
                                icon={icons.ui.close}
                                variant="flat"
                                onClicked={handleClose}
                                tooltipText="Close"
                            />
                        )}
                    </box>
                )}
                <box class="card-body" orientation={Gtk.Orientation.VERTICAL} vexpand valign={Gtk.Align.FILL} spacing={0}>
                    {children}
                </box>
                {footer && (
                    <box class="mt-1" valign={Gtk.Align.END}>
                        {footer}
                    </box>
                )}
            </Card>
        </window>
    )
}

function setupPopup(
    self: Astal.Window,
    name: PopupName,
    anchor: number,
    target: "focused" | "main" | Accessor<Gdk.Monitor | null>,
    widthPct?: number | null,
    heightPct?: number | null,
    onShow?: () => void,
    onHide?: () => void,
    onClose?: () => void,
    keymap?: Parameters<typeof attachKeymap>[1],
): void {
    const margin = options.popups.margin
    // Explicitly top-anchored popups clear the floating bar (live
    // popupTopOffset = bar height + 2 × gaps_out); centered (default) and
    // other popups get a uniform margin on all sides.
    const topAnchored =
        (anchor & (Astal.WindowAnchor.TOP | Astal.WindowAnchor.BOTTOM)) ===
        Astal.WindowAnchor.TOP
    self.margin_top = topAnchored ? Math.max(margin, popupTopOffset()) : margin
    self.margin_bottom = margin
    self.margin_start = margin
    self.margin_end = margin

    const resolveTarget = (): { gdk: Gdk.Monitor | null; dimsTarget: "focused" | "main" } => {
        if (typeof target === "function") {
            return { gdk: (target as Accessor<Gdk.Monitor | null>)(), dimsTarget: "focused" }
        }
        const gdk = target === "main" ? mainGdk() : focusedGdk()
        return { gdk, dimsTarget: target as "focused" | "main" }
    }

    self.connect("notify::visible", () => {
        if (!self.visible) {
            debugLog("popup", name, "close")
            onHide?.()
            return
        }
        debugLog("popup", name, "open")

        const { gdk, dimsTarget } = resolveTarget()
        if (gdk === null) return

        if (self.gdkmonitor !== gdk) self.gdkmonitor = gdk

        const isAccessorTarget = typeof target === "function"
        const dim = (isAccessorTarget ? null : hyprDimensions(dimsTarget)) ?? {
            width: gdk.geometry.width,
            height: gdk.geometry.height,
        }
        debugLog(
            "popup",
            name,
            "size",
            `${dim.width}x${dim.height}`,
            widthPct != null ? `${widthPct}%` : "natural",
            heightPct != null ? `${heightPct}%` : "natural",
        )
        if (widthPct != null) self.widthRequest = pct(widthPct, dim.width)
        if (heightPct != null) self.heightRequest = pct(heightPct, dim.height)

        if (widthPct != null || heightPct != null) {
            self.defaultWidth = widthPct != null ? pct(widthPct, dim.width) : -1
            self.defaultHeight = heightPct != null ? pct(heightPct, dim.height) : -1
        }

        onShow?.()
    })

    attachKeymap(self, {
        onEscape: options.popups.escToClose
            ? () => {
                  debugLog("popup", name, "esc-to-close")
                  if (onClose) onClose()
                  else self.visible = false
              }
            : undefined,
        ...keymap,
    })
}
