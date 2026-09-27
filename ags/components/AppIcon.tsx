import { Gtk } from "ags/gtk4"
import Gio from "gi://Gio"
import { loadScaledTexture } from "@/lib/image"
import { icons } from "@/lib/icons"

interface AppIconProps {
    name?: string | null
    path?: string | null
    gicon?: Gio.Icon | null
    size?: Gtk.IconSize
    pixelSize?: number
    class?: string
    valign?: Gtk.Align
}

/**
 * Single image-rendering surface that picks the right `<image>` form based
 * on the source. Always renders; never displays a path or a textual
 * description. Decision order: path → name → gicon → fallback icon.
 * A path that fails to decode falls back to the placeholder icon.
 */
export function AppIcon({
    name,
    path,
    gicon,
    size = Gtk.IconSize.NORMAL,
    pixelSize,
    class: cls = "",
    valign,
}: AppIconProps) {
    const trimmedPath = path?.trim() ?? ""
    if (trimmedPath !== "") {
        const tex = loadScaledTexture(trimmedPath, pixelSize ?? 48)
        return tex !== null ? (
            <image
                paintable={tex}
                pixelSize={pixelSize}
                class={cls}
                valign={valign}
            />
        ) : (
            <image
                iconName={icons.ui.notifications}
                class={cls}
                valign={valign}
            />
        )
    }
    if (name !== null && name !== undefined && name !== "") {
        return <image iconName={name} iconSize={size} class={cls} valign={valign} />
    }
    if (gicon !== null && gicon !== undefined) {
        return <image gicon={gicon} iconSize={size} class={cls} valign={valign} />
    }
    return (
        <image
            iconName={icons.ui.notifications}
            iconSize={size}
            class={cls}
            valign={valign}
        />
    )
}
