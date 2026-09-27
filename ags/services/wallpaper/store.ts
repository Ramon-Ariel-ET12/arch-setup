import { createState, type Accessor } from "gnim"
import { LEGACY_WALLPAPER_JSON, WALLPAPER_JSON } from "@/lib/paths"
import { debugLog } from "@/lib/log"
import { loadJson, saveJson } from "@/lib/json-state"
import type { WallpaperEntry } from "@/lib/wallpaper-backend"
import { listWallpapers, queryCurrentPath } from "@/lib/wallpaper-backend"

interface WallpaperState {
    current: string | null
}

const wallpaperState = (): WallpaperState => ({ current: null })

function loadCurrent(): string | null {
    return loadJson<WallpaperState>(
        WALLPAPER_JSON,
        wallpaperState(),
        (raw): WallpaperState => {
            if (typeof raw !== "object" || raw === null) return wallpaperState()
            const r = raw as Partial<WallpaperState>
            return { current: typeof r.current === "string" ? r.current : null }
        },
        LEGACY_WALLPAPER_JSON,
    ).current
}

function saveCurrent(name: string): void {
    saveJson<WallpaperState>(WALLPAPER_JSON, { current: name })
}

const [entries, setEntries] = createState<WallpaperEntry[]>([])
const [currentName, setCurrentName] = createState<string | null>(loadCurrent())
const [busy, setBusy] = createState(false)

export const wallpaperEntries: Accessor<WallpaperEntry[]> = entries
export const currentWallpaper: Accessor<string | null> = currentName
export const isBusy: Accessor<boolean> = busy

export function refresh(): void {
    setEntries(listWallpapers())
}

/**
 * Reconcile stored state with the daemon on picker open: ask `awww query`
 * what is actually on screen and adopt it when it names a known file.
 * Fixes drift from external changes (`awww img` elsewhere, daemon restart
 * with `restore`, manual JSON edits) — the picker cursor, "Applied" badge,
 * and cancel-revert target all follow ground truth, not stale state.
 * Unknown/unqueryable → keep stored state.
 */
export async function syncFromDaemon(): Promise<void> {
    refresh()
    const path = await queryCurrentPath()
    debugLog("wallpaper", "syncFromDaemon daemon=", path, "stored=", currentName.peek())
    if (path === null) return
    const match = entries.peek().find((e) => e.path === path)
    if (match === undefined) {
        debugLog("wallpaper", "syncFromDaemon daemon path not in dir, keeping stored")
        return
    }
    if (match.name !== currentName.peek()) {
        debugLog("wallpaper", "syncFromDaemon adopting daemon state:", match.name)
        setCurrentName(match.name)
        saveCurrent(match.name)
    }
}

export { entries, setEntries, currentName, setCurrentName, busy, setBusy, saveCurrent, loadCurrent }
