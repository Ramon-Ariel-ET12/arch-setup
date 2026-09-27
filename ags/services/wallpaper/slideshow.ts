import GLib from "gi://GLib"
import { options } from "@/options"
import { isGif, paintArgs, ensureDaemon } from "@/lib/wallpaper-backend"
import type { WallpaperEntry } from "@/lib/wallpaper-backend"
import { debugLog } from "@/lib/log"
import { logError, logWarn } from "@/lib/notify"
import { hyprMessage, syncHyprlandOptions } from "@/services/hyprland"
import { currentName, entries, refresh, saveCurrent, setBusy, setCurrentName } from "./store"
import { runCommandChecked } from "@/lib/subprocess"

const RETRY_SECONDS = 5

let lastApplied: string | null = null
/** Path of the last paint known to have succeeded (commit or preview). */
let lastPainted: string | null = null
let applyTail: Promise<void> = Promise.resolve()

async function applyWallpaper(path: string): Promise<void> {
    const run = applyTail.then(() => runApply(path))
    applyTail = run.catch(() => {})
    return run
}

async function runApply(path: string): Promise<void> {
    if (path === lastApplied) return
    await ensureDaemon()
    await runCommandChecked(paintArgs(path))
    lastPainted = path
    await applyTheme(path)
    lastApplied = path
}

/** Paint without committing anything: no matugen, no state, no dedupe. */
async function paintOnly(path: string): Promise<void> {
    await ensureDaemon()
    await runCommandChecked(paintArgs(path))
}

/** Matugen + theme reload for a committed (non-gif) wallpaper. */
async function applyTheme(path: string): Promise<void> {
    if (isGif(path)) {
        logWarn(`gif wallpapers paint only (matugen not implemented yet): ${path}`)
        return
    }
    if (options.wallpaper.matugen) {
        const colorFile = options.wallpaper.colorFile
        const checksum = (p: string): string | null => {
            try {
                const [ok, bytes] = GLib.file_get_contents(p)
                if (!ok) return null
                return GLib.compute_checksum_for_data(GLib.ChecksumType.MD5, bytes)
            } catch {
                return null
            }
        }
        const before = checksum(colorFile)
        await runCommandChecked(["matugen", "image", path])
        const after = checksum(colorFile)
        if (before !== null && before !== after) {
            try {
                await hyprMessage("reload")
            } catch {
                await runCommandChecked(["hyprctl", "reload"])
            }
            await syncHyprlandOptions().catch((error) => logError(error))
        }
    }
    const { compileAndReload } = await import("@/services/theme")
    await compileAndReload().catch((error) => logError(error))
}

let timerId: number | null = null

function armRetry(refreshFn: () => void, beginFn: () => void): void {
    if (timerId !== null) GLib.source_remove(timerId)
    timerId = GLib.timeout_add_seconds(GLib.PRIORITY_DEFAULT, RETRY_SECONDS, () => {
        refreshFn()
        if (entries.peek().length === 0) return true
        beginFn()
        return false
    })
}

function tick(armRetryFn: () => void, cycleFn: (e: WallpaperEntry) => void): boolean {
    const list = entries.peek()
    if (list.length === 0) {
        armRetryFn()
        return false
    }
    const index = list.findIndex((e) => e.name === currentName.peek())
    void cycleFn(list[(index + 1) % list.length])
    return true
}

async function cycle(entry: WallpaperEntry): Promise<void> {
    setBusy(true)
    try {
        await applyWallpaper(entry.path)
    } catch (error) {
        logError(error)
        return
    } finally {
        setBusy(false)
    }
    setCurrentName(entry.name)
    saveCurrent(entry.name)
}

export function createSlideshow(refresh: () => void) {
    let started = false

    const begin = () => beginSlideshow(refresh)

    function arm(): void {
        if (entries.peek().length === 0) {
            armRetry(refresh, begin)
            return
        }
        begin()
    }

    function start(): void {
        if (started) return
        started = true
        refresh()
        arm()
    }

    async function apply(entry: WallpaperEntry): Promise<void> {
        scheduleSlideshow(refresh, begin)
        await cycle(entry)
    }

    return { start, refresh, schedule: () => scheduleSlideshow(refresh, begin), arm, tick, cycle, apply, preview, beginSession, commit: (entry: WallpaperEntry) => commit(refresh, entry), revert, getTimerId: () => timerId }
}

function beginSlideshow(refreshFn: () => void): void {
    const list = entries.peek()
    const id = currentName.peek()
    const index = list.findIndex((e) => e.name === id)
    void cycle(list[index >= 0 ? index : 0])
    scheduleSlideshow(refreshFn, () => beginSlideshow(refreshFn))
}

