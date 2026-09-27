import AstalNotifd from "gi://AstalNotifd?version=0.1"
import { createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { NOTIFICATIONS_JSON } from "@/lib/paths"
import { loadJson, saveJson } from "@/lib/json-state"
import { closePopup, openPopup } from "@/services/popups"

/**
 * Persisted notification history — the saved list behind the center/detail.
 *
 * The daemon (`AstalNotifd`) only keeps *unresolved* notifications in memory:
 * toasts resolve them on expiry and reboots wipe them, so the center would
 * always be empty. This store snapshots every notification to
 * `notifications.json` (XDG state, survives cache wipes) on `notified` and
 * drops entries on user dismiss (`resolved` by the client, not by timeout).
 *
 * Two record kinds:
 * - live: daemon `Notification` objects (actions invokable, dismiss works).
 * - saved: plain JSON snapshots rehydrated on boot (no actions — the sender
 *   is gone, invoking would be a no-op per the GIR docs).
 */

export interface SavedNotification {
    id: number
    appName: string
    summary: string
    body: string
    appIcon: string
    image: string
    time: number
    urgency: number
}

export type HistoryRecord =
    | { kind: "live"; notification: AstalNotifd.Notification }
    | { kind: "saved"; saved: SavedNotification }

const HISTORY_LIMIT = 100

function snapshot(n: AstalNotifd.Notification): SavedNotification {
    return {
        id: n.id,
        appName: n.appName ?? "",
        summary: n.summary ?? "",
        body: n.body ?? "",
        appIcon: n.appIcon ?? "",
        image: n.image ?? "",
        time: Number(n.time ?? 0),
        urgency: Number(n.urgency ?? 1),
    }
}

function validate(raw: unknown): SavedNotification[] {
    if (!Array.isArray(raw)) return []
    const out: SavedNotification[] = []
    for (const item of raw) {
        if (typeof item !== "object" || item === null) continue
        const r = item as Partial<SavedNotification>
        if (typeof r.id !== "number" || typeof r.summary !== "string") continue
        out.push({
            id: r.id,
            appName: typeof r.appName === "string" ? r.appName : "",
            summary: r.summary,
            body: typeof r.body === "string" ? r.body : "",
            appIcon: typeof r.appIcon === "string" ? r.appIcon : "",
            image: typeof r.image === "string" ? r.image : "",
            time: typeof r.time === "number" ? r.time : 0,
            urgency: typeof r.urgency === "number" ? r.urgency : 1,
        })
    }
    return out
}

const notifd = AstalNotifd.get_default()

function loadSaved(): HistoryRecord[] {
    return loadJson<SavedNotification[]>(NOTIFICATIONS_JSON, [], validate).map((saved) => ({
        kind: "saved",
        saved,
    }))
}

const [history, setHistory] = createState<HistoryRecord[]>(loadSaved())

export const notificationHistory: Accessor<HistoryRecord[]> = history

function persist(): void {
    const snapshots: SavedNotification[] = []
    for (const record of history.peek()) {
        snapshots.push(record.kind === "live" ? snapshot(record.notification) : record.saved)
        if (snapshots.length >= HISTORY_LIMIT) break
    }
    saveJson(NOTIFICATIONS_JSON, snapshots)
}

/** Live record for a daemon id, or null once resolved/saved. */
export function findLive(id: number): AstalNotifd.Notification | null {
    for (const record of history.peek()) {
        if (record.kind === "live" && record.notification.id === id) return record.notification
    }
    return notifd.get_notification(id)
}

/** User dismiss: resolve in the daemon AND drop from history. */
export function dismissRecord(record: HistoryRecord): void {
    const id = record.kind === "live" ? record.notification.id : record.saved.id
    debugLog("notifcenter", "dismiss id=", id)
    if (record.kind === "live") {
        try {
            record.notification.dismiss()
        } catch {
        }
    }
    setHistory((prev) =>
        prev.filter((r) => (r.kind === "live" ? r.notification.id : r.saved.id) !== id),
    )
    persist()
}

export function clearHistory(): void {
    debugLog("notifcenter", "clear", history.peek().length)
    for (const record of history.peek()) {
        if (record.kind === "live") {
            try {
                record.notification.dismiss()
            } catch {
            }
        }
    }
    setHistory([])
    persist()
}

function upsertLive(n: AstalNotifd.Notification): void {
    setHistory((prev) => {
        const rest = prev.filter(
            (r) => (r.kind === "live" ? r.notification.id : r.saved.id) !== n.id,
        )
        const record: HistoryRecord = { kind: "live", notification: n }
        return [record, ...rest].slice(0, HISTORY_LIMIT)
    })
    persist()
}

// ---------------------------------------------------------------------------
// Selection + detail UI state (plain createState: sync, predictable).
// Lives here so center/detail share one module instead of actions.ts.

const [selectionMode, setSelectionMode] = createState(false)
const [selectedIds, setSelectedIds] = createState<Set<number>>(new Set())
const [detailId, setDetailId] = createState<number | null>(null)

export const isSelectionMode: Accessor<boolean> = selectionMode
export const selectedCount: Accessor<number> = selectedIds((s) => s.size)
export const currentDetailId: Accessor<number | null> = detailId

export function toggleSelectionMode(): void {
    setSelectionMode((on) => !on)
    if (selectionMode.peek() === false) {
        setSelectedIds(new Set())
    }
}

export function setSelectionModeOn(on: boolean): void {
    setSelectionMode(on)
    if (!on) setSelectedIds(new Set())
}

/** Tracked check: re-runs whenever the selection set changes. */
export function isSelected(id: number): Accessor<boolean> {
    return selectedIds((set) => set.has(id))
}

export function toggleSelected(id: number): void {
    setSelectedIds((prev) => {
        const next = new Set(prev)
        if (next.has(id)) next.delete(id)
        else next.add(id)
        return next
    })
}

/** Dismiss every selected record; clears the selection afterwards. */
export function deleteSelected(): void {
    const ids = selectedIds.peek()
    if (ids.size === 0) return
    setHistory((prev) => {
        for (const r of prev) {
            if (r.kind === "live" && ids.has(r.notification.id)) {
                try {
                    r.notification.dismiss()
                } catch {
                }
            }
        }
        return prev.filter(
            (r) => !ids.has(r.kind === "live" ? r.notification.id : r.saved.id),
        )
    })
    setSelectedIds(new Set())
    persist()
}

/**
 * Switch to the detail popup for a history id. Closes the center so the
 * detail has the screen; the popup registry handles `closeOthers` when the
 * detail opens if that option is on.
 */
export function openDetail(id: number): void {
    debugLog("notifcenter", "openDetail id=", id)
    setDetailId(id)
    closePopup("notifcenter")
    openPopup("notifdetail")
}

// ---------------------------------------------------------------------------
// Daemon events drive the store below.
notifd.connect("notified", (_d, id: number) => {
    const n = notifd.get_notification(id)
    if (n !== null) upsertLive(n)
})

notifd.connect("resolved", (_d, id: number) => {
    const current = history.peek()
    const record = current.find(
        (r) => (r.kind === "live" ? r.notification.id : r.saved.id) === id,
    )
    if (record === undefined || record.kind === "saved") return
    const saved = snapshot(record.notification)
    setHistory((prev) =>
        prev.map((r) =>
            r.kind === "live" && r.notification.id === id ? { kind: "saved", saved } : r,
        ),
    )
    persist()
})
