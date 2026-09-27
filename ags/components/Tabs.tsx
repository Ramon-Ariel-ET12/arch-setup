import type { Accessor } from "gnim"
import { debugLog } from "@/lib/log"

export interface TabDef<T extends string = string> {
    id: T
    label: string
}

interface TabsProps<T extends string> {
    tabs: readonly TabDef<T>[]
    active: Accessor<T>
    onChange: (id: T) => void
}

/** Simple tab bar (see `_tabs.scss`). */
export function Tabs<T extends string>({ tabs, active, onChange }: TabsProps<T>) {
    return (
        <box class="tabs" homogeneous>
            {tabs.map((tab) => (
                <button class={active((id) => (id === tab.id ? "tab px-3 py-1 active" : "tab px-3 py-1"))} onClicked={() => {
                    debugLog("tabs", "switch", tab.id)
                    onChange(tab.id)
                }}>
                    <label label={tab.label} />
                </button>
            ))}
        </box>
    )
}
