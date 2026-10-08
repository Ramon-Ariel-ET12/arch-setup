# AGENTS.md — dotfiles-ags

Guidelines for AI coding agents working on this repository.

This project is a Hyprland desktop shell built with **AGS 3.x, Astal, Gnim, GJS, and GTK4**.

## Core Rules

* **This is not React.** Gnim provides JSX, but React APIs, patterns, lifecycle assumptions, browser APIs, and DOM APIs do not apply.
* **Read the existing code before changing it.** Repository code and local framework sources (`.deps/ags/`, `node_modules/gnim/`, `@girs/`) are the source of truth for implementation details.
* **Do not invent framework behavior.** When uncertain about an API, check the installed sources/types or the official documentation.
* Prefer the smallest change that solves the problem; prefer deletion over new abstraction. Do not add features.
* **No style-carrier components.** Reuse existing components or raw intrinsics and add a `class` at the call site when styling is needed; leave default styling until a class is actually specified. Components carry behavior/structure, never exist just to apply styles.
* Do not duplicate configuration values; put tunables in `options.ts`.
* **Warn/error reporting:** use `logWarn`/`logError` from `lib/notify.ts` instead of `console.warn`/`console.error` — they log to `logs.log` *and* launch a notification toast; plain console calls bypass notifications. `app.tsx` additionally installs `installErrorReporting()` (the process GLib log writer), which captures GTK/Astal GLib warnings, uncaught JS errors, and echoes every `console.*` call — the writer must NEVER call `console.*` or throw for a captured message, because console output re-enters the writer itself (instant recursion).
* Do not hand-edit generated files (e.g. the matugen palette, `@girs/`, `dist/`).

## Architecture

```text
app.tsx       entry point: popups → wallpaper manager → bars; requestHandler for `ags request reload-theme`
options.ts    single source of truth for every tunable (paths, priorities, popup sizing, commands)
lib/          pure utilities + tiny persistence helpers
services/     Astal singletons, subprocess IO, persisted state, and the reactive state derived from them
components/   reusable behavior/structure UI: Popup (window + card chrome + header/footer), Popover, Card, ScrollArea, SearchEntry, Tabs, AppIcon, Button, Collapsible
widgets/      features: bar modules + floating popup cards
style/        SCSS (7-1-ish); matugen palette flows in via style/abstracts/_matugen.scss (GENERATED)
data/         user state that must survive cache wipes: monitors.json, prefs.json
cache/        regenerable runtime caches: frecency.json, wallpaper.json (safe to wipe)
tools/        thin wrappers around external binaries (see "External tools")
dist/         compiled style.css (generated)
```

Dependency direction (no exceptions):

```text
widgets → components → services → lib → options
```

* `gi://` imports live in `services/` **except**: enum/type needs in widgets (e.g. `Mpris.PlaybackStatus`), widget registration in `components/intrinsics.ts`, and `Gdk/Gtk/GLib/Pango` widget plumbing.
* JSX intrinsics beyond AGS's built-ins are registered in `components/intrinsics.ts` by mutating gnim's shared `intrinsicElements` record (`Object.assign`), with matching `JSX.IntrinsicElements` declarations. That module is imported first in `app.tsx` — keep the ordering.

### What earns a service

A service wraps one external system and adds **filtering, config, derived state, or actions** — nothing else. Bare re-exports of an Astal singleton are forbidden (single-consumer singletons live directly in their widget — e.g. battery/network in their bar modules); widgets import the singleton directly instead (`Media`, `Tray`, and the notification widgets do exactly that). Current services: `hyprland`, `monitors` (persistence + geometry mapping + reactive state), `popups` (window-visibility registry), `wallpaper` (awww/matugen pipeline + slideshow), `audio`, `bluetooth`, `apps`, `clipboard`, `emoji`, `symbols`, `hyprbinds` (cached binds), `theme` (SCSS compile), `config` (dnd pref).

Feature-scoped `actions.ts` state modules under `widgets/<feature>/` are deliberate: single-consumer reactive state stays with its feature.

## Styling (matugen + Hyprland are the only sources)

