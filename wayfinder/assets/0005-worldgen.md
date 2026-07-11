# World generation — the design note

> Design asset for ticket **0005 — World generation design**.
> Audience: Fiachra — solo dev, evenings/weekends, no deadline; new to Godot,
> strong web/TS. Reached by grilling, not decided for him.
> Scope: the *shape of the mine* and every tunable that shapes it — strata,
> gem distribution, caves, determinism, chunk-streaming, the darkness curve.
> **Not** gem values or upgrade curves (0006), the hazard roster or fall-damage
> tuning (0007), art/audio (0008), or the save serialization format (0009 — but
> this note states the determinism requirement 0009 inherits). Chunk-streaming
> being *mandatory* is settled by 0002/0003; this note sets the numbers.

## TL;DR

- **Bounded-but-extensible mine.** A designed bottom (~700 tiles) for the
  vertical slice, but hardness and gem distribution are **functions of depth**,
  so extending deeper later is a tuning change, not a redesign.
- **5 identity bands** — Topsoil → Clay → Sandstone → Granite → Bedrock — each a
  name + a baseline-hardness range + a signature gem tier.
- **Frontier-resistance feel.** The hardness-by-depth function is 0005's; it
  *declares the target effective drill-time band* (frontier ~1.0–1.3 s,
  already-conquered rock ~0.3–0.5 s) as a **requirement 0006's drill-power curve
  must satisfy**. Resistance lives at the frontier; travel through beaten rock is
  fast.
- **Gems = overlapping tiers with tails**, seated in **2–5-tile veins wrapped in
  a +1-hardness halo** (the halo is the telegraph — you *feel* a find before you
  see it). Base density ~8%, roughly flat with depth; deeper pays more via
  *tier*, not density.
- **One seeded prize gem** — top value, outside the tier curve, hard singleton
  nodule, a glint that shines wider than anything else through the dark. This
  *is* 0003's glimpsed-prize hook.
- **Sparse caves/voids**, more common and larger with depth — terrain for
  fall-damage and hazard homes (rules → 0007).
- **Deterministic:** per-player world seed saved at new-game; a chunk's undug
  content is a pure function of `(seed, chunk_x, chunk_y)`; the save stores only
  dug/collected **deltas** (0009's format).
- **Chunk-streaming with a bounded resident window** — the one non-negotiable.
  Resident tile count is **constant regardless of depth**: floor 500 costs the
  same memory as floor 5.

---

## 1. Extent & framing — bounded now, extensible later

The mine has a **designed bottom at ~700 tiles** (~11,200 px at 16 px tiles) for
the vertical slice — a "core" payoff and a visible long-term goal for the
upgrade ratchet (0003). But the canonical thing is **not** that number: it's that
**hardness(depth) and gem-distribution(depth) are expressed as functions**, so
moving the bottom deeper later is a tuning change, never a redesign.

Why this over a hard-infinite mine: it fits every standing constraint — the
smallest design that answers the question (a finite, playtestable band list),
while the function-of-depth discipline keeps the door open. A known bottom also
gives the persistent-shaft hook (0003) a finish line without committing to
authoring infinite content.

**The shaft is bounded in width** (~96 tiles), walled by unbreakable bedrock. It
reads as *a mine*, not an infinite plane, and bounds sideways wandering.

## 2. Strata — 5 identity bands

Each band is a *place* you descend into (name + look + signature gems), not just
a hardness step — this strengthens the "persistent shaft is progress made
physical" hook (0003) and gives gems natural homes. Starting table (all values
are **defaults to tune on-device**; the hardness-by-depth *function* underneath
is canonical, per §1):

| Band | Depth (tiles) | Baseline hardness | Characteristic gem tier |
|---|---|---|---|
| **Topsoil**   | 0 – 40    | 1 | Tier 1   |
| **Clay**      | 40 – 120  | 2 | Tier 1–2 |
| **Sandstone** | 120 – 260 | 3 | Tier 2–3 |
| **Granite**   | 260 – 450 | 4 | Tier 3–4 |
| **Bedrock**   | 450 – 700 | 5 | Tier 4–5 |

