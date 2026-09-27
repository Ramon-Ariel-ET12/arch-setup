import { Gtk } from "ags/gtk4"
import type Gdk from "gi://Gdk?version=4.0"
import { isMainGdk } from "@/services/monitors"
import { Workspaces } from "./modules/Workspaces"
import { Clock } from "./modules/Clock"
import { Tray } from "./modules/Tray"
import { Battery } from "./modules/Battery"
import { Network } from "./modules/Network"
import { Audio } from "./modules/Audio"
import { Bluetooth } from "./modules/Bluetooth"
import { Media } from "./modules/Media"
import { NotificationsIndicator } from "./modules/NotificationsIndicator"
import { PopupTriggers } from "./modules/PopupTriggers"

/**
 * Bar composition: left = workspaces + popup triggers,
 * center = clock (+ notifications badge, main only),
 * right = status modules; tray/badge are hidden (not unmounted) off-main
 * via reactive `visible` bindings.
 */

const { START, END, CENTER } = Gtk.Align

interface BarLayoutProps {
    gdkmonitor: Gdk.Monitor
}

export function BarLayout({ gdkmonitor }: BarLayoutProps) {
    const isMain = isMainGdk(gdkmonitor)

    return (
        // Inner gaps follow Hyprland gaps_in truth (j/getoption → $gaps-in);
        // the bar window itself stays edge-to-edge (TOP|LEFT|RIGHT,
        // EXCLUSIVE, options.bar.height).
        <centerbox class="bar px-2">
            <box $type="start" class="bar-side" hexpand halign={START} spacing={5}>
                <Workspaces />
                <PopupTriggers />
            </box>

            <box $type="center" class="bar-side" halign={CENTER} spacing={5}>
                <box visible={isMain} spacing={5}>
                    <NotificationsIndicator />
                </box>
                <Clock />
            </box>

            <box $type="end" class="bar-side" hexpand halign={END} spacing={5}>
                <Audio />
                <Network />
                <Bluetooth />
                <Battery />
                <Media />
                <box visible={isMain}>
                    <Tray />
                </box>
            </box>
        </centerbox>
    )
}
