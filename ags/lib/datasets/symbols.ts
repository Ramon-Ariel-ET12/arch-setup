import { debugLog } from "@/lib/log"
import { loadCached, rankByName, readUtf8File, words } from "@/lib/unicode-dataset"

/**
 * Unicode symbols dataset + search, built from the system Unicode data
 * (`unicode-character-database` package → /usr/share/unicode/UnicodeData.txt
 * and /usr/share/unicode/NameAliases.txt).
 *
 * Categories are derived from the UCD's own general categories (Sm, Sc, So,
 * …) plus targeted code-point ranges for arrows and typography.
 */

export interface SymbolEntry {
    char: string
    name: string
    category: string
    keywords: string[]
}

export const SYMBOL_CATEGORIES = [
    "Math",
    "Arrows",
    "Currency",
    "Typography",
    "Misc",
] as const

const UCD = "/usr/share/unicode/UnicodeData.txt"
const ALIASES = "/usr/share/unicode/NameAliases.txt"

function categoryFor(cp: number, ucdCat: string): string | null {
    if (ucdCat === "Sm") return "Math"
    if (ucdCat === "Sc") return "Currency"
    if (cp >= 0x2190 && cp <= 0x21ff) return "Arrows"
    if (cp >= 0x2000 && cp <= 0x206f) return "Typography"
    if (cp >= 0x2100 && cp <= 0x214f) return "Typography"
    if ([0x00a9, 0x00ae, 0x2122, 0x00b6, 0x00a7, 0x2117, 0x00b0].includes(cp)) {
        return "Typography"
    }
    if (ucdCat === "So" && (cp >= 0x2600 && cp <= 0x27bf || cp >= 0x2b00 && cp <= 0x2bff)) {
        return "Misc"
    }
    return null
}

interface Cache {
    index: SymbolEntry[]
}

const getCache = loadCached<Cache>(() => {
    const index: SymbolEntry[] = []
    const seen = new Set<string>()

    const aliasText = readUtf8File(ALIASES)
    const aliases = new Map<string, string[]>()
    for (const raw of aliasText.split("\n")) {
        const line = raw.split("#", 1)[0].trim()
        if (line === "") continue
        const m = line.match(/^([0-9A-F]+)\s*;\s*(correction|alternate)\s*;\s*(.+)$/)
        if (!m) continue
        const [, hex, , alias] = m
        const key = parseInt(hex, 16).toString(16).toLowerCase()
        const list = aliases.get(key) ?? []
        list.push(alias.toLowerCase())
        aliases.set(key, list)
    }

    const ucdText = readUtf8File(UCD)
    for (const raw of ucdText.split("\n")) {
        if (raw === "") continue
        const cols = raw.split(";")
        if (cols.length < 3) continue
        const [hex, name, cat] = cols
        const cp = parseInt(hex, 16)
        if (!Number.isFinite(cp) || cp > 0x10ffff) continue
        const cat_ = categoryFor(cp, cat)
        if (cat_ === null) continue
        const nameLc = name.toLowerCase()
        const key = cp.toString(16).toLowerCase()
        const aliasWords = (aliases.get(key) ?? []).flatMap((a) => words(a))
        const keywords = [...new Set([...words(name), ...aliasWords])]
        const ch = String.fromCodePoint(cp)
        if (seen.has(ch)) continue
        seen.add(ch)
        index.push({ char: ch, name: nameLc, category: cat_, keywords })
    }

    // Stable, familiar order: ascending codepoint within each category.
    index.sort((a, b) => (a.char < b.char ? -1 : a.char > b.char ? 1 : 0))
    debugLog("symbols-ds", "parsed", index.length)
    return { index }
})

/** All symbols in a category. */
export function symbolsByCategory(category: string): SymbolEntry[] {
    return getCache().index.filter((s) => s.category === category)
}

/** Search symbols by Unicode name / keyword. Ranks: name-prefix > name-substring > keyword. */
export function searchSymbols(rawQuery: string): SymbolEntry[] {
    const { index } = getCache()
    const results = rankByName(index, rawQuery, (s) => s.name, (s) => s.keywords)
    debugLog("symbols-ds", "search", rawQuery, results.length, index.length)
    return results
}
