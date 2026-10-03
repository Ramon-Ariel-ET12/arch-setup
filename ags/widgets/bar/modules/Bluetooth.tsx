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
    pairDevice,
    removeDevice,
    setTrusted,
    togglePower,
    type AstalAdapter,
    type AstalDevice,
} from "@/services/bluetooth"

/**
 * Bluetooth indicator with a device control popover.
 *
 * The bar shows a bluetooth icon that reflects the powered/connected state;
 * clicking opens a GTK4 `Popover` below the button. Inside: a power toggle at
 * the top and a scrollable list of devices grouped into Known (paired or
 * trusted) and Available (discovered, not yet paired) sections. Each device
 * is a `Collapsible` with connect / disconnect / pair / remove actions.
 */

/** Paired or trusted devices are "known"; everything else is merely available. */
function isKnown(device: AstalDevice): boolean {
    return device.get_paired() || device.get_trusted()
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
    const trusted = createBinding(device, "trusted")
    const connecting = createBinding(device, "connecting")
    const battery = createBinding(device, "batteryPercentage")

    const { error, notBusy, run } = useRowAction()

    // BlueZ-proposed icon, tracked live — falls back to the generic glyph.
    const deviceIcon = createBinding(device, "icon")
    const typeIcon = deviceIcon((i) => i || icons.bluetooth.device)

    // State badge: trusted lock, paired check, nothing for merely available.
    const badge = createComputed(() => {
        if (trusted()) return icons.ui.trusted
        if (paired()) return icons.ui.check
        return null
    })

    const batteryLabel = createComputed(() => pctLabel(battery(), ""))

    const addressLine = createComputed(() => {
        const flags = [paired() ? "Paired" : null, trusted() ? "Trusted" : null].filter(
            (f): f is string => f !== null,
        )
        return flags.length > 0
            ? `${device.get_address()} · ${flags.join(" · ")}`
            : device.get_address()
    })

    const chevron = open((o) => (o ? icons.ui.chevronUp : icons.ui.chevronDown))
    const trustLabel = trusted((t) => (t ? "Untrust" : "Trust"))

    return (
        <Collapsible
            open={open}
            onToggle={onToggle}
            header={
                <box spacing={10} widthRequest={240}>
                    <image iconName={typeIcon} />
                    <label
                        label={deviceName(device)}
                        hexpand
                        ellipsize={Pango.EllipsizeMode.END}
                        xalign={0}
                    />
                    <label label={batteryLabel} class="subtitle" />
                    <image
                        iconName={badge((b) => b ?? "")}
                        visible={badge((b) => b !== null)}
                    />
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
                            label="Disconnect"
                            onClicked={() => run(() => disconnectDevice(device))}
                            sensitive={notBusy}
                            visible={connected}
                        />
                        <Button
                            label="Connect"
                            onClicked={() => run(() => connectDevice(device))}
                            sensitive={notBusy}
                            visible={createComputed(() => paired() && !connected())}
                        />
                        <Button
                            label="Pair"
                            onClicked={() => run(() => pairDevice(device))}
                            sensitive={notBusy}
                            visible={paired((p) => !p)}
                        />
                        <Button
                            label={trustLabel}
                            onClicked={() => run(() => setTrusted(device, !trusted()))}
                            sensitive={notBusy}
                            visible={paired}
                        />
                        <Button
                            label="Forget"
                            onClicked={() => run(() => removeDevice(device.get_address()))}
                            sensitive={notBusy}
                            visible={paired}
                        />
                    </box>

                    <label label={addressLine} class="subtitle" halign={Gtk.Align.START} />
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
    const icon = createBinding(device, "icon")

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
            <image
                iconName={icon((i) => i || icons.bluetooth.enabled)}
                valign={Gtk.Align.CENTER}
            />
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

/** Text-only section label with a count — rows carry the iconography. */
function SectionHeader({ label, count }: { label: string; count: Accessor<number> }) {
    return (
        <box spacing={8} valign={Gtk.Align.CENTER}>
            <label label={label} class="subtitle" halign={Gtk.Align.START} hexpand />
            <label label={count((c) => `${c}`)} class="subtitle" />
        </box>
    )
}

/** One grouped device list sharing the panel-wide single-open accordion. */
function DeviceList({
    devices,
    openAddr,
    setOpenAddr,
}: {
    devices: Accessor<AstalDevice[]>
    openAddr: Accessor<string | null>
    setOpenAddr: (addr: string | null) => void
}) {
    return (
        <For each={devices}>
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

    // Known (paired/trusted) vs Available (discovered, unpaired) sections.
    // The connected device lives in the header, so it is excluded here.
    // Unknown/nameless devices are kept in Available — that is where
    // not-yet-paired headphones show up while discovering.
    const known = createComputed(() => {
        void devices()
        return [...getDevices()]
            .filter((d) => !d.get_connected() && isKnown(d))
            .sort((a, b) => deviceName(a).localeCompare(deviceName(b)))
    })

    const available = createComputed(() => {
        void devices()
        return [...getDevices()]
            .filter((d) => !d.get_connected() && !isKnown(d))
            .sort((a, b) => b.get_rssi() - a.get_rssi() || deviceName(a).localeCompare(deviceName(b)))
    })

    // Collapsible: only one device expanded at a time, by address.
    const [openAddr, setOpenAddr] = createState<string | null>(null)

    const knownCount = createComputed(() => known().length)
    const availableCount = createComputed(() => available().length)
    const empty = createComputed(
        () => !discovering() && known().length === 0 && available().length === 0,
    )

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
                <With value={knownCount}>
                    {(c) =>
                        c === 0 ? (
                            <box />
                        ) : (
                            <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                                <SectionHeader label="Known" count={knownCount} />
                                <DeviceList
                                    devices={known}
                                    openAddr={openAddr}
                                    setOpenAddr={setOpenAddr}
                                />
                            </box>
                        )
                    }
                </With>
                <With value={availableCount}>
                    {(c) =>
                        c === 0 ? (
                            <box />
                        ) : (
                            <box orientation={Gtk.Orientation.VERTICAL} spacing={2}>
                                <SectionHeader label="Available" count={availableCount} />
                                <DeviceList
                                    devices={available}
                                    openAddr={openAddr}
                                    setOpenAddr={setOpenAddr}
                                />
                            </box>
                        )
                    }
                </With>
            </ScrollArea>
        </box>
    )
}

/** Connected-device icon in the bar pill (BlueZ-proposed, live). */
function ConnectedTriggerIcon({ device }: { device: AstalDevice }) {
    const icon = createBinding(device, "icon")
    return <image iconName={icon((i) => i || icons.bluetooth.enabled)} />
}

/** Bar trigger icon + connected-device name/battery. */
export function BluetoothTrigger() {
    const bt = getBluetooth()
    const powered = createBinding(bt, "isPowered")
    const isConnected = createBinding(bt, "isConnected")
    const devices = createBinding(bt, "devices")

    // Default bluetooth glyph; replaced by the connected device's own icon.
    const defaultIcon = createComputed(() => {
        if (!powered()) return icons.bluetooth.disabled
        return isConnected() ? icons.bluetooth.enabled : icons.bluetooth.disconnected
    })

    const active = createComputed(() => {
        void devices()
        return getDevices().find((d) => d.get_connected()) ?? null
    })

    return (
        <box spacing={4} tooltipText="Bluetooth">
            <With value={active}>
                {(dev) =>
                    dev === null ? (
                        <box spacing={4}>
                            <image iconName={defaultIcon} />
                        </box>
                    ) : (
                        <box spacing={4}>
                            <ConnectedTriggerIcon device={dev} />
                            <TriggerDeviceInfo device={dev} />
                        </box>
                    )
                }
            </With>
        </box>
    )
}
