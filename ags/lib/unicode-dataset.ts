import GLib from "gi://GLib"
import { logWarn } from "@/lib/notify"

/**
 * Shared core for `services/emoji.ts` and `services/symbols.ts`.
 *
 * Both services parse a UTF-8 dataset, derive a name + keyword list per
 * entry, and answer substring queries with the same three-bucket ranking
 * (name-prefix > name-substring > keyword). The file-format-specific
 * parsers stay in each service; this module owns the bits that don't
 * depend on the source format.
 */

/** Stopwords that get filtered out of `words(text)`. */
export const STOPWORDS = new Set([
    "with", "and", "of", "the", "for", "a", "an", "in", "on", "to", "no",
])

/** Lowercase, split on non-alphanumerics, drop stopwords + empties. */
export function words(text: string): string[] {
    return text
        .toLowerCase()
        .split(/[^a-z0-9]+/)
        .filter((w) => w !== "" && !STOPWORDS.has(w))
}

/**
 * Memoized loader. The first call invokes `loader` and caches the result;
 * subsequent calls return the same reference. `loader` itself may throw or
 * return partial data — the cache only commits what the loader returns.
 */
export function loadCached<T>(loader: () => T): () => T {
    let cache: { value: T } | null = null
    return () => {
        if (cache === null) cache = { value: loader() }
        return cache.value
    }
}

/**
 * Ranks items by name-prefix > name-substring > keyword, case-insensitive.
 * Empty `query` returns the input list unchanged. Stable for equal-rank
 * items (input order is preserved).
 */
export function rankByName<T>(
    items: readonly T[],
    query: string,
    nameOf: (item: T) => string,
    keywordsOf: (item: T) => readonly string[],
): T[] {
    const q = query.trim().toLowerCase()
    if (q === "") return [...items]
    const buckets: T[][] = [[], [], []]
    for (const item of items) {
        const name = nameOf(item)
        let bucket = -1
        if (name.startsWith(q)) bucket = 0
        else if (name.includes(q)) bucket = 1
        else if (keywordsOf(item).some((k) => k.includes(q))) bucket = 2
        if (bucket !== -1) buckets[bucket].push(item)
    }
    return [...buckets[0], ...buckets[1], ...buckets[2]]
}

/**
 * Reads a UTF-8 text file from disk. Returns "" on any failure (missing
 * file, permission, decode error) and logs a single warn so missing
 * optional datasets don't spam logs.
 */
export function readUtf8File(path: string): string {
    try {
        const [, bytes] = GLib.file_get_contents(path)
        return new TextDecoder("utf-8").decode(bytes)
    } catch (e) {
        logWarn(`cannot read ${path}: ${e}`)
        return ""
    }
}
