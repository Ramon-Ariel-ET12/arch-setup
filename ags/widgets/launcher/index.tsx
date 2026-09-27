import { Popup } from "@/components"
import { activateSelected, moveSelection, resetLauncher } from "./actions"
import { LauncherContent } from "./content"

/**
 * App launcher (Wofi replacement). Opens centered on the **focused** monitor,
 * with arrow-key navigation and Enter to launch.
 *
 * Toggle: `ags toggle launcher`
 */
export default function LauncherPopup() {
    return (
        <Popup
            name="launcher"
            title="Applications"
            target="focused"
            widthPct={35}
            heightPct={80}
            keymap={{
                onMove: moveSelection,
                onConfirm: activateSelected,
            }}
            onShow={() => resetLauncher()}
        >
            <LauncherContent />
        </Popup>
    )
}
