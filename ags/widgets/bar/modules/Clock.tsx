import GLib from "gi://GLib"
import { createPoll } from "ags/time"
import { activeClass } from "@/lib/helpers/cursor"
import { popupIsOpen, togglePopup } from "@/services/popups"

/** Clock bar module — click toggles the calendar popup. */
export function Clock() {
    const time = createPoll("", 1000, () =>
        GLib.DateTime.new_now_local().format("%H:%M") ?? "",
    )
    const open = popupIsOpen("calendar")

    return (
        <button
            class={activeClass(open, "card")}
            onClicked={() => togglePopup("calendar")}
            tooltipText="Calendar"
        >
            <label label={time} />
        </button>
    )
}
