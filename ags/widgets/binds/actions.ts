import { createState } from "gnim"
import { debugLog } from "@/lib/log"
import { fetchBinds, type HyprBind } from "@/services/hyprbinds"

const [binds, setBinds] = createState<HyprBind[] | null>(null)

export const bindList = binds

export function refreshBinds(): void {
    debugLog("binds", "refresh")
    fetchBinds().then((list) => {
        debugLog("binds", "loaded", list.length)
        setBinds(list)
    })
}
