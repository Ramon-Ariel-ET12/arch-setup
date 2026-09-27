import app from "ags/gtk4/app"
import type Gtk from "gi://Gtk?version=4.0"
import { createBinding, createState, type Accessor } from "gnim"
import { options } from "@/options"
import { debugLog } from "@/lib/log"
import { logWarn } from "@/lib/notify"

/**
 * Central popup registry.
 *
 * Every popup is an `Astal.Window` created at startup with a unique `name`,
 * which makes it toggleable via `ags toggle <name>`. Window visibility is the
 * single source of truth: both this service and the CLI flip the same
 * property, and reactive readers (`popupIsOpen`) stay in sync automatically.
 */

export const POPUPS = [
    "launcher",
    "clipboard",
    "wallpaper",
    "monitors",
    "notifcenter",
    "notifdetail",
    "binds",
    "calendar",
] as const

export type PopupName = (typeof POPUPS)[number]

function windowOf(name: PopupName): Gtk.Window | undefined {
    return app.get_window(name)
}

function show(name: PopupName, visible: boolean): void {
    const win = windowOf(name)
    if (!win) return logWarn(`no popup registered with name "${name}"`)
    if (win.visible === visible) return
    debugLog("popups", visible ? "open" : "close", name)
    win.visible = visible
}

export function openPopup(name: PopupName): void {
    if (options.popups.closeOthers) closeAllPopups(name)
    show(name, true)
}

export function closePopup(name: PopupName): void {
    show(name, false)
}

/** Mirrors the behavior of `ags toggle <name>`. */
export function togglePopup(name: PopupName): void {
    const win = windowOf(name)
    if (!win) return logWarn(`no popup registered with name "${name}"`)
    if (!win.visible) openPopup(name)
    else closePopup(name)
}

export function closeAllPopups(except?: PopupName): void {
    for (const name of POPUPS) {
        if (name === except) continue
        const win = windowOf(name)
        if (win?.visible) {
            debugLog("popups", "close-others", name)
            win.visible = false
        }
    }
}

/** Reactive visibility of a popup; safe to call before registration. */
export function popupIsOpen(name: PopupName): Accessor<boolean> {
    const win = windowOf(name)
    if (!win) {
        logWarn(`no popup registered with name "${name}"`)
        return createState(false)[0]
    }
    return createBinding(win, "visible")
}
