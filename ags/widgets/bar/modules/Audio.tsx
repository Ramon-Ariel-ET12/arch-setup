import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango"
import type Astal from "gi://Astal?version=4.0"
import type AstalWp from "gi://AstalWp?version=0.1"
import { For, With, createBinding, createComputed, createState } from "gnim"
import { Popover, ScrollArea, Tabs, type TabDef } from "@/components"
import { EmptyState } from "@/lib/helpers/empty"
import { pctLabel } from "@/lib/helpers/numbers"
import { icons, micIcon, speakerIcon } from "@/lib/icons"
import { popoverSize } from "@/services/monitors"
import {
    defaultMic,
    defaultSpeaker,
    devices,
    microphones,
    recorders,
    speakers,
    streams,
} from "@/services/audio"

/**
 * Audio indicator with a pavucontrol-style mixer popover.
 *
 * The bar shows a speaker icon + percentage and a microphone icon +
 * percentage; clicking opens a GTK4 `Popover` below the button with five
 * tabs mirroring pavucontrol: Output / Input (every endpoint with volume,
 * mute, default toggle and port selector), Playback / Recording (every app
 * stream with volume, mute and output/input device routing), and Config
 * (card profile switching).
 *
 * All actions use the AstalWp objects directly: `set_is_default` for the
 * default device, `set_target_endpoint` for stream routing, `set_route`
 * (object form) for ports, `set_active_profile_id` for profiles.
 */

type AudioTab = "output" | "input" | "playback" | "recording" | "config"

const TABS: readonly TabDef<AudioTab>[] = [
    { id: "output", label: "Output" },
    { id: "input", label: "Input" },
    { id: "playback", label: "Playback" },
    { id: "recording", label: "Recording" },
    { id: "config", label: "Config" },
]

/** Lists in the popover never outgrow the monitor: taller content scrolls. */
const LIST_MAX_HEIGHT = 320

function describeEndpoint(ep: AstalWp.Endpoint): string {
    return ep.get_description() ?? "Unknown device"
}

function describeStream(stream: AstalWp.Stream): string {
    return stream.get_description() ?? stream.get_name() ?? "Unknown stream"
}

/** Volume slider with the external-change echo guard (see Media seekbar). */
function VolumeSlider({ node }: { node: AstalWp.Node }) {
    const volume = createBinding(node, "volume")
    return (
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
                node.volume = self.value
            }}
        />
    )
}

/** Mute toggle button with a live volume-ladder icon. */
function MuteButton({
    node,
    iconFor,
    muteLabel,
}: {
    node: AstalWp.Node
    iconFor: (volume: number, muted: boolean) => string
    muteLabel: string
}) {
    const volume = createBinding(node, "volume")
    const mute = createBinding(node, "mute")
    const icon = createComputed(() => iconFor(volume(), mute()))
    return (
        <button
            class="card"
            onClicked={() => node.set_mute(!node.mute)}
            tooltipText={mute((m) => (m ? `Unmute ${muteLabel}` : `Mute ${muteLabel}`))}
        >
            <image iconName={icon} iconSize={Gtk.IconSize.LARGE} />
        </button>
    )
}

/** "Set as default" star — only shown on non-default endpoints. */
function DefaultButton({ endpoint }: { endpoint: AstalWp.Endpoint }) {
    const isDefault = createBinding(endpoint, "is_default")
    return (
        <button
            class="card"
            visible={isDefault((d) => !d)}
            onClicked={() => endpoint.set_is_default(true)}
            tooltipText="Set as default"
        >
            <image iconName={icons.ui.check} />
        </button>
    )
}

/** Port (route) selector — rendered only when ≥2 ports are available. */
function PortSelect({ endpoint }: { endpoint: AstalWp.Endpoint }) {
    // Subscribed so the selector rebuilds when ports appear/disappear.
    const routesTick = createBinding(endpoint, "routes")
    const model = createComputed(() => {
        const routes = routesTick() ?? []
        if (routes.length < 2) return null
        const active = endpoint.get_route()
        let selected = routes.findIndex((r) => r.get_index() === endpoint.get_route_id())
        if (selected < 0 && active !== null) {
            selected = routes.findIndex((r) => r.get_description() === active.get_description())
        }
        return {
            names: routes.map((r) => r.get_description() || r.get_name()),
            selected: selected < 0 ? 0 : selected,
            routes,
        }
    })
    return (
        <With value={model}>
            {(m) =>
                m === null ? (
                    <box />
                ) : (
                    <box spacing={8}>
                        <label label="Port" class="subtitle" valign={Gtk.Align.CENTER} />
                        <dropdown
                            hexpand
                            model={Gtk.StringList.new(m.names)}
                            $={(self: Gtk.DropDown) => {
                                self.selected = m.selected
                                self.connect("notify::selected", () => {
                                    const route = m.routes[self.selected]
                                    if (route) endpoint.set_route(route)
                                })
                            }}
                        />
                    </box>
                )
            }
        </With>
    )
}

