import { Popup } from "@/components"
import { syncFromDaemon } from "@/services/wallpaper"
import { WallpaperGrid } from "./grid"
import { applySelected, cancelPicker, moveCursor, resetCursor } from "./actions"

/**
 * Wallpaper picker: centered carousel with live preview on the focused
 * monitor. Focus paints immediately; Esc/Enter/Space commits the selection,
 * closing via X/toggle-off reverts to the wallpaper from before opening.
 *
 * Toggle: `ags toggle wallpaper`
 */
export default function WallpaperPopup() {
    return (
        <Popup
            name="wallpaper"
            title="Wallpapers"
            target="focused"
            widthPct={60}
            heightPct={70}
            keymap={{
                onMoveH: moveCursor,
                onConfirm: applySelected,
                onEscape: applySelected,
                confirmOnSpace: true,
            }}
            onClose={cancelPicker}
            onShow={() => {
                void syncFromDaemon().then(() => resetCursor())
            }}
            onHide={cancelPicker}
        >
            <WallpaperGrid />
        </Popup>
    )
}
