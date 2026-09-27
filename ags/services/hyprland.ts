import GLib from "gi://GLib"
import AstalHyprland from "gi://AstalHyprland?version=0.1"
import { createBinding, createComputed, createState, type Accessor } from "gnim"
import { execAsync } from "ags/process"
import { debugLog } from "@/lib/log"
import { logError, logWarn } from "@/lib/notify"
import { callGirAsync } from "@/lib/subprocess"
import { options } from "@/options"

/**
 * Thin access layer over AstalHyprland.
 * The singleton is only ever touched here (DIP); everything else consumes
 * these helpers or `services/monitors`.
 */

export const hypr = AstalHyprland.get_default()

export type HyprMonitor = AstalHyprland.Monitor

/**
 * Hyprland IPC request.
 *
 * GJS gotcha: `message_async` is a C `_async`/`_finish` pair with two
 * overloads, and the runtime dispatches on arity — `hypr.message_async(msg)`
 * throws "At least 2 arguments required", while `hypr.message_async(msg,
 * null)` silently takes the `void` overload (fire-and-forget, result lost).
 * So neither bare form returns the reply: pass a real callback and finish
 * with `message_finish` via the shared `callGirAsync` helper. Every
 * Hyprland request in the shell goes through here so nobody repeats the
 * mistake.
 */
export function hyprMessage(message: string): Promise<string> {
    debugLog("hyprland", "ipc", message.length > 80 ? message.slice(0, 80) + "…" : message)
    return callGirAsync(
        (done) => hypr.message_async(message, done),
        (res) => hypr.message_finish(res),
    )
}

/**
 * Address of the client that should receive typed glyphs (the window
 * focused before the clipboard picker stole keyboard focus). Layer
 * surfaces are not regular clients, so `focusedClient` usually still
 * points at the target while the picker is open. Falls back to the
 * `activewindow` IPC reply; null when nothing focusable exists.
 */
export async function getInsertTarget(): Promise<string | null> {
    try {
        const focused = hypr.get_focused_client()
        const address = focused?.get_address() ?? ""
        if (address !== "" && address !== "0x0") {
            debugLog("hyprland", "insert target via binding", address)
            return address
        }
    } catch (err) {
        debugLog("hyprland", "insert target binding failed", err)
    }
    try {
        const parsed = JSON.parse(await hyprMessage("j/activewindow")) as { address?: unknown }
        if (typeof parsed.address === "string" && parsed.address !== "" && parsed.address !== "0x0") {
            debugLog("hyprland", "insert target via ipc", parsed.address)
            return parsed.address
        }
    } catch (err) {
        debugLog("hyprland", "insert target ipc failed", err)
    }
    return null
}

/**
 * Refocuses a client captured by `getInsertTarget` so `wtype` keystrokes
 * land in the target input instead of the picker. Returns false (with a
 * toast) when the window is gone.
 */
export async function focusInsertTarget(rawAddress: string): Promise<boolean> {
    const address = rawAddress.startsWith("0x") ? rawAddress : `0x${rawAddress}`
    debugLog("hyprland", "focus insert target", address)
    // Astal's `Client.focus()` builds a legacy `dispatch focuswindow
    // address:…` string, which Hyprland 0.56 rejects (Lua shorthand needs
    // `hl.dsp.focus({ window = "address:…" })`). Shell out via `hyprctl`
    // in the verified Lua form instead; `execAsync` rejects on error, so
    // a missing binary or gone window lands in the catch below.
    // `getInsertTarget` may return the bare hex (Astal strips `0x`), while
    // the IPC form keeps it — normalize here so both work.
    try {
        const out = await execAsync([
            "hyprctl",
            "dispatch",
            `hl.dsp.focus({ window = "address:${address}" })`,
        ])
        if (out.trim() !== "ok") {
            debugLog("hyprland", "focus insert target rejected", out)
            logWarn("insert target window is gone")
            return false
        }
        return true
    } catch (err) {
        debugLog("hyprland", "focus insert target failed", err)
    }
    logWarn("insert target window is gone")
    return false
}

/**
 * True while the focused client is real fullscreen (games, fullscreen video).
 * Toast-like surfaces hide during it: a layer surface mapping over a captured
 * game cursor breaks pointer input, and the notifications still land in the
 * center history regardless.
 */
