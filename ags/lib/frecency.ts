import { FRECENCY_JSON, LEGACY_FRECENCY_JSON } from "./paths"
import { debugLog } from "@/lib/log"
import { loadJson, saveJson } from "./json-state"

/**
 * Tiny JSON-backed frecency cache used to rank launcher apps.
 * Scores are capped so one entry cannot dominate forever, and the store is
 * pruned on write so it cannot grow unbounded.
 */

const MAX_SCORE = 1_000
const MAX_ENTRIES = 200

type Scores = Record<string, number>

const scores: Scores = loadJson<Scores>(
    FRECENCY_JSON,
    {},
    (raw) => (typeof raw === "object" && raw !== null && !Array.isArray(raw)
        ? (raw as Scores)
        : {}),
    LEGACY_FRECENCY_JSON,
)

function score(key: string): number {
    return scores[key] ?? 0
}

/** Keeps only the `MAX_ENTRIES` highest-scoring keys (in place). */
function prune(): void {
    const keys = Object.keys(scores)
    if (keys.length <= MAX_ENTRIES) return
    keys.sort((a, b) => scores[b] - scores[a])
    const dropped = keys.slice(MAX_ENTRIES)
    for (const key of dropped) delete scores[key]
    debugLog("frecency", "prune dropped", dropped.length)
}

/** Records a usage of `key`. */
export function bumpFrecency(key: string): void {
    debugLog("frecency", "bump", key)
    scores[key] = Math.min((scores[key] ?? 0) + 1, MAX_SCORE)
    prune()
    saveJson(FRECENCY_JSON, scores)
}

/** Ranks an entry by frecency score (descending). Accepts readonly inputs. */
export function rankByFrecency<T>(items: readonly T[], keyOf: (item: T) => string): T[] {
    return [...items].sort(
        (a, b) => score(keyOf(b)) - score(keyOf(a)),
    )
}
