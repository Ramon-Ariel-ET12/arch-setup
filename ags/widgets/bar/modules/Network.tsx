import { Gtk } from "ags/gtk4"
import Pango from "gi://Pango"
import AstalNetwork from "gi://AstalNetwork?version=0.1"
import { For, With, createBinding, createComputed, createEffect, createState, type Accessor } from "gnim"
import { Collapsible, Button } from "@/components"
import { ScrollArea } from "@/components/ScrollArea"
import { EmptyState, ErrorLabel, LoadingRow } from "@/lib/helpers/empty"
import { icons, signalIcon } from "@/lib/icons"
import { useRowAction } from "@/lib/row-action"
import { callGirAsync } from "@/lib/helpers/gir"

/**
 * Network indicator with a Wi‑Fi / Ethernet control popover.
 *
 * The bar icon shows wifi/wired/offline state; clicking it opens a GTK4
 * `Popover` below the button. Wi‑Fi shows the connected network + a list of
 * nearby networks (each a `Collapsible` with connect/forget actions);
 * Ethernet shows connection info only (no actions — wired is automatic).
 */

/** NM.DeviceState.ACTIVATED (numeric, avoids pulling the NM GIR). */
const STATE_ACTIVATED = 2

type AstalAccessPoint = AstalNetwork.AccessPoint
type AstalWifi = AstalNetwork.Wifi
type AstalWired = AstalNetwork.Wired

const network = AstalNetwork.get_default()
const wifiDevice = network.get_wifi()
const wiredDevice = network.get_wired()

/**
 * Nearby access points, deduplicated by SSID keeping the strongest signal,
 * sorted strongest-first, excluding the currently active one (by BSSID).
 */
function listAccessPoints(wifi: AstalWifi): AstalAccessPoint[] {
    const activeBssid = wifi.active_access_point?.get_bssid()
    const seen = new Map<string, AstalAccessPoint>()
    for (const ap of wifi.get_access_points()) {
        // Skip the network we're currently connected to (BSSID match,
        // since SSID strings may differ in encoding across AP objects).
        if (activeBssid && ap.get_bssid() === activeBssid) continue
        const ssid = ap.get_ssid()
        if (!ssid) continue
        const existing = seen.get(ssid)
        if (!existing || ap.get_strength() > existing.get_strength()) {
            seen.set(ssid, ap)
        }
    }
    return [...seen.values()].sort((a, b) => b.get_strength() - a.get_strength())
}

/** Forget a saved NetworkManager connection for an access point. */
async function forgetAp(ap: AstalAccessPoint): Promise<void> {
    const conns = ap.get_connections()
    if (conns.length > 0) await conns[0].delete_async(null)
}

/** Connect to an access point (the installed GIR does not promisify `activate`). */
function activateAp(ap: AstalAccessPoint, password: string | null): Promise<void> {
    return callGirAsync(
        (done) => ap.activate(password, done),
        (res) => ap.activate_finish(res),
    )
}

function NetworkRow({
    ap,
    open,
    onToggle,
}: {
    ap: AstalAccessPoint
    open: Accessor<boolean>
    onToggle: (open: boolean) => void
}) {
    const ssid = ap.get_ssid() ?? "Unknown network"
    const secure = ap.get_requires_password()
    const [password, setPassword] = createState("")
    const { busy, error, notBusy, run } = useRowAction()

    // Saved-ness is only read by the row body, so evaluate it on expand: the
    // per-row render path must never touch `get_connections` — it segfaults in
    // libastal-network on stale access points (gjs coredump 2026-09-14).
    const [saved, setSaved] = createState(false)
    createEffect(() => {
        if (!open()) return
        setSaved(ap.get_connections().length > 0)
    })

    // Mapped accessors keep row-level changes reactive without re-running the
    // whole `For` row (unwrapped reads inside a row body would rebuild it).
    const signal = createBinding(ap, "strength")
    const rowIcon = createComputed(() =>
        secure ? icons.network.encrypted : signalIcon(signal() ?? 0),
    )
    const chevron = open((o) => (o ? icons.ui.chevronUp : icons.ui.chevronDown))
    const actionLabel = busy((b) => (b ? "Connecting…" : "Connect"))

    const connect = (pass?: string) => run(() => activateAp(ap, pass ?? null))
    const forget = () => run(() => forgetAp(ap))

    return (
        <Collapsible
            open={open}
            onToggle={onToggle}
            header={
                <box spacing={10} widthRequest={240}>
                    <image iconName={rowIcon} />
                    <label
                        label={ssid}
                        hexpand
                        ellipsize={Pango.EllipsizeMode.END}
                        xalign={0}
                    />
                    <image
                        iconName={chevron}
                    />
                </box>
            }
            body={
                <With value={saved}>
                    {(sv) => (
                        <box
                            orientation={Gtk.Orientation.VERTICAL}
                            spacing={8}
                        >
                            {secure && !sv && (
                                <box spacing={6}>
                                    <entry
                                        placeholderText="Password"
                                        visibility={false}
                                        hexpand
                                        onActivate={() => connect(password())}
                                        onNotifyText={(self: Gtk.Entry) => setPassword(self.text)}
                                    />
                                    <Button label={actionLabel} onClicked={() => connect(password())} sensitive={notBusy} />
                                </box>
                            )}

                            {(!secure || sv) && (
                                <Button label={actionLabel} onClicked={() => connect()} sensitive={notBusy} />
                            )}

                            {sv && (
                                <Button label="Forget" onClicked={forget} sensitive={notBusy} />
                            )}

                            <ErrorLabel error={error} />
                        </box>
                    )}
                </With>
            }
        />
    )
}