export const focusedFullscreen: Accessor<boolean> = createBinding(hypr, "focusedClient")(
    (client) => client?.fullscreen === AstalHyprland.Fullscreen.FULLSCREEN,
)

export interface CursorPos {
    x: number
    y: number
}

export async function getCursorPosition(): Promise<CursorPos | null> {
    const parse = (raw: string): CursorPos | null => {
        try {
            const pos = JSON.parse(raw) as CursorPos
            if (typeof pos.x === "number" && typeof pos.y === "number") return pos
        } catch {
        }
        return null
    }
    try {
        const pos = parse(await hyprMessage("j/cursorpos"))
        if (pos) return pos
        debugLog("hyprland", "cursorpos ipc empty, trying hyprctl")
    } catch (err) {
        debugLog("hyprland", "cursorpos ipc failed, trying hyprctl", err)
    }
    try {
        const pos = parse(await execAsync(["hyprctl", "-j", "cursorpos"]))
        if (pos) {
            debugLog("hyprland", "cursorpos via hyprctl", pos.x, pos.y)
            return pos
        }
    } catch (err) {
        debugLog("hyprland", "cursorpos hyprctl failed", err)
    }
    // GTK note: no GDK fallback — GTK4 removed the global pointer query
    // (Seat/Device expose no position API; only events carry coordinates), so
    // Astal IPC with a `hyprctl` fallback is the only source. The caller falls
    // back to the margin position on null. Warns via the notify util (console
    // + toast); error-reporter dedups repeats within COOLDOWN_MS.
    logWarn("failed to read cursor position from Hyprland")
    return null
}

export interface HyprlandOptions {
    gapsIn: number
    gapsOut: number
    borderSize: number
    borderActive: string
    borderInactive: string
    rounding: number
    roundingPower: number
    activeOpacity: number
    inactiveOpacity: number
    shadowEnabled: boolean
    shadowRange: number
    shadowColor: string
    blurEnabled: boolean
    blurSize: number
    blurPasses: number
    animEnabled: boolean
    layout: string
}

interface HyprOptionReply {
    option: string
    int?: number
    float?: number
    str?: string
    bool?: boolean
    gradient?: string
}

const FALLBACKS: HyprlandOptions = {
    gapsIn: 5,
    gapsOut: 18,
    borderSize: 2,
    borderActive: "#99ccfa",
    borderInactive: "#8c9198",
    rounding: 8,
    roundingPower: 2,
    activeOpacity: 0.92,
    inactiveOpacity: 0.82,
    shadowEnabled: true,
    shadowRange: 10,
    shadowColor: "#1a110f55",
    blurEnabled: true,
    blurSize: 6,
    blurPasses: 2,
    animEnabled: true,
    layout: "scrolling",
}

const OPTION_MAP: readonly (readonly [keyof HyprlandOptions, string])[] = [
    ["gapsIn", "general:gaps_in"],
    ["gapsOut", "general:gaps_out"],
    ["borderSize", "general:border_size"],
    ["borderActive", "general:col.active_border"],
    ["borderInactive", "general:col.inactive_border"],
    ["rounding", "decoration:rounding"],
    ["roundingPower", "decoration:rounding_power"],
    ["activeOpacity", "decoration:active_opacity"],
    ["inactiveOpacity", "decoration:inactive_opacity"],
    ["shadowEnabled", "decoration:shadow:enabled"],
    ["shadowRange", "decoration:shadow:range"],
    ["shadowColor", "decoration:shadow:color"],
    ["blurEnabled", "decoration:blur:enabled"],
    ["blurSize", "decoration:blur:size"],
    ["blurPasses", "decoration:blur:passes"],
    ["animEnabled", "animations:enabled"],
    ["layout", "general:layout"],
] as const

/**
 * First color of a Hyprland gradient reply as GTK CSS hex.
 *
 * Border/shadow colors come back as e.g. `"ffffb4a4 eeffb4a4 45deg"`:
 * space-separated AARRGGBB tokens plus an angle. GTK CSS has no
 * gradient-border equivalent, so the leading (opaque) stop is the
 * expressible part — converted from Hypr's AARRGGBB to `#rrggbbaa`.
 */
