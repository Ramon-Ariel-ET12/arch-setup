import { debugLog } from "@/lib/log"
import { logWarn } from "@/lib/notify"
import { runCommand } from "@/lib/subprocess"
import { hypr } from "./hyprland"

export interface HyprBind {
    locked: boolean
    mouse: boolean
    release: boolean
    repeat: boolean
    longPress: boolean
    non_consuming: boolean
    auto_consuming: boolean
    has_description: boolean
    modmask: number
    submap: string
    submap_universal: string
    key: string
    keycode: number
    catch_all: boolean
    description: string
    allow_input_capture: boolean
    dispatcher: string
    arg: string
}

const MODS: readonly [number, string][] = [
    [1 << 0, "SHIFT"],
    [1 << 2, "CTRL"],
    [1 << 3, "ALT"],
    [1 << 6, "SUPER"],
]

function modmaskToMods(mask: number): string[] {
    return MODS.filter(([bit]) => (mask & bit) !== 0).map(([, name]) => name)
}

export function formatBind(bind: HyprBind): string {
    const mods = modmaskToMods(bind.modmask)
    return [...mods, bind.key].join(" + ")
}

let cache: HyprBind[] | null = null

hypr.connect("config-reloaded", () => {
    debugLog("hyprbinds", "cache invalidate")
    cache = null
})

export async function fetchBinds(): Promise<HyprBind[]> {
    if (cache !== null) {
        debugLog("hyprbinds", "cache hit", cache.length)
        return cache
    }
    debugLog("hyprbinds", "fetch")
    const raw = await runCommand(["hyprctl", "-j", "binds"])
    if (!raw) {
        debugLog("hyprbinds", "fetch empty, returning []")
        return []
    }
    try {
        const all: HyprBind[] = JSON.parse(raw)
        cache = all
            .filter((b) => b.has_description)
            .sort((a, b) => {
                const aDef = a.submap === ""
                const bDef = b.submap === ""
                if (aDef !== bDef) return aDef ? -1 : 1
                if (a.submap !== b.submap) return a.submap.localeCompare(b.submap)
                return a.description.localeCompare(b.description)
            })
        debugLog("hyprbinds", "fetched", cache.length)
        return cache
    } catch (err) {
        debugLog("hyprbinds", "parse failed", err)
        logWarn("failed to parse hyprctl binds JSON")
        return []
    }
}