* **AGS creates no style.** Palette fills come from `style/abstracts/_matugen.scss` (GENERATED, never hand-edit); outer chrome — radii, border width + border colors, gaps, shadow, surface opacity — comes from `style/abstracts/_hyprland.scss` (GENERATED via `services/hyprland.ts :: writeHyprlandScss` from `j/getoption`), both re-exported through `style/abstracts/_variables.scss`. Never add hex/rgb colors, `1px` borders, or magic-number spacing anywhere else. Rounding power, backdrop blur and per-leaf animation speeds have no GTK CSS equivalent and stay compositor-side by design.
* **No per-widget SCSS.** There is no `style/widgets/` directory. All styling lives in `style/abstracts/` (tokens + `mixins.scss` `card-surface`/`row-button`/`row-states`/`overlay-on`), `style/base/` (reset, typography, `utilities.scss` spacing scale + `.radius-*`/`.min-w-popup`/`.border-b`), and `style/components/` (`_card.scss` single surface incl. `.bar`/`.bar-side` caps + native `calendar`, `_button.scss` incl. `.row-selected`/`.workspace-active`, `_list.scss` incl. `.row`/`.list`/`.separator`/`.scroll-area`, `_slider.scss`, `_scrollbar.scss` (global default for every scrollbar), `_levelbar.scss`, `_tabs.scss`, `_search.scss`, `_popover.scss`).
* **Reuse at the call site:** surfaces = `.card` (or `<Card>`/`<Popup>`/`<Popover>`); rows = `.row` (+ `row-selected` for cursor/applied ring); buttons = `<Button variant="flat|primary|danger">` (never raw `btn btn-flat`); collapsible bodies carry their own `pl-4 py-1 pr-2` in `components/Collapsible.tsx`; fixed sizes via `widthRequest`/`heightRequest` (bind key col 120, media art 64, clipboard cell `options.clipboard.cell`), never new CSS classes.
* **Bar:** floating strip (`TOP|LEFT|RIGHT`, `EXCLUSIVE`, `options.bar.height` = `$bar-height` = 40) with outer `margin_top/left/right` bound to live `hyprGapsOut` and inner `spacing` bound to live `hyprGapsIn` — same grid as tiled windows. TOP-anchored `Popup`s offset via live `popupTopOffset` (`bar height + 2 × gaps_out`: top margin + strip + gap below); `options.popups.topOffsetFallback` (76) is pre-sync fallback only.

## Reactivity (Gnim + Astal)

* Current primitives: `createBinding`, `createComputed`, `createState`, `createEffect` (gnim), `createPoll` (**from `ags/time`**, not gnim), `createConnection`, `For`, `With`.
* Accessors: call them inside tracked scopes, pass them as props, or `.peek()` for untracked reads. Never `.get()`.
* **The big gotcha — unwrapped accessor reads in eager contexts silently freeze.** Function components run once, untracked. `label={relative()}` renders once and never updates; `label={relative}` (accessor prop) stays live. The same applies to any `accessor()` read inside a component body that is not inside `With`/`For`/`createComputed`/`createEffect`.
* `For`/`With` run their children inside effects: reads inside a row/child are tracked, but any tracked change **re-runs the whole `For`/`With`** (remove + re-append). In list rows prefer mapped accessors (`busy((b) => !b)`, `createComputed` labels) over unwrapped reads so single-item updates don't rebuild every row. Re-appending **remaps every row widget**, so per-row `map`/lifecycle hooks fire on any list change (e.g. windowed-list growth mid-scroll) — keep such side effects on static ancestors, not rows. Event handlers (`onClicked`) are untracked — reading `accessor()` there is fine.
* **TS quirk:** don't inline a generic call (`createBinding(...)`) into a JSX prop that needs inference (e.g. `For`'s `each`); the element type collapses to `unknown`. Assign it to a `const` first.
* `createBinding(obj, "prop_name")` kebabifies for the `notify::` signal, so snake_case GIR properties work.
* `With value={accessor}` re-creates its subtree when the value changes — the standard way to bind over *reactive singletons* (e.g. `defaultSpeaker`) whose identity changes at runtime.
* `lib/time.ts` exposes a shared, always-on 30s `now` wall-clock for relative-time labels. Do not stop it; one timer for the whole shell.
* Type event-handler `self` explicitly (`$={(self: Gtk.Button) => ...}`).
* Use only widgets and properties supported by the installed GTK4/AGS/Gnim versions.

## Astal / GTK4 usage

