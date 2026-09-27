import AstalWp from "gi://AstalWp?version=0.1"
import { createBinding, createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"

/**
 * Audio access (speakers/microphones). Wp singleton only touched here.
 *
 * The default endpoints are exposed as *reactive* accessors bound to
 * `audio.default-speaker` / `audio.default-microphone`, so consumers follow
 * default-device changes (device hotplug, bluetooth headset connect) instead
 * of holding a stale snapshot from first render.
 */

const wp = AstalWp.get_default()
const audio = wp?.audio ?? null
debugLog("audio", "init audio=", audio === null ? "null" : "ready")

const nullEndpoint = createState<AstalWp.Endpoint | null>(null)[0]

export const defaultSpeaker: Accessor<AstalWp.Endpoint | null> =
    audio === null ? nullEndpoint : createBinding(audio, "default_speaker")

export const defaultMic: Accessor<AstalWp.Endpoint | null> =
    audio === null ? nullEndpoint : createBinding(audio, "default_microphone")
