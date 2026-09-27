import { createState } from "gnim"
import { debugLog } from "@/lib/log"
import { runAction } from "@/lib/helpers/run-action"

export function useRowAction() {
    const [busy, setBusy] = createState(false)
    const [error, setError] = createState("")
    const notBusy = busy((b) => !b)
    const run = (fn: () => Promise<unknown> | void) => {
        if (busy.peek()) debugLog("row-action", "skip busy")
        runAction({ busy, setBusy, setError }, fn)
    }
    return { busy, setBusy, error, setError, notBusy, run } as const
}

export type RowAction = ReturnType<typeof useRowAction>
