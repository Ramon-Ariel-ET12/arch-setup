import { Gtk } from "ags/gtk4"
import AstalTray from "gi://AstalTray?version=0.1"
import { createBinding, createConnection, For } from "gnim"

/**
 * System tray. Rendered only on the main monitor (see `layout.tsx`).
 */

function TrayItemWidget({ item }: { item: AstalTray.TrayItem }) {
    const gicon = createConnection(
        item.get_gicon(),
        [item, "notify::gicon", () => item.get_gicon()],
        [item, "changed", () => item.get_gicon()],
    )
    const tooltip = createBinding(item, "tooltipText")

    return (
        <button
            tooltipText={tooltip}
            onClicked={() => item.activate(0, 0)}
            $={(self: Gtk.Button) => {
                const actionGroup = item.get_action_group()
                if (actionGroup) self.insert_action_group("dbusmenu", actionGroup)

                // One popover per button, reused across right-clicks — a fresh
                // PopoverMenu per press would accumulate on the button.
                let popover: Gtk.PopoverMenu | null = null

                const gesture = new Gtk.GestureClick()
                gesture.set_button(3)
                gesture.connect("pressed", () => {
                    item.about_to_show()
                    const menuModel = item.get_menu_model()
                    if (!menuModel) return
                    if (popover === null) {
                        popover = new Gtk.PopoverMenu()
                        popover.set_parent(self)
                        self.connect("destroy", () => {
                            popover?.unparent()
                            popover = null
                        })
                    }
                    popover.set_menu_model(menuModel)
                    popover.popup()
                })
                self.add_controller(gesture)
            }}
        >
            {/* pixelSize pins tray icons: unfixed SNI pixmaps render at their
                natural size and would stretch the bar. */}
            <image gicon={gicon} pixelSize={16} />
        </button>
    )
}

export function Tray() {
    // Const (not inlined into `For`): TS cannot infer the element type of a
    // generic call expression inside JSX props.
    const items = createBinding(AstalTray.get_default(), "items")
    // Empty tray unmounts entirely: an empty `.card` box would still paint a
    // visible chip on the bar. GTK `visible=false` skips allocation, so the
    // module collapses instead of leaving a gap.
    const hasItems = items((list) => list.length > 0)

    return (
        <box class="card" spacing={2} visible={hasItems}>
            <For each={items}>{(item) => <TrayItemWidget item={item} />}</For>
        </box>
    )
}
