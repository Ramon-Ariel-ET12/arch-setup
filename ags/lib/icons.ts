/** Central icon-name registry so widgets never hardcode theme icons. */

export const icons = {
    ui: {
        close: "window-close-symbolic",
        search: "system-search-symbolic",
        check: "object-select-symbolic",
        star: "starred-symbolic",
        starOutline: "non-starred-symbolic",
        refresh: "view-refresh-symbolic",
        apps: "view-app-grid-symbolic",
        wallpaper: "wallpaper-symbolic",
        monitors: "display-symbolic",
        settings: "emblem-system-symbolic",
        notifications: "notification-symbolic",
        bell: "preferences-system-notifications-symbolic",
        bellOff: "preferences-system-notifications-disabled-symbolic",
        keyboard: "input-keyboard-symbolic",
        clipboard: "edit-paste-symbolic",
        emoji: "face-smile-symbolic",
        symbol: "insert-symbol-symbolic",
        link: "insert-link-symbolic",
        trash: "user-trash-symbolic",
        select: "object-select-symbolic",
        open: "go-next-symbolic",
        prev: "go-previous-symbolic",
        next: "go-next-symbolic",
        chevronUp: "pan-up-symbolic",
        chevronDown: "pan-down-symbolic",
        warn: "dialog-warning-symbolic",
        error: "dialog-error-symbolic",
    },
    audio: {
        high: "audio-volume-high-symbolic",
        medium: "audio-volume-medium-symbolic",
        low: "audio-volume-low-symbolic",
        muted: "audio-volume-muted-symbolic",
        mic: "audio-input-microphone-symbolic",
        micMuted: "microphone-sensitivity-muted-symbolic",
    },
    network: {
        wired: "network-wired-symbolic",
        wiredActive: "network-wired-activated-symbolic",
        wifi: "network-wireless-signal-excellent-symbolic",
        wifiGood: "network-wireless-signal-good-symbolic",
        wifiOk: "network-wireless-signal-ok-symbolic",
        wifiWeak: "network-wireless-signal-weak-symbolic",
        wifiNone: "network-wireless-signal-none-symbolic",
        encrypted: "network-wireless-encrypted-symbolic",
        offline: "network-offline-symbolic",
        error: "network-error-symbolic",
    },
    bluetooth: {
        enabled: "bluetooth-active-symbolic",
        disabled: "bluetooth-disabled-symbolic",
        disconnected: "bluetooth-disconnected-symbolic",
        device: "bluetooth-symbolic",
        console: "bluetooth-hardware-disabled-symbolic",
    },
    battery: {
        full: "battery-full-symbolic",
        charging: "battery-full-charging-symbolic",
    },
    media: {
        play: "media-playback-start-symbolic",
        pause: "media-playback-pause-symbolic",
        next: "media-skip-forward-symbolic",
        prev: "media-skip-backward-symbolic",
    },
} as const

/** Volume ladder (0–1) → speaker icon; muted or 0 → muted icon. */
export function speakerIcon(volume: number, muted: boolean): string {
    if (muted || volume === 0) return icons.audio.muted
    if (volume < 0.33) return icons.audio.low
    if (volume < 0.66) return icons.audio.medium
    return icons.audio.high
}

/** Mic mute → microphone icon. */
export function micIcon(_volume: number, muted: boolean): string {
    return muted ? icons.audio.micMuted : icons.audio.mic
}

/** Wi-Fi signal strength (0–100) → signal icon. */
export function signalIcon(strength: number): string {
    if (strength > 80) return icons.network.wifi
    if (strength > 60) return icons.network.wifiGood
    if (strength > 40) return icons.network.wifiOk
    if (strength > 20) return icons.network.wifiWeak
    return icons.network.wifiNone
}
