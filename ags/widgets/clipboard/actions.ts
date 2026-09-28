import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib"
import { execAsync } from "ags/process"
import { createComputed, createState } from "gnim"
import type { TabDef } from "@/components"
import { debugLog } from "@/lib/log"
import { loadJson, saveJson } from "@/lib/json-state"
import { logWarn } from "@/lib/notify"
import { CLIPBOARD_RECENTS_JSON, LEGACY_CLIPBOARD_RECENTS_JSON } from "@/lib/paths"
import { getHistory, copyEntry, type ClipboardEntry } from "@/services/clipboard"
import { emojiGroups, emojiByGroup, searchEmoji } from "@/services/emoji"
import {
    SYMBOL_CATEGORIES,
    symbolsByCategory,
    searchSymbols,
} from "@/services/symbols"
import { focusInsertTarget, getCursorPosition, getInsertTarget, restoreCursorPosition } from "@/services/hyprland"
import { closePopup, presentPopup } from "@/services/popups"
import { options } from "@/options"

/**
 * Universal clipboard picker state: query + keyboard cursor + active section.
 * Clipboard is a vertical list; emoji/symbols are wrap-grids with their own
 * second-level tabs (Recents + one per dataset group/category, each with an
 * independent MRU). All panels share one cursor, so arrow/Enter navigation
 * behaves identically everywhere (mirrors `widgets/launcher/actions.ts`).
 *
 * Emoji/symbols are *inserted* into the previously focused window via `wtype`
 * (and always copied to the clipboard as fallback); clipboard entries are
 * restored via `cclip copy`.
 *
 * All panels render *windowed* (infinite scroll): only the leading slice of
 * each list is widgetised (`gridInitial` items up front), grown on demand as
 * the scroll nears the bottom (`growSlice`) or the cursor moves past the edge
 * (`ensureVisible`) instead of creating hundreds/thousands of widgets at once.
 */

export type TabId = "clipboard" | "emoji" | "symbols"

/** Second-level tab id: "Recents" or a dataset group/category name. */
export const RECENT_TAB = "Recents"

export type ClipboardItem =
    | { kind: "header"; label: string }
    | { kind: "clip"; entry: ClipboardEntry }
    | { kind: "char"; char: string; name: string }

const [query, setQueryRaw] = createState("")
const [cursor, setCursor] = createState(0)
const [tab, setTab] = createState<TabId>("emoji")
const [history, setHistory] = createState<ClipboardEntry[]>([])
// Per-grid-tab second-level category (memory kept across tab switches).
const [emojiCat, setEmojiCat] = createState<string>(RECENT_TAB)
const [symbolCat, setSymbolCat] = createState<string>(RECENT_TAB)

export const activeCursor = cursor
export const searchText = query
export const activeTab = tab
export const emojiCategory = emojiCat
export const symbolCategory = symbolCat

export const EMOJI_SUB_TABS: readonly TabDef<string>[] = [
    { id: RECENT_TAB, label: RECENT_TAB },
    ...emojiGroups().map((g): TabDef<string> => ({ id: g, label: g })),
]

export const SYMBOL_SUB_TABS: readonly TabDef<string>[] = [
    { id: RECENT_TAB, label: RECENT_TAB },
    ...SYMBOL_CATEGORIES.map((c): TabDef<string> => ({ id: c, label: c })),
]

/** Grid layout: whether `id` renders as a wrap-grid (vs. a vertical list). */
export function isGridTab(id: TabId): boolean {
    return id === "emoji" || id === "symbols"
}

/**
 * Number of grid columns. Derived from the card's content width and the cell
 * pitch so keyboard navigation stays in sync with the FlowBox wrapping.
 */
const CARD_PADDING = 24
export const gridColumns = Math.max(
    1,
    Math.floor((options.clipboard.width - CARD_PADDING) / (options.clipboard.cell + 4)),
)

// --- glyph recents (MRU per kind, persisted) -----------------------------------

interface GlyphRecent {
    char: string
    name: string
}

interface GlyphRecents {
    emoji: GlyphRecent[]
    symbols: GlyphRecent[]
}

