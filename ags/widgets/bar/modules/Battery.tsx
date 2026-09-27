import { Gtk } from "ags/gtk4"
import AstalBattery from "gi://AstalBattery?version=0.1"
import { createBinding } from "gnim"
import { pctLabel } from "@/lib/helpers/numbers"
import { icons } from "@/lib/icons"

/**
 * Battery indicator; hidden when the device has no battery (the box always
 * exists — gnim FCs must return a widget — but `visible` tracks presence
 * reactively, so a battery appearing later shows the module).
 */
export function Battery() {
    const battery = AstalBattery.get_default()
    const percentage = createBinding(battery, "percentage")((p) => pctLabel(p))
    const iconName = createBinding(battery, "icon_name")
    const charging = createBinding(battery, "charging")
    const isPresent = createBinding(battery, "is_battery")

    return (
        <box class="card" spacing={4} visible={isPresent} valign={Gtk.Align.CENTER}>
            <image
                iconName={iconName((name) => name || icons.battery.full)}
            />
            <label label={percentage} />
            <image iconName={icons.battery.charging} visible={charging} />
        </box>
    )
}
