import GLib from "gi://GLib"

export const COOLDOWN_MS = 10_000
export const BODY_MAX = 300

export type LogLevel = "DEBUG" | "INFO" | "WARN" | "ERROR"

/**
 * Dev-only debug logging. Enabled when `AGS_DEBUG` is set (see
 * `tools/dev-reload.sh`, which exports it for `bun run dev`).
 *
 * Every line follows `TIMESTAMP | LEVEL | FILE:LINE | METHOD() | MESSAGE`:
 * `12:04:31.123 | DEBUG | json-state.ts:42 | loadJson() | [json] load /path/...`
 *
 * - FILE:LINE names the source when esbuild preserves it in the frame
 *   (`system/xdg/base.ts:1501`); otherwise it is the bundle (`ags.js:3386`)
 *   — grep METHOD() to find the source in that case.
 * - The `[scope]` prefix in MESSAGE names the module for grep.
 * - Disabled (plain `ags run` = production): zero output, returns `false`
 *   so callers can skip expensive formatting work.
 *
 * Never sends desktop notifications — use `logWarn`/`logError` for
 * user-visible failures (same line format, level WARN/ERROR, always on).
 */
export function debugLog(scope: string, ...args: unknown[]): boolean {
    if (GLib.getenv("AGS_DEBUG") === null) return false
    const c = callerInfo()
    print(`${timestamp()} | DEBUG | ${c.file}:${c.line} | ${c.method}() | [${scope}] ${args.map(formatArg).join(" ")}`)
    return true
}

/**
 * Same line format at an explicit level. DEBUG stays gated on `AGS_DEBUG`;
 * INFO/WARN/ERROR always print (WARN/ERROR go to stderr). An empty scope
 * omits the `[scope]` segment.
 *
 * Prefer the named wrappers below over calling this directly: `logInfo` for
 * one-shot milestones (daemon starts, cache writes), `logWarn`/`logError`
 * from `lib/notify` for failures (they also notify + dedupe).
 */
export function logLine(level: LogLevel, scope: string, ...args: unknown[]): void {
    if (level === "DEBUG" && GLib.getenv("AGS_DEBUG") === null) return
    const c = callerInfo()
    const tag = scope === "" ? "" : `[${scope}] `
    const line = `${timestamp()} | ${level} | ${c.file}:${c.line} | ${c.method}() | ${tag}${args.map(formatArg).join(" ")}`
    if (level === "WARN" || level === "ERROR") printerr(line)
    else print(line)
}

export function timestamp(): string {
    const d = new Date()
    return `${pad(d.getHours())}:${pad(d.getMinutes())}:${pad(d.getSeconds())}.${pad(d.getMilliseconds(), 3)}`
}

/**
 * One-shot milestone at INFO (always on, stdout). For rare lifecycle events
 * only (startup phases, daemon starts) — per-action tracing stays DEBUG.
 */
export function logInfo(scope: string, ...args: unknown[]): void {
    logLine("INFO", scope, ...args)
}

function pad(n: number, len = 2): string {
    return String(n).padStart(len, "0")
}

interface Caller {
    file: string
    line: string
    method: string
}

const INTERNAL_METHODS = new Set([
    "callerInfo",
    "debugLog",
    "logLine",
    "logInfo",
    "logWarn",
    "logError",
    "send",
    "formatArg",
    "formatError",
])

function callerInfo(): Caller {
    const stack = new Error().stack ?? ""
    for (const raw of stack.split("\n")) {
        const frame = raw.trim()
        if (frame === "") continue
        const parsed = parseV8Frame(frame) ?? parseGjsFrame(frame)
        if (parsed === null || INTERNAL_METHODS.has(parsed.method)) continue
        return parsed
    }
    return { file: "unknown", line: "?", method: "top" }
}

/** `at foo (file:///x/ags.js:12:34)` / `at async foo (...)` / `at file:///x:12:34` (bun/node). */
function parseV8Frame(frame: string): Caller | null {
    const m = frame.match(/^at\s+(?:async\s+)?(?:(.+?)\s+\()?(.+?):(\d+)(?::\d+)?\)?$/)
    if (!m) return null
    const rawMethod = (m[1] ?? "").trim()
    return {
        file: baseName(m[2] ?? "unknown"),
        line: m[3] ?? "?",
        method: rawMethod === "" ? "top" : rawMethod,
    }
}

/**
 * `system/xdg/base.ts@file:///x/ags.js:1501:13` — path-like frames carry the
 * real source *file* in the name (method is `top` at module scope), so FILE
 * is the source and LINE stays the bundle line;
 * `loadJson@file:///x/ags.js:3386:11` carries a *method* and the bundle as
 * the file.
 */
function parseGjsFrame(frame: string): Caller | null {
    const m = frame.match(/^(.*)@(.+?):(\d+)(?::\d+)?$/)
    if (!m) return null
    const rawNames = (m[1] ?? "").trim()
    const last = rawNames === "" ? "" : (rawNames.split(" ").pop() ?? "")
    if (last === "") return { file: baseName(m[2] ?? "unknown"), line: m[3] ?? "?", method: "top" }
    if (isPathLike(last)) return { file: last, line: m[3] ?? "?", method: "top" }
    return {
        file: baseName(m[2] ?? "unknown"),
        line: m[3] ?? "?",
        method: cleanMethod(last),
    }
}

function isPathLike(name: string): boolean {
    return name.includes("/") || /\.(ts|tsx|js|jsx)$/.test(name)
}

/** Strip esbuild artifacts: `getCache<` → `getCache`, keep dedupe `getCache2`. */
function cleanMethod(name: string): string {
    return name.replace(/<+$/, "")
}

function baseName(path: string): string {
    const base = path.split("/").pop() ?? path
    return base === "" ? path : base
}

export function formatArg(arg: unknown): string {
    if (typeof arg === "string") return arg
    if (arg instanceof Error) return formatError(arg)
    if (typeof arg === "object" && arg !== null) {
        if (isGjsStackObject(arg)) return formatError(arg)
        try {
            const json = JSON.stringify(arg)
            return json.length > 300 ? json.slice(0, 300) + "…" : json
        } catch {
            return String(arg)
        }
    }
    return String(arg)
}

function formatError(arg: object): string {
    const e = arg as { message?: unknown; stack?: unknown; fileName?: unknown; lineNumber?: unknown }
    const message = typeof e.message === "string" ? e.message : String(arg)
    const firstStackLine =
        typeof e.stack === "string" ? e.stack.split("\n")[1]?.trim() ?? "" : ""
    const at = firstStackLine.startsWith("at ") ? ` (${firstStackLine.slice(3)})` : ""
    const loc =
        typeof e.fileName === "string"
            ? ` @${e.fileName.split("/").pop()}:${String(e.lineNumber ?? "?")}`
            : ""
    return `${message}${at}${loc}`
}

/** GJS wraps thrown JS errors in plain objects carrying stack/fileName. */
function isGjsStackObject(arg: object): boolean {
    return "stack" in arg && "fileName" in arg
}
