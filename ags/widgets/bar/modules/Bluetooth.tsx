import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango"
import { createBinding, createComputed, createState, For, With, type Accessor } from "gnim"
import { Collapsible, Button } from "@/components"
import { ScrollArea } from "@/components/ScrollArea"
import { icons } from "@/lib/icons"
import { EmptyState, ErrorLabel, LoadingRow } from "@/lib/helpers/empty"
import { pctLabel } from "@/lib/helpers/numbers"
import { useRowAction } from "@/lib/row-action"
import {
    connectDevice,
    disconnectDevice,
    getBluetooth,
    getDevices,
    removeDevice,
    togglePower,
    type AstalAdapter,
    type AstalDevice,
} from "@/services/bluetooth"

/**
 * Bluetooth indicator with a device control popover.
 *
 * The bar shows a bluetooth icon that reflects the powered/connected state;
 * clicking opens a GTK4 `Popover` below the button. Inside: a power toggle at
 * the top and a scrollable list of known devices grouped into Connected /
 * Paired / Available. Each device is a `Collapsible` with connect / disconnect
 * / pair / remove actions.
 */

/** Sort connected devices first, then paired, then the rest, alphabetically. */
function segmentWeight(device: AstalDevice): number {
    if (device.get_connected()) return 0
    if (device.get_paired()) return 1
    return 2
}

function deviceName(device: AstalDevice): string {
    return device.get_alias() || device.get_name() || "Unknown device"
}

/** One device row: header with icon/name/battery, body with actions. */
function DeviceRow({
    device,
    open,
    onToggle,
}: {
    device: AstalDevice
    open: Accessor<boolean>
    onToggle: (open: boolean) => void
}) {
    const connected = createBinding(device, "connected")
    const paired = createBinding(device, "paired")
    const connecting = createBinding(device, "connecting")
    const battery = createBinding(device, "batteryPercentage")

    const { error, notBusy, run } = useRowAction()

    const iconName = createComputed(() =>
        connected() ? icons.bluetooth.enabled : icons.bluetooth.disconnected,
    )

    const batteryLabel = createComputed(() => pctLabel(battery(), ""))

    const chevron = open((o) => (o ? icons.ui.chevronUp : icons.ui.chevronDown))
    const actionLabel = createComputed(() =>
        connected() ? "Disconnect" : paired() ? "Connect" : "Pair",
    )

    return (
        <Collapsible
            open={open}
            onToggle={onToggle}
            header={
                <box spacing={10} widthRequest={240}>
                    <image iconName={iconName} />
                    <label
                        label={deviceName(device)}
                        hexpand
                        ellipsize={Pango.EllipsizeMode.END}
                        xalign={0}
                    />
                    <label label={batteryLabel} class="subtitle" />
                    <image
                        iconName={chevron}
                    />
                </box>
            }
            body={
                <box
                    orientation={Gtk.Orientation.VERTICAL}
                    spacing={8}
                >
                    <With value={connecting}>
                        {(isConnecting) =>
                            isConnecting ? (
                                <LoadingRow label="Connecting…" />
                            ) : (
                                <box />
                            )
                        }
                    </With>

                    <box spacing={6} homogeneous>
                        <Button
                            label={actionLabel}
                            onClicked={() => {
                                if (connected()) run(() => disconnectDevice(device))
                                else if (paired()) run(() => connectDevice(device))
                                else run(() => device.pair())
                            }}
                            sensitive={notBusy}
                        />
                        <Button
                            label="Remove"
                            onClicked={() => run(() => removeDevice(device.get_address()))}
                            sensitive={notBusy}
                        />
                    </box>

                    <ErrorLabel error={error} />
                </box>
            }
        />
    )
}

export /** Connected device summary in the panel header (mirrors the wifi header). */
function ConnectedDeviceHeader({ device }: { device: AstalDevice }) {
    const alias = createBinding(device, "alias")
    const battery = createBinding(device, "batteryPercentage")

    const name = createComputed(() => alias() || device.get_name() || "Unknown device")
    const batteryLabel = createComputed(() => pctLabel(battery(), ""))

    return (
        <box spacing={10} hexpand>
            <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                <label
                    label={name}
                    halign={Gtk.Align.START}
                    ellipsize={Pango.EllipsizeMode.END}
                />
                <label label="Connected" class="subtitle" halign={Gtk.Align.START} />
            </box>
            <label
                label={batteryLabel}
                class="subtitle"
                valign={Gtk.Align.CENTER}
                visible={battery((b) => b >= 0)}
            />
            <Button
                label="Disconnect"
                valign={Gtk.Align.CENTER}
                onClicked={() => {
                    void disconnectDevice(device).catch(() => undefined)
                }}
            />
        </box>
    )
}