* Singletons via `get_default()`; property bindings via `createBinding`; signals only where no binding exists (gestures, `notify::visible` hooks, `activate-link`).
* `ags/gtk4/app`'s `monitors` is a registered, reactive property (`createBinding(app, "monitors")`) — used by `Bars()` for monitor hotplug.
* Popups are `Astal.Window`s registered with a unique `name` (`ags toggle <name>`); window visibility is the single source of truth (`services/popups.ts`). `components/Popup.tsx` is the one popup component (window + card chrome + header/footer slots); it never wraps another component — features pass `title`, `showCloseButton`, `footer`, and a `class` directly.
* Icon names live in the `lib/icons.ts` registry (plus its `speakerIcon`/`micIcon`/`signalIcon` ladders) — never hardcode theme icon strings or emoji glyphs in widgets.

## Non-obvious patterns

* **Popup sizing (`components/Popup.tsx`):** `widthRequest`/`heightRequest` are only minimums; on every `notify::visible` the code re-resolves the gdk monitor and also resets `defaultWidth`/`defaultHeight`, because GTK re-applies the default size on every map — that is what actually reshapes the layer surface.
* **Clipboard-at-mouse (`widgets/clipboard/index.tsx`):** a fullscreen transparent window owns input; the card is placed via `Gtk.Fixed.move` at monitor-local coordinates from AstalHyprland IPC (`j/cursorpos` via `hyprMessage`, fallback `hyprctl -j cursorpos`). `hyprMessage` must use the callback + `message_finish` form via `callGirAsync` — the 1-arg form throws and the `(msg, null)` form is fire-and-forget `void`. Position is computed once per open; GDK seat pointer APIs are not used (unreliable on Wayland).
* **Glyph insert (`widgets/clipboard/actions.ts`):** emoji/symbols are typed via `wtype` into the pre-picker focused client — capture the target with `getInsertTarget()` *before* closing, then `focusInsertTarget` + `typeDelayMs` grace + type; the glyph is always copied to the clipboard first as fallback. Recents are per-kind MRUs (`options.clipboard.recentsLimit`) persisted in `clipboard-recents.json` (XDG cache, regenerable).
* **matugen flow (`services/wallpaper/slideshow.ts`):** paint via `awww img` → `matugen image <path>` regenerates templates → md5 of `~/.config/hypr/generated/color.lua` is only a *change sentinel* → reload via `hypr.message_async("reload")` (Astal IPC, fallback `hyprctl reload`) only when the palette changed → explicit `syncHyprlandOptions()` + `compileAndReload()` (never rely on the `config-reloaded` side-effect: sync only compiles when gaps/border/rounding changed, so a pure color change would stay stale). Applies are serialized through a promise chain (`applyTail`); `lastApplied` is set only on success so failures stay retryable. Same-image applies short-circuit within a session.
* **Binds cache (`services/hyprbinds.ts`):** the parsed `hyprctl -j binds` snapshot is cached in memory and invalidated by AstalHyprland's `config-reloaded` signal.
* **Hyprland options bridge (`services/hyprland.ts`):** `initHyprlandSync()` (called once from `app.tsx` before the first compile) runs one `syncHyprlandOptions()` pass then listens on `config-reloaded` with a ~400ms trailing debounce. Options are read via sequential `j/getoption` (one in flight, one retry per option — never `Promise.all`, which bursts 17 parallel connects and trips `hyprland.vala: Could not connect` while Hyprland restarts its socket). Gradient replies (`col.active_border`, `col.inactive_border`, `shadow:color`) carry no int/float/str — parse the first `AARRGGBB` token via `gradientFirstToCss`, not `parseOption` numerics. Exposes `hyprGapsOut` etc. and the derived `popupTopOffset` (`bar height + 2 × gaps_out`). `setHyprlandOption` writes via `keyword` and lets the signal round-trip update the accessor — Hyprland stays authoritative. `writeHyprlandScss` skips the write when content is unchanged.
* **Texture caches:** clipboard thumbnails by cclip id (`services/clipboard.ts`, limit 100) and wallpaper grid thumbnails by path (`lib/image.ts`, scaled load, limit 200) — never re-decode bytes per render.
* **Tray popovers:** one `Gtk.PopoverMenu` per tray button, reused across right-clicks and unparented on destroy.
* **Windowed rendering (`widgets/clipboard/actions.ts`):** the clipboard history list and the emoji/symbols grids render a leading slice (`gridInitial`) grown by `gridBatch` on demand — scroll near the bottom (`watchGridScroll` in `index.tsx`), keyboard cursor movement (`ensureVisible`), or query/tab changes — never hundreds/thousands of rows at once.
* **Animations (`components/Reveal.tsx`):** every in-app appear/collapse animation goes through the shared `Reveal` wrapper — variants live in its `ANIM` table, duration in `options.anim.duration`; never inline `Gtk.Revealer` configs or CSS transitions. Whole-window animation is compositor-side: per-namespace `hl.layer_rule` animation entries in `hypr/modules/rules.lua`. GTK cannot animate a layer-surface unmap, so hiding a window is instant by design (toasts collapse via `Reveal` *before* dismissal instead).
* **Window keymaps (`lib/keyboard.ts`):** two key controllers — Enter/Escape run in the CAPTURE phase (a focused `Gtk.Entry` consumes Return for its own `activate` signal, hiding it from BUBBLE controllers), while arrows/Tab stay in BUBBLE so caret keys reach the focused entry.
* **Scroll-into-view (`lib/helpers/scroll.ts`):** `scrollRangeIntoView(widget, top, bottom)` is the shared ancestor-ScrolledWindow vadjustment clamp — callers compute their own pixel range (launcher rows, clipboard cursor cells/list pitch); never re-implement the clamp tail.
* **GIR async calls (`lib/helpers/gir.ts`):** `callGirAsync(start, finish)` promisifies non-promisified GIR `*_async`/`*_finish` pairs (bluetooth connect/disconnect, NM access-point activate) — don't hand-roll Promise wrappers for GIR methods.
* **Notification accessors (`widgets/notifications/notification.ts`):** `useNotification(n)` exposes the shared summary/body/appIcon/image/time bindings plus relative/absolute time labels — used by toasts, history cards and the detail popup; add new per-notification accessors there, not per-component.
* **DND / fullscreen:** `services/config.ts` persists the DND toggle; `widgets/notifications/Popups.tsx` hides the toast window while DND is on or while `focusedFullscreen` (`services/hyprland.ts`) is true — layer surfaces mapping over a captured fullscreen game cursor break pointer input (toasts still expire, so nothing bursts out when suppression ends).
* **Notifications from code (`lib/notify.ts`):** GJS `console` methods are read-only and non-configurable — monkey-patching console is impossible, hence the explicit helpers. Sending goes through `notify-send` (the shell itself is the notifd daemon and `Notifd` has no send API), so it round-trips back into the shell's own toast UI and works before `app.start()` (boot-time SCSS errors).
* **AstalBluetooth (`services/bluetooth.ts`):** `get_default()` returns the singleton and its `adapter` property is nullable; the library exposes **no daemon-presence state**, so "no `org.bluez`" and "`org.bluez` with no adapter" are indistinguishable through Astal (both give `adapter === null`). That is the only reason for the `Gio.bus_watch_name("org.bluez")` probe: `bluezAvailable` means *the name has an owner*, never "an adapter exists" — do not substitute `adapters.length > 0`. One implementation detail, **not** covered by the docs and to be re-checked on Astal upgrades (read from `lib/bluetooth/src/bluetooth.vala` of the installed `libastal-bluetooth-git`): only `adapters` is ever notified — `adapter-added`/`adapter-removed` call `notify_property("adapters")`, and nothing notifies `adapter`, whose getter is `adapters.nth_data(0)`. So bind `createBinding(bt, "adapters")(l => l[0] ?? null)`, **never** `createBinding(bt, "adapter")`, which would subscribe to a never-emitted signal and freeze. Same trap one level down: only `device_added`/`device_removed` notify `devices` — connect/disconnect and pair/trust flips touch no list membership, so derived device state must key off the `bluetoothRevision` counter (singleton `is-connected`/`is-powered` aggregates + per-device `connected`/`paired`/`trusted`/`alias` notifies), never just `notify::devices`, or the bar goes stale while a freshly opened popover reads current truth.