/** One endpoint row: header (mute/name/default/percent) + slider + ports. */
function EndpointRow({
    endpoint,
    iconFor,
    muteLabel,
}: {
    endpoint: AstalWp.Endpoint
    iconFor: (volume: number, muted: boolean) => string
    muteLabel: string
}) {
    const volume = createBinding(endpoint, "volume")
    const isDefault = createBinding(endpoint, "is_default")
    const percent = createComputed(() => pctLabel(volume()))

    return (
        <box class="p-2" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
            <box spacing={10}>
                <MuteButton node={endpoint} iconFor={iconFor} muteLabel={muteLabel} />
                <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                    <label
                        label={describeEndpoint(endpoint)}
                        halign={Gtk.Align.START}
                        ellipsize={Pango.EllipsizeMode.END}
                    />
                    <label
                        label="Default"
                        class="subtitle"
                        halign={Gtk.Align.START}
                        visible={isDefault}
                    />
                </box>
                <DefaultButton endpoint={endpoint} />
                <label label={percent} class="bold" valign={Gtk.Align.CENTER} />
            </box>
            <VolumeSlider node={endpoint} />
            <PortSelect endpoint={endpoint} />
        </box>
    )
}

/**
 * Per-stream device routing dropdown — rendered only when ≥2 targets exist.
 * Pre-selects the stream's explicit target, falling back to the default
 * endpoint (where the server routes streams with no explicit target).
 */
function TargetSelect({
    stream,
    targets,
}: {
    stream: AstalWp.Stream
    targets: typeof speakers
}) {
    // Subscribed so routing follows hotplug/default changes.
    const targetTick = createBinding(stream, "target_endpoint")
    const model = createComputed(() => {
        const endpoints = targets()
        if (endpoints.length < 2) return null
        void targetTick()
        const serial = stream.get_target_serial()
        let selected = endpoints.findIndex((e) => e.get_serial() === serial)
        if (selected < 0) selected = endpoints.findIndex((e) => e.get_is_default())
        return {
            names: endpoints.map(describeEndpoint),
            selected: selected < 0 ? 0 : selected,
            endpoints,
        }
    })
    return (
        <With value={model}>
            {(m) =>
                m === null ? (
                    <box />
                ) : (
                    <box spacing={8}>
                        <label label="Device" class="subtitle" valign={Gtk.Align.CENTER} />
                        <dropdown
                            hexpand
                            model={Gtk.StringList.new(m.names)}
                            $={(self: Gtk.DropDown) => {
                                self.selected = m.selected
                                self.connect("notify::selected", () => {
                                    const target = m.endpoints[self.selected]
                                    if (target) stream.set_target_endpoint(target)
                                })
                            }}
                        />
                    </box>
                )
            }
        </With>
    )
}

/** One app-stream row: header (mute/name/percent) + slider + routing. */
function StreamRow({
    stream,
    targets,
    iconFor,
    muteLabel,
}: {
    stream: AstalWp.Stream
    targets: typeof speakers
    iconFor: (volume: number, muted: boolean) => string
    muteLabel: string
}) {
    const volume = createBinding(stream, "volume")
    const percent = createComputed(() => pctLabel(volume()))

    return (
        <box class="p-2" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
            <box spacing={10}>
                <MuteButton node={stream} iconFor={iconFor} muteLabel={muteLabel} />
                <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                    <label
                        label={describeStream(stream)}
                        halign={Gtk.Align.START}
                        ellipsize={Pango.EllipsizeMode.END}
                    />
                </box>
                <label label={percent} class="bold" valign={Gtk.Align.CENTER} />
            </box>
            <VolumeSlider node={stream} />
            <TargetSelect stream={stream} targets={targets} />
        </box>
    )
}

/** Card profile selector — dropdown for ≥2 profiles, static label for one. */
function ProfileSelect({ device }: { device: AstalWp.Device }) {
    // Both subscribed: profiles come and go with the card, the active id
    // changes when the user (or another mixer) switches profile.
    const profilesTick = createBinding(device, "profiles")
    const activeId = createBinding(device, "active_profile_id")
    const model = createComputed(() => {
        const profiles = profilesTick() ?? []
        if (profiles.length === 0) return null
        const active = activeId()
        let selected = profiles.findIndex((p) => p.get_index() === active)
        if (selected < 0) selected = 0
        return {
            names: profiles.map((p) => p.get_description() || p.get_name()),
            selected,
            profiles,
        }
    })
    return (
        <With value={model}>
            {(m) => {
                if (m === null) return <box />
                if (m.profiles.length === 1) {
                    return (
                        <label
                            label={m.names[0] ?? ""}
                            class="subtitle"
                            halign={Gtk.Align.START}
                        />
                    )
                }
                return (
                    <box spacing={8}>
                        <label label="Profile" class="subtitle" valign={Gtk.Align.CENTER} />
                        <dropdown
                            hexpand
                            model={Gtk.StringList.new(m.names)}
                            $={(self: Gtk.DropDown) => {
                                self.selected = m.selected
                                self.connect("notify::selected", () => {
                                    const profile = m.profiles[self.selected]
                                    if (profile) device.set_active_profile_id(profile.get_index())
                                })
                            }}
                        />
                    </box>
                )
            }}
        </With>
    )
}

