import GLib from "gi://GLib"
import Soup from "gi://Soup?version=3.0"
import { createState, type Accessor } from "gnim"
import { debugLog } from "@/lib/log"
import { icons } from "@/lib/icons"
import { callGirAsync } from "@/lib/subprocess"
import { options } from "@/options"

export interface WeatherState {
    temp: number | null
    code: number | null
    isDay: boolean
}

interface OpenMeteoResponse {
    current?: {
        temperature_2m?: number
        weather_code?: number
        is_day?: number
    }
}

const [weather, setWeather] = createState<WeatherState>({ temp: null, code: null, isDay: true })

export const currentWeather: Accessor<WeatherState> = weather

const session = new Soup.Session()
session.timeout = 10

function decodeBody(bytes: GLib.Bytes): string {
    return new TextDecoder().decode(bytes.toArray())
}

async function fetchOnce(): Promise<void> {
    const url =
        "https://api.open-meteo.com/v1/forecast" +
        `?latitude=${options.weather.latitude}&longitude=${options.weather.longitude}` +
        "&current=temperature_2m,weather_code,is_day&timezone=auto&forecast_days=1"
    debugLog("weather", "fetch", url)
    const msg = Soup.Message.new("GET", url)
    const bytes = await callGirAsync(
        (done) => session.send_and_read_async(msg, GLib.PRIORITY_DEFAULT, null, done),
        (res) => session.send_and_read_finish(res),
    )
    if (msg.status_code !== Soup.Status.OK) {
        debugLog("weather", "http status", msg.status_code)
        return
    }
    const parsed = JSON.parse(decodeBody(bytes)) as OpenMeteoResponse
    const current = parsed.current
    if (current === undefined) return
    const temp = typeof current.temperature_2m === "number" ? current.temperature_2m : null
    const code = typeof current.weather_code === "number" ? current.weather_code : null
    const isDay = current.is_day !== 0
    debugLog("weather", "update temp=", temp, "code=", code, "isDay=", isDay)
    setWeather({ temp, code, isDay })
}

let started = false

export function startWeather(): void {
    if (started) return
    started = true
    const refresh = () => {
        fetchOnce().catch((err) => debugLog("weather", "fetch failed", err))
    }
    refresh()
    setInterval(refresh, options.weather.refreshMinutes * 60_000)
}

export function weatherIcon(code: number | null, isDay: boolean): string {
    if (code === null) return icons.weather.fewClouds
    if (code === 0 || code === 1) return isDay ? icons.weather.clear : icons.weather.clearNight
    if (code === 2) return isDay ? icons.weather.fewClouds : icons.weather.fewCloudsNight
    if (code === 3) return icons.weather.overcast
    if (code === 45 || code === 48) return icons.weather.fog
    if (code >= 51 && code <= 57) return icons.weather.showersScattered
    if (code >= 61 && code <= 67) return icons.weather.showers
    if (code >= 71 && code <= 77) return icons.weather.snow
    if (code >= 80 && code <= 82) return icons.weather.showers
    if (code === 85 || code === 86) return icons.weather.snow
    if (code >= 95) return icons.weather.storm
    return icons.weather.fewClouds
}