## Cache / data strategy

* `data/` = user state (`monitors.json` main monitor, `prefs.json` dnd). `cache/` = regenerable (`frecency.json` with a 200-entry prune, `wallpaper.json` current image). Both live under `~/.config/ags/` and are gitignored.
* All JSON IO goes through `lib/json-state.ts` (`loadJson`/`saveJson`, parent dirs auto-created).
* Never query a system source repeatedly for data that changes only on events: monitors come from bindings (no polling), binds from the event-invalidated cache, textures from the memory caches. The one intentional poll: `Clock` (1s `createPoll`) for the minute display.

## External tools (intentionally kept)

| Tool | Used for |
|---|---|
| `awww` / `awww-daemon` | wallpaper painting (detached daemon outlives the shell) |
| `matugen` | palette generation from the wallpaper (writes SCSS + hypr templates) |
| `hyprctl` | cursor position, binds dump, reload |
| `cclip` | clipboard history daemon (owns the history store) |
| `sass` | SCSS compile (CLI in tools, in-process via `execAsync` in `services/theme`) |
| `wl-copy` | copying emoji/symbols |
| `bun`, `ags`, `watchexec`, `tsgo` | build/dev/typecheck tooling |

`tools/setup.sh` vendors `/usr/share/ags/js` into `.deps/ags`, links it as `node_modules/ags`, and regenerates `@girs`. Re-run after system AGS upgrades. No wallpaper/matugen/monitor shell scripts exist — those pipelines are pure GJS on purpose.

