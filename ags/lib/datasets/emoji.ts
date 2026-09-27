import { debugLog } from "@/lib/log"
import { loadCached, rankByName, readUtf8File, words } from "@/lib/unicode-dataset"

/**
 * Emoji dataset + search, built from the system Unicode data
 * (`unicode-emoji` package → /usr/share/unicode/emoji/emoji-test.txt).
 *
 * The file groups entries and carries the official CLDR-style names, so the
 * dataset is complete and always matches the installed Unicode version — no
 * hardcoded lists. Parsing is lazy (first search/lookup) and memoized.
 */

export interface EmojiEntry {
    char: string
    name: string
    keywords: string[]
    group: string
}

const EMOJI_TEST = "/usr/share/unicode/emoji/emoji-test.txt"

interface Cache {
    index: EmojiEntry[]
    groups: string[]
}

const getCache = loadCached<Cache>(() => {
    const index: EmojiEntry[] = []
    const groups: string[] = []
    let group = ""
    let subgroup = ""

    const text = readUtf8File(EMOJI_TEST)
    if (text === "") {
        debugLog("emoji-ds", "parse empty", EMOJI_TEST)
        return { index, groups }
    }

    for (const line of text.split("\n")) {
        if (line.startsWith("# group:")) {
            group = line.slice(9).trim()
            if (!groups.includes(group) && group !== "Component") groups.push(group)
            continue
        }
        if (line.startsWith("# subgroup:")) {
            subgroup = line.slice(12).trim()
            continue
        }
        if (line === "" || line.startsWith("#")) continue

        // `<codepoints> ; <status> # <char> E<version> <name>`
        const m = line.match(
            /^([0-9A-F][0-9A-F ]*);\s*fully-qualified\s*#\s*(\S+)\s+E[\d.]+\s+(.+)$/,
        )
        if (!m) continue
        const [, hex, , name] = m
        // Skip the five skin-tone variants of each emoji (search noise).
        if (/\bskin tone\b/i.test(name)) continue

        const keywords = [...new Set([...words(name), ...words(subgroup)])]
        index.push({
            char: fromCodepoints(hex),
            name: name.toLowerCase(),
            keywords,
            group,
        })
    }

    debugLog("emoji-ds", "parsed", index.length, groups.length)
    return { index, groups }
})

function fromCodepoints(hex: string): string {
    return String.fromCodePoint(
        ...hex.trim().split(/\s+/).map((h) => parseInt(h, 16)),
    )
}

/** All emoji groups present in the installed Unicode data (in file order). */
export function emojiGroups(): string[] {
    return getCache().groups
}

/** All entries in a group (in the official file order). */
export function emojiByGroup(group: string): EmojiEntry[] {
    return getCache().index.filter((e) => e.group === group)
}

/** Search emoji by name/keyword. Ranks: name-prefix > name-substring > keyword. */
export function searchEmoji(rawQuery: string): EmojiEntry[] {
    const { index } = getCache()
    const results = rankByName(index, rawQuery, (e) => e.name, (e) => e.keywords)
    debugLog("emoji-ds", "search", rawQuery, results.length, index.length)
    return results
}
