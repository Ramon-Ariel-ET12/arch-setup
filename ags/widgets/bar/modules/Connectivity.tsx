import { Gtk } from "ags/gtk4"
import { createComputed, createState, With } from "gnim"
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
    type AstalAdapter,
} from "@/services/bluetooth"
import { BluetoothPanel, BluetoothTrigger } from "./Bluetooth"
import { NetworkPanel, NetworkTrigger, refreshWifi } from "./Network"

type ConnTab = "wifi" | "bluetooth"

/**
 * Bluetooth tab content, flattened into one `With` value: gnim fragments
 * cannot nest, so the adapter / waiting / missing cases resolve here instead
 * of through nested `With`s.
 */
type BtTab =
    | { kind: "panel"; adapter: AstalAdapter }
    | { kind: "waiting" }
    | { kind: "missing" }

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

    const btTab = createComputed<BtTab>(() => {
        const adapter = bluetoothAdapter()
        if (adapter !== null) return { kind: "panel", adapter }
        return bluezAvailable() ? { kind: "missing" } : { kind: "waiting" }
    })

    // startDiscovery is safe to call unconditionally: it resolves the live
    // adapter itself and no-ops while unpowered or adapter-less.
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
                        <With value={btTab}>
                            {(state) =>
                                state.kind === "panel" ? (
                                    <BluetoothPanel adapter={state.adapter} />
                                ) : state.kind === "missing" ? (
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
                    </box>
                </box>
            }
        />
    )
}
