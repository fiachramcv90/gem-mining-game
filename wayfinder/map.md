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
- [Dig feel & touch controls prototype](tickets/0004-dig-feel-controls.md) — **virtual stick + floaty + hold-to-drill**, chosen by thumb on a real iPhone (grey-box prototype, felt live via the single-threaded web export). The stick must be *dynamic + trailing* (floating origin, base follows the thumb so reversing thrust is instant, ~16% dead zone) — that detail is what made it feel good. Dig time ∝ rock hardness (~0.34 s/unit) — feeling resistance is the core pleasure; **this dig-time-per-hardness band feeds 0005's strata**. Floaty keeps descent + self-powered ascent (0003) one continuous verb. Discarded: tap-adjacent (stop-start), drag-direction (no neutral anchor), grounded (two modes), instant dig (world felt like paper). [Decision asset](assets/0004-dig-feel-controls.md) · [prototype](prototype/) · [live build](https://fiachramcv90.github.io/gem-mining-game/).
- [World generation design](tickets/0005-worldgen.md) — **bounded-but-extensible** mine (~700-tile designed bottom, ~96-tile-wide shaft; hardness & gem curves are *functions of depth* so deepening later is tuning). **5 identity bands** (Topsoil→Bedrock, baseline hardness 1→5). **Frontier-resistance** hardness curve: 0005 owns `hardness(depth)` and *declares the target drill-time band* (frontier ~1.0–1.3 s, conquered ~0.3–0.5 s) as a **requirement 0006's drill-power curve must hold**. Gems = **overlapping tiers + tails**, seated in **2–5-tile veins in a +1-hardness halo** (the telegraph), **~8% density ≈flat with depth**. One seeded **prize gem** (hard nodule, wider glint) = 0003's glimpsed-prize hook. **Sparse depth-scaled caves** (terrain for 0007's fall damage/hazards). **Determinism:** per-player `world_seed` saved at new-game, chunk = pure fn of `(seed,x,y)` via `FastNoiseLite`, save stores only dug/collected **deltas** (0009). **Streaming (the hard req made concrete):** 16 px tiles · 32×32 chunks · resident = camera + 1-chunk margin, **everything else freed** · regenerate-from-seed on re-entry · resident footprint tens of MB. All numbers are on-device tunables. [Design note](assets/0005-worldgen.md) · [cross-section](assets/0005-worldgen-crosssection.svg).
- [Save system on the web build](tickets/0009-save-system.md) — web `user://` is IndexedDB via Emscripten **IDBFS**; Godot **auto-syncs** it (no manual `syncfs`; flush on `visibilitychange` to catch tab-kill). Save = **one `user://save.dat`**, binary `store_var` of a **plain `Dictionary`** (never a `Resource`). Don't serialize the world (0005): store `world_seed` + **per-32×32-chunk 128-byte dug bitmask** + sparse collected-gem coords + `wallet`/`upgrades` (0006 fields) + optional `run`; `save_version` for migration. **Whole dug mine ≈ 8 KB** → size is a non-issue; the risks are **eviction** (WebKit 7-day cap, LRU) and **PWA/Safari divergence**. Mitigate: `navigator.storage.persist()` + **"Add to Home Screen" (exempt from the 7-day cap)**. Safety hatch = **local export/import now** (`JavaScriptBridge.download_buffer()` / file-input), **cloud-ready** behind a single `SaveBlob` seam (Fiachra's call). Dexie transfer: durability model 1:1, but `user://` is a file, not object-stores/indexes/transactions. [Research asset](assets/0009-save-system.md).
- [Economy & upgrade curve](tickets/0006-economy-upgrades.md) — **first-draft numbers ship as defaults; every value stays a named `@export` knob** (re-balance = slider drag, the load-bearing decision — validated by a throwaway 20-run **simulation**, not intuition). Gem values by **tier** (T1 8→T5 95, prize **900** off-curve); EV/tile rises ~7× Topsoil→Bedrock (~1.8× per *minute*, so shallow farming stays viable-but-inferior). **Six tracks:** Drill (power curve *holds 0005's 0.3–1.5 s drill-time contract* — one band at the ~1.1 s frontier/level, between-band step a soft cliff = frontier-resistance), Fuel (round-trip gate), Cargo (greed cap, late limiter), Hull + Light (prices real, damage/darkness *benefit* is 0007's placeholder), and an aspirational **Hoist** (5000, halves ascent). Prices ~2.5×/level = self-funding ratchet. **First hour:** first upgrade ~run 3, mid-Sandstone by 60 min (~17 runs), Bedrock ~run 19, 700 t bottom still unreached (the one-more-run goal). Free refuel stays cost-pinned-to-zero (0003); no per-run cash sink → no death-spiral. [Design note](assets/0006-economy-upgrades.md) · [sim console](https://claude.ai/code/artifact/8b0a93aa-b680-4b11-9a92-217037ae2469) · [`economy-sim/`](economy-sim/).
- [Hazards & depth progression](tickets/0007-hazards-depth.md) — danger is **discrete, telegraphed, dodgeable events** (not a drain), their *expected* hull cost/tile calibrated to reproduce 0006's placeholder so **Hull/Light prices don't move**. **Roster = 4, one per mechanism:** **Falls** (kinetic drop into 0005's caves — 3-tile grace, ~linear, capped at 45% of *current* Hull), **Gas pockets** (dig-triggered burst), **Cave-ins** (structural, Granite+), **Lava/heat** (contact-over-time `Area2D`, glows so darkness can't hide it). **3 danger acts over the 5 bands**, cumulative one-beat-per-band: *Learning* (Topsoil/Clay) → *The Squeeze* (Sandstone/Granite) → *The Deep* (Bedrock). **Darkness = avoidance:** Light buys *sight* (see the tell → dodge), scaling **hit probability** not damage size. **Only Hull (soak) + Light (dodge) mitigate**; Fuel couples emergently (falls drop you deeper), Drill/Cargo stay out. 0006's `hazard_base`/`depth_gain` re-cast as the calibration *target*; all damage numbers are named `@export` knobs. [Design note](assets/0007-hazards-depth.md) (band × act × hazards table + Godot Area2D/collision-layer/DoT notes).
- [Web export viability on iOS Safari](tickets/0002-web-export-ios-safari.md) — **web-first HOLDS.** Ship the **single-threaded** export (default since 4.3; no COOP/COEP headers, dodges Safari's threaded-WASM bugs). Web = **Compatibility/WebGL2 only** (no Forward+/WebGPU) — fine for 2D, ~60 FPS on iPhone 15. **The binding constraint is memory, not CPU:** iOS Safari OOMs the old 2 GB WASM cap and can lose the WebGL context at the ~400 MB baseline heap — so the mine must chunk-stream/free tiles. Audio = Sample-playback one-shots (no bus effects), tap-to-start unlocks it. PWA gives a chrome-less home-screen app but **no Fullscreen/orientation-lock on iOS** and **installed-PWA storage diverges from Safari's**. [Viability asset](assets/0002-web-export-ios-safari.md).
- [On-device iOS Safari smoke test](tickets/0011-ios-smoke-test.md) — **0002 CONFIRMED on a real iPhone.** A throwaway single-threaded Compatibility/WebGL2 export runs in iOS **WebKit**: renders (`gl_compatibility` / OpenGL ES 3.0 / WebGL 2.0), touch works, **Sample audio unlocks on first tap**, holds **60 FPS**, and — the headline for 0002 §4 — **survived 9 rotate/resizes incl. landscape with no canvas-resize crash and no context loss.** No blocker → platform bet stands (not re-litigated). Two caveats logged: the on-device **memory numbers didn't instrument** (Godot `MEMORY_STATIC` reads 0 on web; the WASM-heap/512 MB-cap shim didn't capture `WebAssembly.Memory`) so the memory result is *qualitative*; and **PWA install wasn't separately confirmed**. Build bug caught en route: `OS.get_current_rendering_method()` doesn't exist in 4.3 → parse error → silent grey screen; now a **CI headless-run gate** fails builds on any script error. [Learning notes](assets/0011-ios-smoke-test-notes.md).

## Not yet specified

- **Meta-progression & retention** — achievements, milestones, daily hooks. Its
  stated blockers (the [core loop](tickets/0003-core-loop.md) and
  [economy](tickets/0006-economy-upgrades.md)) are **now both closed**, so this is
  ready to graduate at the next charting pass: milestones can pin to real economy
  landmarks — first Bedrock, first prize gem, affording the Hoist — **and now to
  [0007](tickets/0007-hazards-depth.md)'s 3 danger acts** (survived first Bedrock
  lava, first cave-in dodged, reached "The Deep") as ready-made danger milestones.
