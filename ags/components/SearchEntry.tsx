import { Gtk } from "ags/gtk4"
import type Astal from "gi://Astal?version=4.0"
import type { Accessor } from "gnim"
import { debugLog } from "@/lib/log"

interface SearchEntryProps {
    text: Accessor<string>
    onChangeText: (text: string) => void
    placeholder?: string
}

/**
 * Search field shared by launcher.
 * Grabs focus whenever its popup window becomes visible.
 */
export function SearchEntry({ text, onChangeText, placeholder = "Search…" }: SearchEntryProps) {
    return (
        <entry
            class="search-entry px-3 py-2"
            placeholderText={placeholder}
            text={text}
            hexpand
            onNotifyText={(self: Gtk.Entry) => {
                debugLog("search", "change", self.text)
                onChangeText(self.text)
            }}
            $={(self: Gtk.Entry) => {
                let wired = false
                self.connect("realize", () => {
                    if (wired) return
                    wired = true
                    const root = self.get_root() as Astal.Window | null
                    root?.connect("notify::visible", () => {
                        if (root.visible) self.grab_focus()
                    })
                })
            }}
        />
    )
}
