import "./components/intrinsics"
import { initHyprlandSync, syncReady } from "./services/hyprland"
import { compileAndReload } from "./services/theme"
import app from "ags/gtk4/app"
import { Bars } from "./widgets/bar"
import MonitorsPopup from "./widgets/monitors"
import LauncherPopup from "./widgets/launcher"
import WallpaperPopup from "./widgets/wallpaper"
import NotificationCenter from "./widgets/notifications/center"
import NotificationDetail from "./widgets/notifications/detail"
import { NotificationPopups } from "./widgets/notifications/popups"
import BindsPopup from "./widgets/binds"
import ClipboardPopup from "./widgets/clipboard"
import CalendarPopup from "./widgets/calendar"
import Osd from "./widgets/osd"
import { start as startWallpaperManager } from "./services/wallpaper"
import { startWeather } from "./services/weather"
import { installErrorReporting, logError } from "@/lib/notify"
import { debugLog } from "@/lib/log"

// Global capture first: every warning/error after this point (GTK/Astal
// GLib warnings, uncaught JS errors) is echoed and notified, including the
// boot-time ones below.
installErrorReporting()
debugLog("app", "initHyprlandSync start")
initHyprlandSync()
await syncReady
debugLog("app", "syncReady done")
debugLog("app", "compileAndReload start")
await compileAndReload()
    .then(() => debugLog("app", "compileAndReload done"))
    .catch((error) => {
        debugLog("app", "compileAndReload fail", error)
        logError(error)
    })

/**
 * Entry point.
 *
 * - One persistent bar per monitor (the only always-visible surface).
 * - Every feature is a named popup card, toggleable via `ags toggle <name>`
 *   (launcher, wallpaper, monitors, notifcenter).
 * - Global surfaces (notification toasts) gate themselves to the main monitor.
 */
function main(): void {
    for (const [popupName, initPopup] of [
        ["monitors", MonitorsPopup],
        ["launcher", LauncherPopup],
        ["wallpaper", WallpaperPopup],
        ["notifcenter", NotificationCenter],
        ["notifdetail", NotificationDetail],
        ["notifpopups", NotificationPopups],
        ["binds", BindsPopup],
        ["clipboard", ClipboardPopup],
        ["calendar", CalendarPopup],
        ["osd", Osd],
    ] as const) {
        debugLog("app", "popup init", popupName)
        initPopup()
    }

    debugLog("app", "wallpaper start")
    startWallpaperManager()
    debugLog("app", "weather start")
    startWeather()

    debugLog("app", "Bars init")
    Bars()
}

app.start({
    requestHandler(argv, res) {
        debugLog("app", "request", argv.join(" "))
        if (argv[0] === "reload-theme") {
            compileAndReload()
                .then(() => res("Theme reloaded"))
                .catch(() => res("Error reloading theme"))
        } else {
            res(`unknown request: ${argv.join(" ")}`)
        }
    },
    main,
})