Band names are placeholder-flavour — swap freely; their job is identity. Adding a
6th band later = extend the function past 700 (§1).

## 3. The hardness curve & the frontier-resistance model

0004 established that **hardness is the primary texture of the dig** and drill
time = `hardness × ~0.34 s`, with a satisfying band of **~0.3–1.5 s**. If hardness
just climbed with depth and nothing else moved, Bedrock would take many seconds
per tile — miserable. The band is held by **two curves moving together**: hardness
rising with depth (this note) and drill power rising with upgrades (0006).

**The feel model is frontier-resistance.** Rock *at your current frontier depth*
(the deepest your drill comfortably handles) sits near the **top** of the band
(~1.0–1.3 s: push-through resistance where the discovery is); rock you've already
upgraded past drills **fast** (~0.3–0.5 s), so flying back up through your own
conquered shaft is quick. This matches a persistent mine, where you're constantly
travelling through beaten rock, and it makes the glimpsed-prize land harder — the
prize is past the frontier, in rock right at the top of your comfortable band.

**The contract with 0006:** 0005 owns `hardness(depth)`. 0005 *declares the
target effective-drill-time band* (frontier ~1.0–1.3 s, conquered ~0.3–0.5 s) as
a **requirement 0006's drill-power curve must keep the player inside**. We set the
shape and the target; 0006 sets its own numbers to keep pace. Neither ticket owns
both curves — they're coupled by this stated band.

**Effective drill time** ≈ `hardness(depth, pocket) × dig_constant /
drill_power(upgrades)`, where `dig_constant ≈ 0.34 s` (0004) and
`drill_power` is 0006's. 0005 supplies the numerator; 0006 supplies the
denominator to hold the band.

## 4. Gem distribution

### 4a. Tier-by-depth — overlapping tiers with a moving peak

Not hard gates. Each band has a **characteristic (dominant) tier that peaks
there**, with **tails**: lower tiers thin out but still appear deep (a lucky
low-tier find), and the next tier up appears rarely *before* its home band (the
"first Tier-4 sighting" treat). Every depth has a dominant gem plus a small chance
of something above or below its station — that unpredictability is exactly the
dopamine beat 0003 wants runs to end on. Implementation is a per-tier spawn weight
that peaks at the tier's home depth and falls off with distance from it.

**Expected value per dug tile rises with depth — but gently.** Deeper must pay
better (or why descend), while shallow farming stays viable-but-inferior so the
pull down is real without being punishing. The rise comes from the *tier* curve,
**not** from density (§4b).

### 4b. Pockets, veins & density — what a "find" physically looks like

Gems sit *inside harder rock* so resistance and reward coincide (0004):

- **Veins:** a gem is a small cluster of **2–5 same-tier tiles**, wrapped in a
  **halo of +1-hardness rock**. Drilling toward one, the rock gets noticeably
  harder — that hardness spike is the **telegraph**: you *feel* a find before you
  see it, then break through into the cluster.
- **Density:** gem-bearing tiles stay **sparse (~8% of tiles) and roughly flat
  with depth**. If density ballooned deep down, the hold would fill instantly and
  cargo pressure (0003) would collapse; deeper payoff is *tier*, not *count*.
- **Cap pickups & particles** so a rich vein can't spawn hundreds of nodes at
  once (memory — §6).

See the illustrative cross-section:
[`0005-worldgen-crosssection.svg`](0005-worldgen-crosssection.svg) (colours/shapes
are placeholder; the *structure* — bands, sparse veins in hard halos, one prize
nodule, visible tails — is the point).

### 4c. The prize gem = the glimpsed-prize hook (unified)

0003 asked worldgen to *deliberately place glimpsed prizes* so runs end on a hook.
Rather than three mechanisms (tier curve + a separate wildcard + a separate
glimpsed-prize system), it's **one seeded prize gem**:

- **Top value, outside the normal tier-by-depth curve**; low spawn chance that
  **scales up a little with depth**.
- Seated as a **hard singleton nodule (+2 hardness over baseline)** — the hardest
  single tile around it, so resistance and the top reward coincide maximally
  (0004).
