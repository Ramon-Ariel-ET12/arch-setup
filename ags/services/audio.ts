import AstalWp from "gi://AstalWp?version=0.1"
import { createBinding, createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"

/**
 * Audio access (devices, endpoints, streams). Wp singleton only touched here.
 *
 * The default endpoints are exposed as *reactive* accessors bound to
 * `audio.default-speaker` / `audio.default-microphone`, so consumers follow
 * default-device changes (device hotplug, bluetooth headset connect) instead
 * of holding a stale snapshot from first render. The list accessors below
 * (`speakers`, `microphones`, `streams`, `recorders`, `devices`) drive the
 * pavucontrol-replacement mixer: every pavucontrol tab maps onto one list
 * (see `widgets/bar/modules/Audio.tsx`).
 */

const wp = AstalWp.get_default()
const audio = wp?.audio ?? null
debugLog("audio", "init audio=", audio === null ? "null" : "ready")

const nullEndpoint = createState<AstalWp.Endpoint | null>(null)[0]
const noEndpoints = createState<AstalWp.Endpoint[]>([])[0]
const noStreams = createState<AstalWp.Stream[]>([])[0]
const noDevices = createState<AstalWp.Device[]>([])[0]

export const defaultSpeaker: Accessor<AstalWp.Endpoint | null> =
    audio === null ? nullEndpoint : createBinding(audio, "default_speaker")

export const defaultMic: Accessor<AstalWp.Endpoint | null> =
    audio === null ? nullEndpoint : createBinding(audio, "default_microphone")

/** All output endpoints (sinks) — mixer "Output" tab. */
export const speakers: Accessor<AstalWp.Endpoint[]> =
    audio === null ? noEndpoints : createBinding(audio, "speakers")((list) => list ?? [])

/** All input endpoints (sources) — mixer "Input" tab. */
export const microphones: Accessor<AstalWp.Endpoint[]> =
    audio === null ? noEndpoints : createBinding(audio, "microphones")((list) => list ?? [])

/** Playback streams (apps producing audio) — mixer "Playback" tab. */
export const streams: Accessor<AstalWp.Stream[]> =
    audio === null ? noStreams : createBinding(audio, "streams")((list) => list ?? [])

/** Recording streams (apps capturing audio) — mixer "Recording" tab. */
export const recorders: Accessor<AstalWp.Stream[]> =
    audio === null ? noStreams : createBinding(audio, "recorders")((list) => list ?? [])

/** Cards — mixer "Config" tab (profile switching). */
export const devices: Accessor<AstalWp.Device[]> =
    audio === null ? noDevices : createBinding(audio, "devices")((list) => list ?? [])
