import { Popup } from "@/components"
import { BindsContent } from "./content"
import { refreshBinds } from "./actions"

/**
 * Keybind helper popup card, centered on the focused monitor.
 *
 * Toggle: `ags toggle binds`
 */
export default function BindsPopup() {
    return (
        <Popup
            name="binds"
            title="Keybinds"
            titleXAlign={0.5}
            target="focused"
            widthPct={80}
            heightPct={75}
            onShow={() => refreshBinds()}
        >
            <BindsContent />
        </Popup>
    )
}
