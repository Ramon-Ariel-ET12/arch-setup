import Gdk from "gi://Gdk?version=4.0"
import Gtk from "gi://Gtk?version=4.0"
import type Astal from "gi://Astal?version=4.0"
import { debugLog } from "@/lib/log"

/** Keyvals used by the navigation below. */
const KEYS = {
    Escape: Gdk.KEY_Escape,
    Up: Gdk.KEY_Up,
    Down: Gdk.KEY_Down,
    Left: Gdk.KEY_Left,
    Right: Gdk.KEY_Right,
    Tab: Gdk.KEY_Tab,
    Return: Gdk.KEY_Return,
    KPEnter: Gdk.KEY_KP_Enter,
    Space: Gdk.KEY_space,
} as const

interface NavigationHandlers {
    onEscape?: () => void
    onMove?: (delta: -1 | 1) => boolean
    onMoveH?: (delta: -1 | 1) => boolean
    onSwitch?: (left: boolean) => boolean
    onConfirm?: () => boolean
    /** Also confirm on Space. Off by default: Space types into entries. */
    confirmOnSpace?: boolean
}

/**
 * Adds Escape-to-close plus optional arrow/enter navigation to a window.
 * (Escape/arrows/Enter/Tab; Shift+Tab goes backwards.)
 *
 * Two controllers, because event order matters around a focused Gtk.Entry:
 * - CAPTURE: Escape + Enter. A focused entry consumes Return for its own
 *   `activate` signal, hiding it from BUBBLE-phase controllers — the window
 *   keymap must see those keys first so Enter still confirms while typing.
 * - BUBBLE: arrows + Tab, so caret keys a text entry needs (Left/Right) and
 *   focus cycling still reach it when the keymap doesn't own them.
 */
export function attachKeymap(
    win: Astal.Window,
    handlers: NavigationHandlers,
): void {
    const windowKeys = new Gtk.EventControllerKey()
    windowKeys.set_propagation_phase(Gtk.PropagationPhase.CAPTURE)
    windowKeys.connect("key-pressed", (_c, keyval: number): boolean => {
        if (keyval === KEYS.Escape && handlers.onEscape) {
            debugLog("keyboard", "escape")
            handlers.onEscape()
            return true
        }
        if ((keyval === KEYS.Return || keyval === KEYS.KPEnter) && handlers.onConfirm) {
            debugLog("keyboard", "confirm", keyval)
            return handlers.onConfirm()
        }
        if (keyval === KEYS.Space && handlers.confirmOnSpace && handlers.onConfirm) {
            debugLog("keyboard", "confirm space")
            return handlers.onConfirm()
        }
        return false
    })
    win.add_controller(windowKeys)

    const navKeys = new Gtk.EventControllerKey()
    navKeys.connect("key-pressed", (_c, keyval: number, _keycode, state): boolean => {
        if ((keyval === KEYS.Up || keyval === KEYS.Down) && handlers.onMove) {
            const delta = keyval === KEYS.Up ? -1 : 1
            debugLog("keyboard", "move", delta)
            return handlers.onMove(delta)
        }
        if ((keyval === KEYS.Left || keyval === KEYS.Right) && handlers.onMoveH) {
            const delta = keyval === KEYS.Left ? -1 : 1
            debugLog("keyboard", "moveH", delta)
            return handlers.onMoveH(delta)
        }
        if (keyval === KEYS.Tab && handlers.onSwitch) {
            const left = (state & Gdk.ModifierType.SHIFT_MASK) !== 0
            debugLog("keyboard", "switch", left)
            return handlers.onSwitch(left)
        }
        return false
    })
    win.add_controller(navKeys)
}