- **A glint that reveals wider than any other tile through the dark** (§7) — you
  catch it right at or just past the edge of vision, exactly when you're deep and
  low on fuel. *That* is the glimpsed-prize: you see it, turn back, and it's the
  reason for the next run.
- "Random placement" means **seeded-pseudorandom** (§5): unpredictable to the
  player, fixed for a given world.

## 5. Determinism — seed + pure-function generation

The persistent mine (0003) must regenerate **identically** on reload, and 0002's
memory ceiling forbids serialising the whole (unbounded) world. So:

- **One per-player world seed**, generated once at new-game and **saved**. Each
  player carves their own unique mine — more ownership of "my shaft" (0003).
- **A chunk's original, undug content is a pure function of
  `(world_seed, chunk_x, chunk_y)`** — fed into seeded noise (Godot's
  `FastNoiseLite`, which takes a `seed`) plus hashing for gem/cave placement.
  Any chunk regenerates identically, any time, from nothing.
- **The save stores only the deltas** — which tiles the player has dug and which
  gems collected — a set bounded by *progress*, not by world size. **0009 owns the
  serialization format**; 0005 states the requirement it must meet: *regenerate
  from seed, then re-apply the dug/collected deltas.*

This is the model that makes the persistent mine simultaneously **streamable**
(§6, freed chunks come back cheap) and **cheap to save** (0009).

## 6. Chunking & streaming — the bounded resident window

**The one non-negotiable commitment** (0002/0003): steady-state memory must stay
low and **bounded regardless of depth**, because 0002 found a *default empty*
Godot export already sits near the danger zone (~400 MB hosted heap can trigger
"WebGL context lost" on iOS Safari 16.2). A naïvely-retained, ever-deepening
`TileMapLayer` is exactly the "floor 7 exceeds what floor 1 fit because you never
released floor 3" failure mode. The counter:

| Parameter | Default | Notes |
|---|---|---|
| **Tile size** | 16 px (logical) | Ultimately 0008's art call; everything below is in *tiles*, so it's px-independent. |
| **Chunk size** | **32 × 32 tiles** (1024 tiles) | Big enough to avoid thousands of chunk objects; small enough to free at fine granularity. |
| **Resident set** | camera view **+ 1-chunk margin ring** | Load-ahead so no seam pops in. ≈ a 5×5-ish chunk window, ~25k tiles resident. |
| **Free policy** | free everything beyond the margin | Release tiles, collision, and pickups. **Resident count is constant with depth.** |
| **Re-entry** | regenerate from seed + re-apply deltas (§5) | Freeing is safe because coming back is cheap and deterministic. |
| **Generation** | incremental, a few chunks/frame max | Single-threaded (0002) — a bursty full-chunk gen would hitch the framerate. |
| **Shaft width** | **~96 tiles**, bedrock-walled | Bounds sideways wandering; reads as a mine (§1). |
| **Steady-state footprint** | worldgen resident = a few tens of MB | Total stays low-hundreds, under the danger zone. Cap particles/pickups. |

The specific 32 / margin-1 / 96-wide numbers are sensible starting values to tune
on-device. The load-bearing rule is **"resident set = a fixed window, everything
else freed"** — that is the hard requirement, not the exact numbers.

## 7. Darkness — the view-radius-by-depth curve

0003 settled *what* darkness is: a shrinking view radius with depth that acts as a
**risk multiplier on hull** (unseen hazards do more damage), bought back by the
Light upgrade (0006 owns the upgrade). 0005 owns the **base curve's parameters**:

- **View radius = generous at the surface, shrinking with depth toward a non-zero
  floor** (~a couple of tiles minimum). Never literally blind — blind-blind is
  frustrating, not scary. Roughly **linear** shrink across the bands is the
  simplest shape.
- **Named knobs:** `surface_view_radius`, `shrink_rate_per_depth`,
  `min_floor_radius`.