function cleanRecentList(raw: unknown): GlyphRecent[] {
    if (!Array.isArray(raw)) return []
    const out: GlyphRecent[] = []
    for (const entry of raw) {
        if (typeof entry !== "object" || entry === null) continue
        const { char, name } = entry as Record<string, unknown>
        if (typeof char !== "string" || char === "" || typeof name !== "string") continue
        if (out.some((r) => r.char === char)) continue
        out.push({ char, name })
        if (out.length >= options.clipboard.recentsLimit) break
    }
    return out
}

const initialRecents = loadJson<GlyphRecents>(
    CLIPBOARD_RECENTS_JSON,
    { emoji: [], symbols: [] },
    (raw) => {
        if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
            return { emoji: [], symbols: [] }
        }
        const r = raw as Record<string, unknown>
        return { emoji: cleanRecentList(r.emoji), symbols: cleanRecentList(r.symbols) }
    },
    LEGACY_CLIPBOARD_RECENTS_JSON,
)

const [emojiRecents, setEmojiRecents] = createState<GlyphRecent[]>(initialRecents.emoji)
const [symbolRecents, setSymbolRecents] = createState<GlyphRecent[]>(initialRecents.symbols)

// Pending MRU reorders: written on every insert, applied to the live state
// only by `flushRecents()`. Null means nothing pending for that kind.
let pendingEmoji: GlyphRecent[] | null = null
let pendingSymbols: GlyphRecent[] | null = null

/** Moves `char` to the front of its kind's MRU (capped, persisted, deferred).
 *
 * The reorder is persisted immediately but applied to the live (rendered)
 * state only by `flushRecents()` on picker close — otherwise every insert
 * would reshuffle the open grid under the cursor (the just-used glyph
 * jumping to the row start while the highlight stays on its index and
 * lands on a different item).
 */
function recordRecent(kind: "emoji" | "symbols", char: string, name: string): void {
    debugLog("clipboard", "recent", kind, name)
    const current =
        kind === "emoji"
            ? (pendingEmoji ?? emojiRecents.peek())
            : (pendingSymbols ?? symbolRecents.peek())
    const next = [{ char, name }, ...current.filter((r) => r.char !== char)].slice(
        0,
        options.clipboard.recentsLimit,
    )
    if (kind === "emoji") pendingEmoji = next
    else pendingSymbols = next
    saveJson<GlyphRecents>(CLIPBOARD_RECENTS_JSON, {
        emoji: pendingEmoji ?? emojiRecents.peek(),
        symbols: pendingSymbols ?? symbolRecents.peek(),
    })
}

/**
 * Applies pending MRU reorders to the live grid state. Called when the
 * picker closes (and defensively on open), so the next open shows the
 * updated Recents while the current session's grid stays stable.
 */
export function flushRecents(): void {
    if (pendingEmoji !== null) {
        setEmojiRecents(pendingEmoji)
        pendingEmoji = null
    }
    if (pendingSymbols !== null) {
        setSymbolRecents(pendingSymbols)
        pendingSymbols = null
    }
}

/** True when the active grid tab sits on an empty Recents category (hint row). */
export const showRecentsHint = createComputed(() => {
    if (query().trim() !== "") return false
    if (tab() === "emoji") return emojiCat() === RECENT_TAB && emojiRecents().length === 0
    if (tab() === "symbols") return symbolCat() === RECENT_TAB && symbolRecents().length === 0
    return false
})

// --- clipboard -----------------------------------------------------------------

/** (Re)load history from cclip; called on open so it stays fresh. */
export async function loadHistory(): Promise<void> {
    const entries = await getHistory()
    debugLog("clipboard", "history loaded", entries.length)
    setHistory(entries)
}

// --- item mapping ---------------------------------------------------------------

function toCharItems<T extends { char: string; name: string }>(entries: T[]): ClipboardItem[] {
    return entries.map((e): ClipboardItem => ({ kind: "char", char: e.char, name: e.name }))
}

// --- results -------------------------------------------------------------------

