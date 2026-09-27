import { Gtk } from "ags/gtk4"

/**
 * Minimal card container: padded, rounded surface (see `_card.scss`).
 * Composition only — no behavior lives here.
 *
 * `children` is intentionally loose (`any`): gnim's runtime flattens
 * arbitrary JSX children (widgets, strings, arrays, conditionals) and its
 * exported `Node` type does not model nested arrays.
 */

import type { BoxProps } from "@/lib/props"

interface CardProps extends BoxProps {}

export function Card({ class: cls = "", spacing = 12, hexpand, vexpand, widthRequest, heightRequest, children }: CardProps) {
    return (
        <box
            orientation={Gtk.Orientation.VERTICAL}
            valign={Gtk.Align.START}
            class={`card ${cls}`}
            spacing={spacing}
            hexpand={hexpand}
            vexpand={vexpand}
            widthRequest={widthRequest}
            heightRequest={heightRequest}
        >
            {children}
        </box>
    )
}
