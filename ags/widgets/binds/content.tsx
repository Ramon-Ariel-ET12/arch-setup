import { Gtk } from "ags/gtk4"
import { With } from "gnim"
import { ScrollArea } from "@/components"
import { EmptyState, LoadingRow } from "@/lib/helpers/empty"
import { icons } from "@/lib/icons"
import { formatBind, type HyprBind } from "@/services/hyprbinds"
import { bindList } from "./actions"

/**
 * Keybind helper body: a compact two-column table grouped by category.
 *
 * Layout per category:
 *   ┌─────────────────────┬──────────────────────────────┐
 *   │ Category title      │                              │
 *   ├─────────────────────┼──────────────────────────────┤
 *   │ SUPER + Q           │ Open terminal                │
 *   │ SUPER + E           │ Open file manager            │
 *   │ SUPER + R           │ Toggle launcher              │
 *   │ ...                 │ ...                          │
 *   └─────────────────────┴──────────────────────────────┘
 *
 * Shorter tables are padded with invisible styled rows so every category
 * block shares the tallest table's row count.
 */
export function BindsContent() {
    return (
        <ScrollArea vexpand class="card-body">
            <With value={bindList}>
                {(list) => {
                    if (list === null) return <LoadingRow label="Loading keybinds…" />
                    const cats = categorize(list)
                    if (cats.length === 0) {
                        return (
                            <EmptyState
                                icon={icons.ui.keyboard}
                                label="No keybinds found"
                            />
                        )
                    }
                    return <BindsGrid cats={cats} />
                }}
            </With>
        </ScrollArea>
    )
}

function BindsGrid({ cats }: { cats: BindCategory[] }) {
    const maxRows = Math.max(0, ...cats.map((c) => c.binds.length))
    return (
        <flowbox halign={Gtk.Align.START} rowSpacing={0} columnSpacing={8}>
            {cats.map((cat) => (
                <flowboxchild>
                    <box orientation={Gtk.Orientation.VERTICAL} spacing={0}>
                        <label
                            label={cat.name}
                            class="text-eyebrow border-b px-1 pt-1"
                            xalign={0}
                        />
                        <box orientation={Gtk.Orientation.VERTICAL} spacing={1}>
                            {cat.binds.map((bind) => (
                                <BindRow bind={bind} />
                            ))}
                            {Array.from({
                                length: maxRows - cat.binds.length,
                            }).map(() => (
                                <box class="px-1 py-0 radius-sm" spacing={12} />
                            ))}
                        </box>
                    </box>
                </flowboxchild>
            ))}
        </flowbox>
    )
}

function BindRow({ bind }: { bind: HyprBind }) {
    return (
        <box class="px-1 py-0 radius-sm" spacing={12}>
            <label class="text-primary bold subtitle" label={formatBind(bind)} widthRequest={120} xalign={0} />
            <label class="subtitle" label={bind.description} hexpand xalign={0} />
        </box>
    )
}

// ---------------------------------------------------------------------------
// Categorization
// ---------------------------------------------------------------------------

interface BindCategory {
    name: string
    binds: HyprBind[]
}

const CATEGORY_RULES: readonly { name: string; match: (b: HyprBind) => boolean }[] = [
    { name: "Applications", match: (b) => /Open|Exit session|Lock screen|Toggle launcher/.test(b.description) },
    { name: "Windows", match: (b) => /Close|Force close|Exit Hyprland|Toggle float|Toggle pseudo|Toggle split|Fullscreen|Rogue/.test(b.description) },
    { name: "Focus", match: (b) => /Focus (left|right|up|down|workspace)/.test(b.description) },
    { name: "Move", match: (b) => /Move (window )?(left|right|up|down|to workspace|to special)/.test(b.description) },
    { name: "Swap", match: (b) => /Swap (left|right|up|down)/.test(b.description) },
    { name: "Resize", match: (b) => /(Shrink|Grow) window/.test(b.description) },
    { name: "Workspaces", match: (b) => /workspace|monitor|special/.test(b.description) && !/Focus|Move/.test(b.description) },
    { name: "Media", match: (b) => /Volume|Mute|Brightness|track|Play|Pause/.test(b.description) },
]

function categorize(binds: HyprBind[]): BindCategory[] {
    const uncategorized: HyprBind[] = []
    const map = new Map<string, HyprBind[]>()

    for (const bind of binds) {
        const rule = CATEGORY_RULES.find((r) => r.match(bind))
        if (rule) {
            let arr = map.get(rule.name)
            if (!arr) {
                arr = []
                map.set(rule.name, arr)
            }
            arr.push(bind)
        } else {
            uncategorized.push(bind)
        }
    }

    const result: BindCategory[] = []
    for (const rule of CATEGORY_RULES) {
        const arr = map.get(rule.name)
        if (arr && arr.length > 0) result.push({ name: rule.name, binds: arr })
    }
    if (uncategorized.length > 0) {
        result.push({ name: "Other", binds: uncategorized })
    }
    return result
}