/** The full ordered list currently shown, driven by tab() + query(). */
export const activeEntries = createComputed<ClipboardItem[]>(() => {
    const q = query().trim().toLowerCase()
    switch (tab()) {
        case "clipboard": {
            const h = history()
            if (q === "") return h.map((e) => ({ kind: "clip", entry: e }))
            return h
                .filter((e) => e.preview.toLowerCase().includes(q))
                .map((e) => ({ kind: "clip", entry: e }))
        }
        case "emoji": {
            // Search always spans the whole dataset; the category only
            // filters the empty-query browse view.
            if (q !== "") return toCharItems(searchEmoji(q))
            const cat = emojiCat()
            if (cat === RECENT_TAB) return toCharItems(emojiRecents())
            return toCharItems(emojiByGroup(cat))
        }
        case "symbols": {
            if (q !== "") return toCharItems(searchSymbols(q))
            const cat = symbolCat()
            if (cat === RECENT_TAB) return toCharItems(symbolRecents())
            return toCharItems(symbolsByCategory(cat))
        }
    }
})

// --- windowed rendering (infinite scroll) ------------------------------------------

/**
 * Total navigable items on the active tab (headers excluded) — independent of
 * how many are currently widgetised.
 */
const totalCount = createComputed(() => {
    if (!isGridTab(tab())) return activeEntries().length
    return activeEntries().reduce((n, e) => (e.kind !== "header" ? n + 1 : n), 0)
})

/**
 * How many leading `activeEntries` items are currently widgetised. Starts at
 * `gridInitial` and grows by `gridBatch` on demand (infinite scroll) so large
 * lists (browse emojis, full history) are never built at once.
 */
const [visibleCount, setVisibleCount] = createState(0)

/**
 * The list the focus ring + list/grid iterate over: the active tab's items,
 * windowed to the leading `visibleCount` so only rendered items are
 * widgetised. Grid tabs drop headers first, so the FlowBox index equals the
 * cursor index (no header-crossing in 2D navigation).
 */
export const navigableEntries = createComputed<ClipboardItem[]>(() => {
    const entries = activeEntries()
    if (!isGridTab(tab())) return entries.slice(0, visibleCount())
    return entries.filter((e) => e.kind !== "header").slice(0, visibleCount())
})

/** Shows the first screenful (tab switch, new query, reopen). */
export function resetSlice(): void {
    setVisibleCount(options.clipboard.gridInitial)
}

/** Appends the next `gridBatch` items to the rendered window (infinite scroll). */
export function growSlice(): void {
    setVisibleCount((n) => Math.min(n + options.clipboard.gridBatch, totalCount.peek()))
}

// --- navigation + selection -----------------------------------------------------

/** Whether `item` is navigable (headers are skipped by the cursor). */
function navigable(picked: ClipboardItem | undefined): boolean {
    return picked !== undefined && picked.kind !== "header"
}

/**
 * Move the cursor by a (dx, dy) delta.
 * - Grid tabs (emoji/symbols): dy moves by one row (columns), dx by one cell;
 *   wraps around the full headerless grid, clamped to bounds. The cursor may
 *   run past the rendered slice — `ensureVisible` grows the window to cover it.
 * - Clipboard (linear list): only dy navigates; dx is a no-op (returns false so
 *   the caller can fall back to section switching).
 * Returns true when the key was consumed (moved or an edge was hit).
 */
export function moveSelection(dx: -1 | 0 | 1, dy: -1 | 0 | 1): boolean {
    if (!isGridTab(tab.peek()) && dx !== 0) return false

    const total = totalCount.peek()
    if (total === 0) return true

    if (!isGridTab(tab.peek())) {
        // Linear vertical movement over the full list, wrapping (clipboard).
        if (dy === 0) return true
        setCursor((cursor.peek() + dy + total) % total)
        return true
    }

    // Grid movement over the full headerless list.
    const step = dy * gridColumns + dx
    if (step === 0) return true
    const target = cursor.peek() + step
    if (target < 0) { setCursor(0); return true } // top/left edge: clamp to first
    if (target >= total) { setCursor(total - 1); return true } // bottom/right edge
    setCursor(target)
    return true
}

/**
 * Grow the rendered window so it covers at least up to `index` plus one batch,
 * keeping the cursor on a real item. Called post-move.
 */
export function ensureVisible(index: number): void {
    const needed = Math.min(index + options.clipboard.gridBatch, totalCount.peek())
    setVisibleCount((n) => Math.max(n, needed))
}

/** Activates the item under the cursor (or the passed item). */
async function select(item: ClipboardItem): Promise<void> {
    if (item.kind === "clip") {
        debugLog("clipboard", "copy id=", item.entry.id)
        await copyEntry(item.entry.id)
        closePopup("clipboard")
    } else if (item.kind === "char") {
        // Char items only come from the active grid tab's dataset.
        const kind = tab.peek() === "symbols" ? "symbols" : "emoji"
        await insertChar(item.char, item.name, kind)
    }
}

