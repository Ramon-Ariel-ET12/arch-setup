import type { Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { logError } from "@/lib/notify"

/**
 * Wraps an async action with the standard "guard against re-entry, mark
 * busy, clear error, run, finish" dance shared by every device/network
 * action in the bar modules.
 *
 * - If `busy()` is already true the call is a no-op.
 * - On success, `setBusy(false)` is called and the error is cleared.
 * - On failure, the error message is stored via `setError` and busy is
 *   cleared; the original error is logged but not re-thrown.
 */
export interface RunActionOpts {
    busy: Accessor<boolean>
    setBusy: (value: boolean) => void
    setError: (message: string) => void
}

export function runAction(
    opts: RunActionOpts,
    fn: () => Promise<unknown> | void,
): void {
    if (opts.busy.peek()) {
        debugLog("run-action", "busy skip")
        return
    }
    opts.setBusy(true)
    opts.setError("")
    const finish = (err?: unknown) => {
        opts.setBusy(false)
        if (err !== undefined) {
            debugLog("run-action", "failed", err)
            logError(err)
            const msg = err instanceof Error ? err.message : String(err)
            opts.setError(msg === "" ? "Action failed" : msg)
        }
    }
    try {
        const result = fn()
        if (result instanceof Promise) {
            void result.then(() => finish()).catch(finish)
        } else {
            finish()
        }
    } catch (err) {
        finish(err)
    }
}
