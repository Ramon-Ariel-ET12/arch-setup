import AstalBluetooth from "gi://AstalBluetooth?version=0.1"
import Gio from "gi://Gio"
import { createBinding, createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { logWarn } from "@/lib/notify"
import { callGirAsync } from "@/lib/helpers/gir"

/**
 * Bluetooth access. AstalBluetooth singleton only touched here.
 *
 * Documented API (docs.astal.dev/bluetooth): `get_default()` returns the
 * singleton; `adapter` is "the first registered adapter which is usually the
 * only adapter" and is nullable; `adapters` is the list of adapters on the
 * host; `adapter-added` / `adapter-removed` fire when an adapter is registered
 * or unregistered on the `org.bluez` bus; `toggle()` flips the first adapter's
 * `powered`.
 *
 * Two behaviours of the *installed* build (libastal-bluetooth-git r930.bcd02cb,
 * read from `lib/bluetooth/src/bluetooth.vala`) shape the code below. Neither is
 * promised by the docs, so do not rely on them without re-checking:
 *
 *  1. `get_default()` cannot propagate a D-Bus failure — it only constructs, and
 *     `construct` wraps the `org.bluez` lookup in its own try/catch. The
 *     singleton is therefore always a valid object and needs no null guard here.
 *  2. Only `adapters` is ever notified: `adapter-added` / `adapter-removed` call
 *     `notify_property("adapters")`, and nothing notifies `adapter`, whose
 *     getter is `adapters.nth_data(0)`.
 *
 * Astal reports no daemon-presence state, and "no `org.bluez`" cannot be told
 * apart from "`org.bluez` with no adapter" through it (both yield a null
 * `adapter`), so the name watch below exists solely to separate those two.
 */

/** AstalBluetooth singleton. */
const bluetooth = AstalBluetooth.get_default()

/** The AstalBluetooth singleton (for property bindings). */
export function getBluetooth(): AstalBluetooth.Bluetooth {
    return bluetooth
}

/**
 * Reactive first adapter.
 *
 * Bound via `adapters`, not `adapter`. The installed build notifies only
 * `adapters`, so a gnim binding on `adapter` subscribes to `notify::adapter` —
 * a signal that is never emitted — and stays frozen on its first value.
 * Measured on that build: `notify::adapters` fires on adapter add *and* remove
 * while `notify::adapter` never fires, and `get_adapter()` and
 * `get_adapters()[0]` return the same value at every sample. Indexing the
 * notified list also matches the documented meaning of `adapter`, "the first
 * registered adapter which is usually the only adapter".
 */
export const bluetoothAdapter: Accessor<AstalBluetooth.Adapter | null> = createBinding(bluetooth, "adapters")(
    (list) => list[0] ?? null,
)

// `Gio.bus_watch_name` is declared with GObject.Closure params, which plain
// arrow functions do not satisfy.
type BusWatch = (
    busType: number,
    name: string,
    flags: number,
    appeared: (connection: unknown, name: string, owner: string) => void,
    vanished: (connection: unknown, name: string) => void,
) => number

// Seeded false: name ownership cannot be read without a blocking round trip,
// and GIO invokes the first handler on the next main-loop iteration. Safe here
// because this value is only consumed while no adapter is present, so the brief
// window where it is not yet authoritative cannot be observed.
const [bluezOnBus, setBluezOnBus] = createState(false)
;(Gio as unknown as { bus_watch_name: BusWatch }).bus_watch_name(
    Gio.BusType.SYSTEM,
    "org.bluez",
    Gio.BusNameWatcherFlags.NONE,
    () => setBluezOnBus(true),
    () => setBluezOnBus(false),
)

/**
 * Whether `org.bluez` currently owns a name on the system bus.
 *
 * This is strictly name ownership, not adapter presence: it is `true` while
 * BlueZ runs even on a host with no adapter, and `false` when BlueZ is not
 * running at all. Do not substitute `getAdapter() !== null` or an
 * `adapters.length > 0` test — that answers a different question and cannot
 * tell the two states apart, which is the sole reason for the watch above.
 */
export const bluezAvailable: Accessor<boolean> = bluezOnBus

/** The first (usually only) adapter, or null if no Bluetooth hardware. */
export function getAdapter(): AstalBluetooth.Adapter | null {
    return bluetooth.get_adapter()
}

/** All devices registered on the bluez bus (paired + discovered). */
export function getDevices(): AstalBluetooth.Device[] {
    return bluetooth.get_devices()
}

/**
 * Toggle the first adapter's `powered` state.
 *
 * Guarded because the documented `adapter` property is nullable while
 * `toggle()` is documented as acting on that adapter; the installed build
 * dereferences it unconditionally.
 */
export function togglePower(): void {
    debugLog("bluetooth", "togglePower")
    if (!getAdapter()) {
        logWarn("bluetooth: no adapter to toggle")
        return
    }
    try {
        bluetooth.toggle()
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
    const adapter = getAdapter()
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

/** Trust (auto-accept reconnects) or untrust a paired device. */
export function setTrusted(device: AstalBluetooth.Device, trusted: boolean): void {
    debugLog("bluetooth", "setTrusted address=", device.get_address(), "trusted=", trusted)
    device.trusted = trusted
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