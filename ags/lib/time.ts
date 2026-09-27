import { createState } from "gnim"

/**
 * Reactive wall-clock for relative-time labels ("5m ago" / "Yesterday").
 *
 * One shared 30s ticker for the whole shell, started at module load and never
 * stopped: the cost is one `Date.now()` per 30s, while refcounted
 * start/stop plumbing previously froze every consumer as soon as any single
 * one unsubscribed (e.g. the clipboard picker closing killed the notification
 * center's relative-time labels).
 *
 * `formatRelativeTime` / `formatTimestamp` are pure, reactive on `now()`.
 */

const [now, setNow] = createState(Math.floor(Date.now() / 1000))

setInterval(() => setNow(Math.floor(Date.now() / 1000)), 30_000)

export { now }

/** Human-friendly relative time; the reactive `now` keeps labels live. */
export function formatRelativeTime(timestamp: number | undefined): string {
    if (timestamp === undefined) return ""
    const diff = Math.max(0, now() - timestamp)
    if (diff < 45) return "just now"
    if (diff < 60 * 60) return `${Math.floor(diff / 60)}m ago`
    if (diff < 60 * 60 * 24) return `${Math.floor(diff / 3600)}h ago`
    const days = Math.floor(diff / 86400)
    if (days === 1) return "Yesterday"
    if (days < 7) return `${days}d ago`
    return new Date(timestamp * 1000).toLocaleDateString(undefined, {
        month: "short",
        day: "numeric",
    })
}

/** Precise locale timestamp (for tooltips / detail headers). */
export function formatTimestamp(timestamp: number | undefined): string {
    if (timestamp === undefined) return ""
    return new Date(timestamp * 1000).toLocaleString()
}
