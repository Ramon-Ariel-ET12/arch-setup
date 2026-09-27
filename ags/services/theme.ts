import GLib from "gi://GLib"
import app from "ags/gtk4/app"
import { execAsync } from "ags/process"
import { debugLog } from "@/lib/log"
import { DIST_CSS, STYLE_ENTRY } from "@/lib/paths"

/**
 * SCSS compilation + live CSS application.
 * Matugen itself runs externally; this only compiles/consumes its output.
 * Throws on sass errors (callers decide how to surface them).
 */
let compileTail: Promise<void> = Promise.resolve()

export function compileAndReload(): Promise<void> {
    debugLog("theme", "compile queued")
    const run = compileTail.then(runCompile)
    compileTail = run.catch(() => {})
    return run
}

async function runCompile(): Promise<void> {
    debugLog("theme", "compile start")
    GLib.mkdir_with_parents(GLib.path_get_dirname(DIST_CSS), 0o755)
    await execAsync([
        "sass",
        STYLE_ENTRY,
        DIST_CSS,
        "--style=expanded",
        "--no-source-map",
        "--no-charset",
    ])
    app.reset_css()
    app.apply_css(DIST_CSS)
    debugLog("theme", "compile done", DIST_CSS)
}
