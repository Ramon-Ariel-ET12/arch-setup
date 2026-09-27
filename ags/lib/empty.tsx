import { Gtk } from "ags/gtk4"
import { With, type Accessor } from "gnim"

export function EmptyState({ icon, label, class: cls = "" }: { icon: string; label: string; class?: string }): JSX.Element {
    return (
        <box class={`empty-state ${cls}`.trim()} orientation={Gtk.Orientation.VERTICAL} spacing={6}>
            <image iconName={icon} iconSize={Gtk.IconSize.LARGE} halign={Gtk.Align.CENTER} />
            <label label={label} class="subtitle" halign={Gtk.Align.CENTER} />
        </box>
    )
}

export function LoadingRow({ label, class: cls = "" }: { label: string; class?: string }): JSX.Element {
    return (
        <box class={`loading-state ${cls}`.trim()} spacing={8}>
            <spinner spinning />
            <label label={label} class="subtitle" halign={Gtk.Align.START} />
        </box>
    )
}

interface ErrorLabelProps {
    error: Accessor<string>
    class?: string
}

export function ErrorLabel({ error, class: cls = "" }: ErrorLabelProps): JSX.Element {
    return (
        <With value={error}>
            {(msg) =>
                msg === "" ? (
                    <box />
                ) : (
                    <label label={msg} class={`error-text ${cls}`.trim()} wrap />
                )
            }
        </With>
    )
}
