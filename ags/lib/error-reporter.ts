import GLib from "gi://GLib"
import { debugLog, logLine, timestamp, BODY_MAX, COOLDOWN_MS, formatArg } from "@/lib/log"
import { icons } from "@/lib/icons"
import { execAsync } from "ags/process"

const lastSent = new Map<string, number>()

function send(level: "warn" | "error", args: unknown[]): void {
    const now = Date.now()
    for (const [key, ts] of lastSent) {
        if (now - ts > COOLDOWN_MS) lastSent.delete(key)
    }
    const body = args.map(formatArg).join(" ").slice(0, BODY_MAX)
    const key = `${level}:${body}`
    if (lastSent.has(key)) return
    lastSent.set(key, now)
    debugLog("error", "notify", level, body)
    void execAsync([
        "notify-send",
        "-a", "ags",
        "-i", level === "error" ? icons.ui.error : icons.ui.warn,
        "-u", level === "error" ? "critical" : "normal",
        level === "error" ? "AGS error" : "AGS warning",
        body,
    ]).catch(() => {})
}

export function logWarn(...args: unknown[]): void {
    logLine("WARN", "", ...args)
    send("warn", args)
}

export function logError(...args: unknown[]): void {
    logLine("ERROR", "", ...args)
    send("error", args)
}

function levelFor(priority: string): "ERROR" | "WARN" | "INFO" | "DEBUG" {
    if (priority <= "3") return "ERROR"
    if (priority === "4") return "WARN"
    if (priority <= "6") return "INFO"
    return "DEBUG"
}

function readField(fields: unknown, key: string): string {
    try {
        const raw = (fields as Record<string, unknown>)[key]
        if (raw instanceof Uint8Array) return new TextDecoder().decode(raw)
        if (typeof raw === "string") return raw
    } catch {
    }
    return ""
}

export function installErrorReporting(): void {
    GLib.log_set_writer_func((_level, fields) => {
        try {
            const message = readField(fields, "MESSAGE")
            const domain = readField(fields, "GLIB_DOMAIN") || "GLib"
            const priority = readField(fields, "PRIORITY") || "4"
            if (domain === "Gjs-Console") {
                if (priority >= "5") {
                    print(message)
                } else {
                    printerr(`${timestamp()} | ${levelFor(priority)} | Gjs-Console | -() | ${message}`)
                }
            } else if (priority <= "5") {
                printerr(`${timestamp()} | ${levelFor(priority)} | ${domain} | -() | ${message}`)
            }
            if (domain !== "Gjs-Console") {
                const uncaught = domain === "Gjs" && message.startsWith("JS ERROR:")
                if (priority === "2" || priority === "3" || uncaught) {
                    send("error", [message])
                } else if (priority === "4") {
                    send("warn", [message])
                }
            }
        } catch {
        }
        return GLib.LogWriterOutput.HANDLED
    })
}
