# Gem Miner — Final Design & Technical Specification

> **The destination document** for the Gem Miner wayfinder map, assembled by
> ticket **[0014 — Final spec assembly](../tickets/0014-final-spec-assembly.md)**.
> One complete design + technical spec, compiled from the Resolutions and
> linked assets of tickets 0001–0013, structured so Fiachra can open
> **Godot 4.3+** and start building with **no open decisions**.
>
> **How to read this:** every section states the decision and its defaults,
> and links the **owning ticket** whose asset holds the full rationale — the
> spec compiles, it does not re-decide. Where two tickets touch the same knob,
> the **reconciled contract is stated once here**, marked **⟲ Reconciled**,
> with links back to the owners. Terms are used exactly as defined in the
> domain glossary, [CONTEXT.md](../../CONTEXT.md).
>
> **The one standing discipline (every ticket reaffirmed it):** all numbers
> below ship as launch **defaults** and stay named `@export` Inspector knobs —
> re-balancing is a slider drag, never a code change. Appendix A gathers them.

---

## The game in one paragraph

A Motherload-style gem-digging game. The player flies a digger down into a
single **persistent mine** — the same excavation across every **run** —
managing **three pressures** (Fuel, Cargo capacity, Hull), selling **cargo**
at the minimal **surface hub** to fund the permanent **upgrade ratchet**
(Drill, Fuel, Cargo, Hull, Light, and the aspirational Hoist), pushing the
**drill frontier** through five ever-harder **bands** toward a ~700-tile
designed bottom, past telegraphed hazards and a shrinking view radius
(**darkness**), chasing the **prize gem** glinting at the edge of vision.
Built in Godot 4.3+, shipped web-first as a single-threaded HTML5 export on
GitHub Pages, installable as a PWA, free with an optional itch.io
pay-what-you-want page.

---

# Part I — Design

## 1. Core loop & failure states — [0003](../tickets/0003-core-loop.md)

*Full detail: [core-loop asset](0003-core-loop.md).*

The loop: descend from the surface hub into the persistent mine → dig,
managing three pressures → decide "one more tile, or just enough fuel to get
home?" → self-powered ascent → sell, refuel, upgrade, descend deeper.

- **Three pressures gate a run**, each with a distinct job:
  - **Fuel** — the clock and the **round-trip budget**: ascent spends fuel
    too, so every tile down must be paid to climb back. The master resource
    and the source of the turn-back decision. Empty → **run lost**.
  - **Cargo capacity** — the greed cap. Full hold = **soft fail**: new gems
    are simply not collected (they stay in the ground); nothing kills you,
    the full hold *pulls* you home.
  - **Hull** — the risk cap, depleted by hazards (§5). Zero → **run lost**.
- **Darkness is a risk multiplier on Hull, not a fourth bar** — see the
  reconciled darkness contract in §6.
- **One "run lost" outcome.** Fuel-empty and hull-zero collapse into a single
  failure: forfeit *only carried cargo*, keep **wallet** and all upgrades,
  respawn at the surface topped up **for free**. No rescue fee — no
  death-spiral, by design. Wallet is never at risk; cargo always is: that
  asymmetry is the greed-vs-safety tension.
- **Self-powered ascent.** No free return button; fast-travel exists only as
  the late-game **Hoist** upgrade (§4). Refuel/repair at the surface is free,
  but modelled as a cost **pinned to zero** (`refuel_cost_per_unit = 0`,
  `repair_cost_per_hp = 0`) so a per-run sink could be switched on later
  without a refactor — the standing recommendation is to leave it at zero.
- **Persistent mine.** One continuous excavation; tunnels survive between
  runs. "One more run" is carried by: the carved shaft as visible progress,
  runs ending on a near-miss or **glimpsed prize**, and the ratchet as the
  secondary engine.

## 2. Controls & dig feel — [0004](../tickets/0004-dig-feel-controls.md)