/** Copies `char` to the Wayland clipboard (fallback + clipboard continuity). */
function copyChar(char: string): void {
    const display = Gdk.Display.get_default()
    if (!display) return
    const clipboard = display.get_clipboard()
    const bytes = new TextEncoder().encode(char)
    clipboard.set_content(
        Gdk.ContentProvider.new_for_bytes("text/plain;charset=utf-8", new GLib.Bytes(bytes)),
    )
}

function delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
            resolve()
            return GLib.SOURCE_REMOVE
        })
    })
}

/**
 * Inserts a glyph into the window focused before the picker opened.
 *
 * The glyph is always copied to the clipboard first (fallback + history),
 * then typed via `wtype` after refocusing the captured target. The pointer
 * position is captured up front and restored right after typing, undoing
 * the warp the refocus causes (`cursor:no_warps` is false). With
 * `keepOpenOnCharInsert` the picker stays mapped for multi-insert and only
 * reclaims keyboard focus afterwards; otherwise it closes up front and
 * Hyprland's own refocus + the explicit focus below both target the client.
 */
async function insertChar(char: string, name: string, kind: "emoji" | "symbols"): Promise<void> {
    debugLog("clipboard", "insert char", char, name)
    recordRecent(kind, char, name)
    copyChar(char)
    // Capture the pointer before the refocus below warps it into the
    // target client; restored right after typing so the cursor never
    // visibly migrates as a side effect of picking a glyph.
    const savedCursor = await getCursorPosition()
    // Capture the target while the picker still owns focus (the layer
    // surface is not a regular client, so `focusedClient` still points at
    // the underlying window); only then close for the refocus grace.
    const target = await getInsertTarget()
    const keepOpen = options.clipboard.keepOpenOnCharInsert
    if (!keepOpen) closePopup("clipboard")
    if (target === null) {
        logWarn("no window to insert into — glyph copied to clipboard")
        return
    }
    let focused = false
    try {
        if (!(await focusInsertTarget(target))) return
        focused = true
        await delay(options.clipboard.typeDelayMs)
        try {
            await execAsync([...options.clipboard.typeCommand, char])
        } catch (err) {
            debugLog("clipboard", "type failed", err)
            if (options.clipboard.typeFallbackToClipboard) {
                logWarn("typing failed — glyph copied to clipboard instead")
            } else {
                logWarn("typing failed (wtype)")
            }
        }
    } finally {
        if (focused && savedCursor !== null) await restoreCursorPosition(savedCursor)
    }
    if (keepOpen) presentPopup("clipboard")
}

export async function activateSelected(): Promise<boolean> {
    ensureVisible(cursor.peek())
    const item = navigableEntries.peek()[cursor.peek()]
    if (!navigable(item)) return true
    await select(item)
    return true
}

/** Selects a specific item (used by mouse click on a row). */
export async function activateItem(item: ClipboardItem): Promise<void> {
    if (navigable(item)) await select(item)
}

// --- section switching ----------------------------------------------------------

/** Set the query text: results re-rank, so reset cursor + window. */
export function setQuery(text: string): void {
    setQueryRaw(text)
    setCursor(0)
    resetSlice()
}

export function switchTab(id: TabId): void {
    debugLog("clipboard", "tab", id)
    setTab(id)
    setQueryRaw("")
    setCursor(0)
    resetSlice()
}

/** Switches the active grid tab's second-level category (clears the query). */
export function switchCategory(id: string): void {
    const t = tab.peek()
    if (t === "emoji") setEmojiCat(id)
    else if (t === "symbols") setSymbolCat(id)
    else return
    debugLog("clipboard", "category", t, id)
    setQuery("")
}

export function switchRelative(left: boolean): boolean {
    const order: TabId[] = ["clipboard", "emoji", "symbols"]
    const idx = order.indexOf(tab.peek())
    const step = left ? -1 : 1
    switchTab(order[((idx + step) % order.length + order.length) % order.length])
    return true
}

/** Resets query + cursor when the picker reopens. */
export function resetClipboard(): void {
    setQueryRaw("")
    setCursor(0)
    resetSlice()
}