- **Glint coupling:** the prize gem (§4c) gets a **larger reveal radius than
  normal tiles** — it shines further through the dark than anything else, so it's
  catchable right at the edge of vision. This asymmetry is what manufactures the
  glimpsed-prize moment.
- The Light upgrade (0006) pushes the whole curve back out; 0005 defines the base
  curve it operates on.

Darkness also interacts with **caves** (§8): an open dark cavern you can't see
across is real tension, and the natural stage for a prize glint on the far side.

## 8. Caves & voids

The generator seeds **sparse open space**, more common and larger with depth:

- **Named knobs:** `cave_frequency(depth)` (rising), `cave_size_distribution`
  (mostly small air gaps, the occasional larger cavern).
- Kept **sparse** on purpose — a mine that's mostly holes stops feeling like solid
  earth you conquer.
- Caves do three jobs: they're **the terrain that enables fall damage** (you break
  into a cavern and drop — the fall-damage *tuning* is 0007's, but 0005 guarantees
  the voids exist), they sharpen **darkness** tension (§7), and they're natural
  **homes for gem clusters and hazards** (0007).

Generation approach: a second noise channel (thresholded `FastNoiseLite`, seeded
per §5) carves cells to empty where it exceeds a depth-scaled threshold — same
deterministic, pure-function-of-coords machinery as the rock, so caves reload
identically too.

## 9. Named tunable parameters (the knobs, in one place)

Everything a future balancing pass touches, gathered for reference. All are
`@export`-able Inspector knobs (0001) or seed-time constants.

**Extent & strata**
- `world_seed` — per-player, saved at new-game (§5).
- `designed_bottom_depth` — ~700 tiles (§1).
- `shaft_width` — ~96 tiles (§1/§6).
- Band edges: `{0, 40, 120, 260, 450, 700}` tiles (§2).
- `baseline_hardness[band]` — `{1,2,3,4,5}` (§2).

