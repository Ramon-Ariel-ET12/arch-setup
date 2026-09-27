import { createState, type Accessor } from "gnim"
import { clampCursor, wrapCursor } from "@/lib/list-nav"
import { closePopup } from "@/services/popups"
import {
    beginSession,
    commit,
    currentWallpaper,
    preview,
    revert,
    wallpaperEntries,
    type WallpaperEntry,
} from "@/services/wallpaper"

/**
 * Wallpaper carousel with live preview:
 * - Focus (arrows, dots) paints the entry immediately, uncommitted.
 * - Esc/Enter/Space commits: state + matugen/theme + slideshow reset, close.
 * - X button / toggle-off reverts to the wallpaper from before opening.
 */

const [cursor, setCursor] = createState(0)
const [committed, setCommitted] = createState(false)

export const activeCursor: Accessor<number> = cursor

function total(): number {
    return wallpaperEntries.peek().length
}

/** Step the carousel; `lastDirection` drives the slide animation. */
const [lastDirection, setLastDirection] = createState<1 | -1>(1)

export const slideDirection: Accessor<1 | -1> = lastDirection

function entryAt(index: number): WallpaperEntry | undefined {
    return wallpaperEntries.peek()[clampCursor(index, total())]
}

/** Focus an entry: move the cursor and paint it as an uncommitted preview. */
export function focusEntry(index: number): void {
    const list = wallpaperEntries.peek()
    if (list.length === 0) return
    const clamped = clampCursor(index, list.length)
    const entry = list[clamped]
    if (entry === undefined) return
    if (clamped !== cursor.peek()) {
        setLastDirection(clamped > cursor.peek() ? 1 : -1)
        setCursor(clamped)
    }
    void preview(entry)
}

export function moveCursor(delta: -1 | 1): boolean {
    const n = total()
    if (n === 0) return true
    setLastDirection(delta)
    const next = wrapCursor(cursor.peek(), delta, n)
    setCursor(next)
    const entry = entryAt(next)
    if (entry !== undefined) void preview(entry)
    return true
}

/** Vertical arrows step the carousel too (single-axis strip). */
export function moveCursorRow(delta: -1 | 1): boolean {
    return moveCursor(delta)
}

export function resetCursor(): void {
    const n = total()
    const current = wallpaperEntries.peek().findIndex((e) => e.name === currentWallpaper())
    setCursor(n === 0 ? 0 : clampCursor(Math.max(0, current), n))
    setCommitted(false)
    beginSession()
}

/** Confirm handler (Esc/Enter/Space/Apply button): commit + close. */
export function applySelected(): boolean {
    const entry = entryAt(cursor.peek())
    if (entry === undefined) return true
    setCommitted(true)
    void commit(entry)
        .then(() => closePopup("wallpaper"))
        .catch(() => setCommitted(false))
    return true
}

/**
 * Revert handler (X button, toggle-off): restore the pre-open wallpaper
 * unless already committed, then close. Revert failures are already logged
 * in the service; the close always lands.
 */
export function cancelPicker(): void {
    if (!committed.peek()) void revert().catch(() => {})
    closePopup("wallpaper")
}
