export { listWallpapers, isGif, paintArgs, ensureDaemon } from "@/lib/wallpaper-backend"
export type { WallpaperEntry } from "@/lib/wallpaper-backend"
export { wallpaperEntries, currentWallpaper, isBusy, refresh, syncFromDaemon } from "./store"
import { createSlideshow } from "./slideshow"
import { refresh } from "./store"

const slideshow = createSlideshow(refresh)

export const start = slideshow.start
export const apply = slideshow.apply
export const preview = slideshow.preview
export const beginSession = slideshow.beginSession
export const commit = slideshow.commit
export const revert = slideshow.revert
