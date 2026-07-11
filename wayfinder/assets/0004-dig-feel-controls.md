# Dig feel & touch controls — the decision

> Decision asset for ticket **0004 — Dig feel & touch controls prototype**.
> Audience: Fiachra — solo dev, evenings/weekends; new to Godot, strong web/TS.
> This records *what the dig feels like and how it's controlled*, validated by
> thumb on a real iPhone via a grey-box prototype. It does **not** decide
> worldgen (0005), economy (0006), hazards (0007), or art/audio (0008).

## The decision

**Virtual stick + floaty movement + hold-to-drill**, chosen by feel-testing a
grey-box prototype on-device (not from code). All three axes were made
switchable live so they could be compared thumb-to-thumb on one build.

| Axis | Chosen | Discarded | Why |
| --- | --- | --- | --- |
| **Control scheme** | **Virtual stick** (dynamic, trailing) | Tap-adjacent-tile; Drag-direction | The stick gives continuous, analogue thrust in any direction — right for a free-flying digger. Tap-adjacent felt stop-start and turned digging into a series of discrete decisions rather than a flow. Drag-direction was close to the stick but with no persistent visual anchor it was easy to lose track of the neutral point. |
| **Movement physics** | **Floaty** (jetpack-in-dirt) | Grounded (drive + jetpack-to-climb) | Floaty makes descent *and* the self-powered climb home (0003) feel like one continuous flying verb. Grounded split the feel in two — drive on the floor, then a separate jetpack mode to ascend — which read as two games stitched together. |
| **Dig timing** | **Hold-to-drill**, time ∝ rock hardness | Instant | Feeling harder rock as *resistance you push through* is the core tactile pleasure of a digger; a visible progress ring sells it. Instant digging made the world feel like wet paper and removed the only moment-to-moment texture the raw movement has. |

## The virtual stick, specifically (this is where the feel lived)

The scheme choice was easy; making the stick *feel good* took one on-device
iteration. What matters:

- **Dynamic (floating) origin** — the stick appears wherever the thumb first
  touches, not at a fixed screen spot. Essential on a phone where you can't look
  down at a fixed pad.
- **Trailing base** — when the thumb pulls past the ring, the base follows it so
  it stays under the thumb. This makes **reversing thrust direction instant**
  instead of having to unwind the whole drag. Before this change the stick was
  "the best of what's on show but not right"; after it, it crossed into good.
  This is the single most important detail and must survive into the real game.
- **Dead zone (~16%, rescaled)** — kills drift from tiny thumb movement and eases
  thrust in from zero rather than snapping on.
- **Throw radius ~64px** — a comfortable full-thrust reach for a thumb.

> Verdict on intuitiveness (feeds the onboarding fog): the scheme was graspable
> immediately, but the *quality* of the stick was not free — a naïve fixed-origin
> stick felt bad. Onboarding should assume the player needs ~no instruction to
> understand "push to fly, hold into rock to dig", but the **stick implementation
> itself carries the feel** and is not a place to cut corners.

## Movement / dig model that was validated

- **Floaty:** thrust accelerates in the stick direction; light gravity so you
  must actively hold to hover/ascend; damping gives a slight glide. Omnidirectional.
- **Self-powered ascent costs fuel** (0003): the fuel bar drains while thrusting
  and refills only at the surface; running dry mid-climb = "run lost". The
  round-trip-budget tension was legible even in the grey box.
- **Hold-to-drill:** the cell the stick presses into drills over
  `time = hardness × ~0.34s` (hardness 1–4 ⇒ ~0.34–1.36s), with a progress ring.
  Collision holds the digger against undug rock until the cell breaks, then it
  slides in — so "drive into dirt and it gives way" needs no separate dig button.

## Consistency with closed decisions

- **0001** — player is a directly-controlled body (`CharacterBody2D` in the real
  game; the prototype hand-rolls AABB-vs-grid collision to stay cheap); dig =
  clearing a cell (`TileMapLayer.erase_cell()` in the real game); hardness is
  per-cell data. Touch-first input, mouse/keyboard fall out for web.
- **0002** — shipped as the **single-threaded** WebGL2 web export
  (`variant/thread_support=false`), which is exactly what let it be felt in
  iPhone Safari with no special headers.
- **0003** — floaty movement is deliberately built so ascent is self-powered and
  burns the shared fuel budget; no free return.

## What this clears / hands off

- **0005 (worldgen)** — inherits a **validated dig-time-per-hardness feel
  constant** (~0.34 s/hardness as the starting point) and the fact that *hardness
  is the primary texture of the dig*. Strata should be designed as a hardness
  curve by depth that keeps the per-tile drill time in a satisfying band (roughly
  0.3–1.5 s at the relevant upgrade level); that band, not raw depth, is the real
  knob. Gem placement should sit *inside* harder pockets so the resistance and the
  reward coincide.
- **Tutorial & onboarding fog** — sharpened: controls are near-instantly
  intuitive, so onboarding can be minimal, **but** the dynamic/trailing virtual
  stick and the round-trip fuel decision are the two things worth surfacing early.
  Still fog (not yet a ticket) — it firms up once a vertical slice exists.

## The prototype (throwaway, kept in-repo as this asset's artifact)

- Code: [`prototype/`](../../prototype/) — Godot 4.3, grey boxes, one screen.
  `scripts/Player.gd` holds the stick/floaty/drill core; `scripts/DigGrid.gd` the
  grey-box mine; `scripts/Main.gd` the live-switch HUD.
- Live build (single-threaded web export, auto-deployed from `main`):
  **https://fiachramcv90.github.io/gem-mining-game/**
- Pipeline: [`.github/workflows/deploy-prototype.yml`](../../.github/workflows/deploy-prototype.yml)
  — `chickensoft-games/setup-godot` → web export → GitHub Pages. Built via
  PRs #4 (prototype + pipeline) and #5 (stick tuning).

## Godot learning notes (continuing the 0001 path)

- **On-device feel testing needs a pipeline, and it's worth building once.** Feel
  cannot be judged from code or desktop — a CI job that web-exports (single-
  threaded, per 0002) and publishes to GitHub Pages gave a URL to open on the
  phone. Gotchas hit along the way: `setup-godot` needs `include-templates: true`;
  the `github-pages` environment only deploys from the default branch (so the
  workflow builds on any branch but deploys only from `main`).
- **Grey-box in code beats authoring scenes for a throwaway.** Building nodes in
  `_ready()` and drawing the mine with `_draw()` avoided all `.tscn`/`TileSet`
  authoring. The real game will use the editor + `TileMapLayer`.
- **GDScript static typing bites early:** an untyped `var grid` makes every
  `grid.method()` return `Variant`, so `:=` can't infer — type your node
  references (and `class_name` the scripts) from the start.
- **Touch:** `emulate_touch_from_mouse` lets the whole touch path be built with a
  mouse; real fingers arrive as the same `InputEventScreenTouch`. Cast the event
  before reading `.position`. Keep HUD `Control` containers `MOUSE_FILTER_IGNORE`
  so gameplay taps reach `_unhandled_input`.
