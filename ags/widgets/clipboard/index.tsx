import { Astal, Gtk } from "ags/gtk4"
import app from "ags/gtk4/app"
import type { Accessor } from "gnim"
import { For, createComputed, createEffect } from "gnim"
import { Card, ScrollArea, SearchEntry, Tabs } from "@/components"
import type { TabDef } from "@/components"
import { attachKeymap } from "@/lib/keyboard"
import { clamp, scrollRangeIntoView } from "@/lib/ui"
import { logWarn } from "@/lib/notify"
import { options } from "@/options"
import { focusedGdk } from "@/services/monitors"
import { getCursorPosition, hypr } from "@/services/hyprland"
import {
    activateSelected,
    activeCursor,
    activeTab,
    EMOJI_SUB_TABS,
    emojiCategory,
    ensureVisible,
    flushRecents,
    gridColumns,
    growSlice,
    isGridTab,
    loadHistory,
    moveSelection,
    navigableEntries,
    resetClipboard,
    searchText,
    setQuery,
    showRecentsHint,
    switchCategory,
    switchRelative,
    switchTab,
    SYMBOL_SUB_TABS,
    symbolCategory,
    type ClipboardItem,
    type TabId,
} from "./actions"
import { ClipboardListRow, GridCell } from "./row"

/**
 * Universal clipboard picker (Windows 11–style): clipboard · emoji · symbols.
 *
 * A fullscreen transparent layer-shell window owns input while the visible
 * card floats at the cursor. Fully keyboard-driven:
 * - Clipboard: a vertical list; Up/Down navigate, Enter copies.
 * - Emoji / Symbols: a second tab row (Recents + dataset categories, each
 *   with its own MRU) over a 50px wrap-grid of glyphs; arrows navigate the
 *   grid, Tab switches sections, hover shows the name, Enter inserts the
 *   glyph into the previously focused window via `wtype` (always copied to
 *   the clipboard too, as fallback).
 * Escape or a click outside closes; Tab (or clicking a tab) switches sections.
 *
 * Toggle: `ags toggle clipboard`
 */

const PICKER_WIDTH = options.clipboard.width
const PICKER_HEIGHT = options.clipboard.height
const PICKER_MARGIN = options.clipboard.margin

export const GRID_ROW_SPACING = 4

// The grid's FlowBox and the list's Box (set via `$` below); used to scroll
// the cursor into view and to anchor the scroll on open. NOTE: per-row hooks
// are not usable for this — gnim's `For` re-appends every row on each slice
// growth, which remaps them — so scroll logic lives on these static widgets.
let gridBox: Gtk.FlowBox | null = null
let listBox: Gtk.Box | null = null

/** Scrolls the shared ScrolledWindow so the cursor's cell (grid) is visible. */
function scrollCursorIntoView(): void {
    if (gridBox === null) return
    const row = Math.floor(activeCursor.peek() / gridColumns)
    const top = row * (options.clipboard.cell + GRID_ROW_SPACING)
    scrollRangeIntoView(gridBox, top, top + options.clipboard.cell)
}

/** Scrolls so the cursor's row (clipboard list) is visible. */
function scrollListCursorIntoView(): void {
    if (listBox === null) return
    // Rows are uniform-height; the first allocated row anchors the pitch.
    const first = listBox.get_first_child()
    if (first === null) return
    const alloc = first.get_allocation()
    if (alloc.height === 0) return // list not laid out yet
    const pitch = alloc.height + listBox.get_spacing()
    const top = alloc.y + activeCursor.peek() * pitch
    scrollRangeIntoView(listBox, top, top + pitch)
}

/**
 * Infinite scroll for the windowed lists: while the viewport sits within one
 * page of the bottom, append the next batch of items. Listens to both
 * adjustment signals — `value-changed` (user scroll) and `changed` (bounds,
 * which also self-fills an under-filled viewport after open/growth).
 */
function watchGridScroll(self: Gtk.FlowBox): void {
    const scroll = self.get_ancestor(Gtk.ScrolledWindow.$gtype) as Gtk.ScrolledWindow | null
    if (scroll === null) return
    const adj = scroll.get_vadjustment()
    if ((adj as Gtk.Adjustment & { __agsWatched?: boolean }).__agsWatched === true) return
    ;(adj as Gtk.Adjustment & { __agsWatched?: boolean }).__agsWatched = true
    const grow = (a: Gtk.Adjustment) => {
        if (a.get_value() + a.get_page_size() >= a.get_upper() - a.get_page_size()) {
            growSlice()
        }
    }
    adj.connect("value-changed", grow)
    adj.connect("changed", grow)
}

const TAB_DEFS: readonly TabDef<TabId>[] = [
    { id: "clipboard", label: "Clipboard" },
    { id: "emoji", label: "Emoji" },
    { id: "symbols", label: "Symbols" },
]

