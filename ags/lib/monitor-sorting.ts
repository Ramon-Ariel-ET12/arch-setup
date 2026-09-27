import { options } from "@/options"

export function parseConnector(name: string): { family: string; port: number } {
    const i = name.search(/\d/)
    if (i < 0) return { family: name.toUpperCase(), port: 0 }
    const family = name.slice(0, i).toUpperCase()
    const port = Number.parseInt(name.slice(i), 10)
    return { family, port: Number.isFinite(port) ? port : 0 }
}

export function compareConnectors(a: string, b: string): number {
    const priority = options.monitors.connectorPriority
    const key = (name: string): string => {
        const f = parseConnector(name).family
        if (priority.includes(f)) return f
        const stripped = f.replace(/[A-Z]$/, "")
        return priority.includes(stripped) ? stripped : f
    }
    const pa = parseConnector(a)
    const pb = parseConnector(b)
    const fa = key(a)
    const fb = key(b)
    if (fa !== fb) return fa.localeCompare(fb)
    if (pa.port !== pb.port) return pa.port - pb.port
    return a.localeCompare(b)
}

export function sortMonitors<T extends { name: string }>(list: readonly T[]): T[] {
    return [...list].sort((a, b) => compareConnectors(a.name, b.name))
}
