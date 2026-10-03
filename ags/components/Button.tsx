import { Gtk } from "ags/gtk4"
import type { Accessor } from "gnim"
import { debugLog } from "@/lib/log"

interface ButtonProps {
    label?: string | Accessor<string>
    icon?: string | Accessor<string>
    variant?: "flat" | "primary" | "danger"
    onClicked: () => void
    tooltipText?: string | Accessor<string>
    hexpand?: boolean | Accessor<boolean>
    valign?: Gtk.Align | Accessor<Gtk.Align>
    sensitive?: boolean | Accessor<boolean>
    visible?: boolean | Accessor<boolean>
}

/** Shared button with variants styled in `_button.scss`. */
export function Button({
    label,
    icon,
    variant = "flat",
    onClicked,
    tooltipText,
    hexpand,
    valign,
    sensitive = true,
    visible = true,
}: ButtonProps) {
    return (
        <button
            class={`btn btn-${variant}`}
            onClicked={() => {
                debugLog("button", "press", typeof label === "string" ? label : (typeof icon === "string" ? icon : variant))
                onClicked()
            }}
            tooltipText={tooltipText}
            hexpand={hexpand}
            valign={valign}
            sensitive={sensitive}
            visible={visible}
        >
            <box spacing={5}>
                {icon !== undefined && <image iconName={icon} />}
                {label !== undefined && <label label={label} />}
            </box>
        </button>
    )
}
