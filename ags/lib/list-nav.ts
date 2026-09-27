import { createComputed, createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"

export function createQueryState(
    initial = "",
): [Accessor<string>, (text: string) => void, ReturnType<typeof createState<string>>[1]] {
    const [query, setQuery] = createState(initial)
    const set = (text: string): void => setQuery(text)
    return [query, set, setQuery]
}

export function createCursor(
    initial = 0,
): ReturnType<typeof createState<number>> {
    return createState(initial)
}

export function wrapCursor(current: number, delta: number, total: number): number {
    if (total === 0) return 0
    return ((current + delta) % total + total) % total
}

export function clampCursor(value: number, total: number): number {
    if (total === 0) return 0
    return Math.max(0, Math.min(value, total - 1))
}

export interface ListNav<T> {
    query: Accessor<string>
    setQuery: (text: string) => void
    cursor: Accessor<number>
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    setCursor: any
    results: Accessor<T[]>
    moveSelection: (delta: -1 | 1) => boolean
    reset: () => void
}

export function createListNav<T>(opts: {
    fetch: (query: string) => T[]
    initialQuery?: string
}): ListNav<T> {
    const [query, setQueryState] = createState(opts.initialQuery ?? "")
    const [cursor, setCursor] = createState(0)
    const results = createComputed(() => opts.fetch(query()))
    const setQuery = (text: string): void => {
        debugLog("list-nav", "setQuery", text)
        setQueryState(text)
        setCursor(0)
    }
    const moveSelection = (delta: -1 | 1): boolean => {
        const total = results.peek().length
        if (total === 0) {
            debugLog("list-nav", "move empty")
            return true
        }
        setCursor((current) => wrapCursor(current, delta, total))
        debugLog("list-nav", "move", delta)
        return true
    }
    const reset = (): void => {
        debugLog("list-nav", "reset")
        setQueryState("")
        setCursor(0)
    }
    return { query, setQuery, cursor, setCursor, results, moveSelection, reset }
}
