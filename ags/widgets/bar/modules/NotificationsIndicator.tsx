import { Gtk } from "ags/gtk4"
import { activeClass } from "@/lib/helpers/cursor"
import { icons } from "@/lib/icons"
import { dndEnabled, setDnd } from "@/services/config"
import { openPopup, popupIsOpen } from "@/services/popups"
import { notificationHistory } from "@/widgets/notifications/history"

/**
 * Notifications badge (bar center; mounted only on the main monitor).
 * Count = saved history entries (survives toast expiry), not the daemon's
 * live list. Left-click opens the notification center; right-click toggles DND.
 */
export function NotificationsIndicator() {
    const count = notificationHistory((list) => list.length)
    const isOpen = popupIsOpen("notifcenter")
    const bellName = dndEnabled((dnd) => (dnd ? icons.ui.bellOff : icons.ui.bell))

    return (
        <button
            class={activeClass(isOpen, "card")}
            onClicked={() => openPopup("notifcenter")}
            tooltipText="Notifications — left: center, right: do not disturb"
            $={(self: Gtk.Button) => {
                const gesture = new Gtk.GestureClick()
                gesture.set_button(3)
                gesture.connect("pressed", () => setDnd(!dndEnabled()))
                self.add_controller(gesture)
            }}
        >
            <box spacing={4}>
                <image iconName={bellName} />
                <label label={count((n) => (n > 0 ? String(n) : ""))} />
            </box>
        </button>
    )
}
