import AstalBluetooth from "gi://AstalBluetooth?version=0.1"
import { debugLog } from "@/lib/log"
import { logWarn } from "@/lib/notify"
import { callGirAsync } from "@/lib/subprocess"

/** Bluetooth access. AstalBluetooth singleton only touched here. */

const bluetooth = AstalBluetooth.get_default()

/** The AstalBluetooth singleton (for property bindings). */
export function getBluetooth(): AstalBluetooth.Bluetooth {
    return bluetooth
}

/** The first (usually only) adapter, or null if no Bluetooth hardware. */
export function getAdapter(): AstalBluetooth.Adapter | null {
    return bluetooth.get_adapter()
}

/** All devices ever registered on the bluez bus (paired + remembered). */
export function getDevices(): AstalBluetooth.Device[] {
    return bluetooth.get_devices()
}

/** Toggle the adapter's powered state (on/off). */
export function togglePower(): void {
    debugLog("bluetooth", "togglePower")
    bluetooth.toggle()
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
    if (adapter && adapter.get_discovering() === false) {
        try {
            adapter.start_discovery()
        } catch (err) {
            // Sync-throwing bluez call: rejects with InvalidArguments/NotReady
            // while the adapter is busy or still powering up.
            logWarn("bluetooth: failed to start discovery:", err)
        }
    }
}

/** Stop an active scan. */
export function stopDiscovery(): void {
    debugLog("bluetooth", "stopDiscovery")
    const adapter = getAdapter()
    if (adapter && adapter.get_discovering()) {
        try {
            adapter.stop_discovery()
        } catch (err) {
            logWarn("bluetooth: failed to stop discovery:", err)
        }
    }
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
