import { Gtk } from "ags/gtk4"
import Gdk from "gi://Gdk?version=4.0"
import Pango from "gi://Pango?version=1.0"
import { For, With, createComputed, createEffect } from "gnim"
import { options } from "@/options"
import { Button } from "@/components"
import { icons } from "@/lib/icons"
import { loadCoverTexture } from "@/lib/image"
import {
    currentWallpaper,
    isBusy,
    wallpaperEntries,
    type WallpaperEntry,
} from "@/services/wallpaper"
import { activeCursor, applySelected, focusEntry, moveCursor, slideDirection } from "./actions"

function selectIndex(index: number): void {
    focusEntry(index)
}

/** Cover thumbnail size: popup is 60%x70% of the monitor, rounded up. */
const THUMB_W = 1600
const THUMB_H = 1000

/**
 * Wallpaper carousel: one prominent full-bleed preview with a slide
 * animation, prev/next arrows, a filmstrip of dots, the file name, and an
 * Apply button. Left/Right step, Enter applies + closes, Esc cancels.
 * Preview pages render cached cover thumbnails (see `ThumbPage`), never
 * full-res decodes — a mounted 4K `Gtk.Picture` costs ~33MB each.
 */
export function WallpaperGrid() {
    const transition = slideDirection((d) =>
        d > 0 ? Gtk.StackTransitionType.SLIDE_LEFT : Gtk.StackTransitionType.SLIDE_RIGHT,
    )
    // Only the cursor page ±1 is mounted: Gtk.Picture keeps a full decoded
    // copy per page, so mounting all N 4K wallpapers costs N×~33MB.
    const visiblePages = createComputed(() => {
        const list = wallpaperEntries()
        const cur = Math.min(activeCursor(), Math.max(0, list.length - 1))
        const out: { entry: WallpaperEntry; index: number }[] = []
        for (let i = cur - 1; i <= cur + 1; i++) {
            if (i < 0 || i >= list.length) continue
            out.push({ entry: list[i]!, index: i })
        }
        return out
    })
    // The visible child is synced imperatively (see `syncStack`): passing
    // `visibleChildName` as a constructor prop fires before `For` children
    // mount, which warns ("Child name not found") and shows the wrong page.
    let stack: Gtk.Stack | null = null
    const syncStack = () => {
        if (stack === null) return
        const list = wallpaperEntries.peek()
        if (list.length === 0) return
        const name = String(Math.min(activeCursor.peek(), list.length - 1))
        if (stack.get_child_by_name(name) !== null) stack.set_visible_child_name(name)
    }
    createEffect(() => {
        activeCursor()
        wallpaperEntries()
        syncStack()
    })
    return (
        <box orientation={Gtk.Orientation.VERTICAL} spacing={8} class="card-body" vexpand>
            <With value={wallpaperEntries((list) => list.length === 0)}>
                {(isEmpty) =>
                    isEmpty ? (
                        <label
                            hexpand
                            halign={Gtk.Align.CENTER}
                            valign={Gtk.Align.CENTER}
                            vexpand
                            label={`No wallpapers in ${options.wallpaper.dir}`}
                            class="muted"
                        />
                    ) : (
                        <box orientation={Gtk.Orientation.VERTICAL} spacing={8} vexpand>
                            <box spacing={8} vexpand>
                                <Button
                                    icon={icons.ui.prev}
                                    onClicked={() => moveCursor(-1)}
                                    valign={Gtk.Align.CENTER}
                                    tooltipText="Previous"
                                    sensitive={isBusy((b) => !b)}
                                />
                                <stack
                                    hexpand
                                    vexpand
                                    transitionType={transition}
                                    transitionDuration={options.anim.duration}
                                    $={(self: Gtk.Stack) => {
                                        stack = self
                                        syncStack()
                                    }}
                                >
                                    <For each={visiblePages}>
                                        {({ entry, index }: { entry: WallpaperEntry; index: number }) => {
                                            const tex = loadCoverTexture(entry.path, THUMB_W, THUMB_H)
                                            if (tex === null) return <box $type="named" name={String(index)} />
                                            return (
                                                <picture
                                                    $type="named"
                                                    name={String(index)}
                                                    paintable={tex as Gdk.Texture}
                                                    contentFit={Gtk.ContentFit.COVER}
                                                    canShrink
                                                    halign={Gtk.Align.FILL}
                                                    valign={Gtk.Align.FILL}
                                                    hexpand
                                                    vexpand
                                                    alternativeText={entry.name}
                                                />
                                            )
                                        }}
                                    </For>
                                </stack>
                                <Button
                                    icon={icons.ui.next}
                                    onClicked={() => moveCursor(1)}
                                    valign={Gtk.Align.CENTER}
                                    tooltipText="Next"
                                    sensitive={isBusy((b) => !b)}
                                />
                            </box>
                            <box spacing={4} halign={Gtk.Align.CENTER}>
                                <For each={wallpaperEntries}>
                                    {(_entry: WallpaperEntry, index) => <Dot index={index()} />}
                                </For>
                            </box>
                            <box spacing={8} valign={Gtk.Align.END}>
                                <label
                                    label={activeCursor((i) => wallpaperEntries.peek()[i]?.name ?? "")}
                                    hexpand
                                    xalign={0}
                                    ellipsize={Pango.EllipsizeMode.END}
                                    class="muted"
                                />
                                <label
                                    label={activeCursor((i) => {
                                        const n = wallpaperEntries.peek().length
                                        return n === 0 ? "" : `${i + 1} / ${n}`
                                    })}
                                    class="muted"
                                />
                                <With value={isApplied}>
                                    {(applied) =>
                                        applied ? <label label="Applied" class="text-primary" /> : <box />
                                    }
                                </With>
                                <Button
                                    icon={icons.ui.check}
                                    label="Apply"
                                    variant="primary"
                                    onClicked={() => applySelected()}
                                    sensitive={isBusy((b) => !b)}
                                    tooltipText="Apply wallpaper"
                                />
                            </box>
                        </box>
                    )
                }
            </With>
        </box>
    )
}

const isApplied = createComputed(() => {
    const list = wallpaperEntries()
    return list[activeCursor()]?.name === currentWallpaper() && currentWallpaper() !== null
})

function Dot({ index }: { index: number }) {
    const active = createComputed(() => activeCursor() === index)
    return (
        <button
            class={active((a) => (a ? "wallpaper-dot wallpaper-dot-active" : "wallpaper-dot"))}
            widthRequest={10}
            heightRequest={10}
            onClicked={() => selectIndex(index)}
            tooltipText={wallpaperEntries.peek()[index]?.name ?? ""}
        >
            <box />
        </button>
    )
}

export { applySelected }
