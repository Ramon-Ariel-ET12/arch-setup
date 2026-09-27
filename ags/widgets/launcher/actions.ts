import { fuzzyApps } from "@/services/apps"
import { bumpFrecency } from "@/lib/frecency"
import { createListNav } from "@/lib/list-nav"
import { debugLog } from "@/lib/log"
import { closePopup } from "@/services/popups"

const nav = createListNav({ fetch: (q) => fuzzyApps(q) })

export const results = nav.results
export const activeCursor = nav.cursor
export const searchText = nav.query
export const setQuery = nav.setQuery
export const moveSelection = nav.moveSelection

/** Launches the app under the keyboard cursor; Enter handler. */
export function activateSelected(): boolean {
    const list = results.peek()
    if (list.length === 0) return true // swallow Enter on empty result
    // Clamp: the cursor can outlive a shrinking result list (apps refresh).
    launchApp(list[Math.min(activeCursor.peek(), list.length - 1)])
    return true
}

export function launchApp(app: { name: string; launch(): void }): void {
    debugLog("launcher", "launch", app.name)
    bumpFrecency(`app:${app.name}`)
    app.launch()
    closePopup("launcher")
}

export const resetLauncher = nav.reset
