# Memory pitfalls — incident notes

 dated, specific things that bit us. General rules live in `AGENTS.md`
 ("Memory discipline"); this file records *what happened* so we don't
 repeat it.

## 2026-09: wallpaper picker hit ~2GB RSS

 Shell RSS grew to 1.5–2GB (`VmRSS`), ~1.3GB of it an anonymous `[heap]`
 mapping. Swung 2.1 → 1.7GB within a minute (heap churn, not a slow leak).

 Causes found together:

 1. **Carousel mounted every wallpaper full-res.** Each
    `Gtk.Picture.set_filename` on a 3840×2160 file keeps a ~33MB decoded
    copy. 9 wallpapers ≈ 300MB mounted, re-decoded on every step.
    Fix: `ThumbPage` renders `loadCoverTexture(path, 1600×1000)` (cached
    in `scaledCache`); only cursor ±1 pages mounted (`visiblePages`);
    full-res paint still goes through `awww` on commit.
    Gotcha hit along the way: named `Gtk.Stack` pages must be
    `<picture $type="named">` — `<image $type="named">` warns
    (`type overriden from named to named`) and renders tiny.
 2. **Preview queue serialized N paints.** `previewTail` chained one
    `awww img` subprocess per carousel step; fast stepping queued 20+
    paints with buffers. Fix: last-write-wins pump (`previewQueued` +
    `pumpPreview` in `services/wallpaper/slideshow.ts`); commit/revert
    drain via `previewSettled`.
 3. **Clipboard decoded thumbs full-res.** `decodeImageBytes` had no
    scale path; 32 image/png history rows decoded full then drawn at
    32px. Fix: `decodeImageBytes(bytes, maxDim)` via
    `new_from_stream_at_scale`, default 64; `getHistory(limit = 100)`
    caps 795 cclip rows.
 4. **AppIcon re-decoded per render.** `decodeImageFile` uncached,
    full-res, per toast/center/detail tick. Fix: `loadScaledTexture(path,
    pixelSize)` memoized.
 5. **Media art subscription leak.** `art.subscribe(update)` in `$`
    without cleanup retained a dead `Gtk.Image` per player switch.
    Fix: `self.connect("destroy", unsub)` + `peek()`/`p===last` guard.

 Incidental: measuring under `bun run dev` inflates RSS — `AGS_DEBUG=1`
 makes every `debugLog` build `new Error().stack`. Baseline with plain
 `ags run`.

 Result: idle ~280MB dev-mode, popup cycle peak ~455MB (was 1.5GB+),
 heap mapping ~117MB, `logs.log` clean, `typecheck: OK`.
