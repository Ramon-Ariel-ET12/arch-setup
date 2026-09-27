import app from "ags/gtk4/app"
import Astal from "gi://Astal?version=4.0"
import type Gdk from "gi://Gdk?version=4.0"
import { createBinding, createEffect } from "gnim"
import { options } from "@/options"
import { BarLayout } from "./layout"

/**
 * One persistent bar per monitor (the only always-visible surface).
 * Global widgets inside decide main-only visibility themselves.
 */

const { TOP, LEFT, RIGHT } = Astal.WindowAnchor

function renderBar(gdkmonitor: Gdk.Monitor): Astal.Window {
    const index = app.get_monitors().indexOf(gdkmonitor)

    // gnim JSX elements are loosely typed (`GObject.Object`), hence the cast.
    return (
        (<window
            name={`bar-${index}`}
            namespace="bar"
            application={app}
            visible
            gdkmonitor={gdkmonitor}
            exclusivity={Astal.Exclusivity.EXCLUSIVE}
            anchor={TOP | LEFT | RIGHT}
            layer={Astal.Layer.TOP}
            // Height cap: `heightRequest` is only a minimum, so the default
            // size pins the layer surface (GTK re-applies it on every map)
            // and taller content clips instead of growing the bar.
            heightRequest={options.bar.height}
            defaultHeight={options.bar.height}
        >
            <BarLayout gdkmonitor={gdkmonitor} />
        </window>) as Astal.Window
    )
}

/**
 * Mounts one bar per connected monitor and keeps them in sync with hotplug:
 * bars are created for new outputs and destroyed for removed ones.
 */
export function Bars(): void {
    const monitors = createBinding(app, "monitors")
    const bars = new Map<Gdk.Monitor, Astal.Window>()

    createEffect(() => {
        const current = monitors()

        for (const [gdk, bar] of [...bars]) {
            if (!current.includes(gdk)) {
                bar.destroy()
                bars.delete(gdk)
            }
        }
        for (const gdk of current) {
            if (!bars.has(gdk)) bars.set(gdk, renderBar(gdk))
        }
    }, { immediate: true })
}
