/**
 * Central configuration for the shell.
 *
 * This is the single source of truth for every tunable:
 * paths, monitor connector priority, popup sizing/policies, feature commands.
 * It must not import from `services/`, `components/` or `widgets/`.
 */

import GLib from "gi://GLib"
import { cacheHome, configHome, home, stateHome } from "@/system/xdg/base"
import { userDirs } from "@/system/xdg/user-dirs"

const agsDir = GLib.build_filenamev([configHome, "ags"])
const wallpaperDir = (() => {
    const pictures = userDirs.pictures
    if (pictures) return GLib.build_filenamev([pictures, "Wallpapers"])
    return GLib.build_filenamev([home, "Pictures", "Wallpapers"])
})()

export const options = {
    paths: {
        /** Root of this config (~/.config/ags, symlinked repo on this machine). */
        root: agsDir,
        /** Regenerable runtime caches (safe to wipe) — XDG cache. */
        frecencyJson: GLib.build_filenamev([cacheHome, "ags", "frecency.json"]),
        wallpaperJson: GLib.build_filenamev([cacheHome, "ags", "wallpaper.json"]),
        /** User prefs/state (survives cache wipes) — XDG state. */
        dataDir: GLib.build_filenamev([stateHome, "ags"]),
        monitorsJson: GLib.build_filenamev([stateHome, "ags", "monitors.json"]),
        prefsJson: GLib.build_filenamev([stateHome, "ags", "prefs.json"]),
        notificationsJson: GLib.build_filenamev([stateHome, "ags", "notifications.json"]),
        /** Styles. */
        styleEntry: GLib.build_filenamev([agsDir, "style", "main.scss"]),
        styleHyprlandScss: GLib.build_filenamev([agsDir, "style", "abstracts", "_hyprland.scss"]),
        distCss: GLib.build_filenamev([cacheHome, "ags", "style.css"]),
        /** Legacy paths for migration (read compat). */
        legacyFrecencyJson: GLib.build_filenamev([agsDir, "cache", "frecency.json"]),
        legacyWallpaperJson: GLib.build_filenamev([agsDir, "cache", "wallpaper.json"]),
        legacyMonitorsJson: GLib.build_filenamev([agsDir, "data", "monitors.json"]),
        legacyPrefsJson: GLib.build_filenamev([agsDir, "data", "prefs.json"]),
        legacyDistCss: GLib.build_filenamev([agsDir, "dist", "style.css"]),
    },

    monitors: {
        /**
         * Connector family priority used to sort outputs and to pick the
         * fallback main monitor. First match wins; unknown families sort last.
         */
        connectorPriority: ["EDP", "LVDS", "DSI", "DP", "HDMI", "DVI", "VGA"],
        /** Prefixes considered "internal panels"; preferred as default main. */
        internalPrefixes: ["EDP", "LVDS", "DSI"],
        /** Rewrite data/monitors.json when the saved main is missing/invalid. */
        rewriteOnFallback: true,
    },

    popups: {
        /** Default card size as a percentage of the target monitor. */
        widthPct: 50,
        heightPct: 60,
        /** Margin between bar/card edges. */
        margin: 8,
        /** Opening one popup closes the others. */
        closeOthers: true,
        /** Escape dismisses the focused popup. */
        escToClose: true,
        /** Where OSD surfaces live ("main" | "focused"). */
        osdTarget: "main" as "main" | "focused",
        /**
         * Fallback top offset for anchored-top transient surfaces before the
         * Hyprland gaps sync lands. The live value is `popupTopOffset`
         * (bar height + Hyprland gaps_out) from `services/hyprland`; keep
         * this in sync as bar.height + gaps_out.
         */
        topOffsetFallback: 58,
    },

    bar: {
        /**
         * Fixed bar strip height (px). Keep in sync with $bar-height in
         * style/abstracts/_variables.scss (asserted by `bun run typecheck`).
         */
        height: 40,
    },

    anim: {
        /** Default in-app transition duration (components/Reveal.tsx). */
        duration: 160,
    },

    clipboard: {
        /** Floating clipboard picker card size in px. */
        width: 380,
        height: 480,
        /** Cursor-offset margin when placing the card. */
        margin: 8,
        /** Emoji/symbol grid cell size in px (glyph cell, width + height). */
        cell: 50,
        /** Initial cells rendered before progressive fill starts. */
        gridInitial: 72,
        /** Cells added per progressive fill tick. */
        gridBatch: 40,
    },

    wallpaper: {
        dir: wallpaperDir,
        /** Paint command (awww = swww fork); the image path is appended. */
        setCommand: ["awww", "img"] as string[],
        /** Wallpaper daemon binary, started detached when missing. */
        daemon: ["awww-daemon"] as string[],
        /** Slideshow interval in seconds between images. */
        interval: 120,
        /** awww transition flags applied to every non-gif paint. */
        transitions: {
            type: "fade" as const,
            position: "center" as const,
            duration: 1,
            fps: 60,
            bezier: ".54,0,.34,.99",
        },
        /** Regenerate the matugen palette + reload hypr/theme (gifs skip). */
        matugen: true,
        /** Matugen-template output used to detect a palette change. */
        colorFile: GLib.build_filenamev([configHome, "hypr", "generated", "color.lua"]),
    },
}
