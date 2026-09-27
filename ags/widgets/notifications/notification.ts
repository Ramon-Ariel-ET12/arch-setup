import AstalNotifd from "gi://AstalNotifd?version=0.1"
import { createBinding, createComputed } from "gnim"
import { formatRelativeTime, formatTimestamp } from "@/lib/time"
import type { SavedNotification } from "./history"

/**
 * Shared reactive accessors for one notification: the common property bindings
 * (summary/body/appIcon/image/time) plus the derived relative/absolute time
 * labels. Used by the toasts, the history cards and the detail popup.
 *
 * Two sources: live daemon objects (reactive bindings) and saved JSON
 * snapshots rehydrated on boot (plain values wrapped read-only — the sender
 * is gone, so nothing can change under us).
 */
export function useNotification(notification: AstalNotifd.Notification) {
    const summary = createBinding(notification, "summary")
    const body = createBinding(notification, "body")
    const appIcon = createBinding(notification, "appIcon")
    const image = createBinding(notification, "image")
    const time = createBinding(notification, "time")

    return {
        summary,
        body,
        appIcon,
        image,
        time,
        relative: createComputed(() => formatRelativeTime(time())),
        absolute: createComputed(() => formatTimestamp(time())),
    }
}

export function useSavedNotification(saved: SavedNotification) {
    return {
        summary: () => saved.summary,
        body: () => saved.body,
        appIcon: () => saved.appIcon,
        image: () => saved.image,
        time: () => saved.time,
        relative: formatRelativeTime(saved.time),
        absolute: formatTimestamp(saved.time),
    }
}
