import { Gtk } from "ags/gtk4"
import { createState } from "gnim"
import { Popover, Tabs } from "@/components"
import { EmptyState } from "@/lib/helpers/empty"
import { icons } from "@/lib/icons"
import { BAR_POPOVER_FALLBACK } from "@/lib/ui"
import { popoverSize } from "@/services/monitors"
import {
    getAdapter,
    startDiscovery,
    stopDiscovery,
} from "@/services/bluetooth"
import { BluetoothPanel, BluetoothTrigger } from "./Bluetooth"
import { NetworkPanel, NetworkTrigger, refreshWifi } from "./Network"

type ConnTab = "wifi" | "bluetooth"

const TABS = [
    { id: "wifi", label: "Wi-Fi" },
    { id: "bluetooth", label: "Bluetooth" },
] as const

/**
 * Combined connectivity pill: wifi/ethernet + bluetooth icons in a single
 * bar card, opening one popover with tabbed panels.
 */
export function Connectivity() {
    const adapter = getAdapter()
    const { width } = popoverSize(20, 40, BAR_POPOVER_FALLBACK)
    const [tab, setTab] = createState<ConnTab>("wifi")

    const selectTab = (id: ConnTab) => {
        setTab(id)
        if (id === "wifi") {
            stopDiscovery()
            refreshWifi()
        } else if (adapter?.get_powered()) {
            startDiscovery()
        }
    }

    return (
        <Popover
            trigger={
                <box spacing={6}>
                    <NetworkTrigger />
                    <BluetoothTrigger />
                </box>
            }
            onOpen={() => {
                if (tab.peek() === "wifi") refreshWifi()
                else if (adapter?.get_powered()) startDiscovery()
            }}
            onClose={() => stopDiscovery()}
            content={
                <box
                    widthRequest={width}
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={8}
                >
                    <Tabs tabs={TABS} active={tab} onChange={selectTab} />
                    {/* No With here: the panels contain their own With/For and
                        gnim does not support nested fragments. Visibility
                        toggling keeps both mounted (preserves row state). */}
                    <box visible={tab((t) => t === "wifi")}>
                        <NetworkPanel />
                    </box>
                    <box visible={tab((t) => t === "bluetooth")}>
                        {adapter ? (
                            <BluetoothPanel adapter={adapter} />
                        ) : (
                            <EmptyState
                                icon={icons.bluetooth.disabled}
                                label="No Bluetooth adapter"
                            />
                        )}
                    </box>
                </box>
            }
        />
    )
}
