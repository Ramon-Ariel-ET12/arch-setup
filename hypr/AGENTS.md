# AGENTS.md — dotfiles-hypr

Hyprland configuration written entirely in **Lua** using the native Lua config API
(Hyprland ≥ 0.55 replaced hyprlang with Lua; global `hl` object). This repo is
symlinked: `~/.config/hypr -> ~/Projects/dotfiles-hypr`.

## Environment

- Arch Linux, Hyprland **0.56.x**, single monitor HDMI-A-1 @ 1920x1080@60, scale 1, no VRR.
- GPU: AMD Cezanne (Vega iGPU).
- Live session is usually accessible from agent shells (`WAYLAND_DISPLAY`, `HYPRLAND_INSTANCE_SIGNATURE` set) — `hyprctl` works directly.

## Structure (flat, load order matters)

```
hyprland.lua            entry point — requires modules in order:
modules/constants.lua   defines _G.Hy (mod/terminal/file_manager) and _G.env globals — MUST load first
modules/env.lua         environment variables (Qt/GTK/cursors/session + dotnet PATH)
modules/monitors.lua    monitor = HDMI-A-1,1920x1080@60,0x0,1
modules/general.lua     gaps/borders/colors/decoration/render/animations/beziers/layouts
modules/input.lua       kb layout us+altgr-intl, follow_mouse 1, gestures, epic-mouse-v1 device
modules/autostart.lua   hl.on("hyprland.start") handler: systemd/dbus env, polkit,
                        gnome-keyring, hypridle, hyprpm reload, cclipd (MIME flags),
                        gsettings dark, kitty, brave, ags run
modules/binds.lua       binds (fullscreen excluded) incl. SUPER+L → loginctl lock-session
                        (hypridle's lock_cmd owns the pause+lock; registers as __lua dispatcher)
modules/fullscreen.lua  fullscreen policy: SUPER+F fake toggle, SUPER+SHIFT+F true toggle (whitelisted
                        against the interceptor), client fullscreen requests downgraded to fake
                        via hl.on("window.fullscreen"); Satty (screenshot) exempted by initial_class
                        whitelist — stable from creation, unlike w.class inside the fullscreen event
modules/rules.lua       window/workspace/layer rules (suppress maximize events global, xwayland drag fix,
                        hyprland-run float, game pointer confine, one popin rule for all AGS transient surfaces)
generated/color.lua     DO NOT HAND-EDIT — Matugen template output (Material You palette from wallpaper)
```

Deleted on purpose (do not resurrect without reason): `appearance/ binds/ config/
layouts/ rules/ services/ utils/ script/` dirs, `modules/plugins.lua`
(dynamic-cursors was never installed; `hyprpm reload` line removed too).

## Companion repos (also symlinked)

- `~/Projects/dotfiles-matugen -> ~/.config/matugen`: `config.toml` (3 templates:
  `hyprland.lua`→`~/.config/hypr/generated/color.lua`, `ags.scss`→AGS `_matugen.scss`,
  `hyprlock.conf`→`~/.config/hypr/hyprlock.conf`) + `templates/`. Paths use `~`.
- `~/Projects/dotfiles-ags -> ~/.config/ags`: AGS v3 shell; consumes `_matugen.scss`.
- Regenerate all theme outputs: `matugen image <wallpaper.png>`

## Theming pipeline (single source of truth)

The whole wallpaper pipeline lives in the AGS shell (`ags/services/wallpaper.ts`) —
Hyprland only ever launches AGS. Slideshow tick → `awww img` (grow transition) →
`matugen image` regenerates color.lua + AGS scss + hyprlock.conf → md5-compares
`generated/color.lua`; if changed it fires `hyprctl reload` in background so
Hyprland borders track the wallpaper live → in-process SCSS reload. The detached
`awww-daemon` is spawned by AGS (`ensureDaemon()`, pgrep-guarded, self-heals on
every apply) and outlives the shell so stopping it never blanks the desktop.
Wallpapers live in `~/Pictures/Wallpapers/`.

`awww` is a REAL package (`/usr/bin/awww`, swww fork) — not a typo of swww.
It failed silently for a long time simply because it wasn't installed.

## Performance/design decisions (recorded 2025-08, do not regress casually)

- blur: size 6, passes 2, vibrancy 0.10, noise 0.01 (noise stays — anti-banding).
- `inactive_opacity = 1.0` — deliberate: avoids constant alpha compositing.
- shadow range 10, power 3; rounding 8; border 2px Matugen gradient (primary→primary+"ee" 45°).
- `render.direct_scanout = 1` — known AMD/Vulkan fullscreen black-screen bug upstream;
  if a Vulkan game black-screens set it back to 0.
- Tearing disabled by owner decision (`general.allow_tearing = false`).
- Animations: `speed` = DURATION IN SECONDS (higher = slower). All leaves ≤1s
  (global 1.0 almostLinear, windowsIn/out 0.55/0.45 quick popin 85%,
  workspacesIn/out 0.8/0.7 slidefade 15%, specialWorkspace 0.7 slidevert).
  Curves kept: easeOutQuint, almostLinear, quick.

## Hyprland 0.56 API gotchas

- `misc.vfr` option REMOVED (VFR always-on). Don't re-add.
- Animation "speed" is duration in seconds.
- `valign` accepts only `top|center|bottom` — `middle` makes widgets render broken/invisible
  while still holding focus (this broke the hyprlock input field once).
- `hyprctl dispatch` evaluates as Lua shorthand now: use
  `hyprctl dispatch 'hl.dsp.exec_cmd("cmd")'` or `hl.dsp.window.close()` style.
- Bind args registered from Lua show up as `dispatcher: __lua` in `hyprctl binds`.
- `window.destroy` passes an already-EXPIRED window: `w.address` is nil. Guard with
  `local addr = w ~= nil and w.address` — `t[w.address] = nil` raises Lua "table index is nil",
  and `CConfigManager::addError` surfaces it as a "Runtime error in lua" toast WITHOUT logging.

## Validation checklist (run after any edit)

```bash
# syntax
for f in hyprland.lua modules/*.lua; do luac -p "$f"; done

# runtime smoke test with mocked hl (no compositor interaction):
lua5.4 /tmp/opencode/harness.lua   # recreate if wiped (snippet below)

# apply + verify live values
hyprctl reload
hyprctl getoption decoration:blur:passes      # expect 2
hyprctl getoption general:col.active_border   # Matugen hex
hyprctl animations | head -40
journalctl --user --since "-2 min" | grep -iE "error"
```

Mock harness snippet (expects callable-and-indexable `hl`; `hl.on` captures handlers;
hyprsplit must be stubbed — it is a compositor plugin with no Lua module on disk):

```lua
package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path
local n, handlers = 0, {}
local mt
-- NOTE: `local mt = {...}` as ONE statement breaks __call on 5.4 — keep it split.
mt = { __index = function() return setmetatable({}, mt) end,
       __call = function() n = n + 1; return true end }
_G.hl = setmetatable({}, mt)
_G.hl.on = function(evt, fn) handlers[evt] = fn end
package.preload["hyprsplit"] = function() return setmetatable({}, mt) end
require("hyprland")
print("registrations:", n)
handlers["hyprland.start"]()
```

## Conventions

- Never commit unless the owner explicitly asks (everything currently uncommitted).
- Keep modules flat and stateless; only `constants.lua` may define globals.
- Preserve registration order semantics when editing `hyprland.lua` requires.
- Spanish comments in original files are the owner's — keep them when editing nearby code.
