import Gio from "gi://Gio?version=2.0"
import { options } from "@/options"
import { debugLog } from "@/lib/log"
import { runCommand, runCommandChecked } from "@/lib/subprocess"

export interface WallpaperEntry {
    path: string
    name: string
}

export function listWallpapers(): WallpaperEntry[] {
    const dir = Gio.File.new_for_path(options.wallpaper.dir)
    if (!dir.query_exists(null)) {
        debugLog("wallpaper-backend", "missing dir", options.wallpaper.dir)
        return []
    }
    const entries: WallpaperEntry[] = []
    let enumerator: Gio.FileEnumerator
    try {
        enumerator = dir.enumerate_children(
            "standard::name,standard::type",
            Gio.FileQueryInfoFlags.NONE,
            null,
        )
    } catch {
        debugLog("wallpaper-backend", "enumerate failed", options.wallpaper.dir)
        return []
    }
    let info: Gio.FileInfo | null
    while ((info = enumerator.next_file(null)) !== null) {
        const fileType = info.get_file_type()
        if (fileType !== Gio.FileType.REGULAR) continue
        const name = info.get_name() ?? ""
        if (!/\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(name)) continue
        entries.push({ name, path: dir.get_child(name).get_path()! })
    }
    enumerator.close(null)
    debugLog("wallpaper-backend", "list", entries.length, options.wallpaper.dir)
    return entries.sort((a, b) => a.name.localeCompare(b.name))
}

export function isGif(path: string): boolean {
    return /\.gif$/i.test(path)
}

export function delay(ms: number): Promise<void> {
    return new Promise((resolve) => setTimeout(resolve, ms))
}

export async function ensureDaemon(): Promise<void> {
    const [name] = options.wallpaper.daemon
    let running = false
    try {
        const out = await runCommandChecked(["pgrep", "-x", name])
        running = out.length > 0
    } catch {
        running = false
    }
    if (running) {
        debugLog("wallpaper-backend", "daemon already running", name)
        return
    }
    debugLog("wallpaper-backend", "starting daemon", name)
    try {
        const proc = Gio.Subprocess.new(
            [name],
            Gio.SubprocessFlags.STDOUT_SILENCE | Gio.SubprocessFlags.STDERR_SILENCE,
        )
        void proc
    } catch {
        await runCommand(["sh", "-c", `setsid ${name} >/dev/null 2>&1 < /dev/null &`])
    }
    const deadline = Date.now() + 2000
    while (Date.now() < deadline) {
        try {
            const out = await runCommandChecked(["pgrep", "-x", name])
            if (out.length > 0) return
        } catch {
        }
        await delay(200)
    }
    debugLog("wallpaper-backend", "daemon start timed out", name)
}

export function paintArgs(path: string): string[] {
    const args = [...options.wallpaper.setCommand, path]
    if (isGif(path)) {
        debugLog("wallpaper-backend", "paint gif", path)
        return args
    }
    debugLog("wallpaper-backend", "paint transition", path)
    const { type, position, duration, fps, bezier } = options.wallpaper.transitions
    args.push("--transition-type", type)
    args.push("--transition-pos", position)
    args.push("--transition-duration", String(duration))
    args.push("--transition-fps", String(fps))
    args.push("--transition-bezier", bezier)
    return args
}

interface AwwwQueryOutput {
    displaying?: { image?: unknown } | unknown
}

/**
 * Ground truth: what the daemon is actually displaying right now.
 * Returns the image path or `null` (daemon down, unparseable output, or a
 * non-image fill like `awww clear`). Never throws — callers treat `null`
 * as "unknown, keep stored state".
 */
export async function queryCurrentPath(): Promise<string | null> {
    let out: string
    try {
        out = await runCommandChecked(["awww", "query", "-j"])
    } catch {
        debugLog("wallpaper-backend", "query failed: daemon down")
        return null
    }
    try {
        const parsed = JSON.parse(out) as Record<string, AwwwQueryOutput[]>
        for (const outputs of Object.values(parsed)) {
            const first = Array.isArray(outputs) ? outputs[0] : undefined
            const displaying = first?.displaying
            if (
                displaying !== null &&
                typeof displaying === "object" &&
                typeof (displaying as { image?: unknown }).image === "string"
            ) {
                const image = (displaying as { image: string }).image
                debugLog("wallpaper-backend", "query", image)
                return image
            }
        }
    } catch {
        debugLog("wallpaper-backend", "query failed: unparseable output")
        return null
    }
    debugLog("wallpaper-backend", "query null: no image displayed")
    return null
}
