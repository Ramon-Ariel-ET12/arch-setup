import Apps from "gi://AstalApps?version=0.1"
import { rankByFrecency } from "@/lib/frecency"
import { debugLog } from "@/lib/log"

/**
 * Application list access with frecency ranking.
 * The `Apps` singleton is only touched here.
 */

const apps = new Apps.Apps()

export interface AppEntry {
    name: string
    description: string
    iconName: string
    /** Launches the application. */
    launch: () => void
}

function toEntry(app: Apps.Application): AppEntry {
    return {
        name: app.name,
        description: app.description,
        iconName: app.iconName,
        launch: () => app.launch(),
    }
}

/** Fuzzy query ranked by usage frequency. */
export function fuzzyApps(query: string): AppEntry[] {
    debugLog("apps", "fuzzyApps query=", query)
    const matches = query === "" ? apps.list : apps.fuzzy_query(query)
    const ranked = rankByFrecency(matches, (a) => a.name).map(toEntry)
    debugLog("apps", "fuzzyApps query=", query, "results=", ranked.length)
    return ranked
}