/** (Re)arm the slideshow timer; shared by `createSlideshow` and `commit`. */
function scheduleSlideshow(refreshFn: () => void, beginFn: () => void): void {
    if (timerId !== null) GLib.source_remove(timerId)
    timerId = GLib.timeout_add_seconds(
        GLib.PRIORITY_DEFAULT,
        options.wallpaper.interval,
        () => tick(() => armRetry(refreshFn, beginFn), cycle),
    )
}

let previewSettled: Promise<void> = Promise.resolve()
let sessionBaseline: WallpaperEntry | null = null
/** Bumps every picker open; stale async reverts check this before painting. */
let sessionGeneration = 0

/**
 * Live preview: paint `entry` immediately without committing — no state
 * write, no matugen, no slideshow reset. Only the latest requested paint
 * lands: a queued preview that is stale by run time is skipped, so rapid
 * carousel stepping runs one `awww img` instead of serializing N paints.
 * Failures are swallowed (the previous wallpaper stays on screen) but
 * tracked: commit compares against the last *successful* paint, never
 * assuming a preview landed.
 */
let previewQueued: WallpaperEntry | null = null
let previewRunning = false

async function pumpPreview(): Promise<void> {
    if (previewRunning) return previewSettled
    previewRunning = true
    const run = (async () => {
        try {
            while (previewQueued !== null) {
                const entry = previewQueued
                previewQueued = null
                try {
                    await paintOnly(entry.path)
                    lastPainted = entry.path
                } catch {
                    debugLog("wallpaper", "preview failed", entry.name)
                }
            }
        } finally {
            previewRunning = false
        }
    })()
    previewSettled = run.catch(() => {})
    return run
}

function preview(entry: WallpaperEntry): Promise<void> {
    debugLog("wallpaper", "preview", entry.name)
    previewQueued = entry
    return pumpPreview()
}

/** Snapshot the committed entry when the picker opens (revert target). */
function beginSession(): void {
    sessionGeneration += 1
    refresh()
    const list = entries.peek()
    sessionBaseline = list.find((e) => e.name === currentName.peek()) ?? null
    debugLog("wallpaper", "beginSession baseline=", sessionBaseline?.name ?? null)
}

/**
 * Commit the previewed entry: wait for in-flight previews to settle, paint
 * if the last successful paint isn't this entry, then write state, run
 * matugen/theme, and reset the slideshow timer. State is only written after
 * a verified paint, so a failed paint can never leave the store ahead of
 * the screen.
 */
async function commit(refreshFn: () => void, entry: WallpaperEntry): Promise<void> {
    debugLog("wallpaper", "commit", entry.name)
    sessionBaseline = null
    await previewSettled.catch(() => {})
    setBusy(true)
    try {
        if (entry.path !== lastPainted) {
            await applyWallpaper(entry.path)
        } else if (entry.path !== lastApplied) {
            await applyTheme(entry.path)
            lastApplied = entry.path
        }
    } catch (error) {
        logError(error)
        throw error
    } finally {
        setBusy(false)
    }
    setCurrentName(entry.name)
    saveCurrent(entry.name)
    scheduleSlideshow(refreshFn, () => beginSlideshow(refreshFn))
}

/**
 * Revert to the session baseline (Esc/close discards the preview). Drains
 * in-flight previews first so the revert paint always wins. Paints via
 * `paintOnly`, not `applyWallpaper`: the `lastApplied` dedupe doesn't know
 * about previews, so a committed-then-previewed baseline would otherwise be
 * skipped as "already applied" while the screen shows the preview.
 * Skipped when a newer session opened mid-revert.
 */
async function revert(): Promise<void> {
    const baseline = sessionBaseline
    const generation = sessionGeneration
    sessionBaseline = null
    debugLog("wallpaper", "revert baseline=", baseline?.name ?? null)
    if (baseline === null) return
    await previewSettled.catch(() => {})
    if (generation !== sessionGeneration) {
        debugLog("wallpaper", "revert skipped: newer session opened")
        return
    }
    if (baseline.path === lastPainted) {
        debugLog("wallpaper", "revert skipped: baseline already showing")
        return
    }
    setBusy(true)
    try {
        await paintOnly(baseline.path)
        lastPainted = baseline.path
        lastApplied = baseline.path
    } catch (error) {
        logError(error)
    } finally {
        setBusy(false)
    }
}

export { applyWallpaper, lastApplied }
