import AstalNotifd from "gi://AstalNotifd?version=0.1"
import { createBinding, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"

export const notifd = AstalNotifd.get_default()

debugLog("notif-svc", "init notifications=", notifd.get_notifications().length)

export const notifications: Accessor<AstalNotifd.Notification[]> = createBinding(notifd, "notifications")

export const dndEnabled = createBinding(notifd, "dontDisturb")

export function getNotifications(): AstalNotifd.Notification[] {
    return notifd.get_notifications()
}

export function getNotification(id: number): AstalNotifd.Notification | null {
    return notifd.get_notification(id)
}
