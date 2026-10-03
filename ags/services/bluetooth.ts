import AstalBluetooth from "gi://AstalBluetooth?version=0.1"
import Gio from "gi://Gio"
import { createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { logWarn } from "@/lib/notify"
import { callGirAsync } from "@/lib/subprocess"

/** Bluetooth access. AstalBluetooth singleton only touched here. */

let bluetooth: AstalBluetooth.Bluetooth | null = null
try {
    bluetooth = AstalBluetooth.get_default()
} catch (err) {
    // bluetoothd / org.bluez not on the bus yet at login: stay uninitialized
    // and retry when the name appears (see the bus watch below) instead of
    // throwing at import time and requiring a shell restart.
    logWarn("bluetooth: service unavailable at startup:", err)
}

function safeGetAdapter(): AstalBluetooth.Adapter | null {
    try {
        return bluetooth?.get_adapter() ?? null
    } catch {
        return null
    }
}

const [adapterState, setAdapterState] = createState<AstalBluetooth.Adapter | null>(safeGetAdapter())
const [serviceAvailable, setServiceAvailable] = createState<boolean>(bluetooth !== null)

function refreshAdapter(): void {
    setAdapterState(safeGetAdapter())
}

function attachSignals(bt: AstalBluetooth.Bluetooth): void {
    // Astal callbacks for late D-Bus availability: when bluetoothd appears
    // after the shell started, `adapter-added` fires and the UI re-resolves.
    bt.connect("adapter-added", () => {
        debugLog("bluetooth", "adapter-added")
        setServiceAvailable(true)
        refreshAdapter()
    })
    bt.connect("adapter-removed", () => {
        debugLog("bluetooth", "adapter-removed")
        refreshAdapter()
    })
    bt.connect("notify::adapter", refreshAdapter)
    bt.connect("notify::adapters", refreshAdapter)
}

/** (Re)create the singleton after it was missing at startup. */
function ensureBluetooth(): AstalBluetooth.Bluetooth | null {
    if (bluetooth === null) {
        try {
            bluetooth = AstalBluetooth.get_default()
            attachSignals(bluetooth)
        } catch (err) {
            logWarn("bluetooth: service still unavailable:", err)
            return null
        }
    }
    return bluetooth
}

if (bluetooth !== null) attachSignals(bluetooth)

// Raw D-Bus name watch: fires even if Astal's own object-manager signals
// miss a late bluetoothd start. Callbacks are best-effort — Astal signals
// above remain the primary path.
try {
    type WatchFn = (
        busType: number,
        name: string,
        flags: number,
        appeared: (connection: unknown, name: string, owner: string) => void,
        vanished: (connection: unknown, name: string) => void,
    ) => number
    const watchName = (Gio as unknown as { bus_watch_name: WatchFn }).bus_watch_name
    watchName(
        Gio.BusType.SYSTEM,
        "org.bluez",
        Gio.BusNameWatcherFlags.NONE,
        () => {
            debugLog("bluetooth", "org.bluez appeared")
            setServiceAvailable(true)
            ensureBluetooth()
            refreshAdapter()
        },
        () => {
            debugLog("bluetooth", "org.bluez vanished")
            setServiceAvailable(false)
            setAdapterState(null)
        },
    )
} catch (err) {
    debugLog("bluetooth", "bus watch unavailable", err)
}

/** The AstalBluetooth singleton (for property bindings). */
export function getBluetooth(): AstalBluetooth.Bluetooth {
    return ensureBluetooth() ?? (bluetooth as AstalBluetooth.Bluetooth)
}

/** Reactive first adapter: updates when bluetoothd appears late or hardware changes. */
export const bluetoothAdapter: Accessor<AstalBluetooth.Adapter | null> = adapterState

/** Whether org.bluez is on the bus (false while waiting for a late bluetoothd). */
export const bluezAvailable: Accessor<boolean> = serviceAvailable

/** The first (usually only) adapter, or null if no Bluetooth hardware. */
export function getAdapter(): AstalBluetooth.Adapter | null {
    if (adapterState.peek() !== null) return adapterState.peek()
    refreshAdapter()
    return adapterState.peek()
}

/** All devices registered on the bluez bus (paired + discovered). */
export function getDevices(): AstalBluetooth.Device[] {
    try {
        return ensureBluetooth()?.get_devices() ?? []
    } catch {
        return []
    }
}

/** Toggle the adapter's powered state (on/off). */
export function togglePower(): void {
    debugLog("bluetooth", "togglePower")
    const bt = ensureBluetooth()
    if (!bt || !getAdapter()) {
        logWarn("bluetooth: no adapter to toggle")
        return
    }
    try {
        bt.toggle()
    } catch (err) {
        logWarn("bluetooth: failed to toggle power:", err)
    }
}

/** Connect all profiles of a device. */
export function connectDevice(device: AstalBluetooth.Device): Promise<void> {
    debugLog("bluetooth", "connectDevice address=", device.get_address())
    return callGirAsync(
        (done) => device.connect_device(done),
        (res) => device.connect_device_finish(res),
    )
}

/** Gracefully disconnect all connected profiles of a device. */
export function disconnectDevice(device: AstalBluetooth.Device): Promise<void> {
    debugLog("bluetooth", "disconnectDevice address=", device.get_address())
    return callGirAsync(
        (done) => device.disconnect_device(done),
        (res) => device.disconnect_device_finish(res),
    )
}

/** Start scanning for discoverable nearby devices. */
export function startDiscovery(): void {
    debugLog("bluetooth", "startDiscovery")
    const adapter = getAdapter()
    if (!adapter) return
    let powered = false
    try {
        powered = adapter.get_powered()
    } catch {
        return
    }
    if (!powered || adapter.get_discovering()) return
    try {
        adapter.start_discovery()
    } catch (err) {
        // Sync-throwing bluez call: rejects with InvalidArguments/NotReady
        // while the adapter is busy or still powering up.
        logWarn("bluetooth: failed to start discovery:", err)
    }
}

/** Stop an active scan. */
export function stopDiscovery(): void {
    debugLog("bluetooth", "stopDiscovery")
    const adapter = adapterState.peek()
    if (!adapter) return
    try {
        if (adapter.get_discovering()) adapter.stop_discovery()
    } catch (err) {
        logWarn("bluetooth: failed to stop discovery:", err)
    }
}

/** Pair with a discovered device (sync bluez call; throws on failure). */
export function pairDevice(device: AstalBluetooth.Device): void {
    debugLog("bluetooth", "pairDevice address=", device.get_address())
    device.pair()
}

export function removeDevice(address: string): void {
    debugLog("bluetooth", "removeDevice address=", address)
    const adapter = getAdapter()
    if (!adapter) return
    const device = getDevices().find((d) => d.get_address() === address)
    if (!device) return
    try {
        adapter.remove_device(device)
    } catch (err) {
        logWarn("bluetooth: failed to remove device:", err)
    }
}

export type AstalBluetoothType = typeof AstalBluetooth
export type AstalDevice = AstalBluetooth.Device
export type AstalAdapter = AstalBluetooth.Adapter
