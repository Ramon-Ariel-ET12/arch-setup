import Gdk from "gi://Gdk?version=4.0"
import GLib from "gi://GLib"
import { createComputed, createState } from "gnim"
import { debugLog } from "@/lib/log"
import { getHistory, copyEntry, type ClipboardEntry } from "@/services/clipboard"
import { emojiGroups, emojiByGroup, searchEmoji } from "@/services/emoji"
import {
    SYMBOL_CATEGORIES,
    symbolsByCategory,
    searchSymbols,
} from "@/services/symbols"
import { closePopup } from "@/services/popups"
import { options } from "@/options"

/**
 * Universal clipboard picker state: query + keyboard cursor + active section.
 * All three panels (clipboard / emoji / symbols) share one flat, ordered item
 * list and one cursor, so arrow/Enter navigation behaves identically everywhere
 * (mirrors `widgets/launcher/actions.ts`).
 *
 * All panels render *windowed* (infinite scroll): only the leading slice of
 * each list is widgetised (`gridInitial` items up front), grown on demand as
 * the scroll nears the bottom (`growSlice`) or the cursor moves past the edge
 * (`ensureVisible`) instead of creating hundreds/thousands of widgets at once.
 */

export type TabId = "clipboard" | "emoji" | "symbols"

export type ClipboardItem =
    | { kind: "header"; label: string }
    | { kind: "clip"; entry: ClipboardEntry }
    | { kind: "char"; char: string; name: string }

const [query, setQueryRaw] = createState("")
const [cursor, setCursor] = createState(0)
const [tab, setTab] = createState<TabId>("emoji")
const [history, setHistory] = createState<ClipboardEntry[]>([])

export const activeCursor = cursor
export const searchText = query
export const activeTab = tab

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

// --- clipboard -----------------------------------------------------------------

/** (Re)load history from cclip; called on open so it stays fresh. */
export async function loadHistory(): Promise<void> {
    const entries = await getHistory()
    debugLog("clipboard", "history loaded", entries.length)
    setHistory(entries)
}

// --- precomputed browse lists (static data, built once) -------------------------

const browseEmoji: ClipboardItem[] = emojiGroups().flatMap((g) => {
    const items = emojiByGroup(g)
    if (items.length === 0) return []
    const header: ClipboardItem = { kind: "header", label: g }
    return [header, ...toCharItems(items)]
})

const browseSymbols: ClipboardItem[] = SYMBOL_CATEGORIES.flatMap((c) => {
    const items = symbolsByCategory(c)
    if (items.length === 0) return []
    const header: ClipboardItem = { kind: "header", label: c }
    return [header, ...toCharItems(items)]
})

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
        case "emoji":
            return q === "" ? browseEmoji : toCharItems(searchEmoji(q))
        case "symbols":
            return q === "" ? browseSymbols : toCharItems(searchSymbols(q))
    }
})

function toCharItems<T extends { char: string; name: string }>(entries: T[]): ClipboardItem[] {
    return entries.map((e): ClipboardItem => ({ kind: "char", char: e.char, name: e.name }))
}

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

/** Copies the item under the cursor (or the passed item) and closes. */
async function select(item: ClipboardItem): Promise<void> {
    if (item.kind === "clip") {
        debugLog("clipboard", "copy id=", item.entry.id)
        await copyEntry(item.entry.id)
    } else if (item.kind === "char") {
        debugLog("clipboard", "copy char", item.char, item.name)
        const display = Gdk.Display.get_default()
        if (display) {
            const clipboard = display.get_clipboard()
            const bytes = new TextEncoder().encode(item.char)
            clipboard.set_content(
                Gdk.ContentProvider.new_for_bytes("text/plain;charset=utf-8", new GLib.Bytes(bytes)),
            )
        }
    }
    closePopup("clipboard")
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
