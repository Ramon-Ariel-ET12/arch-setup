import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango"
import type Astal from "gi://Astal?version=4.0"
import type AstalWp from "gi://AstalWp?version=0.1"
import { With, createBinding, createComputed } from "gnim"
import { Popover } from "@/components"
import { EmptyState } from "@/lib/helpers/empty"
import { pctLabel } from "@/lib/helpers/numbers"
import { icons, micIcon, speakerIcon } from "@/lib/icons"
import { popoverSize } from "@/services/monitors"
import { defaultMic, defaultSpeaker } from "@/services/audio"

/**
 * Audio indicator with an output + input (microphone) control popover.
 *
 * The bar shows a speaker icon + percentage and a microphone icon +
 * percentage (reflecting the mic mute state); clicking opens a GTK4 `Popover` below the button.
 * Inside: a speaker section (icon, name, volume slider, mute toggle) and a
 * microphone section with the same controls. `With` over the reactive default
 * endpoints re-creates the sections when the default device changes.
 */

/** One endpoint row: header (mute button/name/percent) + slider. */
function AudioSection({
    endpoint,
    muteIconFor,
    title,
}: {
    endpoint: AstalWp.Endpoint
    muteIconFor: (muted: boolean) => string
    title: string
}) {
    const volume = createBinding(endpoint, "volume")
    const mute = createBinding(endpoint, "mute")

    const muteIcon = createComputed(() => muteIconFor(mute()))
    const percent = createComputed(() => pctLabel(volume()))
    const deviceName = endpoint.get_description() || title

    return (
        <box class="p-2" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
            <box spacing={10}>
                <button
                    class="card"
                    onClicked={() => endpoint.set_mute(!endpoint.mute)}
                    tooltipText={mute((m) => (m ? "Unmute" : "Mute"))}
                >
                    <image iconName={muteIcon} iconSize={Gtk.IconSize.LARGE} />
                </button>
                <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                    <label label={title} class="text-eyebrow" halign={Gtk.Align.START} />
                    <label
                        label={deviceName}
                        halign={Gtk.Align.START}
                        ellipsize={Pango.EllipsizeMode.END}
                    />
                </box>
                <label label={percent} class="bold" valign={Gtk.Align.CENTER} />
            </box>

            <box spacing={8}>
                <slider
                    hexpand
                    value={volume}
                    max={1}
                    onNotifyValue={(self: Astal.Slider) => {
                        // Binding pushes external volume changes (call ducking,
                        // video players, wpctl keys) into the slider, which also
                        // emits notify::value. Without this guard every external
                        // change writes straight back and fights the source.
                        if (Math.abs(self.value - volume.peek()) < 0.001) return
                        endpoint.volume = self.value
                    }}
                />
            </box>
        </box>
    )
}

export function Audio() {
    const { width } = popoverSize(28, 0, { width: 360, height: 0 })

    return (
        <Popover
            trigger={<AudioTrigger />}
            content={
                <box class="min-w-popup" widthRequest={width} orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                    <With value={defaultSpeaker}>
                        {(sp) =>
                            sp === null ? (
                                <EmptyState icon={icons.audio.muted} label="No audio device" />
                            ) : (
                                <AudioSection endpoint={sp} muteIconFor={(m) => (m ? icons.audio.muted : icons.audio.high)} title="Output" />
                            )
                        }
                    </With>
                    <With value={defaultMic}>
                        {(mic) =>
                            mic === null ? (
                                <box />
                            ) : (
                                <AudioSection endpoint={mic} muteIconFor={(m) => (m ? icons.audio.micMuted : icons.audio.mic)} title="Input" />
                            )
                        }
                    </With>
                </box>
            }
        />
    )
}

/** The bar button: speaker icon + % + microphone icon + % (reflecting mic mute). */
function AudioTrigger() {
    // One With over both endpoints — gnim cannot nest Fragments (With inside
    // With), so the endpoints are merged into a single computed.
    const endpoints = createComputed(() => ({
        speaker: defaultSpeaker(),
        mic: defaultMic(),
    }))

    return (
        <With value={endpoints}>
            {({ speaker, mic }) => {
                const speakerVolume = speaker === null ? null : createBinding(speaker, "volume")
                const speakerMute = speaker === null ? null : createBinding(speaker, "mute")
                const micVolume = mic === null ? null : createBinding(mic, "volume")
                const micMute = mic === null ? null : createBinding(mic, "mute")

                const speakerIconName = createComputed(() => {
                    if (speakerVolume === null || speakerMute === null) return icons.audio.muted
                    return speakerIcon(speakerVolume(), speakerMute())
                })
                const percent = createComputed(() =>
                    speakerVolume === null ? "—" : pctLabel(speakerVolume()),
                )
                const micIconName = createComputed(() =>
                    micVolume === null || micMute === null ? "" : micIcon(micVolume(), micMute()),
                )
                const micPercent = createComputed(() =>
                    micVolume === null ? "—" : pctLabel(micVolume()),
                )

                return (
                    <box spacing={6}>
                        <image iconName={speakerIconName} />
                        <label label={percent} />
                        <image
                            iconName={micIconName}
                            visible={mic !== null}
                        />
                        <label label={micPercent} visible={mic !== null} />
                    </box>
                )
            }}
        </With>
    )
}
