import { execAsync } from "ags/process"
import Gdk from "gi://Gdk?version=4.0"
import { debugLog } from "@/lib/log"
import { runBytes } from "@/lib/subprocess"
import { decodeImageBytes, getCachedTexture } from "@/lib/image"

export interface ClipboardEntry {
    /** Stable history index (cclip row id, an integer). */
    id: string
    /** Rendered preview (first line of the copied text). */
    preview: string
    /** MIME type reported by cclip (e.g. "text/plain;charset=utf-8", "image/png"). */
    mime: string
    /** Best-effort classification used only for icon/thumbnail decisions. */
    type: "text" | "image"
    /** Unix timestamp in seconds, when known. */
    timestamp?: number
    /** Cached decoded thumbnail, filled lazily on first preview render. */
    texture?: Gdk.Texture
}

/**
 * Lists the clipboard history (newest first) from cclip.
 * Resolves to `[]` when cclip is unavailable or has no history.
 */
export async function getHistory(limit = 100): Promise<ClipboardEntry[]> {
    debugLog("clipboard-svc", "getHistory")
    let out: string
    try {
        out = await execAsync(["cclip", "list", "id,preview,time,mime_type"])
    } catch {
        // cclip missing/empty — empty state, not an error the UI should break on.
        debugLog("clipboard-svc", "getHistory cclip unavailable, returning []")
        return []
    }

    const entries: ClipboardEntry[] = []
    for (const line of out.split("\n")) {
        if (line === "") continue
        const cols = line.split("\t")
        const [idStr, previewRaw, timeStr, mimeRaw] = cols
        if (idStr === undefined || previewRaw === undefined) continue
        const mime = mimeRaw ?? ""
        const isImage = mime.startsWith("image/")
        const timeNum = timeStr !== undefined ? Number(timeStr) : NaN
        const preview = isImage
            ? (previewRaw === "" ? "Image" : previewRaw.split("\n")[0].slice(0, 120))
            : previewRaw.split("\n")[0].slice(0, 120)
        entries.push({
            id: idStr,
            preview,
            mime,
            type: isImage ? "image" : "text",
            timestamp: Number.isFinite(timeNum) ? timeNum : undefined,
        })
    }
    debugLog("clipboard-svc", "getHistory results=", entries.length)
    return entries.slice(0, limit)
}

/**
 * Copies an entry into the Wayland clipboard. `cclip copy` validates the id
 * is an integer and pushes the stored bytes back; no shell pipe involved.
 */
export async function copyEntry(id: string): Promise<void> {
    debugLog("clipboard-svc", "copyEntry id=", id)
    if (!/^\d+$/.test(id)) return
    await execAsync(["cclip", "copy", id])
}

export async function decodeImage(
    entry: ClipboardEntry,
    maxDim = 64,
): Promise<Gdk.Texture | null> {
    debugLog("clipboard-svc", "decodeImage id=", entry.id)
    if (entry.type !== "image") return null
    const cached = getCachedTexture(entry.id) ?? entry.texture
    if (cached !== undefined) {
        debugLog("clipboard-svc", "decodeImage cache hit id=", entry.id)
        return cached
    }
    debugLog("clipboard-svc", "decodeImage cache miss id=", entry.id)
    if (!/^\d+$/.test(entry.id)) return null
    const bytes = await runBytes(["cclip", "get", entry.id])
    if (bytes === null) return null
    const tex = decodeImageBytes(bytes, maxDim)
    if (tex === null) return null
    entry.texture = tex
    const { decodeImageEntry } = await import("@/lib/image")
    await decodeImageEntry(entry.id, bytes, tex)
    return tex
}
