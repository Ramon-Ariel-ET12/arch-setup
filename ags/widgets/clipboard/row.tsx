import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango?version=1.0"
import Gdk from "gi://Gdk?version=4.0"
import { createComputed, createState, type Accessor } from "gnim"
import { activeClass } from "@/lib/ui"
import { options } from "@/options"
import { icons } from "@/lib/icons"
import { formatRelativeTime, formatTimestamp } from "@/lib/time"
import { decodeImage, type ClipboardEntry } from "@/services/clipboard"
import { activateItem, activeCursor, type ClipboardItem } from "./actions"

const THUMB_SIZE = 32

export function GridCell(item: ClipboardItem, index: Accessor<number>): JSX.Element {
    if (item.kind !== "char") return <flowboxchild />
    const active = createComputed(() => activeCursor() === index())
    return (
        <flowboxchild>
            <button
                // Zero-padding glyph cell (no `.row`: its padding would beat
                // p-0/m-0 — shared row styles live later in the cascade).
                class={activeClass(active, "p-0 m-0")}
                widthRequest={options.clipboard.cell}
                heightRequest={options.clipboard.cell}
                onClicked={() => void activateItem(item)}
                tooltipText={item.name}
            >
                <label label={item.char} class="text-glyph" />
            </button>
        </flowboxchild>
    )
}

export function ClipboardListRow(item: ClipboardItem, index: Accessor<number>): JSX.Element {
    if (item.kind !== "clip") return <box />
    const entry = item.entry
    const active = createComputed(() => activeCursor() === index())
    const rel = createComputed(() => formatRelativeTime(entry.timestamp))
    const iso = formatTimestamp(entry.timestamp)
    const tooltip = entry.type === "image"
        ? `${entry.mime} · ${iso}`
        : `${entry.preview}${iso !== "" ? ` — ${iso}` : ""}`
    return (
        <button
            class={activeClass(active, "row")}
            onClicked={() => void activateItem(item)}
            tooltipText={tooltip}
        >
            {entry.type === "image"
                ? <ImageThumb entry={entry} />
                : <image iconName={icons.ui.clipboard} pixelSize={THUMB_SIZE} class="mr-2" />}
            <box orientation={Gtk.Orientation.VERTICAL} hexpand spacing={2}>
                <label
                    label={entry.preview}
                    hexpand
                    xalign={0}
                    ellipsize={Pango.EllipsizeMode.END}
                    class="text-body"
                />
                <label label={rel} class="text-micro opacity-mid" halign={Gtk.Align.START} />
            </box>
        </button>
    )
}

function ImageThumb({ entry }: { entry: ClipboardEntry }): JSX.Element {
    const [tex, setTex] = createState<Gdk.Texture | null>(entry.texture ?? null)
    if (tex() === null) {
        void decodeImage(entry).then((t) => {
            if (t !== null) setTex(t)
        })
        return <image iconName={icons.ui.clipboard} pixelSize={THUMB_SIZE} />
    }
    return <image paintable={tex() as Gdk.Texture} pixelSize={THUMB_SIZE} />
}
