import Gdk from "gi://Gdk?version=4.0"
import { createBinding, createComputed, type Accessor } from "gnim"
import type AstalHyprland from "gi://AstalHyprland?version=0.1"
import { hypr } from "@/services/hyprland"
import { sortMonitors } from "@/lib/monitor-sorting"
import { connectorFromGdk, gdkFromHypr, hyprDimensions as hyprDims } from "./geometry"
import { jsonState, resolveMain, setMain as setMainStore } from "./store"

export type { MonitorsJson } from "./store"
export { parseConnector, compareConnectors, sortMonitors } from "@/lib/monitor-sorting"
export { gdkFromHypr, connectorFromGdk } from "./geometry"
export { resolveMain, setMain } from "./store"

type Monitor = AstalHyprland.Monitor

const monitorList = createBinding(hypr, "monitors")

export const monitors: Accessor<Monitor[]> = createComputed(() =>
    sortMonitors(monitorList()),
)

export const mainName: Accessor<string> = createComputed(() =>
    resolveMain(jsonState().main, monitors())?.name ?? "",
)

export const focusedName: Accessor<string> = createBinding(hypr, "focused_monitor")(
    (m) => m?.name ?? "",
)

export function isMainConnector(
    name: string | null | undefined,
): Accessor<boolean> {
    return mainName((main) => name != null && main === name)
}

export function isMainGdk(gdk: Gdk.Monitor): Accessor<boolean> {
    return createComputed(() => {
        const list = monitors()
        const connector = connectorFromGdk(gdk)
        const main = resolveMain(jsonState().main, list)
        return connector !== null && main !== null && connector === main.name
    })
}

export function gdkOf(name: string): Gdk.Monitor | null {
    return gdkFromHypr(hypr.get_monitors().find((m) => m.name === name) ?? null)
}

export function focusedGdk(): Gdk.Monitor | null {
    return gdkFromHypr(hypr.get_focused_monitor())
}

export function mainGdk(): Gdk.Monitor | null {
    return gdkOf(mainName.peek()) ?? gdkFromHypr(hypr.get_focused_monitor()) ?? gdkFromHypr(null)
}

export function hyprDimensions(
    target: "focused" | "main",
): { width: number; height: number } | null {
    return hyprDims(target, jsonState.peek().main ?? "")
}

export const setMainExport = setMainStore
export type { PopoverSize } from "@/lib/ui"
export { BAR_POPOVER_FALLBACK, popoverSize as popoverSizeFromMonitors } from "@/lib/ui"

import { pct } from "@/lib/ui"

export function popoverSize(
    widthPct: number,
    heightPct: number,
    fallback: import("@/lib/ui").PopoverSize,
): import("@/lib/ui").PopoverSize {
    const gdk = focusedGdk()
    if (gdk === null) return fallback
    return {
        width: pct(widthPct, gdk.geometry.width),
        height: pct(heightPct, gdk.geometry.height),
    }
}