export default function ClipboardPopup() {
    // All four anchors → the layer-shell surface fills its monitor.
    return (
        <window
            name="clipboard"
            namespace="clipboard"
            application={app}
            visible={false}
            anchor={
                Astal.WindowAnchor.TOP |
                Astal.WindowAnchor.BOTTOM |
                Astal.WindowAnchor.LEFT |
                Astal.WindowAnchor.RIGHT
            }
            layer={Astal.Layer.TOP}
            exclusivity={Astal.Exclusivity.NORMAL}
            keymode={Astal.Keymode.ON_DEMAND}
            $={(self: Astal.Window) => setupPicker(self)}
        >
            <fixed hexpand vexpand>
                <Card
                    widthRequest={PICKER_WIDTH}
                    heightRequest={PICKER_HEIGHT}
                    class="p-3"
                >
                    <SearchEntry text={searchText} onChangeText={setQuery} />
                    <Tabs tabs={TAB_DEFS} active={activeTab} onChange={switchTab} />
                    <SubTabsRow
                        visible={activeTab((t) => t === "emoji")}
                        tabs={EMOJI_SUB_TABS}
                        active={emojiCategory}
                    />
                    <SubTabsRow
                        visible={activeTab((t) => t === "symbols")}
                        tabs={SYMBOL_SUB_TABS}
                        active={symbolCategory}
                    />
                    <ClipboardBody />
                </Card>
            </fixed>
        </window>
    )
}

/** Cursor-anchored, focused-monitor-clamped position for the clipboard card. */
async function positionAtCursor(): Promise<{ x: number; y: number }> {
    const mon = hypr.get_focused_monitor()
    const pos = await getCursorPosition()
    if (!mon || !pos) return { x: PICKER_MARGIN, y: PICKER_MARGIN }
    const lx = pos.x - mon.x
    const ly = pos.y - mon.y
    const x = clamp(lx + PICKER_MARGIN, PICKER_MARGIN, mon.width - PICKER_WIDTH - PICKER_MARGIN)
    const y = clamp(ly + PICKER_MARGIN, PICKER_MARGIN, mon.height - PICKER_HEIGHT - PICKER_MARGIN)
    return { x, y }
}

/** Open/close behavior: retarget monitor, (re)place the card, keymap, click-outside. */
function setupPicker(win: Astal.Window): void {
    win.connect("notify::visible", async () => {
        if (!win.visible) {
            // Picker closed: apply any pending recents reorder so the next
            // open shows the updated MRU (the open grid stays stable).
            flushRecents()
            return
        }

        const gdk = focusedGdk()
        if (gdk) win.gdkmonitor = gdk
        resetClipboard()
        // Cursor resets to 0; anchor the shared scroll at the top too.
        const scroll = gridBox?.get_ancestor(Gtk.ScrolledWindow.$gtype) as Gtk.ScrolledWindow | null
        scroll?.get_vadjustment().set_value(0)
        void loadHistory()

        const fixed = win.child as Gtk.Fixed | null
        const card = fixed?.get_first_child() as Gtk.Widget | null
        if (!fixed || !card) return

        // Place the card at the cursor-anchored, clamped position.
        try {
            const { x, y } = await positionAtCursor()
            fixed.move(card, x, y)
        } catch {
            logWarn("clipboard: failed to position card")
        }
    })

    // Click outside the card dismisses (on-demand behavior).
    const click = new Gtk.GestureClick()
    click.connect("pressed", (_g, _n, px: number, py: number) => {
        if (!win.visible) return
        const fixed = win.child as Gtk.Fixed | null
        const card = fixed?.get_first_child() as Gtk.Widget | null
        if (!fixed || !card) return
        const alloc = card.get_allocation()
        const inside =
            px >= alloc.x &&
            px <= alloc.x + alloc.width &&
            py >= alloc.y &&
            py <= alloc.y + alloc.height
        if (!inside) win.visible = false
    })
    win.add_controller(click)

    attachKeymap(win, {
        onEscape: options.popups.escToClose ? () => (win.visible = false) : undefined,
        onMove: (dy) => {
            const handled = moveSelection(0, dy)
            ensureVisible(activeCursor.peek())
            if (isGridTab(activeTab.peek())) scrollCursorIntoView()
            else scrollListCursorIntoView()
            return handled
        },
        onMoveH: (dx) => {
            if (moveSelection(dx, 0)) {
                ensureVisible(activeCursor.peek())
                scrollCursorIntoView()
                return true
            }
            // Clipboard (linear list) has no horizontal move: Left/Right
            // falls back to switching sections there.
            return switchRelative(dx < 0)
        },
        onSwitch: (left) => switchRelative(left),
        onConfirm: () => {
            void activateSelected()
            return true
        },
    })
}

