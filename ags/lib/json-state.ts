import GLib from "gi://GLib"
import { debugLog } from "@/lib/log"
import { logWarn } from "@/lib/notify"

/**
 * Tiny JSON-persistence helpers. The shape-aware validation lives in the
 * caller's `validate` callback so the same helpers serve both strict
 * (e.g. monitors.json with a `main` connector) and permissive (e.g. a
 * `WallpaperState` with one optional field) use cases.
 *
 * `loadJson` never throws; `saveJson` returns `false` and warns on
 * failure so callers can decide whether to retry / log / ignore.
 * Both work on any path; the parent directory is created as needed.
 */

export function loadJson<T>(
    path: string,
    fallback: T,
    validate: (raw: unknown) => T,
    legacyPath?: string,
): T {
    debugLog("json", "load", path)
    try {
        let ok: boolean
        let contents: Uint8Array
        ;[ok, contents] = GLib.file_get_contents(path)
        if (!ok && legacyPath) {
            ;[ok, contents] = GLib.file_get_contents(legacyPath)
            if (ok) debugLog("json", "legacy fallback", legacyPath)
        }
        if (!ok) return fallback
        const parsed: unknown = JSON.parse(new TextDecoder().decode(contents!))
        try {
            return validate(parsed)
        } catch {
            debugLog("json", "validate fallback", path)
            return fallback
        }
    } catch (err) {
        debugLog("json", "load fallback", path, err)
        return fallback
    }
}

export function saveJson<T>(path: string, value: T): boolean {
    try {
        GLib.mkdir_with_parents(GLib.path_get_dirname(path), 0o755)
        GLib.file_set_contents(path, JSON.stringify(value, null, 4) + "\n")
        debugLog("json", "saved", path)
        return true
    } catch {
        logWarn(`failed to persist ${path}`)
        return false
    }
}
