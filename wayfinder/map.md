---
label: wayfinder:map
title: Gem Miner — design & tech spec
created: 2026-07-10
---

# Gem Miner — design & tech spec (Wayfinder Map)

> **Tracker conventions (local markdown fallback):** each ticket is a file in
> `tickets/`, named `NNNN-slug.md`. Frontmatter carries `type`, `status`
> (`open`/`closed`), `assignee`, and `blocked-by` (list of ticket ids).
> A ticket is **claimed** by setting `assignee` before work starts.
> The **frontier** = open tickets with an empty/void `blocked-by` (all blockers
> closed) and no assignee. Resolutions are appended to the ticket under
> `## Resolution`, the ticket closed, and a one-line gist added to
> *Decisions so far* below. One ticket per session.

## Destination

A complete design + technical spec for a Motherload-style gem-digging game,
built in **Godot 4** with a **web build first** (stores deferred), sharp enough
that Fiachra can open Godot and start building with no open decisions.

## Notes

- Solo dev, evenings/weekends, no deadline — bias every decision toward small
  scope and steady momentum.
- Godot is a *new* engine for Fiachra (strong TypeScript/web background);
  research tickets should produce learning-path notes, not just answers.
- All personal devices are Apple; no Apple dev account (£100 avoided for now)
  — hence web-first. **iOS Safari compatibility of the web export is a
  route-critical question.**
- Monetization explicitly deferred to its own ticket; don't let it leak into
  other decisions.
- Skills to consult per session: /grilling and /domain-modeling equivalents
  (structured one-question-at-a-time interviewing in chat).

## Decisions so far

<!-- one line per closed ticket: gist + link -->

- [Godot 4 foundations for a 2D tile-digging game](tickets/0001-godot-foundations.md) — target Godot **4.3+**; destructible world = `TileMapLayer` + `erase_cell()` with hardness/gem_type as TileSet custom data; player = `CharacterBody2D`; autoload singletons for run/wallet/save; touch-first input. [Learning-path asset](assets/0001-godot-foundations-learning-path.md).
- [Core loop & failure states](tickets/0003-core-loop.md) — three pressures gate a run: **fuel** (the clock + **round-trip budget** — ascent costs fuel, so you must reserve enough to climb home), **cargo** (greed cap; full = **soft fail**), **hull** (risk cap). **Darkness** = a **risk multiplier on hull** (deeper=darker=more damage), not a fourth bar, countered by a Light upgrade. Fuel-empty & hull-zero collapse to **one "run lost"** = forfeit *only carried cargo*, keep wallet + upgrades, free respawn (no rescue fee → no death-spiral). Banked money never at risk; carried cargo always is. Self-powered ascent (no free return button; fast-travel = deferred upgrade); minimal sell/refuel/upgrade/descend hub; refuel free but modelled as *cost-pinned-to-zero* for later. **Persistent mine** (not regenerating) — carved shaft = visible progress; runs end on near-miss / glimpsed-prize; upgrade ratchet is the secondary engine. [Core-loop asset](assets/0003-core-loop.md).
- [Web export viability on iOS Safari](tickets/0002-web-export-ios-safari.md) — **web-first HOLDS.** Ship the **single-threaded** export (default since 4.3; no COOP/COEP headers, dodges Safari's threaded-WASM bugs). Web = **Compatibility/WebGL2 only** (no Forward+/WebGPU) — fine for 2D, ~60 FPS on iPhone 15. **The binding constraint is memory, not CPU:** iOS Safari OOMs the old 2 GB WASM cap and can lose the WebGL context at the ~400 MB baseline heap — so the mine must chunk-stream/free tiles. Audio = Sample-playback one-shots (no bus effects), tap-to-start unlocks it. PWA gives a chrome-less home-screen app but **no Fullscreen/orientation-lock on iOS** and **installed-PWA storage diverges from Safari's**. [Viability asset](assets/0002-web-export-ios-safari.md).

## Not yet specified

- **Meta-progression & retention** — achievements, milestones, daily hooks.
  Hangs on the core loop and economy decisions; too dim to ticket.
- **Tutorial & onboarding** — shape depends on how intuitive the dig controls
  turn out to be (prototype will tell us).
- **Performance budget** — framed by [0002](tickets/0002-web-export-ios-safari.md)
  as a **binding memory constraint on iOS Safari**, and now *tightened* by
  [0003](tickets/0003-core-loop.md)'s **persistent-mine** decision: the world grows
  without bound across runs, so chunk-streaming **and** freeing off-screen
  tiles/pickups are a **hard requirement**, not optional. Steady-state memory must
  stay in the low-hundreds of MB (well below the ~2 GB WASM cap), + capping
  particles. Still fog — the actual numbers can't be set until worldgen (0005) fixes
  the mine's shape — but the streaming requirement is now non-negotiable.
- **Playtesting plan** — who plays early builds and when; likely graduates
  once a vertical-slice definition exists.
- **Final spec assembly** — the destination document itself; its structure
  will be clear once most decisions are in.

## Out of scope

- **Native App Store / Play Store release** — consciously deferred until the
  web build proves the game; avoids the £100 Apple dev account for now.
  Returns as a fresh effort if the destination is redrawn.
- **Multiplayer** — ruled out in early scoping discussion.
- **Story / NPCs** — ruled out; depth comes from the upgrade curve, not
  narrative content.
- **More than ~8 gem types at launch** — content-volume cap agreed in early
  scoping.