function WifiPanel({ wifi }: { wifi: AstalWifi }) {
    const activeAp = createBinding(wifi, "activeAccessPoint")
    const accessPoints = createBinding(wifi, "accessPoints")
    const scanning = createBinding(wifi, "scanning")

    const networks = createComputed(() => {
        void accessPoints()
        return listAccessPoints(wifi)
    })

    const empty = createComputed(() => !scanning() && networks().length === 0)

    const [openSsid, setOpenSsid] = createState<string | null>(null)

    const connectedIcon = createComputed(
        () => activeAp()?.get_icon_name() || signalIcon(activeAp()?.get_strength() ?? 0),
    )

    return (
        <box class="min-w-popup" orientation={Gtk.Orientation.VERTICAL} spacing={4} valign={Gtk.Align.START} vexpand>
            <box orientation={Gtk.Orientation.VERTICAL} spacing={6} valign={Gtk.Align.START}>
                <With value={activeAp}>
                    {(ap) =>
                        ap == null ? (
                            <box />
                        ) : (
                            <box class="mb-1" orientation={Gtk.Orientation.VERTICAL} spacing={6}>
                                <box class="p-2" spacing={10}>
                                    <button
                                        class="card"
                                        onClicked={() => {
                                            wifi.enabled = !wifi.enabled
                                        }}
                                        tooltipText="Turn Wi-Fi off"
                                    >
                                        <image iconName={connectedIcon} iconSize={Gtk.IconSize.LARGE} />
                                    </button>
                                    <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                                        <label label={ap.get_ssid() ?? "Connected"} />
                                        <label label="Connected" class="subtitle" />
                                    </box>
                                    <Button
                                        label="Disconnect"
                                        onClicked={() => {
                                            void wifi.deactivate_connection().catch(() => undefined)
                                        }}
                                    />
                                </box>
                                <separator class="separator m-0" />
                            </box>
                        )
                    }
                </With>
            </box>
            <ScrollArea class="card-body" vexpand spacing={2}>
                <With value={scanning}>
                    {(s) => (s ? <LoadingRow label="Scanning for networks…" /> : <box />)}
                </With>
                <With value={empty}>
                    {(e) =>
                        e ? (
                            <EmptyState icon={icons.network.error} label="No networks found" />
                        ) : (
                            <box />
                        )
                    }
                </With>
                <For each={networks}>
                    {(ap: AstalAccessPoint) => {
                        const ssid = ap.get_ssid() ?? ""
                        const open = createComputed(() => openSsid() === ssid)
                        return (
                            <NetworkRow
                                ap={ap}
                                open={open}
                                onToggle={(next) => setOpenSsid(next ? ssid : null)}
                            />
                        )
                    }}
                </For>
            </ScrollArea>
        </box>
    )
}