/** Connected-device name + battery shown in the bar pill. */
function TriggerDeviceInfo({ device }: { device: AstalDevice }) {
    const alias = createBinding(device, "alias")
    const battery = createBinding(device, "batteryPercentage")

    const name = createComputed(() => alias() || device.get_name() || "")

    return (
        <box spacing={4}>
            <label
                label={name}
                maxWidthChars={12}
                ellipsize={Pango.EllipsizeMode.END}
            />
            <label
                label={battery((b) => pctLabel(b, ""))}
                class="subtitle"
                visible={battery((b) => b >= 0)}
            />
        </box>
    )
}

export function BluetoothPanel({ adapter }: { adapter: AstalAdapter }) {
    const powered = createBinding(adapter, "powered")
    const discovering = createBinding(adapter, "discovering")
    const devices = createBinding(getBluetooth(), "devices")

    // First connected device, if any — shown in the header like wifi.
    const connected = createComputed(() => {
        void devices()
        return getDevices().find((d) => d.get_connected()) ?? null
    })

    // Connected → Paired → Available, alphabetical within each group.
    // The connected device lives in the header, so it is excluded here.
    const sorted = createComputed(() => {
        void devices()
        return [...getDevices()]
            .filter((d) => !d.get_connected())
            .sort((a, b) => {
                const wa = segmentWeight(a)
                const wb = segmentWeight(b)
                return wa !== wb
                    ? wa - wb
                    : deviceName(a).localeCompare(deviceName(b))
            })
    })

    // Collapsible: only one device expanded at a time, by address.
    const [openAddr, setOpenAddr] = createState<string | null>(null)

    const empty = createComputed(() => !discovering() && sorted().length === 0)

    return (
        <box class="min-w-popup" orientation={Gtk.Orientation.VERTICAL} spacing={4} valign={Gtk.Align.START} vexpand>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={6} valign={Gtk.Align.START}>
                <box class="mb-1" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
                    <box class="p-2" spacing={10}>
                        <button
                            class="card"
                            onClicked={() => togglePower()}
                            tooltipText={powered((p) => (p ? "Turn Bluetooth off" : "Turn Bluetooth on"))}
                        >
                            <image
                                iconName={powered((p) => (p ? icons.bluetooth.enabled : icons.bluetooth.disabled))}
                                iconSize={Gtk.IconSize.LARGE}
                            />
                        </button>
                        <With value={connected}>
                            {(dev) =>
                                dev === null ? (
                                    <box spacing={10} hexpand>
                                        <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                                            <label label="Bluetooth" halign={Gtk.Align.START} />
                                            <label
                                                label={powered((p) => (p ? "On" : "Off"))}
                                                class="subtitle"
                                                halign={Gtk.Align.START}
                                            />
                                        </box>
                                        <switch
                                            active={powered}
                                            valign={Gtk.Align.CENTER}
                                            onNotifyActive={(self: Gtk.Switch) => {
                                                if (self.active !== powered.peek()) togglePower()
                                            }}
                                        />
                                    </box>
                                ) : (
                                    <ConnectedDeviceHeader device={dev} />
                                )
                            }
                        </With>
                    </box>
                    <With value={powered}>
                        {(on) =>
                            !on ? (
                                <EmptyState icon={icons.bluetooth.disabled} label="Bluetooth is off" />
                            ) : (
                                <box />
                            )
                        }
                    </With>
                    <separator class="separator m-0" />
                </box>
            </box>
            <ScrollArea class="card-body" vexpand spacing={2}>
                <With value={discovering}>
                    {(scanning) =>
                        scanning ? <LoadingRow label="Scanning…" /> : <box />
                    }
                </With>
                <With value={empty}>
                    {(e) =>
                        e ? (
                            <EmptyState icon={icons.bluetooth.disabled} label="No devices found" />
                        ) : (
                            <box />
                        )
                    }
                </With>
                <For each={sorted}>
                    {(device: AstalDevice) => {
                        const id = device.get_address()
                        const open = createComputed(() => openAddr() === id)
                        return (
                            <DeviceRow
                                device={device}
                                open={open}
                                onToggle={(next) => setOpenAddr(next ? id : null)}
                            />
                        )
                    }}
                </For>
            </ScrollArea>
        </box>
    )
}

/** Bar trigger icon + connected-device name/battery. */
export function BluetoothTrigger() {
    const bt = getBluetooth()
    const powered = createBinding(bt, "isPowered")
    const isConnected = createBinding(bt, "isConnected")
    const devices = createBinding(bt, "devices")

    const icon = createComputed(() => {
        if (!powered()) return icons.bluetooth.disabled
        return isConnected() ? icons.bluetooth.enabled : icons.bluetooth.disconnected
    })

    const active = createComputed(() => {
        void devices()
        return getDevices().find((d) => d.get_connected()) ?? null
    })

    return (
        <box spacing={4} tooltipText="Bluetooth">
            <image iconName={icon} />
            <With value={active}>
                {(dev) => {
                    if (dev === null) return <box visible={false} />
                    return <TriggerDeviceInfo device={dev} />
                }}
            </With>
        </box>
    )
}
