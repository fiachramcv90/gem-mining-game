# Dig-feel prototype — wayfinder ticket 0004

> **THROWAWAY grey-box prototype.** Its only job is to let Fiachra *feel* the
> digging on a touchscreen and react. Grey boxes, one static screen, no real
> mine, no art, no economy. When 0004 resolves, the chosen scheme folds into the
> real game and this folder is deleted.

## The feel question it answers

Three sub-questions, and the prototype makes all the options switchable **live**
(on-screen buttons) so they can be compared back-to-back on one build:

| Axis | Options (cycle with the top buttons) |
| --- | --- |
| **Control scheme** | Tap-adjacent-tile · Drag-direction · Virtual stick |
| **Movement physics** | Floaty (jetpack-in-dirt) · Grounded (drive + jetpack-to-climb) |
| **Dig timing** | Hold-drill (time ∝ hardness) · Instant |

Both movement modes obey ticket 0003: **ascent is self-powered and costs fuel**
— you fly *up* under your own thrust and the fuel bar drains while you do, so
"do I have enough to get home?" is felt even in the grey box.

## How to feel it

- **On iPhone (the point):** open the GitHub Pages URL the CI publishes (single-
  threaded WebGL2 export per ticket 0002 — no special headers, works in mobile
  Safari). Tap the screen once to start (unlocks audio/canvas), then dig.
- **On desktop (dev):** arrow keys also drive the digger in every scheme, and a
  mouse click acts as a touch (emulate-touch-from-mouse is on).
- **Locally in the editor:** open `prototype/project.godot` in Godot 4.3+ and hit
  play. No import/build step.

Harder rock is drawn darker; the little cyan squares are "gems" (just coloured
dig targets here — gem *values* are ticket 0006, out of scope for 0004). "Runs
lost" ticks up when you let the fuel hit zero before climbing back to the sky.

## What to react to (feed this back and I'll iterate)

1. Which **control scheme** feels most natural under one thumb?
2. Does **hold-drill** (hardness = resistance you feel) beat **instant**, or is
   the wait annoying?
3. **Floaty vs grounded** — which movement makes descending *and* climbing home
   feel good, given ascent burns fuel?
4. Anything that feels wrong (too slippery, too sticky, digs the wrong cell…).

## Files

- `project.godot` — Godot 4.3, Compatibility/WebGL2 renderer, portrait, touch
  emulation on.
- `scripts/DigGrid.gd` — the grey-box mine (a code array, drawn with `_draw()`).
- `scripts/Player.gd` — the digger: input → intent, movement, AABB-vs-grid
  collision, hardness-scaled drilling, round-trip fuel.
- `scripts/Main.gd` — builds the scene + the on-screen control panel (HUD).
- `export_presets.cfg` — the single-threaded **Web** export preset.
- `../.github/workflows/deploy-prototype.yml` — CI: export + deploy to Pages.

## Godot learning notes captured while building this

For a web/TypeScript dev meeting Godot (continues the 0001 learning-path asset):

- **Everything is built in code here on purpose.** Rather than author `.tscn`
  scenes and a `TileSet` in the editor (fiddly without a GUI, and this is
  throwaway), `Main.gd` `new()`s its children in `_ready()`. In the *real* game
  you'd build scenes in the editor; for a prototype, code-only is faster.
- **`_draw()` is immediate-mode canvas drawing** (like a `<canvas>` 2D context),
  but you don't call it — you call `queue_redraw()` and Godot calls `_draw()`.
  The grey mine and the digger are just `draw_rect`/`draw_arc` calls.
- **Constants are reachable through an instance** (`grid.CELL`) — handy, no need
  for the class to be global.
- **`class_name`** promotes a script to a project-global type, so `Main` can do
  `DigGrid.new()` / `DiggerPlayer.Scheme.TAP` without preloading paths.
- **Custom collision by hand** is easy for a grid: per-axis, move then push the
  AABB out of any solid cell it overlaps. The real game gets this *for free* from
  `TileMapLayer` + a `CharacterBody2D` (ticket 0001) — worth knowing the manual
  version to understand what the engine is doing.
- **Input:** `emulate_touch_from_mouse` lets the whole touch path be developed
  with a mouse; real touches arrive as the same `InputEventScreenTouch`. GUI
  (`Control`) nodes eat input first, so set the HUD containers to
  `MOUSE_FILTER_IGNORE` and only the buttons to `STOP`, or the panel swallows
  every gameplay tap.
- **Web export gotcha:** keep `variant/thread_support=false` (single-threaded) so
  no COOP/COEP headers are needed — GitHub Pages can't set them, and mobile
  Safari is happier (ticket 0002).
