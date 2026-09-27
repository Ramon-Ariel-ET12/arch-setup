import { createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { loadJson, saveJson } from "@/lib/json-state"
import { LEGACY_PREFS_JSON } from "@/lib/paths"
import { options } from "@/options"

/**
 * Persisted shell preferences (currently only do-not-disturb).
 * Stored in `data/prefs.json`; kept intentionally tiny.
 */

interface Prefs {
    dnd: boolean
}

const PREFS_JSON = options.paths.prefsJson

const validatePrefs = (raw: unknown): Prefs => {
    if (typeof raw !== "object" || raw === null) return { dnd: false }
    const r = raw as Partial<Prefs>
    return { dnd: r.dnd === true }
}

const [state, setState] = createState<Prefs>(
    loadJson<Prefs>(PREFS_JSON, { dnd: false }, validatePrefs, LEGACY_PREFS_JSON),
)

export const dndEnabled: Accessor<boolean> = state((s) => s.dnd)

export function setDnd(enabled: boolean): void {
    debugLog("config", "setDnd enabled=", enabled)
    setState((current) => {
        const next = { ...current, dnd: enabled }
        saveJson(PREFS_JSON, next)
        return next
    })
}
