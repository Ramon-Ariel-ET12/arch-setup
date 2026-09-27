import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango?version=1.0"
import type AstalNotifd from "gi://AstalNotifd?version=0.1"
import { AppIcon } from "@/components"
import { useNotification, useSavedNotification } from "./notification"
import type { SavedNotification } from "./history"

interface NotificationCardBase {
    subtitle?: string
    timeAlign?: Gtk.Align
    iconSize?: Gtk.IconSize
    iconPixelSize?: number
}

type NotificationCardProps = NotificationCardBase &
    ({ notification: AstalNotifd.Notification; saved?: never } | { saved: SavedNotification; notification?: never })

export function NotificationCard({
    notification,
    saved,
    subtitle,
    timeAlign = Gtk.Align.END,
    iconSize = Gtk.IconSize.LARGE,
    iconPixelSize = 28,
}: NotificationCardProps) {
    const fields =
        saved !== undefined ? useSavedNotification(saved) : useNotification(notification!)
    const { summary, body, appIcon, image, relative } = fields
    return (
        <box spacing={8}>
            <AppIcon name={appIcon()} path={image()} size={iconSize} pixelSize={iconPixelSize} valign={Gtk.Align.CENTER} />
            <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={2} valign={Gtk.Align.START}>
                <label label={summary()} hexpand xalign={0} ellipsize={Pango.EllipsizeMode.END} />
                {body() !== "" && (
                    <label label={body()} xalign={0} wrap opacity={0.75} ellipsize={Pango.EllipsizeMode.END} maxWidthChars={45} />
                )}
                {subtitle !== undefined && (
                    <label label={subtitle} xalign={0} opacity={0.6} wrap />
                )}
                <label label={relative} xalign={0} opacity={0.55} halign={timeAlign} />
            </box>
        </box>
    )
}