## Commands

```sh
bun install
./tools/setup.sh      # vendor AGS runtime + types (after system upgrades)
bun run typecheck     # tsc + tsgo (TS7); REQUIRED before considering a change done
bun run build         # typecheck + sass compile
bun run dev           # watchexec loop restarting ags run (writes logs.log)
ags run
ags toggle <name>     # launcher, clipboard, wallpaper, monitors,
                      # notifcenter, notifdetail, binds, calendar
ags request reload-theme
```

Imports use the `@/` alias (see `tsconfig.json` `paths`); same-directory imports stay relative. Development/runtime output is written to `logs.log`.

## Validation

1. `bun run typecheck` must pass (both tsc 5.x and tsgo).
2. Exercise the affected behavior when practical; `ags run`/`bun run dev`.
3. Inspect `logs.log` for errors, criticals, or unexpected warnings.
4. For UI/API changes, verify the relevant GTK4, Astal, or Gnim API rather than relying on memory.

## Known limitations / TODOs

* **Wallpaper history is not tracked** — only the current image (`cache/wallpaper.json`). Adding history would be a new feature.
* **Popover sizes snapshot the monitor geometry at render time** (`services/monitors.ts` `popoverSize`); a monitor hotplug does not resize already-created bar popovers until restart. Popup cards re-size on every open.
* Bars use `bar-<index>` window names; hotplug re-creation can reuse a name after its bar was destroyed.
* `widgets/launcher/actions.ts` and `widgets/clipboard/actions.ts` intentionally mirror each other's query/cursor state machines (kept separate: the UXes diverge in details); same for the Bluetooth/Network one-open accordion pattern.
* GIF wallpapers paint only — matugen from the first frame is unimplemented.
* `node_modules/` contains pnpm residue; bun is the canonical package manager.
* SCSS classes used by TSX but unstyled (harmless): `.notification-detail-header`.

## Documentation

* AGS — https://aylur.github.io/ags/ · repo — https://github.com/Aylur/ags
* Astal — https://aylur.github.io/astal/ · site — https://astal.dev/ · repo — https://github.com/Aylur/Astal · references — https://aylur.github.io/astal/guide/libraries/references
* Gnim — https://aylur.github.io/gnim/ · Gnim JSX — https://aylur.github.io/gnim/jsx
* GTK4 — https://docs.gtk.org/gtk4/ · drawing model — https://docs.gtk.org/gtk4/drawing-model.html
* GDK4 — https://docs.gtk.org/gdk4/ · GdkTexture — https://docs.gtk.org/gdk4/class.Texture.html
* GJS — https://gjs.guide/ · memory management — https://gjs.guide/guides/gjs/memory-management.html
* TypeScript native compiler (tsgo) — https://github.com/microsoft/typescript-go
* Matugen — https://github.com/InioX/matugen
* cclip — https://github.com/heather7283/cclip

Local sources (prefer these for installed behavior): `.deps/ags/`, `node_modules/gnim/`, `@girs/`.

## Keep This File Useful

Update AGENTS.md when a significant **general rule, architectural constraint, command, tool, or hard-won gotcha** is discovered. Do not turn it into a description of every feature.

---

**Remember:** Gnim + Astal + GJS + GTK4 is not React. Read the code, use the installed APIs, consult the official docs, and do not invent framework behavior.