function WiredPanel({ wired }: { wired: AstalWired }) {
    const state = createBinding(wired, "state")
    const speed = createBinding(wired, "speed")

    const connected = createComputed(() => (state() as number) === STATE_ACTIVATED)

    const speedLabel = createComputed(() => {
        const mbps = speed()
        return mbps > 0 ? `${mbps} Mb/s` : "—"
    })

    return (
        <box
            class="min-w-popup"
            orientation={Gtk.Orientation.VERTICAL}
            spacing={8}
            valign={Gtk.Align.START}
            vexpand
        >
            <box spacing={10} valign={Gtk.Align.START}>
                <image
                    iconName={connected()
                        ? icons.network.wiredActive
                        : icons.network.offline}
                    iconSize={Gtk.IconSize.LARGE}
                />
                <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                    <label label="Ethernet" halign={Gtk.Align.START} />
                    <label
                        label={connected() ? "Connected" : "Disconnected"}
                        class="subtitle"
                        halign={Gtk.Align.START}
                    />
                </box>
                <label label={speedLabel} class="subtitle" />
            </box>
            <label
                label="Wired connections are managed automatically."
                class="subtitle"
                wrap
            />
        </box>
    )
}

/** Bar trigger icon; reflects wifi/wired/offline state. */
export function NetworkTrigger() {
    const wifi = wifiDevice

    if (wifi === null) {
        const wired = wiredDevice
        if (wired === null) {
            return (
                <box>
                    <image iconName={icons.network.offline} />
                </box>
            )
        }
        const state = createBinding(wired, "state")
        return (
            <box>
                <image
                    iconName={state((s) =>
                        (s as number) === STATE_ACTIVATED
                            ? icons.network.wiredActive
                            : icons.network.offline,
                    )}
                />
            </box>
        )
    }

    const enabled = createBinding(wifi, "enabled")
    const wifiIcon = createBinding(wifi, "icon_name")
    const ssid = createBinding(wifi, "ssid")
    const strengthening = createBinding(wifi, "strength")

    const icon = createComputed(() =>
        !enabled() ? icons.network.offline : wifiIcon() || signalIcon(strengthening()),
    )

    return (
        <box spacing={4} tooltipText={ssid((s) => s || "Wi-Fi")}>
            <image iconName={icon} />
            <label
                label={ssid((s) => s || "")}
                visible={ssid((s) => (s ?? "") !== "")}
                maxWidthChars={12}
                ellipsize={Pango.EllipsizeMode.END}
            />
        </box>
    )
}

/** Trigger a Wi-Fi rescan (no-op when wifi is absent or disabled). */
export function refreshWifi() {
    if (wifiDevice !== null && wifiDevice.enabled) wifiDevice.scan()
}

/** Wi-Fi radio header shown when the radio is off (re-enable here). */
function WifiOffHeader({ wifi, enabled }: { wifi: AstalWifi; enabled: Accessor<boolean> }) {
    return (
        <box class="p-2" spacing={10}>
            <button
                class="card"
                onClicked={() => {
                    wifi.enabled = true
                }}
                tooltipText="Turn Wi-Fi on"
            >
                <image iconName={icons.network.offline} iconSize={Gtk.IconSize.LARGE} />
            </button>
            <box orientation={Gtk.Orientation.VERTICAL} hexpand>
                <label label="Wi-Fi" halign={Gtk.Align.START} />
                <label label="Off" class="subtitle" halign={Gtk.Align.START} />
            </box>
            <switch
                active={enabled}
                valign={Gtk.Align.CENTER}
                onNotifyActive={(self: Gtk.Switch) => {
                    if (self.active !== enabled.peek()) wifi.enabled = self.active
                }}
            />
        </box>
    )
}

/** Wifi / wired panel body for embedding in a popover. */
export function NetworkPanel() {
    const wifi = wifiDevice
    const wired = wiredDevice
    const wifiEnabled: Accessor<boolean> =
        wifi === null ? createState(false)[0] : createBinding(wifi, "enabled")

    return (
        <With value={wifiEnabled}>
            {(wifiOn) =>
                wifiOn && wifi !== null ? (
                    <WifiPanel wifi={wifi} />
                ) : (
                    <box orientation={Gtk.Orientation.VERTICAL} spacing={8}>
                        {wifi !== null && <WifiOffHeader wifi={wifi} enabled={wifiEnabled} />}
                        {wired === null ? (
                            <EmptyState
                                icon={icons.network.offline}
                                label="No network connection"
                            />
                        ) : (
                            <WiredPanel wired={wired} />
                        )}
                    </box>
                )
            }
        </With>
    )
}