function gradientFirstToCss(raw: string | undefined): string | null {
    const token = raw?.trim().split(/\s+/)[0]
    if (token === undefined || !/^[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(token)) return null
    if (token.length === 8) {
        const alpha = token.slice(0, 2)
        const rgb = token.slice(2)
        return `#${rgb}${alpha}`
    }
    return `#${token}`
}

function parseOption(
    raw: string,
    key: keyof HyprlandOptions,
): number | string | boolean | null {
    try {
        const reply = JSON.parse(raw) as HyprOptionReply
        if ((key as string) === "layout") {
            if (typeof reply.str === "string") return reply.str
            return null
        }
        if (key === "borderActive" || key === "borderInactive" || key === "shadowColor") {
            return gradientFirstToCss(reply.gradient)
        }
        if (key === "blurEnabled" || key === "animEnabled" || key === "shadowEnabled") {
            if (typeof reply.bool === "boolean") return reply.bool
            if (typeof reply.int === "number") return reply.int !== 0
        }
        if (typeof reply.int === "number") return reply.int
        if (typeof reply.float === "number") {
            if (key === "roundingPower" || key === "activeOpacity" || key === "inactiveOpacity") {
                return reply.float
            }
            return Math.round(reply.float)
        }
        if (typeof reply.bool === "boolean") return reply.bool
        if (typeof reply.str === "string") {
            const n = Number(reply.str)
            if (!Number.isNaN(n)) return n
            if ((key as string) === "layout") return reply.str
        }
    } catch {
    }
    return null
}

function parseGapsIn(raw: string): number | null {
    try {
        const reply = JSON.parse(raw) as HyprOptionReply & { css?: string }
        if (typeof reply.css === "string") {
            const first = reply.css.trim().split(/\s+/)[0]
            if (first !== undefined) {
                const n = Number(first)
                if (!Number.isNaN(n)) return n
            }
        }
        if (typeof reply.int === "number") return reply.int
        if (typeof reply.str === "string") {
            const n = Number(reply.str.split(/\s+/)[0] ?? "")
            if (!Number.isNaN(n)) return n
        }
    } catch {
    }
    return null
}

const [hyprlandOptions, setHyprlandOptions] = createState<HyprlandOptions>({ ...FALLBACKS })

export const hyprGapsIn: Accessor<number> = createComputed(() => hyprlandOptions().gapsIn)
export const hyprGapsOut: Accessor<number> = createComputed(() => hyprlandOptions().gapsOut)
export const hyprBorderSize: Accessor<number> = createComputed(() => hyprlandOptions().borderSize)
export const hyprRounding: Accessor<number> = createComputed(() => hyprlandOptions().rounding)
export const hyprRoundingPower: Accessor<number> = createComputed(() => hyprlandOptions().roundingPower)
export const hyprBlurEnabled: Accessor<boolean> = createComputed(() => hyprlandOptions().blurEnabled)
export const hyprAnimEnabled: Accessor<boolean> = createComputed(() => hyprlandOptions().animEnabled)

export const popupTopOffset: Accessor<number> = createComputed(
    // Floating bar: top margin (gaps_out) + strip + gap below (gaps_out).
    () => options.bar.height + 2 * hyprlandOptions().gapsOut,
)

function hyprlandScssContent(opts: HyprlandOptions): string {
    // roundingPower / blur size-passes-vibrancy-noise / layout are fetched
    // (TS truth via accessors) but intentionally not emitted: GTK CSS has
    // no squircle-power, no backdrop-blur, and no layout concept.
    // Per-leaf animation speeds (`hyprctl animations`) stay compositor-side
    // for the same reason — only the enabled flag maps onto Reveal.
    return `/* ========================================================================== */
/* GENERATED — DO NOT EDIT                                                     */
/* Sourced from Hyprland via j/getoption on startup + config-reloaded.         */
/* Regenerated by services/hyprland.ts :: writeHyprlandScss()                  */
/* ========================================================================== */

$hypr-gaps-in: ${opts.gapsIn}px;
$hypr-gaps-out: ${opts.gapsOut}px;
$hypr-border-size: ${opts.borderSize}px;
$hypr-border-active: ${opts.borderActive};
$hypr-border-inactive: ${opts.borderInactive};
$hypr-rounding: ${opts.rounding}px;
$hypr-active-opacity: ${opts.activeOpacity};
$hypr-inactive-opacity: ${opts.inactiveOpacity};
$hypr-shadow-enabled: ${opts.shadowEnabled ? "true" : "false"};
$hypr-shadow-range: ${opts.shadowRange}px;
$hypr-shadow-color: ${opts.shadowColor};
$hypr-anim-enabled: ${opts.animEnabled ? "true" : "false"};
`
}

function writeHyprlandScss(opts: HyprlandOptions): void {
    const path = options.paths.styleHyprlandScss
    const content = hyprlandScssContent(opts)
    try {
        const [ok, bytes] = GLib.file_get_contents(path)
        if (ok && bytes !== null && new TextDecoder().decode(bytes) === content) {
            debugLog("hyprland", "scss unchanged, skip write")
            return
        }
    } catch {
    }
    const dir = GLib.path_get_dirname(path)
    try {
        GLib.mkdir_with_parents(dir, 0o755)
    } catch {
    }
    try {
        GLib.file_set_contents(path, content)
        debugLog("hyprland", "scss written")
    } catch {
        logWarn("failed to write Hyprland-generated SCSS")
    }
}

const OPTION_RETRY_MS = 100
const RELOAD_DEBOUNCE_MS = 400

function delay(ms: number): Promise<void> {
    return new Promise((resolve) => {
        GLib.timeout_add(GLib.PRIORITY_DEFAULT, ms, () => {
            resolve()
            return GLib.SOURCE_REMOVE
        })
    })
}

async function fetchOption(
    key: keyof HyprlandOptions,
    name: string,
): Promise<number | string | boolean | null> {
    for (let attempt = 0; attempt < 2; attempt++) {
        try {
            const raw = await hyprMessage(`j/getoption ${name}`)
            if (raw) {
                const value =
                    key === "gapsIn" || key === "gapsOut"
                        ? parseGapsIn(raw)
                        : parseOption(raw, key)
                if (value !== null) return value
            }
        } catch (err) {
            debugLog("hyprland", "getoption failed", name, err)
        }
        if (attempt === 0) await delay(OPTION_RETRY_MS)
    }
    debugLog("hyprland", "getoption fallback", name)
    return null
}

let syncInFlight = false
let syncQueued = false

export async function syncHyprlandOptions(): Promise<boolean> {
    if (syncInFlight) {
        syncQueued = true
        debugLog("hyprland", "sync queued, already in flight")
        return false
    }
    syncInFlight = true
    debugLog("hyprland", "sync start")
    try {
        const next = { ...hyprlandOptions.peek() }
        for (const [key, name] of OPTION_MAP) {
            const value = await fetchOption(key, name)
            if (value !== null && (next[key] as unknown) !== value) {
                ;(next as Record<string, unknown>)[key] = value
            }
        }
        let changed = false
        const current = hyprlandOptions.peek()
        for (const [key] of OPTION_MAP) {
            if ((current[key] as unknown) !== (next[key] as unknown)) {
                changed = true
                break
            }
        }
        if (changed) {
            debugLog("hyprland", "sync changed, recompiling theme")
            setHyprlandOptions(next)
            writeHyprlandScss(next)
            try {
                const { compileAndReload } = await import("@/services/theme")
                await compileAndReload()
            } catch (error) {
                logError(error)
            }
        } else {
            debugLog("hyprland", "sync no change")
            writeHyprlandScss(next)
        }
        return changed
    } finally {
        syncInFlight = false
        if (syncQueued) {
            syncQueued = false
            void syncHyprlandOptions()
        }
    }
}

export async function setHyprlandOption(option: string, value: string | number): Promise<void> {
    debugLog("hyprland", "set", option, value)
    try {
        await hyprMessage(`keyword ${option} ${String(value)}`)
    } catch {
        logWarn(`failed to set Hyprland option ${option}`)
    }
}

let reloadDebounceId: number | null = null
let syncReadyResolve: () => void = () => {}
export const syncReady: Promise<void> = new Promise((resolve) => {
    syncReadyResolve = resolve
})

export function initHyprlandSync(): void {
    debugLog("hyprland", "init sync")
    void syncHyprlandOptions()
        .catch(() => {})
        .finally(() => syncReadyResolve())
    hypr.connect("config-reloaded", () => {
        debugLog("hyprland", "config-reloaded, debouncing sync")
        if (reloadDebounceId !== null) GLib.source_remove(reloadDebounceId)
        reloadDebounceId = GLib.timeout_add(GLib.PRIORITY_DEFAULT, RELOAD_DEBOUNCE_MS, () => {
            reloadDebounceId = null
            void syncHyprlandOptions()
            return GLib.SOURCE_REMOVE
        })
    })
}
