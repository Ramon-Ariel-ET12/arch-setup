import { Popup } from "@/components"

/**
 * Calendar popup — month view (`Gtk.Calendar`, registered in
 * `components/intrinsics.ts`), opened from the bar clock.
 * Top-center dropdown card on the focused monitor, at the calendar's
 * natural size (`null` percentages skip the popup sizing).
 */
export default function CalendarPopup() {
    return (
        <Popup name="calendar" title="Calendar" widthPct={null} heightPct={null}>
            <calendar />
        </Popup>
    )
}