**Hardness / drill feel**
- `dig_constant` — ~0.34 s/hardness (from 0004).
- Target effective-drill-time band — frontier ~1.0–1.3 s, conquered ~0.3–0.5 s
  (§3; the requirement handed to 0006's `drill_power` curve).
- `pocket_hardness_bonus` — +1 (vein halo), +2 (prize nodule) (§3/§4).

**Gems**
- `base_gem_density` — ~8% of tiles, ~flat with depth (§4b).
- `tier_weight(tier, depth)` — moving-peak curve with tails (§4a).
- `vein_size_range` — 2–5 tiles (§4b).
- `prize_spawn_chance(depth)` — low, rising gently with depth (§4c).
- `pickup_cap` / `particle_cap` — memory guard (§4b/§6).

**Caves**
- `cave_frequency(depth)` — rising (§8).
- `cave_size_distribution` (§8).

**Streaming**
- `tile_px` — 16 (§6, 0008's call).
- `chunk_size` — 32×32 tiles (§6).
- `resident_margin` — 1 chunk beyond view (§6).
- `chunks_per_frame_budget` — incremental gen cap (§6).
- `worldgen_memory_target` — a few tens of MB resident (§6).

**Darkness**
- `surface_view_radius`, `shrink_rate_per_depth`, `min_floor_radius` (§7).
- `prize_glint_radius` — wider than normal reveal (§4c/§7).

## 10. Godot learning notes (continuing the 0001/0004 path)

Worldgen-relevant Godot APIs, for a web dev new to the engine:

- **`FastNoiseLite`** is the built-in noise resource. Set `.seed`, `.noise_type`
  (Perlin/Simplex/etc.), and `.frequency`; call `get_noise_2d(x, y)` → a value in
  ~[-1, 1]. **Determinism (§5) is just "same seed + same coords → same value"**,
  so derive rock hardness, gem rolls, and cave carving from noise/hashes keyed on
  cell coords — never from `randf()` at runtime, which wouldn't reload identically.
  Use a cheap integer hash of `(seed, x, y)` for discrete rolls (gem/no-gem, which
  tier) and thresholded noise for continuous fields (hardness, caves).
- **TileMapLayer chunk pattern.** There's no built-in streaming — you build it. The
  common shape: keep a dictionary of loaded chunks keyed by `Vector2i` chunk coord;
  each frame, compute which chunk coords fall inside the camera + margin window;
  **load** (generate cells via `set_cell`, apply saved deltas) any newly-needed
  chunk and **free** (`erase` its cells / release its data) any that dropped out of
  the window. Spread generation across frames (a per-frame budget) because it's
  single-threaded (0002). One `TileMapLayer` can hold the whole visible window —
  you're adding/removing *cells* within it by chunk, not instancing a node per
  chunk (though a node-per-chunk approach also works and can be simpler to free).
- **`erase_cell` + collision** updates automatically (0001), so freeing a chunk's
  cells also drops its collision — which is where most of the per-tile memory
  actually goes. Freeing is what keeps §6's footprint bounded.
- **Custom data layers** (0001) carry `hardness` and `gem_type` per tile — but with
  procedural generation you can *also* compute them on the fly from the seed rather
  than baking every cell, keeping the authored TileSet to one entry per visual
  rock/gem type rather than per world position.
- **`@export` the knobs** (§9): surfacing band edges, densities, and chunk sizes in
  the Inspector is what turns this note's numbers into things you tune by feel
  on-device (0004's lesson) without editing code.

## 11. What this clears / hands off

- **Performance-budget fog (0002/0003) → tightened with real numbers.** No longer
  "we'll profile later": 32×32 chunks, a bounded resident window (camera + 1-chunk
  margin), freed-beyond-window, ~96-tile shaft, worldgen resident footprint in the
  tens of MB. The **bounded-resident-window** rule is the concrete form of the
  "stream and free" hard requirement. Still needs on-device profiling to confirm
  the exact window size, but the shape and targets are now set.
- **0006 (economy & upgrades)** inherits: (a) the **drill-time band contract** —
  its `drill_power` curve must keep effective drill time in ~0.3–1.5 s across the
  descent (frontier ~1.0–1.3 s); (b) the **tier structure** gems sit in (values are
  0006's to assign, positions are fixed here); (c) the **Light upgrade** operates on
  §7's base darkness curve; (d) expected-value-per-tile rises gently with depth, so
  upgrade costs should track that.
- **0007 (hazards & depth)** inherits: **caves/voids exist** as the terrain for
  fall damage and hazard homes (0005 provides frequency/size; 0007 owns fall-damage
  tuning and the hazard roster), and **darkness-as-risk-multiplier** with §7's
  concrete curve to build against.
- **0009 (save system)** inherits a hard requirement: **regenerate from
  `world_seed` + re-apply dug/collected deltas** — do *not* serialize the whole
  world. The seed itself must be saved. 0009 owns the delta format.
- **0008 (art/audio)** inherits the tile-size knob and the 5 named bands (each
  wants a distinct look) plus the prize-gem glint (a distinct shine).

No new decisions surfaced that aren't already ticketed or fogged, so this
resolution creates no new tickets — it sharpens existing fog and feeds
downstream tickets.

## Sources & basis

- Inherited constraints: [0004 dig-feel asset](0004-dig-feel-controls.md)
  (hardness texture, ~0.34 s/unit, 0.3–1.5 s band, gems-in-hard-pockets),
  [0003 core-loop asset](0003-core-loop.md) (persistent mine, glimpsed-prize hook,
  darkness = view-radius-by-depth risk multiplier),
  [0002 web-export asset](0002-web-export-ios-safari.md) (memory is the binding
  iOS-Safari ceiling → stream-and-free mandatory),
  [0001 foundations asset](0001-godot-foundations-learning-path.md)
  (`TileMapLayer` + `erase_cell`, custom data layers, autoloads).
- Godot noise/tilemap APIs: `FastNoiseLite`, `TileMapLayer`
  (`set_cell`/`erase_cell`/custom data) — official Godot 4 docs
  (`docs.godotengine.org`), consistent with the 4.3+ floor from 0001.
- Reached by a `/grilling` session with Fiachra (11 questions, breadth-then-depth);
  every number here is a **default to tune on-device**, per the standing "name
  knobs, don't over-specify curves" preference.
