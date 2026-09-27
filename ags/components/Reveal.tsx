import { Gtk } from "ags/gtk4"
import type { Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { options } from "@/options"
import { hyprAnimEnabled } from "@/services/hyprland"

/**
 * Shared appear/collapse animation — the single in-app animation abstraction.
 *
 * A thin `Gtk.Revealer` wrapper: pass `shown` (static boolean or accessor) and
 * the content animates in when it maps and collapses when `shown` goes false.
 * Revealed children do not re-animate on remap; an unmapped revealer resumes
 * its transition when remapped.
 *
 * Window-level (appear/disappear of whole layer-shell surfaces) animation is
 * compositor-side — see `hypr/modules/rules.lua`. GTK cannot animate a
 * layer-surface unmap; window visibility stays instant by design.
 */

/** Animation variants — swap the mapping (or pass `anim`) to retune. */
export type AnimName =
    | "none"
    | "fade"
    | "slide-up"
    | "slide-down"
    | "slide-left"
    | "slide-right"
    | "swing-up"
    | "swing-down"
    | "swing-left"
    | "swing-right"

const ANIM: Record<AnimName, Gtk.RevealerTransitionType> = {
    none: Gtk.RevealerTransitionType.NONE,
    fade: Gtk.RevealerTransitionType.CROSSFADE,
    "slide-up": Gtk.RevealerTransitionType.SLIDE_UP,
    "slide-down": Gtk.RevealerTransitionType.SLIDE_DOWN,
    "slide-left": Gtk.RevealerTransitionType.SLIDE_LEFT,
    "slide-right": Gtk.RevealerTransitionType.SLIDE_RIGHT,
    "swing-up": Gtk.RevealerTransitionType.SWING_UP,
    "swing-down": Gtk.RevealerTransitionType.SWING_DOWN,
    "swing-left": Gtk.RevealerTransitionType.SWING_LEFT,
    "swing-right": Gtk.RevealerTransitionType.SWING_RIGHT,
}

interface RevealProps {
    /** Reveal (true) or collapse (false). */
    shown?: Accessor<boolean> | boolean
    /** Animation variant; default "slide-down". */
    anim?: AnimName
    /** Transition duration in ms; default `options.anim.duration`. */
    duration?: number
    /** Fired when the collapse transition finishes (child fully hidden). */
    onCollapsed?: () => void
    children: JSX.Element
}

export function Reveal({
    shown = true,
    anim = "slide-down",
    duration = options.anim.duration,
    onCollapsed,
    children,
}: RevealProps) {
    // Hyprland is authoritative for animation: when the compositor disables
    // animations, in-app transitions go instant too.
    const transitionType = hyprAnimEnabled((on) => (on ? ANIM[anim] : ANIM.none))
    return (
        <revealer
            revealChild={shown}
            transitionType={transitionType}
            transitionDuration={duration}
            $={(self: Gtk.Revealer) => {
                self.connect("notify::reveal-child", () => {
                    debugLog("reveal", self.revealChild ? "show" : "hide")
                })
                if (onCollapsed) {
                    self.connect("notify::child-revealed", () => {
                        if (!self.childRevealed) onCollapsed()
                    })
                }
            }}
        >
            {children}
        </revealer>
    )
}
