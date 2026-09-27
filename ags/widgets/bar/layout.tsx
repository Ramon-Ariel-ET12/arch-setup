import { Gtk } from "ags/gtk4"
import type Gdk from "gi://Gdk?version=4.0"
import { isMainGdk } from "@/services/monitors"
import { hyprGapsIn } from "@/services/hyprland"
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
        // Inner gaps follow Hyprland gaps_in truth (live accessor); the bar
        // window floats on gaps_out margins (see widgets/bar/index.tsx) with
        // no extra inner padding, so edge pills land exactly on gaps_out —
        // the same grid as tiled window borders.
        <centerbox class="bar">
            <box $type="start" class="bar-side" hexpand halign={START} spacing={hyprGapsIn}>
                <Workspaces />
                <PopupTriggers />
            </box>

            <box $type="center" class="bar-side" halign={CENTER} spacing={hyprGapsIn}>
                <box visible={isMain} spacing={hyprGapsIn}>
                    <NotificationsIndicator />
                </box>
                <Clock />
            </box>

            <box $type="end" class="bar-side" hexpand halign={END} spacing={hyprGapsIn}>
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