/**
 * Second-level tab row (Recents + categories): a horizontally scrollable row
 * panned by the wheel (or a horizontal trackpad swipe), with no scrollbar —
 * the row is a thin tab strip, not a content viewport, so it claims no gutter.
 * Only one row is ever visible (per grid tab).
 */
function SubTabsRow({
    visible,
    tabs,
    active,
}: {
    visible: Accessor<boolean>
    tabs: readonly TabDef<string>[]
    active: Accessor<string>
}) {
    return (
        <box visible={visible} orientation={Gtk.Orientation.HORIZONTAL} spacing={2}>
            <scrolledwindow
                hexpand
                class="subtabs"
                // EXTERNAL, not NEVER: NEVER also disables horizontal scrolling, so the row
                // demands every category's width and the card grows to fit. The
                // card's own widthRequest owns the layout.
                hscrollbarPolicy={Gtk.PolicyType.EXTERNAL}
                vscrollbarPolicy={Gtk.PolicyType.NEVER}
                propagateNaturalHeight
                propagateNaturalWidth={false}
                $={(self: Gtk.ScrolledWindow) => hookSubTabWheel(self)}
            >
                <Tabs tabs={tabs} active={active} onChange={switchCategory} homogeneous={false} />
            </scrolledwindow>
        </box>
    )
}

/** Pixels the sub-tab row pans per mouse-wheel tick. */
const SUBTAB_WHEEL_STEP = 64

/** Pans a horizontal-only row with the vertical wheel (see `SubTabsRow`). */
function hookSubTabWheel(scroll: Gtk.ScrolledWindow): void {
    const ctrl = Gtk.EventControllerScroll.new(Gtk.EventControllerScrollFlags.BOTH_AXES)
    ctrl.connect("scroll", (_c, dx: number, dy: number) => {
        if (dx !== 0 || dy === 0) return false // native horizontal / nothing
        const adj = scroll.get_hadjustment()
        if (adj.get_upper() <= adj.get_page_size()) return false // fits: nothing to pan
        adj.set_value(
            clamp(
                adj.get_value() + Math.sign(dy) * SUBTAB_WHEEL_STEP,
                0,
                adj.get_upper() - adj.get_page_size(),
            ),
        )
        return true
    })
    scroll.add_controller(ctrl)
}

function ClipboardBody() {
    // Windowed clipboard entries only — don't build hidden rows while on a
    // grid tab; the slice grows on demand (infinite scroll).
    const clipboard = createComputed<ClipboardItem[]>(() =>
        activeTab() === "clipboard" ? navigableEntries() : [],
    )
    // Grid items only — don't build hidden cells while on the clipboard tab.
    const grid = createComputed<ClipboardItem[]>(() =>
        isGridTab(activeTab()) ? navigableEntries() : [],
    )
    // Query/tab changes rebuild the content from the top; anchor the scroll
    // there too (cursor movement and slice growth never touch these deps).
    createEffect(() => {
        searchText()
        activeTab()
        const scroll = gridBox?.get_ancestor(Gtk.ScrolledWindow.$gtype) as Gtk.ScrolledWindow | null
        scroll?.get_vadjustment().set_value(0)
    })
    return (
        <ScrollArea class="card-body">
            <box visible={showRecentsHint} halign={Gtk.Align.CENTER} class="py-2">
                <label
                    label="Recently inserted glyphs will appear here"
                    class="text-micro opacity-mid"
                />
            </box>
            <box
                orientation={Gtk.Orientation.VERTICAL}
                spacing={2}
                class="list"
                visible={activeTab((t) => t === "clipboard")}
                $={(self: Gtk.Box) => (listBox = self)}
            >
                <For each={clipboard}>
                    {(item: ClipboardItem, index: Accessor<number>) => ClipboardListRow(item, index)}
                </For>
            </box>
            <flowbox
                class="py-1"
                visible={activeTab((t) => isGridTab(t))}
                maxChildrenPerLine={gridColumns}
                minChildrenPerLine={gridColumns}
                rowSpacing={GRID_ROW_SPACING}
                columnSpacing={4}
                homogeneous
                vexpand
                halign={Gtk.Align.FILL}
                valign={Gtk.Align.START}
                $={(self: Gtk.FlowBox) => {
                    gridBox = self
                    if ((self as Gtk.FlowBox & { __agsWatched?: boolean }).__agsWatched !== true) {
                        ;(self as Gtk.FlowBox & { __agsWatched?: boolean }).__agsWatched = true
                        self.connect("realize", () => watchGridScroll(self))
                    }
                }}
            >
                <For each={grid}>
                    {(item: ClipboardItem, index: Accessor<number>) => GridCell(item, index)}
                </For>
            </flowbox>
        </ScrollArea>
    )
}