/** One card row: icon/name + profile selector. */
function DeviceRow({ device }: { device: AstalWp.Device }) {
    const icon = createBinding(device, "icon")
    const description = createBinding(device, "description")
    const formFactor = device.get_form_factor()

    return (
        <box class="p-2" orientation={Gtk.Orientation.VERTICAL} spacing={8}>
            <box spacing={10}>
                <image
                    iconName={icon((i) => i || icons.ui.settings)}
                    iconSize={Gtk.IconSize.LARGE}
                />
                <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                    <label
                        label={description((d) => d ?? "Unknown device")}
                        halign={Gtk.Align.START}
                        ellipsize={Pango.EllipsizeMode.END}
                    />
                    {formFactor !== null && (
                        <label label={formFactor} class="subtitle" halign={Gtk.Align.START} />
                    )}
                </box>
            </box>
            <ProfileSelect device={device} />
        </box>
    )
}

export function Audio() {
    const { width } = popoverSize(25, 0, { width: 440, height: 0 })
    const [tab, setTab] = createState<AudioTab>("output")

    const speakerCount = createComputed(() => speakers().length)
    const micCount = createComputed(() => microphones().length)
    const streamCount = createComputed(() => streams().length)
    const recorderCount = createComputed(() => recorders().length)
    const deviceCount = createComputed(() => devices().length)

    return (
        <Popover
            trigger={<AudioTrigger />}
            content={
                <box class="min-w-popup" widthRequest={width} orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                    <Tabs tabs={TABS} active={tab} onChange={setTab} />
                    {/* No With here: each tab owns its With/For and gnim does
                        not support nested fragments. Visibility toggling keeps
                        all tabs mounted (preserves slider/dropdown state). */}
                    <box visible={tab((t) => t === "output")}>
                        <ScrollArea class="card-body" vexpand spacing={2} maxHeight={LIST_MAX_HEIGHT}>
                            <With value={speakerCount}>
                                {(c) =>
                                    c === 0 ? (
                                        <EmptyState icon={icons.audio.muted} label="No output devices" />
                                    ) : (
                                        <box />
                                    )
                                }
                            </With>
                            <For each={speakers}>
                                {(ep: AstalWp.Endpoint) => (
                                    <EndpointRow endpoint={ep} iconFor={speakerIcon} muteLabel="output" />
                                )}
                            </For>
                        </ScrollArea>
                    </box>
                    <box visible={tab((t) => t === "input")}>
                        <ScrollArea class="card-body" vexpand spacing={2} maxHeight={LIST_MAX_HEIGHT}>
                            <With value={micCount}>
                                {(c) =>
                                    c === 0 ? (
                                        <EmptyState icon={icons.audio.micMuted} label="No input devices" />
                                    ) : (
                                        <box />
                                    )
                                }
                            </With>
                            <For each={microphones}>
                                {(ep: AstalWp.Endpoint) => (
                                    <EndpointRow endpoint={ep} iconFor={micIcon} muteLabel="input" />
                                )}
                            </For>
                        </ScrollArea>
                    </box>
                    <box visible={tab((t) => t === "playback")}>
                        <ScrollArea class="card-body" vexpand spacing={2} maxHeight={LIST_MAX_HEIGHT}>
                            <With value={streamCount}>
                                {(c) =>
                                    c === 0 ? (
                                        <EmptyState icon={icons.audio.muted} label="No applications playing audio" />
                                    ) : (
                                        <box />
                                    )
                                }
                            </With>
                            <For each={streams}>
                                {(stream: AstalWp.Stream) => (
                                    <StreamRow stream={stream} targets={speakers} iconFor={speakerIcon} muteLabel="stream" />
                                )}
                            </For>
                        </ScrollArea>
                    </box>
                    <box visible={tab((t) => t === "recording")}>
                        <ScrollArea class="card-body" vexpand spacing={2} maxHeight={LIST_MAX_HEIGHT}>
                            <With value={recorderCount}>
                                {(c) =>
                                    c === 0 ? (
                                        <EmptyState icon={icons.audio.micMuted} label="No applications recording" />
                                    ) : (
                                        <box />
                                    )
                                }
                            </With>
                            <For each={recorders}>
                                {(stream: AstalWp.Stream) => (
                                    <StreamRow stream={stream} targets={microphones} iconFor={micIcon} muteLabel="recording" />
                                )}
                            </For>
                        </ScrollArea>
                    </box>
                    <box visible={tab((t) => t === "config")}>
                        <ScrollArea class="card-body" vexpand spacing={2} maxHeight={LIST_MAX_HEIGHT}>
                            <With value={deviceCount}>
                                {(c) =>
                                    c === 0 ? (
                                        <EmptyState icon={icons.ui.settings} label="No audio devices" />
                                    ) : (
                                        <box />
                                    )
                                }
                            </With>
                            <For each={devices}>
                                {(device: AstalWp.Device) => <DeviceRow device={device} />}
                            </For>
                        </ScrollArea>
                    </box>
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
