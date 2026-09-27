import GLib from "gi://GLib"
import { options } from "@/options"

export const MONITORS_JSON = options.paths.monitorsJson
export const FRECENCY_JSON = options.paths.frecencyJson
export const WALLPAPER_JSON = options.paths.wallpaperJson
export const NOTIFICATIONS_JSON = options.paths.notificationsJson
export const DIST_CSS = options.paths.distCss
export const STYLE_ENTRY = options.paths.styleEntry
export const STYLE_HYPRLAND_SCSS = options.paths.styleHyprlandScss

export const LEGACY_MONITORS_JSON = options.paths.legacyMonitorsJson
export const LEGACY_FRECENCY_JSON = options.paths.legacyFrecencyJson
export const LEGACY_WALLPAPER_JSON = options.paths.legacyWallpaperJson
export const LEGACY_DIST_CSS = options.paths.legacyDistCss
export const LEGACY_PREFS_JSON = options.paths.legacyPrefsJson

/** Expands a leading `~` to `$HOME`. @deprecated Use GLib.build_filenamev with XDG dirs. */
export function expandHome(path: string): string {
    return path.startsWith("~") ? `${GLib.get_home_dir()}${path.slice(1)}` : path
}
