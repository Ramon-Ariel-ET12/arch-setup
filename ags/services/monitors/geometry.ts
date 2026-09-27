import Gdk from "gi://Gdk?version=4.0"
import app from "ags/gtk4/app"
import { debugLog } from "@/lib/log"
import { hypr, type HyprMonitor } from "@/services/hyprland"

const GEOMETRY_TOLERANCE = 2
const POSITION_TOLERANCE = 1

function logicalSize(hm: HyprMonitor): { width: number; height: number } {
    return { width: Math.round(hm.width / hm.scale), height: Math.round(hm.height / hm.scale) }
}

export function gdkFromHypr(hm: HyprMonitor | null): Gdk.Monitor | null {
    const gdks = app.get_monitors()
    if (gdks.length === 0) {
        debugLog("monitors", "gdkFromHypr no gdk monitors")
        return null
    }
    if (!hm) return gdks[0]!
    const { width: logicalWidth, height: logicalHeight } = logicalSize(hm)
    for (const gdk of gdks) {
        const geo = gdk.geometry
        const positionMatch =
            Math.abs(geo.x - hm.x) <= POSITION_TOLERANCE && Math.abs(geo.y - hm.y) <= POSITION_TOLERANCE
        const sizeMatch =
            Math.abs(geo.width - logicalWidth) <= GEOMETRY_TOLERANCE &&
            Math.abs(geo.height - logicalHeight) <= GEOMETRY_TOLERANCE
        if (positionMatch && sizeMatch) return gdk
    }
    debugLog("monitors", "gdkFromHypr no match, fallback", hm.name)
    return gdks[0]!
}

export function connectorFromGdk(gdk: Gdk.Monitor): string | null {
    for (const hm of hypr.get_monitors()) {
        if (gdkFromHypr(hm) === gdk) return hm.name
    }
    return null
}

export function hyprDimensions(
    target: "focused" | "main",
    mainName: string,
): { width: number; height: number } | null {
    const all = hypr.get_monitors()
    const hm =
        target === "focused"
            ? hypr.get_focused_monitor()
            : (all.find((m) => m.name === mainName) ?? null)
    if (!hm) {
        debugLog("monitors", "hyprDimensions no monitor", target)
        return null
    }
    return logicalSize(hm)
}
