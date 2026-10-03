import { Gtk } from "ags/gtk4"
import { createState, With } from "gnim"
import { Popover, Tabs } from "@/components"
import { EmptyState } from "@/lib/helpers/empty"
import { icons } from "@/lib/icons"
import { BAR_POPOVER_FALLBACK } from "@/lib/ui"
import { popoverSize } from "@/services/monitors"
import {
    bluetoothAdapter,
    bluezAvailable,
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
    const { width } = popoverSize(20, 40, BAR_POPOVER_FALLBACK)
    const [tab, setTab] = createState<ConnTab>("wifi")

    // startDiscovery is safe to call unconditionally: the service re-resolves
    // the live adapter and no-ops while unpowered or adapter-less.
    const selectTab = (id: ConnTab) => {
        setTab(id)
        if (id === "wifi") {
            stopDiscovery()
            refreshWifi()
        } else {
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
                else startDiscovery()
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
                        <With value={bluetoothAdapter}>
                            {(adapter) =>
                                adapter !== null ? (
                                    <BluetoothPanel adapter={adapter} />
                                ) : (
                                    <With value={bluezAvailable}>
                                        {(ready) =>
                                            ready ? (
                                                <EmptyState
                                                    icon={icons.bluetooth.disabled}
                                                    label="No Bluetooth adapter"
                                                />
                                            ) : (
                                                <EmptyState
                                                    icon={icons.ui.refresh}
                                                    label="Waiting for Bluetooth service…"
                                                />
                                            )
                                        }
                                    </With>
                                )
                            }
                        </With>
                    </box>
                </box>
            }
        />
    )
}
