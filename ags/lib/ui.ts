import { Gtk } from "ags/gtk4"
import { createComputed, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"

export function clamp(value: number, min: number, max: number): number {
    return Math.min(Math.max(value, min), max)
}

export function pct(percentage: number, total: number): number {
    return Math.round((percentage / 100) * total)
}

/**
 * Single percentage formatter — every battery/volume/level label reuses this.
 *
 * Accepts both scales (values > 1 are already percentages, e.g. Bluetooth
 * `batteryPercentage` 0–100; fractions 0–1 like audio `volume` are scaled up)
 * and maps unknown/invalid input to `fallback` ("—" hides nothing, "" hides
 * the label). NaN/Infinity/-1 (no battery) all fall back.
 */
export function pctLabel(value: number, fallback = "—", suffix = "%"): string {
    if (!Number.isFinite(value) || value < 0) return fallback
    const percent = value > 1 ? value : value * 100
    return `${Math.round(percent)}${suffix}`
}

export function activeClass(
    active: Accessor<boolean>,
    base: string,
    modifier = "active",
): Accessor<string> {
    return createComputed(() => (active() ? `${base} ${modifier}` : base))
}

export function scrollRangeIntoView(
    widget: Gtk.Widget | null,
    top: number,
    bottom: number,
): void {
    if (widget === null) return
    const scroll = widget.get_ancestor(Gtk.ScrolledWindow.$gtype) as Gtk.ScrolledWindow | null
    if (scroll === null) return
    const adj = scroll.get_vadjustment()
    if (top < adj.get_value()) {
        debugLog("ui", "scroll up", top)
        adj.set_value(top)
    } else if (bottom > adj.get_value() + adj.get_page_size()) {
        debugLog("ui", "scroll down", bottom)
        adj.set_value(bottom - adj.get_page_size())
    }
}

export interface PopoverSize {
    width: number
    height: number
}

export const BAR_POPOVER_FALLBACK: PopoverSize = { width: 320, height: 320 }

export function popoverSize(
    widthPct: number,
    heightPct: number,
    fallback: PopoverSize,
    monitorWidth: number | null,
    monitorHeight: number | null,
): PopoverSize {
    if (monitorWidth === null || monitorHeight === null) return fallback
    return {
        width: pct(widthPct, monitorWidth),
        height: pct(heightPct, monitorHeight),
    }
}
