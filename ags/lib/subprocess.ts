import { execAsync } from "ags/process"
import Gio from "gi://Gio"
import { debugLog } from "@/lib/log"
import { logWarn } from "@/lib/notify"

export async function runCommand(cmd: readonly string[]): Promise<string> {
    debugLog("subprocess", "run", cmd.join(" "))
    try {
        const stdout = await execAsync(cmd as string[])
        const out = stdout.trim()
        if (out === "") debugLog("subprocess", "run empty", cmd.join(" "))
        return out
    } catch (err) {
        debugLog("subprocess", "run failed", cmd.join(" "), err)
        logWarn(`command failed: ${cmd.join(" ")}`)
        return ""
    }
}

export async function runCommandChecked(cmd: readonly string[]): Promise<string> {
    debugLog("subprocess", "runChecked", cmd.join(" "))
    try {
        const stdout = await execAsync(cmd as string[])
        return stdout.trim()
    } catch (err) {
        debugLog("subprocess", "runChecked failed", cmd.join(" "), err)
        throw err
    }
}

export async function runBytes(argv: string[]): Promise<Uint8Array | null> {
    debugLog("subprocess", "runBytes", argv.join(" "))
    let proc: Gio.Subprocess
    try {
        proc = Gio.Subprocess.new(argv, Gio.SubprocessFlags.STDOUT_PIPE)
    } catch (err) {
        debugLog("subprocess", "runBytes spawn failed", argv.join(" "), err)
        return null
    }
    return new Promise((resolve) => {
        proc.communicate_async(null, null, (_, res) => {
            try {
                const [, out] = proc.communicate_finish(res)
                if (out === null) {
                    debugLog("subprocess", "runBytes null", argv.join(" "))
                    return resolve(null)
                }
                resolve(out.toArray())
            } catch (err) {
                debugLog("subprocess", "runBytes failed", argv.join(" "), err)
                resolve(null)
            }
        })
    })
}

export function callGirAsync<T>(
    start: (done: (source: unknown, res: Gio.AsyncResult) => void) => void,
    finish: (res: Gio.AsyncResult) => T,
): Promise<T> {
    return new Promise((resolve, reject) => {
        start((_source, res) => {
            try {
                resolve(finish(res))
            } catch (err) {
                debugLog("subprocess", "callGirAsync rejected", err)
                reject(err)
            }
        })
    })
}
