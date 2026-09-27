import { createState } from "gnim"
import { options } from "@/options"
import { debugLog } from "@/lib/log"
import { LEGACY_MONITORS_JSON, MONITORS_JSON } from "@/lib/paths"
import { sortMonitors } from "@/lib/monitor-sorting"
import { loadJson, saveJson } from "@/lib/json-state"
import { hypr, type HyprMonitor } from "@/services/hyprland"

export interface MonitorsJson {
    main?: string | null
}

const EMPTY_MONITORS_JSON: MonitorsJson = {}

export function loadMonitorsJson(): MonitorsJson {
    return loadJson<MonitorsJson>(MONITORS_JSON, EMPTY_MONITORS_JSON, (raw) => {
        if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
            return EMPTY_MONITORS_JSON
        }
        const r = raw as Record<string, unknown>
        return {
            main: typeof r.main === "string" ? r.main : null,
        }
    }, LEGACY_MONITORS_JSON)
}

function saveMonitorsJson(state: MonitorsJson): void {
    saveJson(MONITORS_JSON, state)
}

export function resolveMain(
    saved: string | null | undefined,
    outputs: readonly HyprMonitor[],
): HyprMonitor | null {
    if (outputs.length === 0) return null
    if (saved) {
        const savedMonitor = outputs.find((m) => m.name === saved)
        if (savedMonitor) return savedMonitor
    }
    const sorted = sortMonitors(outputs)
    const internal = sorted.find((m) =>
        options.monitors.internalPrefixes.some((p) => m.name.toUpperCase().startsWith(p)),
    )
    return internal ?? sorted[0]
}

const [jsonState, setJsonState] = createState<MonitorsJson>(loadMonitorsJson())

export { jsonState }

function revalidate(): void {
    const current = jsonState.peek()
    const resolved = resolveMain(current.main, hypr.get_monitors())
    const nextName = resolved?.name ?? null
    if (nextName === current.main) return
    debugLog("monitors", "revalidate", current.main, "->", nextName)
    setJsonState({ ...current, main: nextName })
    if (options.monitors.rewriteOnFallback && current.main !== nextName) {
        saveMonitorsJson({ ...current, main: nextName })
    }
}

hypr.connect("monitor-added", () => {
    debugLog("monitors", "monitor-added")
    revalidate()
})
hypr.connect("monitor-removed", () => {
    debugLog("monitors", "monitor-removed")
    revalidate()
})
revalidate()

export function setMain(name: string): void {
    debugLog("monitors", "setMain", name)
    const next: MonitorsJson = { ...jsonState.peek(), main: name }
    setJsonState(next)
    saveMonitorsJson(next)
}
