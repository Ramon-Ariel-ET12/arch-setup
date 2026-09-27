import { Gtk } from "ags/gtk4"
import Astal from "gi://Astal?version=4.0"
import Mpris from "gi://AstalMpris?version=0.1"
import Pango from "gi://Pango?version=1.0"
import { With, createBinding, createComputed } from "gnim"
import { Popover, Button } from "@/components"
import { icons } from "@/lib/icons"

function fmtDuration(seconds: number): string {
    if (!Number.isFinite(seconds) || seconds <= 0) return "0:00"
    const h = Math.floor(seconds / 3600)
    const m = Math.floor((seconds % 3600) / 60)
    const s = Math.floor(seconds % 60)
    if (h > 0) return `${h}:${String(m).padStart(2, "0")}:${String(s).padStart(2, "0")}`
    return `${m}:${String(s).padStart(2, "0")}`
}

const MAX_TRACK_LENGTH = 7 * 24 * 3600

function isLiveLength(length: number): boolean {
    return !(length > 0) || !Number.isFinite(length) || length > MAX_TRACK_LENGTH
}

function MediaSummary({ player }: { player: Mpris.Player }) {
    const title = createBinding(player, "title")
    const position = createBinding(player, "position")
    const length = createBinding(player, "length")

    const label = createComputed(() => {
        const t = (title() || "").trim()
        return t !== "" ? t : "Unknown"
    })

    const live = createComputed(() => isLiveLength(length()))

    const duration = createComputed(() => {
        if (live()) return ""
        const pos = position()
        const len = length()
        if (len > 0) return `${fmtDuration(pos)} / ${fmtDuration(len)}`
        if (pos > 0) return fmtDuration(pos)
        return ""
    })

    return (
        <box class="min-w-0" spacing={6}>
            <label
                label={label}
                maxWidthChars={20}
                ellipsize={Pango.EllipsizeMode.END}
                xalign={0}
            />
            <label label="LIVE" class="subtitle" visible={live} />
            <label label={duration} class="subtitle" visible={duration((d) => d !== "")} />
        </box>
    )
}

function MediaControls({ player }: { player: Mpris.Player }) {
    const status = createBinding(player, "playback_status")
    const canPlay = createBinding(player, "can_play")
    const canPause = createBinding(player, "can_pause")
    const canNext = createBinding(player, "can_go_next")
    const canPrev = createBinding(player, "can_go_previous")

    const playing = createComputed(() => status() === Mpris.PlaybackStatus.PLAYING)

    return (
        <box spacing={4} halign={Gtk.Align.CENTER}>
            <Button icon={icons.media.prev} onClicked={() => player.previous()} sensitive={canPrev} tooltipText="Previous" />
            <Button
                icon={playing((p) => (p ? icons.media.pause : icons.media.play))}
                onClicked={() => (playing() ? player.pause() : player.play())}
                sensitive={createComputed(() => (playing() ? canPause() : canPlay()))}
                tooltipText={playing((p) => (p ? "Pause" : "Play"))}
            />
            <Button icon={icons.media.next} onClicked={() => player.next()} sensitive={canNext} tooltipText="Next" />
        </box>
    )
}

function MediaSeekbar({ player }: { player: Mpris.Player }) {
    const position = createBinding(player, "position")
    const length = createBinding(player, "length")
    const canSeek = createBinding(player, "can_seek")

    const live = createComputed(() => isLiveLength(length()))
    const seekable = createComputed(() => !live() && canSeek() && length() > 0)

    return (
        <box spacing={6}>
            <label label={position((p) => fmtDuration(p))} class="subtitle" />
            <slider
                hexpand
                visible={seekable}
                sensitive={seekable}
                value={createComputed(() => {
                    const len = length()
                    return len > 0 ? position() / len : 0
                })}
                min={0}
                max={1}
                onNotifyValue={(self: Astal.Slider) => {
                    if (!seekable.peek()) return
                    const len = length.peek()
                    const expected = position.peek() / len
                    if (Math.abs(self.value - expected) < 0.001) return
                    player.position = self.value * len
                }}
            />
            <label
                label={length((l) => fmtDuration(l))}
                class="subtitle"
                visible={seekable}
            />
            <label label="LIVE" class="subtitle" visible={live} />
        </box>
    )
}