*Full detail: [decision asset](0004-dig-feel-controls.md) ·
[prototype](../../prototype/) ·
[live build](https://fiachramcv90.github.io/gem-mining-game/).*

**Virtual stick + floaty movement + hold-to-drill**, validated by thumb on a
real iPhone via a grey-box prototype (all three axes switchable live).

- **The stick must be dynamic and trailing** — floating origin (appears where
  the thumb touches), base follows the thumb past the ring so reversing
  thrust is instant, ~16% dead zone (rescaled), ~64 px throw radius. The
  trailing behaviour is the single most important feel detail and **must
  survive into the real game** — a naïve fixed-origin stick felt bad.
- **Floaty** (jetpack-in-dirt): thrust accelerates in the stick direction,
  light gravity, slight glide damping. Makes descent and the self-powered
  climb home one continuous flying verb.
- **Hold-to-drill:** the cell the stick presses into drills over
  `time = hardness × dig_constant`, `dig_constant ≈ 0.34 s`, with a progress
  ring. Collision holds the digger against undug rock until the cell breaks —
  no separate dig button. Feeling harder rock as resistance is the core
  tactile pleasure (instant digging made the world feel like paper).
- Discarded on-device: tap-adjacent (stop-start), drag-direction (no neutral
  anchor), grounded (two modes), instant dig.
- Touch-first input; mouse/keyboard fall out free on the web export.

## 3. The mine — world generation — [0005](../tickets/0005-worldgen.md)

*Full detail: [worldgen design note](0005-worldgen.md) ·
[cross-section](0005-worldgen-crosssection.svg).*

- **Bounded-but-extensible:** designed bottom at **~700 tiles**, shaft
  **~96 tiles wide**, walled by unbreakable bedrock. `hardness(depth)` and
  gem distribution are **functions of depth**, so deepening later is tuning,
  not redesign.
- **Five identity bands** (names are placeholder-flavour; identity is the job):

  | Band | Depth (tiles) | Baseline hardness | Characteristic gem tier |
  |---|---|---|---|
  | Topsoil   | 0–40    | 1 | T1   |
  | Clay      | 40–120  | 2 | T1–2 |
  | Sandstone | 120–260 | 3 | T2–3 |
  | Granite   | 260–450 | 4 | T3–4 |
  | Bedrock   | 450–700 | 5 | T4–5 |

- **Gems:** overlapping tier weights with a moving peak + tails (lucky
  low-tier deep finds, rare early sightings of the next tier up). A find is a
  **vein** of 2–5 same-tier tiles wrapped in a **halo** of +1-hardness rock —
  the telegraph: you *feel* the rock harden before you break through. Base
  density **~8% of tiles, roughly flat with depth** — deeper pays via *tier*,
  never count (or cargo pressure collapses). Six gem types total (T1–T5 +
  prize) — comfortably inside the ~8-type scope cap.
- **The prize gem** = 0003's glimpsed-prize hook, unified into one mechanism:
  one seeded top-value gem (900, off the tier curve), a hard singleton nodule
  (+2 hardness), spawn chance low and rising gently with depth, and a **glint
  that reveals wider through darkness than anything else** — catchable right
  at the edge of vision, exactly when you're deep and low on fuel.
- **Caves:** sparse voids, more common and larger with depth
  (`cave_frequency(depth)` rising, `cave_size_distribution`). They are the
  terrain for falls, the stage for darkness tension, and homes for gems and
  hazards. Kept sparse — a mine that's mostly holes stops feeling like earth.
- **Determinism:** per-player **world seed**, generated once at new-game and
  saved. A chunk's undug content is a **pure function of
  `(world_seed, chunk_x, chunk_y)`** via seeded `FastNoiseLite` + integer
  hashing — never runtime `randf()`. The save stores only dug/collected
  **deltas** (§13). Caves carve from a second seeded noise channel, so they
  reload identically too.
- **Darkness base curve (owned here):** view radius generous at the surface,
  shrinking roughly linearly with depth to a **non-zero floor** (~a couple of
  tiles — never blind-blind). Knobs: `surface_view_radius`,
  `shrink_rate_per_depth`, `min_floor_radius`, `prize_glint_radius`.
- Streaming numbers (chunk size, resident window) are technical — see §12.

### ⟲ Reconciled: the drill-time contract — [0005](../tickets/0005-worldgen.md) × [0006](../tickets/0006-economy-upgrades.md)

Two tickets touch the same knob — the felt drill time — and their coupling is
a stated contract, not an overlap:

> **0005 owns `hardness(depth)` and declares the target effective drill-time
> band; 0006's `drill_power` curve must hold the player inside it.**
> `effective_drill_time = hardness × 0.34 / drill_power`. Baseline rock stays
> in **~0.3–1.5 s** across the whole descent: rock at the current **drill
> frontier** ~**1.0–1.3 s** (push-through resistance), conquered rock
> **~0.3–0.5 s** (fast travel back through your own shaft).

0006's shipped curve satisfies it exactly: `drill_power`
{0.31, 0.62, 0.93, 1.24, 1.55} parks each band's baseline at ~1.1 s at the
matching level (hardness n × 0.34 / power[n−1] ≈ 1.1 s). Two deliberate
consequences are **features, not breaches**:

- **The between-band step is a soft cliff.** At a given drill level the next
  band's baseline sits well over the 1.5 s ceiling — you don't grind a band
  early, you buy the drill that opens it. That *is* frontier-resistance, and
  it makes Drill the legible primary depth-gate.
- **Halo (+1) and prize (+2) tiles poke above the ceiling on purpose** —
  they're the telegraph and the grind-for-the-prize, resistance spikes on a
  few tiles. The contract governs **baseline** rock only.

## 4. Economy & the upgrade ratchet — [0006](../tickets/0006-economy-upgrades.md)

*Full detail: [economy design note](0006-economy-upgrades.md) ·
[`economy-sim/`](../../economy-sim/) (`node economy-sim/run.js`) ·
[interactive console](https://claude.ai/code/artifact/8b0a93aa-b680-4b11-9a92-217037ae2469).*

Validated by a throwaway 20-run simulation, not intuition. The entire economy
lives in the permanent-upgrade **ratchet**; there is **no per-run cash sink**
(refuel/repair free, §1) and **no death-spiral**.

- **Gem values by tier:** T1 **8** · T2 **15** · T3 **28** · T4 **52** ·
  T5 **95** · prize **900** (off-curve, ~9.5× a T5). Expected value per dug
  tile rises **~7× Topsoil→Bedrock** ($0.77 → $5.45), but only **~1.8× per
  minute** once round-trips are paid — shallow farming stays
  viable-but-inferior, so the pull down is real without being punishing.
- **Six tracks** (L0 = free starting kit; prices climb ~2.5×/level — the
  self-funding ratchet):

  | Track | Levels (L0→max) | Prices (L1→max) | Job |
  |---|---|---|---|
  | **Drill** | power 0.31 / 0.62 / 0.93 / 1.24 / 1.55 | 100 / 280 / 750 / 1900 | Holds the §3 drill-time contract; the primary depth-gate |
  | **Fuel**  | cap 80 / 180 / 380 / 650 / 1050 | 80 / 240 / 640 / 1600 | The round-trip gate; each level's safe round-trip reaches ~the next band's floor |
  | **Cargo** | slots 12 / 20 / 32 / 50 / 75 (1 gem = 1 slot, any tier) | 120 / 320 / 800 / 2000 | The greed cap; deliberately the *late* limiter |
  | **Hull**  | cap 100 / 150 / 220 / 320 / 450 | 90 / 260 / 700 / 1750 | The risk cap — soaks hazard spikes (§5) |
  | **Light** | darkness ×1.00 / 0.68 / 0.42 / 0.25 (L0→L3) | 150 / 450 / 1200 | Buys sight — scales hazard *hit probability* down (§6) |
  | **Hoist** | one purchase: ascent fuel & time ×0.5 | 5000 | The aspirational late-game luxury; surfaces in the shop only once Drill/Fuel/Cargo are deep |

- **Fuel consumption knobs:** descent **0.4**/tile, **ascent 1.0**/tile (the
  asymmetry that makes the climb a real budget line), hover-while-drilling
  **0.15**/tile dug, reserve margin **12%**.
- **First-hour pacing** (greedy-miner sim, fixed seed): first upgrade ~run 3
  (~4½ min); mid-Sandstone by 60 min (~17 runs); Granite run ~18, first
  Bedrock ~run 19; **the 700-tile bottom unreached in 20 runs** — it stays
  the standing one-more-run goal. Early runs 1½–3 min, deep runs 10–15 min —
  the intended rhythm.
- Master pacing lever: a global `price_scale` over all price arrays.

## 5. Hazards & depth progression — [0007](../tickets/0007-hazards-depth.md)

*Full detail: [hazards design note](0007-hazards-depth.md).*

**Danger is discrete, telegraphed, dodgeable events — never a smooth drain.**
Hull is rarely lost to the average; it's lost to the spike (one bad blind
moment). The roster's *expected* hull cost per dug tile is calibrated to
reproduce the curve 0006 priced Hull/Light against, so **no 0006 price or
capacity moves** — see the reconciled contract below.

**Four hazards, one per trigger mechanism:**

- **Falls** (kinetic — Act I baseline): drill into a cave and drop. Grace
  ≤ 3 tiles free; then ~4 hull/tile, ~linear; **capped at 45% of *current*
  Hull** (scales with upgrades — serious but survivable, never a one-shot).
  Seen in the light, a thrust-brace cuts damage to ×0.4. Falls also drop you
  deeper — quietly eating ascent fuel (0003's round-trip budget) with no new
  system.
- **Gas pockets** (dig-triggered burst — rare in Clay, common Sandstone+):
  a tile with a visible tell that bursts when drilled. Burst damage by band:
  Clay 8 / Sandstone 14 / Granite 18 / Bedrock 22.
- **Cave-ins** (structural — Granite+): undermining cracked/unstable rock
  drops it on you. 15 (Granite) / 25 (Bedrock). The one hazard with real
  gameplay-logic cost (support check) — flagged as the natural candidate to
  **ship last** if Act II slips.
- **Lava / heat** (contact-over-time — Bedrock): an `Area2D` volume, 5 hull
  per 0.2 s tick while inside. **Lava glows** — self-lit through darkness
  (the fair exception), so Bedrock's headline threat can't cheap-shot.

**Three danger acts over the five bands** — cumulative, one new beat per band:

| Band | Act | Active roster | Exp. dmg/tile @ L0 | Typical spike |
|---|---|---|---|---|
| Topsoil   | I · Learning     | falls                      | ~0.022 | 0–8   |
| Clay      | I · Learning     | + rare gas                 | ~0.029 | 8–14  |
| Sandstone | II · The Squeeze | gas common                 | ~0.042 | 12–18 |
| Granite   | II · The Squeeze | + cave-ins                 | ~0.061 | 15–28 |
| Bedrock   | III · The Deep   | + lava, everything at max  | ~0.086 | 20–48 |

**Only Hull (soak) and Light (dodge) mitigate** — the clean pair 0006 priced.
Fuel couples emergently (falls); Drill and Cargo stay out of the danger model.

### ⟲ Reconciled: the hazard calibration target — [0006](../tickets/0006-economy-upgrades.md) × [0007](../tickets/0007-hazards-depth.md)

> 0006's placeholder damage model — `hazard_base_per_tile (0.02) ×
> (1 + hazard_depth_gain (4.0) × depth_fraction) × darkness_mult` — is **not
> a live drain**. It is retained as the **expected-damage/tile curve the
> hazard encounter rates are tuned against**, so the Hull/Light purchase math
> 0006 validated stays honest while the *felt* danger becomes variance.
> 0007 fills in what a point of hull damage means; **0006's prices and
> capacities are untouched.**

## 6. ⟲ Reconciled: the darkness contract — [0003](../tickets/0003-core-loop.md) × [0005](../tickets/0005-worldgen.md) × [0006](../tickets/0006-economy-upgrades.md) × [0007](../tickets/0007-hazards-depth.md)

Four tickets touch darkness; the reconciled whole, stated once:

> **Darkness is a depth-scaled shrink of the view radius — a risk multiplier
> on Hull, never a fourth bar or a fourth death** (0003). **0005 owns the
> base curve** (linear shrink to a non-zero floor; knobs
> `surface_view_radius`, `shrink_rate_per_depth`, `min_floor_radius`).
> **0006 owns the Light track's prices** and its `light_darkness_mult` ladder
> {1.00, 0.68, 0.42, 0.25}. **0007 owns what the multiplier means:** darkness
> scales hazard **hit probability**, not damage size — Light buys *sight*
> (see the tell → dodge). Implementation is a rendering rule: a hazard's tell
> is drawn only inside the lit view radius — the darkness renderer *is* the
> dodge mechanic. Two self-lit exceptions pierce the dark by design: the
> **prize gem's glint** (`prize_glint_radius`, the glimpsed-prize hook) and
> **lava's glow** (`lava_glow_radius`, fairness).

## 7. Art & audio direction — [0008](../tickets/0008-art-audio.md)

*Full detail: [direction note](0008-art-audio.md) ·
[palette moodboard](0008-palette-moodboard.html).*

**Make everything, spend nothing.** All art hand-made in **Pixelorama**, all
SFX free (**jsfxr/ChipTone** + Audacity foley), all music self-composed
(**Bosca Ceoil**). AI/Claude is scoped to palette/reference/procedural
code-gen — never final sprites. No paid packs, no CC-BY obligations.

- **Look:** 16 px tiles, one fixed master palette — **Resurrect-64** — with
  the load-bearing **reserve-saturation** rule: rock stays desaturated and
  earthy; **gems, lava, and the prize glint own the saturated hues**, so a
  few bright pixels read as "not-rock" at the edge of the shrinking view
  radius. Bands = hue+value shifts of one shared rock ramp (Topsoil
  warm/light → Bedrock cold/dark), reinforcing the darkness curve.
- **Telegraphs (art owns the look, §5/§6 own the rules):** vein halo = a
  darker, tighter-grained ring; prize = a gold cross-glint shader piercing
  the darkness overlay; gas = shimmer/tint tell; cave-ins = cracks/dust;
  lava = self-lit glow.
- **Animation budget: near-zero hand-drawn frames.** Motion = Godot `Tween`s
  (bob, drill spin, squash) + **capped pooled particles** (4–8 per burst,
  `CPUParticles2D` on Compatibility) + **one reused CanvasItem shader**
  (glint/glow/shimmer). 2-frame hand animation is a last-resort fallback.
- **Sound is a bonus layer, never load-bearing** (the iOS silent switch mutes
  Web Audio — §11). Warm/chunky lo-fi: ~10–12 one-shots (foley dig thud is
  the core verb) + 2–3 loops; **"no bus effects" is runtime-only — bake
  reverb/EQ into samples offline** in Audacity. Music = 3–4 self-composed
  ambient loops, **depth-crossfaded** (volume crossfade is playback, not a
  bus effect).
- **Juice is visual-first:** every feedback beat fully lands with sound off.
  "Haptics-equivalent" = short sharp screen-shake + flash; best-effort
  `navigator.vibrate` additive only. Ship a **reduce-motion/shake toggle**
  honouring `prefers-reduced-motion`. Full moment→visual→audio checklist in
  the asset's §4 table.
- Import notes: Nearest texture filtering / "2D Pixel" preset; SFX as
  WAV → Sample; music as looped OGG Vorbis.

## 8. Meta-progression — the Miner's Log — [0012](../tickets/0012-meta-progression.md)

*Full detail: [design note](0012-meta-progression.md).*

**The persistent mine + upgrade ratchet are the retention engine; the
Miner's Log is one thin honorific layer on top.** Daily hooks are **rejected
on the record** (nothing legal to pay out, streak-guilt is anti-tonal, the
shaft *is* the daily hook) — do not let them creep back during the build.

- **8 lifetime stats** (plain int counters, incremented at the moment of the
  event): `deepest_depth`, `tiles_dug`, `gems_collected`, `money_banked`,
  `prize_gems_banked`, `runs_completed`, `runs_lost`, `cargo_value_lost`.
  No playtime tracking.
- **14 milestones in three families** — Depth 5 (first Clay / Sandstone /
  Granite / Bedrock + the ~700-tile bottom capstone), Wealth 4 (first sell,
  first upgrade, first prize gem *banked*, the 5000 Hoist), Survival 5 (one
  per hazard mechanism + **first lost run** as a rite-of-passage badge).
  **Ground rule:** every milestone pins to an event the game already detects
  — no new detection systems. Names/count are launch content; the families +
  pin rule are the decision. No cumulative grind badges.
- **Honorific-only is a hard line:** a badge that grants +anything becomes a
  shadow currency and reopens 0006. Celebration = 0008's existing
  shake+flash + a one-line terse miner-voiced banner (*"BEDROCK. Few dig
  this deep."*) — never a modal mid-run; honored fully in the Log at the hub.
  14 lines of copy are the entire content cost.
- **Surfacing:** one Miner's Log screen (stats + checklist together) behind
  exactly **one new hub button**; unearned milestones show as "???"
  silhouettes; title screen untouched.
- **Persistence:** the `stats` and `milestones` save fields (§13).
  Stat-derivable badges **self-heal at load**; event-only survival badges are
  simply earnable going forward.

## 9. Onboarding & the surface hub — [0013](../tickets/0013-tutorial-onboarding.md)

*Full detail: [arrangement note](0013-tutorial-onboarding.md).*

Onboarding is **two text lines, one gauge behaviour, and two nudges** —
nothing gates play, zero modals, every beat lands silent, no new art, and the
whole save-schema cost is one `nudges` key (§13).

| Element | Surface | Timing | Dismissal |
|---|---|---|---|
| **Controls ghost line** — *"push to fly · hold into rock to dig"* | mid-run | first descent only | self-dismisses on first dig (~10 s backstop); first-run **derived** from an empty dug-delta — no flag |
| **Round-trip fuel lesson** | fuel gauge + run-lost screen | every run, forever | none — permanent UI |
| **Add-to-Home-Screen nudge** | 💾 save-safety corner in the hub | from first sell **or** first run lost | `nudges.a2hs_dismissed` (0–2); one re-show after a later run lost; suppressed when standalone |
| **Silent-switch caption** — *"🔊 flip off silent for sound"* | tap-to-start screen | first session only | `nudges.audio_hint_shown`; the game-starting tap dismisses it |

- **The round-trip warning is the teacher:** the fuel-gauge pulse is pinned
  **round-trip aware** — it fires when remaining fuel approaches the
  estimated ascent cost from current depth (threshold multiplier, e.g.
  ~1.3× ascent cost, is a named `@export` knob), plus a permanent
  death-reason line on the run-lost screen (*"ran dry below ground — the
  climb home costs fuel too"*). The cheap first lesson (early runs are
  shallow by design) does the rest.
- **The 💾 save-safety corner is permanent** — install how-to + save
  export/import's forever home (import can never live behind a nudge that
  stops showing).
- **First 10 seconds:** tap-to-start (title + tap prompt + 🔊 caption +
  ♥ corner) → surface hub (no onboarding content — four buttons teach
  themselves) → first descent (ghost line).

### ⟲ Reconciled: the final hub census — [0003](../tickets/0003-core-loop.md) × [0010](../tickets/0010-monetization.md) × [0012](../tickets/0012-meta-progression.md) × [0013](../tickets/0013-tutorial-onboarding.md)

> The **surface hub** is, completely and finally: **4 core actions** (sell ·
> refuel/repair · upgrade · descend) **+ the Miner's Log button** (0012)
> **+ the ♥ Support corner** (0010) **+ the 💾 save-safety corner** (0013).
> Nothing else claims hub space.

---

# Part II — Technical

## 10. Engine & foundations — [0001](../tickets/0001-godot-foundations.md)

*Full detail: [learning-path asset](0001-godot-foundations-learning-path.md)
(includes the GDScript-from-TypeScript idiom table, web-dev gotchas, and the
recommended learning path).*

- **Engine:** latest stable Godot 4.x, **hard floor 4.3** (the release that
  introduced `TileMapLayer` and the single-threaded web export). Beware
  later-4.x-only APIs when following tutorials — a call to a method that
  doesn't exist in your version is a *parse error* that silently kills the
  whole script (§14).
- **Destructible world:** `TileMapLayer` nodes over a shared `TileSet`;
  dig = `erase_cell()` (collision updates automatically); per-tile
  `hardness` / `gem_type` / `hazard_type` via TileSet **custom data layers**
  — or computed on the fly from the seed (§3), keeping the TileSet to one
  entry per visual type.
- **Player:** `CharacterBody2D` + `move_and_slide()`, floating motion mode
  (per §2); `Camera2D` child with `position_smoothing`.
- **Input:** named Input-Map actions; `InputEventScreenTouch`/`ScreenDrag`;
  "Emulate Touch From Mouse" for desktop dev. Build the touch path first —
  mouse falls out free.
- **Architecture:** autoload singletons for cross-run state (`GameState`,
  `Wallet`/`Upgrades`, `SaveManager`); scene shape
  `Main → Mine (TileMapLayers + Pickups + Hazards) + Player (+DigController
  + Camera2D) + HUD (CanvasLayer)`; **signals up, calls down**. Config lives
  in `Resource`s (`EconomyConfig` / `HazardConfig` `.tres`) with every knob
  `@export`ed — Appendix A. Derive effective values
  (drill time, reach) as pure functions of `(config, upgrades, depth)`;
  never store them.

## 11. Web export & iOS Safari — [0002](../tickets/0002-web-export-ios-safari.md), confirmed on-device by [0011](../tickets/0011-ios-smoke-test.md)

*Full detail: [viability asset](0002-web-export-ios-safari.md) ·
[smoke-test build notes](0011-ios-smoke-test-notes.md).*

**Web-first holds — empirically de-risked on a real iPhone**, not just from
docs: single-threaded Compatibility/WebGL2 renders, touch works, Sample audio
unlocks on first tap, the PWA installs, 60 FPS holds, and WebKit survived 9
rotate/resizes with no canvas-resize crash and no context loss.

The iOS-safe export configuration (all confirmed working):

- **Thread Support OFF** (single-threaded — the one load-bearing toggle):
  no `SharedArrayBuffer`, no COOP/COEP headers, sidesteps Safari's
  threaded-WASM bugs. `export_presets.cfg` · `variant/thread_support=false`.
- **Renderer: Compatibility / WebGL 2.0** (the only web option — fine for
  2D; ~60 FPS on device).
- **Audio: Sample playback** (`audio/general/default_playback_type.web=2`):
  low latency without threads; no runtime bus effects / reverb / doppler /
  **procedural** (an `AudioStreamGenerator` will not work — generate
  `AudioStreamWAV` samples instead). First tap = the audio-unlock gesture.
- **PWA ON** (`progressive_web_app/enabled=true`, `display=1` standalone,
  144/180/512 icons): chrome-less home-screen app + offline caching. On iOS
  there is **no Fullscreen API and no orientation lock** — use safe-area
  insets (`viewport-fit=cover` + `env(safe-area-inset-*)`); the manifest
  orientation is a hint iOS may ignore.
- **Textures: Basis Universal** (`vram_texture_compression/for_mobile=true`
  + `import_etc2_astc=true` — both needed together).
- **Serving: HTTPS** (secure context required for IndexedDB/PWA); no special
  headers. GitHub Pages satisfies this.
- **Memory is the binding constraint, not CPU** — see §12. WASM max memory:
  4.3's stock templates grow dynamically (the old rejected 2 GB fixed
  request is gone); there is no preset knob — the smoke test clamped via an
  `html/head_include` shim to 512 MB (a ~400 MB hosted baseline heap makes
  256 MB risk false OOM). The clamp's effect is **unconfirmed** — a
  confirm-during-build item (§16).
- **Two UX realities confirmed on-device:** the **iOS ring/silent switch
  mutes Web Audio** (hence 0008's visual-first juice and 0013's caption);
  and `performance.memory` is Chrome-only — the Safari-safe memory signal is
  the WASM buffer's `byteLength` via `JavaScriptBridge` (§16).

## 12. ⟲ Reconciled: the memory budget — [0002](../tickets/0002-web-export-ios-safari.md) × [0003](../tickets/0003-core-loop.md) × [0005](../tickets/0005-worldgen.md)

Three tickets converge on one rule; stated once:

> **iOS Safari's memory ceiling is the binding platform constraint** (0002:
> ~400 MB hosted baseline heap can lose the WebGL context; the old 2 GB WASM
> max is rejected), **the persistent mine grows without bound** (0003), so
> **the mine chunk-streams inside a bounded resident window** (0005 — the
> non-negotiable): **16 px tiles · 32×32-tile chunks · resident = camera
> view + 1-chunk margin ring (~a 5×5 window, ~25k tiles) · everything beyond
> the margin freed** (tiles, collision, pickups) **· regenerate-from-seed +
> re-apply deltas on re-entry · generation incremental (a few chunks/frame —
> single-threaded)**. Resident count is constant with depth: floor 500 costs
> what floor 5 costs. Worldgen resident footprint: tens of MB; total
> steady-state comfortably under the ceiling. Particles and pickups capped
> and pooled (0005/0008). Avoid orientation thrash / WebGL-context
> recreation (WebKit's canvas-resize leak — no crash in 9 on-device resizes,
> but design against it; one device isn't a guarantee).
>
> The bounded-window **rule** is the hard requirement; the specific numbers
> (32, margin-1, 96-wide) are on-device tunables pending §16's profiling.

## 13. ⟲ Reconciled: the save system — [0009](../tickets/0009-save-system.md), fields added by [0012](../tickets/0012-meta-progression.md) & [0013](../tickets/0013-tutorial-onboarding.md)

*Full detail: [save research asset](0009-save-system.md) (includes the
Dexie/IndexedDB transfer table).*

**Mechanism:** web `user://` is IndexedDB via Emscripten IDBFS; **Godot
auto-syncs** it (never call `syncfs`). The sync is async — the residual risk
is losing the *last* write on an abrupt tab kill, mitigated by flushing on
`visibilitychange → hidden` (the reliable "going away" signal on iOS).

**Format:** one file `user://save.dat`, binary `store_var` of a **plain
`Dictionary`** — never a `Resource`/class (binds the save to script paths).
The complete reconciled envelope — 0009's schema with 0012's and 0013's
planned additions under the same `save_version` migration:

```gdscript
{
  "save_version": 1,               # 0009 — checked first; drives migration
  "world_seed":   1234567890,      # 0005 — REQUIRED; absent ⇒ treat as corrupt
  "world": {                       # 0009 serializes 0005's deltas
     "dug":       { Vector2i(cx,cy): PackedByteArray(128 bytes), ... },
     "collected": PackedInt32Array([x0,y0, x1,y1, ...]),
  },
  "wallet":   0,                   # 0006 owns the value
  "upgrades": { "drill": 0, "fuel": 0, "cargo": 0,
                "hull": 0, "light": 0, "hoist": false },   # 0006's six tracks
  "run":      null,                # optional best-effort mid-run state;
                                   # missing/partial ⇒ start at surface
  "stats":      { ... 8 int counters ... },   # 0012 (§8)
  "milestones": { "milestone_id": true },     # 0012 (§8)
  "nudges":     { "audio_hint_shown": false,
                  "a2hs_dismissed":   0 },    # 0013 (§9)
  "meta":     { "saved_at": 0, "play_secs": 0, "schema_note": "" },
}
```

- **Deltas:** per touched 32×32 chunk, a **128-byte dug bitmask** (1 bit per
  tile) + a sparse collected-gem coord list. Dug ≠ collected (full-hold gems
  stay in the ground — 0003), so both sets persist independently. A
  maximally-explored save is **≈ 8–15 KB** — quota never matters; the risks
  are **eviction** and **context divergence**.
- **Durability:** default storage is best-effort — WebKit's **7-day
  no-interaction cap** is the most likely way a save dies. Mitigations:
  `navigator.storage.persist()` at startup (silent grant on WebKit) and the
  **Add-to-Home-Screen nudge** (§9) — the installed app is **exempt from the
  7-day cap**. The installed PWA and the Safari tab hold **independent**
  storage (one-time copy at install) — which is exactly why the hatch is a
  portable file, not a unification attempt.
- **Safety hatch:** **local export/import now** —
  `JavaScriptBridge.download_buffer()` out, hidden HTML file-input in (with
  a "this replaces your progress" confirm) — behind the single **`SaveBlob`
  seam**: one function serializes the envelope to a `PackedByteArray`, one
  loads it back; local file, export, and any future cloud PUT/GET all
  consume the same bytes. **Cloud backup is deferred, not designed out.**
- **Versioning:** hand-rolled — check `save_version`, run an ordered
  `migrate(dict) -> dict` chain (pure, unit-testable); load defensively
  (missing key → default). Only ever add keys or bump the version.
- **Cadence:** write whole-file snapshots on surface events (arrive, sell,
  upgrade), on run lost, on `visibilitychange → hidden` (the critical one),
  plus an optional low-frequency autosave tick. Never per-dug-tile.

## 14. Build pipeline & CI — from [0004](../tickets/0004-dig-feel-controls.md) / [0011](../tickets/0011-ios-smoke-test.md)

The pipeline already exists and carried two tickets' prototypes
([`.github/workflows/deploy-prototype.yml`](../../.github/workflows/deploy-prototype.yml)):

- `chickensoft-games/setup-godot` (with `include-templates: true`) → headless
  two-pass export (`--import` then `--export-release "Web"`) → single GitHub
  Pages artifact. Builds verify on any branch; **deploy is main-only** (one
  Pages site per repo).
- **The CI headless-run gate is load-bearing:** `godot --headless
  --export-release` compiles-and-packs scripts but never *runs* them — a
  parse error (e.g. calling a later-4.x API that doesn't exist in 4.3) sails
  through a green export and dies on device as a silent grey screen. The gate
  (`godot --headless --quit-after 120` + grep for script errors) makes green
  mean "the scene loaded and ran clean." Keep it for the real game.
- On-device feel testing needs this pipeline (0004's lesson): feel is judged
  by thumb on a phone via the deployed URL, not on desktop.
- The 0004 prototype (at `/`) and 0011 smoke-test harness (at `/smoke/`) are
  **throwaways**: the prototype's stick/floaty/drill core is the reference
  implementation to port, and `smoke-test/` should be deleted once §16's
  profiling task no longer needs it.

---

# Part III — Release

## 15. Monetization & distribution — [0010](../tickets/0010-monetization.md)

*Full detail: [decision note](0010-monetization.md).*

**The game is free; one optional, voluntary support channel — itch.io
pay-what-you-want (min £0).** Chosen for portfolio fit and hands-on learning;
money is incidental. Ads, premium, and IAP/soft-currency are **rejected**
(they'd reopen 0006's no-cash-sink economy, collide with the silent-switch
reality, or need store rails/accounts the web build doesn't have).

- **Distribution is hybrid, GitHub Pages canonical:**
  `fiachramcv90.github.io/gem-mining-game/` stays the canonical build — the
  portfolio address and, decisively, the home of the **installable PWA**
  that protects §13's save-durability path (itch's sandboxed iframe makes
  PWA install unreliable, which is why itch-as-primary lost).
- **itch.io page** = storefront + devlog + the *single* support surface (its
  own tip rails — no Ko-fi/Patreon).
- **The build is touched in exactly one place:** a quiet **"♥ Support / also
  on itch.io"** link on the title / surface-hub screen (§9's census). Never
  mid-run, never a modal, never gated.
- Standing it up (create the itch page, set PWYW, add the link) is small
  downstream execution.

---

# Part IV — Confirm during build

The map's two remaining fog patches are **execution-phase work gated on a
build existing** — carried here as explicit confirm-during-build items with
their known prerequisites, **not** as open decisions. (Also standing:
every default in Appendix A is a knob to tune on-device by feel.)

## 16. On-device memory profiling

**What:** confirm the §12 numbers — the real resident-window size, chunk
budget, and steady-state heap — on a physical iPhone (neither desktop nor
the iOS Simulator reproduces the memory/safe-area behaviour), and verify the
WASM max-memory clamp actually applies.

**Known prerequisite (from [0011](../tickets/0011-ios-smoke-test.md)):
get real web memory instrumentation working first.** The smoke test produced
only a *qualitative* result (no OOM, 60 FPS, 9 resizes, no crash) because
Godot's `Performance.MEMORY_STATIC` reads **0 on the web export** (the WASM
heap is Emscripten-managed) and the `head_include` shim's
`WebAssembly.Memory` capture never fired — so no measured heap number
exists and the 512 MB clamp is unconfirmed. The profiling pass must first
fix the capture (measure the Emscripten WASM heap — the buffer's
`byteLength` via a correct `JavaScriptBridge` hook; `performance.memory` is
Chrome-only and useless on the target) before any resident-window/chunk
number can be trusted. The `smoke-test/` harness is available to build on
until then.

**When:** once a vertical slice with real chunk-streaming exists.

## 17. Playtesting plan

**What:** who plays early builds, and when — including watching the two
onboarding items [0013](../tickets/0013-tutorial-onboarding.md) flags as
assumptions to verify (the ghost line, and the round-trip pulse threshold —
the arrangement assumes 0004's "grasped near-instantly" generalises beyond
its author).

**Known prerequisite:** a build worth handing to people — it couldn't be
phrased sharply on a planning map with nothing to hand out. Define it when a
vertical slice exists; the deployed-URL pipeline (§14) makes distribution to
testers trivial.

---

# Out of scope (locked at charting — returns only as a fresh effort)

- **Native App Store / Play Store release** (avoids the £100 Apple dev
  account; the web build proves the game first).
- **Multiplayer.**
- **Story / NPCs** — depth comes from the upgrade curve, not narrative.
- **More than ~8 gem types at launch** (shipping 6: T1–T5 + prize).

---

# Appendix A — the master knob list

Every tunable, by owner. **All ship as the stated defaults and stay named
`@export` Inspector values** (an `EconomyConfig` / `HazardConfig` `.tres` or
scene exports). Defaults are first drafts to tune on-device.

**Dig feel — [0004](../tickets/0004-dig-feel-controls.md)**
`dig_constant` ~0.34 s/hardness · stick: dynamic origin, trailing base,
dead zone ~16%, throw ~64 px.

**Worldgen — [0005](../tickets/0005-worldgen.md)**
`world_seed` (per-player, saved) · `designed_bottom_depth` ~700 ·
`shaft_width` ~96 · band edges {0, 40, 120, 260, 450, 700} ·
`baseline_hardness[band]` {1,2,3,4,5} · `pocket_hardness_bonus` +1 halo /
+2 prize · `base_gem_density` ~8% · `tier_weight(tier, depth)` moving peak +
tails · `vein_size_range` 2–5 · `prize_spawn_chance(depth)` ·
`cave_frequency(depth)` · `cave_size_distribution` · `tile_px` 16 ·
`chunk_size` 32×32 · `resident_margin` 1 · `chunks_per_frame_budget` ·
`worldgen_memory_target` tens of MB · `pickup_cap` / `particle_cap` ·
`surface_view_radius` · `shrink_rate_per_depth` · `min_floor_radius` ·
`prize_glint_radius`.

**Economy — [0006](../tickets/0006-economy-upgrades.md)**
`gem_value[tier]` {8,15,28,52,95} · `prize_value` 900 ·
`drill_power[0..4]` {0.31,0.62,0.93,1.24,1.55} · `drill_price[1..4]`
{100,280,750,1900} · `fuel_capacity[0..4]` {80,180,380,650,1050} ·
`fuel_price[1..4]` {80,240,640,1600} · `fuel_descent_per_tile` 0.4 ·
`fuel_ascent_per_tile` 1.0 · `fuel_hover_per_tile` 0.15 ·
`fuel_reserve_margin` 0.12 · `cargo_slots[0..4]` {12,20,32,50,75} ·
`cargo_price[1..4]` {120,320,800,2000} · `hull_capacity[0..4]`
{100,150,220,320,450} · `hull_price[1..4]` {90,260,700,1750} ·
`light_darkness_mult[0..3]` {1.0,0.68,0.42,0.25} · `light_price[1..3]`
{150,450,1200} · `hoist_price` 5000 · `hoist_ascent_factor` 0.5 ·
`refuel_cost_per_unit` 0 · `repair_cost_per_hp` 0 (both stay zero — plumbing,
not a plan) · `price_scale` (global) · `surface_hub_seconds` 15.

**Hazards — [0007](../tickets/0007-hazards-depth.md)**
`fall_grace_tiles` 3 · `fall_dmg_per_tile` 4 · `fall_dmg_cap_frac` 0.45 ·
`fall_light_brace_factor` 0.4 · `gas_burst_dmg[band]` {8,14,18,22} ·
`gas_encounter_rate[band]` · `cavein_dmg[band]` {15,25} ·
`cavein_encounter_rate[band]` · `lava_tick_dmg` 5 · `lava_tick_interval`
0.2 s · `lava_glow_radius` · `lava_encounter_rate` ·
`hazard_hit_frac_dark[band]` · calibration targets `hazard_base_per_tile`
0.02 / `hazard_depth_gain` 4.0 (expected-curve anchors, not a live drain).

**Onboarding — [0013](../tickets/0013-tutorial-onboarding.md)**
round-trip pulse threshold multiplier (~1.3× estimated ascent cost) ·
ghost-line backstop ~10 s.

---

# Appendix B — where every decision lives

| # | Ticket | Asset |
|---|---|---|
| 0001 | [Godot 4 foundations](../tickets/0001-godot-foundations.md) | [learning path](0001-godot-foundations-learning-path.md) |
| 0002 | [Web export on iOS Safari](../tickets/0002-web-export-ios-safari.md) | [viability & mitigations](0002-web-export-ios-safari.md) |
| 0003 | [Core loop & failure states](../tickets/0003-core-loop.md) | [core loop](0003-core-loop.md) |
| 0004 | [Dig feel & touch controls](../tickets/0004-dig-feel-controls.md) | [decision](0004-dig-feel-controls.md) · [prototype](../../prototype/) |
| 0005 | [World generation](../tickets/0005-worldgen.md) | [design note](0005-worldgen.md) · [cross-section](0005-worldgen-crosssection.svg) |
| 0006 | [Economy & upgrades](../tickets/0006-economy-upgrades.md) | [design note](0006-economy-upgrades.md) · [`economy-sim/`](../../economy-sim/) |
| 0007 | [Hazards & depth](../tickets/0007-hazards-depth.md) | [design note](0007-hazards-depth.md) |
| 0008 | [Art & audio](../tickets/0008-art-audio.md) | [direction note](0008-art-audio.md) · [moodboard](0008-palette-moodboard.html) |
| 0009 | [Save system](../tickets/0009-save-system.md) | [research](0009-save-system.md) |
| 0010 | [Monetization](../tickets/0010-monetization.md) | [decision note](0010-monetization.md) |
| 0011 | [iOS smoke test](../tickets/0011-ios-smoke-test.md) | [build notes](0011-ios-smoke-test-notes.md) · [`smoke-test/`](../../smoke-test/) |
| 0012 | [Meta-progression](../tickets/0012-meta-progression.md) | [Miner's Log](0012-meta-progression.md) |
| 0013 | [Tutorial & onboarding](../tickets/0013-tutorial-onboarding.md) | [arrangement](0013-tutorial-onboarding.md) |
| 0014 | [Final spec assembly](../tickets/0014-final-spec-assembly.md) | this document |

*Assembled 2026-07-14. The map is complete: no open tickets remain, and the
only unconfirmed items are the two confirm-during-build tasks above — both
execution-phase, neither a design decision.*
