import Gio from "gi://Gio"
import Gtk from "gi://Gtk?version=4.0"
import { debugLog } from "@/lib/log"

export function openUri(uri: string, parent: Gtk.Window | null = null): void {
    debugLog("desktop", "openUri", uri)
    const launcher = new Gtk.UriLauncher({ uri })
    launcher.launch(parent, null, (_src, res) => {
        try {
            launcher.launch_finish(res)
        } catch (err) {
            debugLog("desktop", "openUri failed", uri, err)
        }
    })
}

export function openUriFallback(uri: string): void {
    debugLog("desktop", "openUri fallback", uri)
    try {
        Gio.AppInfo.launch_default_for_uri(uri, null)
    } catch (err) {
        debugLog("desktop", "openUri fallback failed", uri, err)
    }
}