function MediaPopoverContent({ player }: { player: Mpris.Player }) {
    const title = createBinding(player, "title")
    const artist = createBinding(player, "artist")
    const album = createBinding(player, "album")
    const artUrl = createBinding(player, "art_url")
    const coverArt = createBinding(player, "cover_art")
    const entry = createBinding(player, "entry")
    const identity = createBinding(player, "identity")

    const art = createComputed(() => coverArt() || artUrl() || "")
    const source = createComputed(() => identity() || entry() || "")

    return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={10}>
            <box spacing={10}>
                <box class="radius-sm" widthRequest={64} heightRequest={64} valign={Gtk.Align.START} visible={art((a) => a !== "")}>
                    <image
                        pixelSize={64}
                        $={(self: Gtk.Image) => {
                            let last = ""
                            const update = () => {
                                const p = art.peek()
                                if (!p || p === last) return
                                last = p
                                try {
                                    self.set_from_file(p)
                                } catch {
                                }
                            }
                            update()
                            const unsub = art.subscribe(update)
                            self.connect("destroy", unsub)
                        }}
                    />
                </box>
                <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={2}>
                    <label
                        label={title((t) => t || "Unknown")}
                        class="bold text-body"
                        xalign={0}
                        wrap
                        maxWidthChars={28}
                        ellipsize={Pango.EllipsizeMode.END}
                    />
                    <label
                        label={artist}
                        class="subtitle"
                        xalign={0}
                        ellipsize={Pango.EllipsizeMode.END}
                        visible={artist((a) => a !== "")}
                    />
                    <label
                        label={album}
                        class="subtitle"
                        xalign={0}
                        ellipsize={Pango.EllipsizeMode.END}
                        visible={album((a) => a !== "")}
                    />
                    <label
                        label={source}
                        class="subtitle"
                        xalign={0}
                        ellipsize={Pango.EllipsizeMode.END}
                        visible={source((s) => s !== "")}
                    />
                </box>
            </box>
            <MediaSeekbar player={player} />
            <box class="mt-1" spacing={6} halign={Gtk.Align.CENTER}>
                <MediaControls player={player} />
            </box>
            <box spacing={6}>
                <label label="Volume" class="subtitle" />
                <slider
                    hexpand
                    value={createBinding(player, "volume")}
                    min={0}
                    max={1}
                    onNotifyValue={(self: Astal.Slider) => (player.volume = self.value)}
                />
            </box>
        </box>
    )
}

export function Media() {
    const player = createBinding(Mpris.get_default(), "players")((list) => list[0] ?? null)

    return (
        <With value={player}>
            {(p) => {
                if (p === null) return <box visible={false} />

                const status = createBinding(p, "playback_status")
                const active = createComputed(
                    () => status() !== Mpris.PlaybackStatus.STOPPED,
                )

                return (
                    <box class="card" spacing={2} visible={active}>
                        <Popover
                            trigger={
                                <box spacing={4}>
                                    <MediaSummary player={p} />
                                </box>
                            }
                            content={<MediaPopoverContent player={p} />}
                        />
                        <button
                            class="card"
                            tooltipText={status((s) =>
                                s === Mpris.PlaybackStatus.PLAYING ? "Pause" : "Play",
                            )}
                            onClicked={() =>
                                p.playback_status === Mpris.PlaybackStatus.PLAYING
                                    ? p.pause()
                                    : p.play()
                            }
                        >
                            <image
                                iconName={status((s) =>
                                    s === Mpris.PlaybackStatus.PLAYING
                                        ? icons.media.pause
                                        : icons.media.play,
                                )}
                            />
                        </button>
                    </box>
                )
            }}
        </With>
    )
}
