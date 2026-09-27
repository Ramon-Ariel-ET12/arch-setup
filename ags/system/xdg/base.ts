import GLib from "gi://GLib"
import { debugLog } from "@/lib/log"

export const home = GLib.get_home_dir()
export const configHome = GLib.get_user_config_dir()
export const dataHome = GLib.get_user_data_dir()
export const cacheHome = GLib.get_user_cache_dir()
export const stateHome = (() => {
    try {
        return GLib.get_user_state_dir()
    } catch {
        return dataHome
    }
})()
export const runtimeDir = (() => {
    try {
        return GLib.get_user_runtime_dir()
    } catch {
        return null as string | null
    }
})()

export function configFile(...parts: string[]): string {
    return GLib.build_filenamev([configHome, ...parts])
}

export function dataFile(...parts: string[]): string {
    return GLib.build_filenamev([dataHome, ...parts])
}

export function cacheFile(...parts: string[]): string {
    return GLib.build_filenamev([cacheHome, ...parts])
}

debugLog(
    "xdg",
    "dirs",
    home,
    configHome,
    dataHome,
    cacheHome,
    stateHome,
    runtimeDir,
)

export function stateFile(...parts: string[]): string {
    return GLib.build_filenamev([stateHome, ...parts])
}
