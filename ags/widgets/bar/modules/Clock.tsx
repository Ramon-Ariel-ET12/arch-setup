import GLib from "gi://GLib"
import { Gtk } from "ags/gtk4"
import { createPoll } from "ags/time"
import { createComputed } from "gnim"
import { activeClass } from "@/lib/helpers/cursor"
import { popupIsOpen, togglePopup } from "@/services/popups"
import { currentWeather, weatherIcon } from "@/services/weather"

/**
 * Datetime bar module — click toggles the calendar popup.
 *
 * Stacked layout: 24h time (HH:MM) on top, `weekday, month day` below;
 * weather (icon + °C) sits next to it in the same button. Refreshes every
 * 10s so the minute flips on time without a per-second wakeup.
 */
export function Clock() {
    const tick = createPoll("", 10_000, () =>
        GLib.DateTime.new_now_local().format("%H:%M\n%A, %B %d") ?? "",
    )
    const time = createComputed(() => tick().split("\n")[0] ?? "")
    const date = createComputed(() => tick().split("\n")[1] ?? "")
    const temp = createComputed(() => {
        const t = currentWeather().temp
        return t === null ? "—" : `${Math.round(t)}°C`
    })
    const icon = createComputed(() => {
        const w = currentWeather()
        return weatherIcon(w.code, w.isDay)
    })
    const tooltip = createComputed(() => {
        const w = currentWeather()
        const label = w.temp === null ? "Weather unavailable" : `${Math.round(w.temp)}°C — Open-Meteo`
        return `Calendar\n${label}`
    })
    const open = popupIsOpen("calendar")

    return (
        <button
            class={activeClass(open, "card")}
            onClicked={() => togglePopup("calendar")}
            tooltipText={tooltip}
        >
            <box spacing={8}>
                <box orientation={Gtk.Orientation.VERTICAL}>
                    <label label={time} class="bold" halign={Gtk.Align.CENTER} />
                    <label label={date} class="subtitle" halign={Gtk.Align.CENTER} />
                </box>
                <box spacing={4} valign={Gtk.Align.CENTER}>
                    <image iconName={icon} />
                    <label label={temp} />
                </box>
            </box>
        </button>
    )
}
