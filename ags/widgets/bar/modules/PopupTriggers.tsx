import { icons } from "@/lib/icons"
import { popupIsOpen, togglePopup, type PopupName } from "@/services/popups"

interface Trigger {
    popup: PopupName
    icon: string
    tooltip: string
}

const TRIGGERS: readonly Trigger[] = [
    { popup: "launcher", icon: icons.ui.apps, tooltip: "Launcher" },
    { popup: "clipboard", icon: icons.ui.clipboard, tooltip: "Clipboard" },
    { popup: "wallpaper", icon: icons.ui.wallpaper, tooltip: "Wallpaper" },
    { popup: "monitors", icon: icons.ui.monitors, tooltip: "Monitors" },
    { popup: "binds", icon: icons.ui.keyboard, tooltip: "Keybinds" },
]

/** Bar buttons that open the shared popup cards. */
export function PopupTriggers() {
    return (
        <box class="card" spacing={2}>
            {TRIGGERS.map(({ popup, icon, tooltip }) => {
                const open = popupIsOpen(popup)
                return (
                    <button
                        class={open((o) => (o ? "active" : ""))}
                        onClicked={() => togglePopup(popup)}
                        tooltipText={tooltip}
                    >
                        <image iconName={icon} />
                    </button>
                )
            })}
        </box>
    )
}