- **Tutorial & onboarding** — [0004](tickets/0004-dig-feel-controls.md) answered
  the "how intuitive?" question: the controls are grasped near-instantly ("push to
  fly, hold into rock to dig"), so onboarding can be *minimal*. The two things
  worth surfacing early are the **dynamic/trailing virtual stick** and the
  **round-trip fuel** decision (0003) — plus, from
  [0009](tickets/0009-save-system.md), an **"Add to Home Screen first"** nudge, since
  the installed web app dodges iOS Safari's 7-day storage-eviction cap (save
  durability). Still fog — firms up into a ticket once a vertical slice exists.
- **Performance budget** — framed by [0002](tickets/0002-web-export-ios-safari.md)
  as a **binding memory constraint on iOS Safari**, tightened by
  [0003](tickets/0003-core-loop.md)'s **persistent-mine** decision (world grows
  without bound), and now given **concrete numbers** by
  [0005](tickets/0005-worldgen.md): 16 px tiles, 32×32-tile chunks, a **bounded
  resident window** (camera + 1-chunk margin, everything else **freed**),
  regenerate-from-seed on re-entry, ~96-tile shaft, worldgen resident footprint in
  the **tens of MB**, particles/pickups capped. The *bounded-resident-window* rule
  is the non-negotiable form of "stream and free." What's left is thin: **on-device
  profiling** to confirm the exact window size / chunk budget on a real iPhone
  (likely graduates into a task once a vertical slice exists) — the shape and
  targets are set. **New from [0011](tickets/0011-ios-smoke-test.md):** WebKit
  handled repeated rotate/resize at 60 FPS with no crash (the *qualitative* memory
  worry is eased) — **but 0011 produced no measured heap number**, because Godot's
  `Performance.MEMORY_STATIC` reads 0 on the web export and a `WebAssembly.Memory`
  capture shim didn't fire. So the profiling task has a **concrete new
  prerequisite: get real web memory instrumentation working first** (measure the
  Emscripten WASM heap, e.g. via a correct `JavaScriptBridge` hook) before any
  resident-window/chunk number can be trusted.
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
