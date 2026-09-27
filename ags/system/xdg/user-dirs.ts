import GLib from "gi://GLib"
import { debugLog } from "@/lib/log"

function specialDir(kind: GLib.UserDirectory, label: string): string | null {
    const dir = GLib.get_user_special_dir(kind)
    if (dir === null) debugLog("xdg", "user dir null", label)
    return dir
}

export const userDirs = {
    get desktop(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_DESKTOP, "desktop")
    },
    get documents(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_DOCUMENTS, "documents")
    },
    get download(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_DOWNLOAD, "download")
    },
    get music(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_MUSIC, "music")
    },
    get pictures(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_PICTURES, "pictures")
    },
    get publicshare(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_PUBLIC_SHARE, "publicshare")
    },
    get templates(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_TEMPLATES, "templates")
    },
    get videos(): string | null {
        return specialDir(GLib.UserDirectory.DIRECTORY_VIDEOS, "videos")
    },
} as const
