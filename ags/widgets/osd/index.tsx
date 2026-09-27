import { Astal } from "ags/gtk4"
import app from "ags/gtk4/app"
import { Gtk } from "ags/gtk4"
import { createBinding, createComputed, createEffect, createState } from "gnim"
import { pctLabel } from "@/lib/helpers/numbers"
import { icons } from "@/lib/icons"
import { options } from "@/options"
import { defaultSpeaker } from "@/services/audio"
import { popupTopOffset } from "@/services/hyprland"
import { focusedGdk, mainGdk, monitors } from "@/services/monitors"

/**
 * On-screen indicator (volume feedback skeleton).
 * Target monitor configurable via `options.popups.osdTarget`.
 * Flashes on volume changes and auto-hides.
 */

const { TOP } = Astal.WindowAnchor

const OSD_TIMEOUT_MS = 1200

export default function Osd() {
    const [visible, setVisible] = createState(false)
    const [level, setLevel] = createState("")
    const [fraction, setFraction] = createState(0)

    // Follows the configured target monitor; a session always has ≥1 output.
    const target = createComputed(() => {
        void monitors() // invalidate when outputs change
        return (options.popups.osdTarget === "main" ? mainGdk() : focusedGdk()) ??
            app.get_monitors()[0]!
    })

    let hideTimer: ReturnType<typeof setTimeout> | null = null
    const armHide = () => {
        if (hideTimer !== null) clearTimeout(hideTimer)
        hideTimer = setTimeout(() => setVisible(false), OSD_TIMEOUT_MS)
    }

    // Reacts to volume changes of the current default speaker; the effect
    // scope re-subscribes when the default device itself changes. The very
    // first run only establishes the subscription (no flash at startup).
    let initialized = false
    createEffect(() => {
        const speaker = defaultSpeaker()
        if (speaker === null) return
        const volume = createBinding(speaker, "volume")()
        if (!initialized) {
            initialized = true
            setLevel(pctLabel(volume))
            setFraction(volume > 1 ? volume / 100 : volume)
            return
        }
        setLevel(pctLabel(volume))
        setFraction(volume > 1 ? volume / 100 : volume)
        setVisible(true)
        armHide()
    })

    return (
        <window
            name="osd"
            namespace="osd"
            application={app}
            visible={visible}
            gdkmonitor={target}
            anchor={TOP}
            margin_top={popupTopOffset}
            exclusivity={Astal.Exclusivity.IGNORE}
            keymode={Astal.Keymode.NONE}
            layer={Astal.Layer.OVERLAY}
        >
            <box class="card" spacing={8}>
                <image iconName={icons.audio.high} />
                <levelbar
                    class="osd-level"
                    widthRequest={160}
                    valign={Gtk.Align.CENTER}
                    vexpand
                    mode={Gtk.LevelBarMode.CONTINUOUS}
                    minValue={0}
                    maxValue={1}
                    value={fraction}
                />
                <label label={level} />
            </box>
        </window>
    )
}
