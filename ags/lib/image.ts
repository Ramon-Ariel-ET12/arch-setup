import Gdk from "gi://Gdk?version=4.0"
import GdkPixbuf from "gi://GdkPixbuf"
import Gio from "gi://Gio"
import GLib from "gi://GLib"
import { debugLog } from "@/lib/log"

/**
 * Generic image decoding helpers shared by feature components.
 *
 * Lives in `lib/` (not under any feature) so `AppIcon`, clipboard, and any
 * future surface can read a file from disk and bind it to `<image paintable=>`
 * without duplicating the GdkPixbuf / Gdk.Texture plumbing.
 */

/**
 * Decode a file path into a `Gdk.Texture`. Returns `null` on any failure
 * (file missing, unreadable, not an image) — callers fall through to a
 * theme-name or GIcon source.
 */
export function decodeImageFile(path: string | null | undefined): Gdk.Texture | null {
    if (path === null || path === undefined || path === "") return null
    if (!path.startsWith("/") && !path.startsWith("file://")) return null
    let pixbuf: GdkPixbuf.Pixbuf
    try {
        pixbuf = GdkPixbuf.Pixbuf.new_from_file(path)
    } catch (err) {
        debugLog("image", "decode file failed", path, err)
        return null
    }
    return Gdk.Texture.new_for_pixbuf(pixbuf)
}

/**
 * Decode an in-memory byte buffer into a `Gdk.Texture`. Used when bytes
 * come from a subprocess (cclip, ffmpeg) rather than a file on disk.
 */
export function decodeImageBytes(
    bytes: Uint8Array | null | undefined,
    maxDim = 0,
): Gdk.Texture | null {
    if (bytes === null || bytes === undefined || bytes.length === 0) return null
    let pixbuf: GdkPixbuf.Pixbuf
    try {
        const stream = Gio.MemoryInputStream.new_from_bytes(new GLib.Bytes(bytes))
        pixbuf =
            maxDim > 0
                ? GdkPixbuf.Pixbuf.new_from_stream_at_scale(stream, maxDim, maxDim, true, null)
                : GdkPixbuf.Pixbuf.new_from_stream(stream, null)
    } catch (err) {
        debugLog("image", "decode bytes failed", err)
        return null
    }
    return Gdk.Texture.new_for_pixbuf(pixbuf)
}

const scaledCache = new Map<string, Gdk.Texture>()
const SCALED_CACHE_LIMIT = 200

export function loadScaledTexture(path: string, size: number): Gdk.Texture | null {
    const key = `${path}#${size}`
    const hit = scaledCache.get(key)
    if (hit !== undefined) {
        debugLog("image", "scaled cache hit", key)
        return hit
    }
    let pixbuf: GdkPixbuf.Pixbuf
    try {
        pixbuf = GdkPixbuf.Pixbuf.new_from_file_at_size(path, size, size)
    } catch (err) {
        debugLog("image", "scaled decode failed", path, err)
        return null
    }
    const tex = Gdk.Texture.new_for_pixbuf(pixbuf)
    if (scaledCache.size >= SCALED_CACHE_LIMIT) {
        const oldest = scaledCache.keys().next().value
        if (oldest !== undefined) {
            debugLog("image", "scaled cache evict", oldest)
            scaledCache.delete(oldest)
        }
    }
    scaledCache.set(key, tex)
    debugLog("image", "scaled cache store", key)
    return tex
}

/**
 * Aspect-fill thumbnail: cover-scales the image to `width`×`height` and
 * center-crops, so every cell shows a uniform full-bleed tile (no
 * letterboxing). Used by the wallpaper grid where aspect-fit thumbs left
 * ugly letterboxed slivers. Cached per path+size.
 */
export function loadCoverTexture(path: string, width: number, height: number): Gdk.Texture | null {
    const key = `${path}#cover-${width}x${height}`
    const hit = scaledCache.get(key)
    if (hit !== undefined) {
        debugLog("image", "cover cache hit", key)
        return hit
    }
    let scaled: GdkPixbuf.Pixbuf
    try {
        const [format, srcW, srcH] = GdkPixbuf.Pixbuf.get_file_info(path)
        if (format === null || srcW <= 0 || srcH <= 0) {
            debugLog("image", "cover no info", path)
            return null
        }
        const scale = Math.max(width / srcW, height / srcH)
        const scaledW = Math.max(1, Math.ceil(srcW * scale))
        const scaledH = Math.max(1, Math.ceil(srcH * scale))
        scaled = GdkPixbuf.Pixbuf.new_from_file_at_scale(path, scaledW, scaledH, false)
        const cropX = Math.max(0, Math.floor((scaled.get_width() - width) / 2))
        const cropY = Math.max(0, Math.floor((scaled.get_height() - height) / 2))
        const cropped = scaled.new_subpixbuf(
            cropX,
            cropY,
            Math.min(width, scaled.get_width()),
            Math.min(height, scaled.get_height()),
        )
        scaled = cropped
    } catch (err) {
        debugLog("image", "cover decode failed", path, err)
        return null
    }
    const tex = Gdk.Texture.new_for_pixbuf(scaled)
    if (scaledCache.size >= SCALED_CACHE_LIMIT) {
        const oldest = scaledCache.keys().next().value
        if (oldest !== undefined) {
            debugLog("image", "cover cache evict", oldest)
            scaledCache.delete(oldest)
        }
    }
    scaledCache.set(key, tex)
    debugLog("image", "cover cache store", key)
    return tex
}

const textureCache = new Map<string, Gdk.Texture>()
const TEXTURE_CACHE_LIMIT = 100

function cacheTexture(id: string, tex: Gdk.Texture): void {
    if (textureCache.size >= TEXTURE_CACHE_LIMIT) {
        const oldest = textureCache.keys().next().value
        if (oldest !== undefined) {
            debugLog("image", "entry cache evict", oldest)
            textureCache.delete(oldest)
        }
    }
    textureCache.set(id, tex)
}

export async function decodeImageEntry(
    id: string,
    bytes: Uint8Array | null,
    fallback?: Gdk.Texture,
): Promise<Gdk.Texture | null> {
    const cached = textureCache.get(id) ?? fallback
    if (cached !== undefined) {
        debugLog("image", "entry cache hit", id)
        return cached ?? null
    }
    if (bytes === null) return null
    const tex = decodeImageBytes(bytes)
    if (tex === null) {
        debugLog("image", "entry decode failed", id)
        return null
    }
    cacheTexture(id, tex)
    debugLog("image", "entry cache store", id)
    return tex
}

export function getCachedTexture(id: string): Gdk.Texture | undefined {
    return textureCache.get(id)
}
