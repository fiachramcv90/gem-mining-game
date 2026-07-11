# Hazards & depth progression — the design note

> Design asset for ticket **0007 — Hazards & depth progression**.
> Audience: Fiachra — solo dev, evenings/weekends, no deadline; new to Godot,
> strong web/TS. Reached by grilling, not decided for him.
> Scope: the *danger* layer — which hazards deplete Hull, how they escalate with
> depth, how darkness/Light gate them, and what a point of hull damage concretely
> *means* (making 0006's placeholder real). **Fixed by 0003** (not relitigated):
> one "run lost" outcome, darkness = a risk multiplier on Hull (not a fourth bar).
> **Fixed by 0005**: caves/voids exist and are placed by 0005 (frequency/size);
> the 5 bands and the darkness base curve are 0005's. **Fixed by 0006**: the Hull
> and Light *price/capacity* ladders — 0007 fills their damage/darkness *benefit*
> **without moving a single price**. **Owned downstream**: hazard art/audio (0008).

## TL;DR

- **Danger is discrete events, not a drain.** Hull damage comes from punctuated,
  telegraphed, *dodgeable* moments (drill a gas pocket → **bang**; fall into a
  cave; trigger a cave-in; breach lava), **not** a smooth per-tile bleed. Their
  *expected* cost-per-tile is calibrated to reproduce 0006's placeholder curve, so
  Hull/Light prices stay valid — but the felt danger is **variance** (a bad blind
  Bedrock moment), never a steady tax.
- **Four hazards, one per trigger mechanism** so they never feel like reskins:
  **Falls** (kinetic drop), **Gas pockets** (dig-triggered burst), **Cave-ins**
  (structural/reactive), **Lava/heat** (contact-over-time).
- **3 danger acts over 0005's 5 bands**, cumulative layer-cake, one new beat per
  band: **Act I "Learning"** (Topsoil falls → Clay + a rare first gas), **Act II
  "The Squeeze"** (Sandstone gas common → Granite + cave-ins), **Act III "The
  Deep"** (Bedrock + lava, everything at max).
- **Darkness = avoidance, not extra damage.** Light lets you *see the telegraph
  and dodge* (gas tell, cave edge, cracking rock); darkness means you drill in
  blind and eat the hit. So darkness scales the **hit probability**, and Light
  buys **sight**. Lava is the fair exception — it *glows*, so darkness barely
  hides it. Same expected value as 0006's `darkness_mult`, better feel.
- **Only Hull and Light mitigate.** Hull soaks the hit; Light buys the dodge.
  Fuel couples *emergently* (a fall drops you deeper → costs more fuel to climb,
  straight out of 0003's round-trip budget — no new system). Drill and Cargo stay
  out of the danger model entirely.
- **Falls are forgiving-but-real**: a 3-tile grace (free), then ~linear with fall
  height, capped at a survivable fraction of *current* Hull (so the cap scales
  with Hull upgrades). Threatens a run, rarely ends it outright.
- **Every number is a named `@export` knob** (continuing 0004/0005/0006's
  discipline). The structure is the decision; the numbers are a first draft to
  tune on-device.

---

## 0. The governing frame (what's fixed, what 0007 owns)

0007 doesn't get to reinvent the failure model — it builds a roster *against* a
frame three earlier tickets already nailed down:

- **0003** — fuel-empty and hull-zero collapse to **one "run lost"** (forfeit
  carried cargo, keep wallet + upgrades, free respawn; no death-spiral). Hazards
  deplete **Hull only**; there is **no fourth failure axis**. Darkness is a **risk
  multiplier on Hull**, not a bar.
- **0005** — caves/voids **exist** as terrain (`cave_frequency(depth)` rising,
  `cave_size_distribution`); 0005 *places* them, 0007 says what falling into one
  *costs*. The darkness **base curve** (`surface_view_radius`,
  `shrink_rate_per_depth`, `min_floor_radius`) is 0005's; 0007 says what
  not-seeing-a-hazard costs. 5 bands, baseline hardness 1→5.
- **0006** — the Hull ladder (`hull_capacity` `{100,150,220,320,450}`) and Light
  ladder (`light_darkness_mult` `{1.0,0.68,0.42,0.25}`) already ship with real
  **prices**. Their damage/darkness *benefit* is a flagged **placeholder** 0007
  makes real: `dmg/tile ≈ hazard_base(0.02) × (1 + 4·depth_fraction) ×
  darkness_mult`. **0007 must not move 0006's prices or capacities** — only fill
  in what a point of hull damage *means*.

So the deliverable is: a small roster, an escalation curve over the bands, a
darkness coupling, and a set of default damage numbers whose **aggregate expected
value tracks 0006's placeholder curve** — leaving the Hull/Light purchase decision
exactly as valuable as 0006 priced it.

## 1. The danger model — discrete events, calibrated to an expected curve

The placeholder 0006 handed over is a *smooth per-tile drain*. We rejected that as
the live model: a slow, unavoidable bleed makes "danger" a tax on depth with no
drama, and it leaves darkness/Light with nothing to *dodge*. Instead:

**Hull damage is punctuated.** You lose Hull in discrete, telegraphed moments you
can (in the light) see coming and avoid. Between those moments, Hull doesn't move.

But the placeholder formula isn't discarded — it's **reinterpreted as the target
expected value**. `hazard_base(0.02) × (1 + 4·depth_fraction)` is read as the
*expected* hull damage per dug tile at zero Light, and the roster's per-hazard
**encounter rates** are tuned so the whole roster *aggregates* to that curve. The
per-band anchors (band-midpoint `depth_fraction`, at no Light):

| Band | Midpoint depth | `depth_fraction` | Expected hull dmg/tile @ L0 |
|---|---|---|---|
| Topsoil   | 20  | 0.029 | **~0.022** |
| Clay      | 80  | 0.114 | **~0.029** |
| Sandstone | 190 | 0.271 | **~0.042** |
| Granite   | 355 | 0.507 | **~0.061** |
| Bedrock   | 575 | 0.821 | **~0.086** |

These are *low* per-tile numbers on purpose: against a 100–450 Hull cap, the
average bleed alone would take hundreds-to-thousands of tiles to matter. **That is
correct** — hull is rarely lost to the average; it's lost to the **spike** (one
bad gas burst or blind fall). The expected curve exists only to keep 0006's
pricing honest; the *variance* around it is where the game lives. Delivering the
same expected value as spikes rather than a trickle is the whole design move.

**Why this preserves 0006's prices.** Hull's value = how much expected damage a
bigger cap lets you absorb before run-loss; Light's value = how much of that
expected damage it removes. Both are functions of the *aggregate expected curve*,
which we hold fixed. The redistribution into spikes changes the *feel* and the
*variance*, not the expectation — so the purchase math 0006 validated still holds.

## 2. The roster — four hazards, four mechanisms

One hazard per distinct trigger mechanism, so each *plays* differently rather than
being a damage-number reskin. This is the "smallest roster that makes depth feel
dangerous" — four is the ceiling, not a floor we padded to.

### 2a. Falls — kinetic drop *(the Act I baseline)*

You drill into one of 0005's voids and gravity takes you; damage lands when you
hit the floor at speed. This is why 0005 built the caves.

- **Grace zone:** drops of **≤ `fall_grace_tiles` (3)** cost nothing — you don't
  get nicked for every little step-down, and shallow play stays pleasant.
- **Scaling:** above the grace, **`fall_dmg_per_tile` (4)** hull per extra tile,
  **~linear** (not quadratic — quadratic + deep caves = brutal one-shots, against
  0003's chill tone).
- **Cap:** total fall damage capped at **`fall_dmg_cap_frac` (0.45)** of *current*
  Hull. The cap is a **fraction of current Hull**, so it scales with Hull
  upgrades — a full plunge is always "a serious but survivable chunk," never a
  guaranteed kill from full.
- **Darkness coupling (via 0004's floaty movement):** a fall is really *"you enter
  a void and can arrest with thrust if you react."* In the **light** you see the
  cave edge and thrust-brace — damage **× `fall_light_brace_factor` (0.4)**, or
  avoided entirely. In the **dark** you don't see the drop, you're still at full
  descent thrust, and you eat it whole. This *is* the avoidance model applied to
  terrain.
- **Depth scaling is free:** falls worsen with depth because 0005's caves get
  bigger and more frequent — no separate depth term needed on the damage.
- **Emergent Fuel sting:** a fall leaves you *deeper than you planned*, so 0003's
  round-trip fuel budget now has to cover a longer climb. Falls cost Hull *and*
  quietly eat your fuel margin — a natural double-pressure with no new system.
- **Godot shape:** no volume needed. On the player `CharacterBody2D`, watch the
  `is_on_floor()` transition and read `velocity.y` at impact; map impact speed →
  fall height → damage. Brace-detection = "was the player applying up-thrust in the
  frames before impact," which is only *possible* if the edge was within the lit
  view radius.

### 2b. Gas pockets — dig-triggered burst *(Act I rare → Act II common)*

A gas-bearing tile that **bursts when drilled**, for an instant Hull spike.

- **Telegraph:** the tile carries a visible tell (discoloured / bubbling —
  0008's look), rendered **only when within the lit view radius**. That "render
  the tell only when lit" rule is *literally* how "Light lets you dodge" is
  implemented.
- **Damage (per burst), by band:** `gas_burst_dmg` = **8 (Clay, the rare "first
  sighting") → 14 (Sandstone) → 18 (Granite) → 22 (Bedrock)**.
- **Darkness coupling:** in the light you see the tell *before* committing the
  dig and route around it — hit rarely. In the dark you drill blind and it bursts
  — hit often. Darkness scales the **probability of drilling into one unseen**,
  not the burst size.
- **Encounter:** `gas_encounter_rate` per band — a rare tail in Clay (the scary
  first sighting, mirroring 0005's gem *tails*), common from Sandstone down. This
  is the primary knob for hitting §1's expected curve in the mid bands.
- **Godot shape:** a **tile custom-data flag** (`hazard_type = gas`) on the
  TileSet, checked in the dig routine right before `erase_cell` — no Area2D, no
  per-frame cost. Consistent with 0005's custom-data approach for `hardness` /
  `gem_type`.

### 2c. Cave-ins — structural / reactive *(Act II, Granite+)*

Digging out the support under unstable rock drops it on you — the "don't tunnel
recklessly" hazard, a tension none of the others carry.

- **Telegraph:** unstable tiles show cracks / trickling dust (0008) when lit; the
  instability is a property you can *read* before you undermine it.
- **Damage:** `cavein_dmg` = **15 (Granite) → 25 (Bedrock)**.
- **Darkness coupling:** lit, you see the cracked rock and back off / shore your
  approach; dark, you undermine it blind and it comes down. Probability, again.
- **Encounter:** `cavein_encounter_rate` per band (Granite+ only).
- **Godot shape (the costliest — flagged for a spike):** the honest version needs
  an "unstable" tile flag plus a *support check* — when a tile is dug, test whether
  a flagged tile above it has lost its support, and if so drop it (spawn a
  short-lived falling `RigidBody2D`, or animate the tile down one cell and apply
  damage on overlap). **Learning-path note:** prototype the support rule on a small
  grid first; it's the one hazard with real gameplay-logic cost, so it's the
  natural candidate to *ship last* if Act II needs to slip.

### 2d. Lava / heat — contact-over-time *(Act III, Bedrock)*

The deep-band signature and the nastiest: a molten pocket or lava-floored cavern
that damages you **while you're in it**. Positional, not instantaneous — you must
*route around* it.

- **Damage:** `lava_tick_dmg` (**5**) every `lava_tick_interval` (**0.2 s**) of
  contact. A clean route-around costs ~0; a careless breach and slow exit is
  **20–40**. The player controls the cost by how they move.
- **Darkness coupling — the fair exception:** lava **glows** (`lava_glow_radius`,
  a self-lit reveal wider than normal tiles — same trick 0005 gives the prize
  gem). So darkness barely hides an *open* lava field: you can see the deep danger
  even in the dark, which makes Bedrock's headline threat *fair* rather than a
  cheap-shot. Light still helps you *judge the safe route* and spot a heat pocket
  still sealed behind rock before you breach it.
- **Encounter:** `lava_encounter_rate` (Bedrock caverns/pockets).
- **Godot shape (the reusable pattern):** an **`Area2D`** covering the lava,
  `body_entered` / `body_exited` to track whether the player is inside, and a
  `Timer` (or accumulator in `_physics_process`) applying `lava_tick_dmg` on each
  tick while overlapping. This is the canonical Godot "hazard volume + damage-over-
  time" pattern — see §5.

## 3. The depth-progression table (band × act × hazards × hull pressure)

The spine of the ticket. Cumulative layer-cake: each row keeps everything above it
and adds one beat. "Expected dmg/tile @ L0" is the §1 calibration anchor; the
"spike range" is the *felt* danger (a single bad event) that the encounter rates
average down into that anchor.

| Band | Act | New this band | Active roster | Exp. dmg/tile @ L0 | Typical bad-moment spike | Feel |
|---|---|---|---|---|---|---|
| **Topsoil**   | **I · Learning**    | tiny falls                     | falls                          | ~0.022 | 0–8   | near-safe; teaches the Hull bar |
| **Clay**      | **I · Learning**    | bigger falls + **rare gas**    | falls, gas(rare)               | ~0.029 | 8–14  | first real scare |
| **Sandstone** | **II · The Squeeze**| **gas common**                 | falls, gas                     | ~0.042 | 12–18 | drill-with-care |
| **Granite**   | **II · The Squeeze**| **+ cave-ins**                 | falls, gas, cave-ins           | ~0.061 | 15–28 | tunnel-with-care |
| **Bedrock**   | **III · The Deep**  | **+ lava**, all at max         | falls, gas, cave-ins, lava     | ~0.086 | 20–48 | everything wants you dead |

- **The acts group the bands into danger chapters** without erasing per-band
  texture: Act I is two bands of *learning* (falls only, then the first gas), Act
  II is two bands of *the squeeze* (gas becomes routine, then cave-ins add
  overhead threat), Act III is Bedrock's *everything at once*.
- **Spike ranges climb faster than the expected value** because deeper darkness
  (0005's shrinking view) raises hit *probability* while Hull upgrades raise the
  *cap* — the two race, which is exactly the Hull-vs-Light purchase tension 0006
  priced.
- **Shallow farming stays safe** (0006's ask): Act I's expected pressure is
  trivial, so a low-Hull player can still farm Topsoil/Clay indefinitely — deep is
  where danger, like reward, concentrates.

## 4. Interactions — what mitigates, what doesn't

| Track | Interacts? | How |
|---|---|---|
| **Hull** | **Yes — soak** | Bigger cap absorbs more spikes before run-loss. The fall cap is a *fraction of current Hull*, so Hull upgrades raise the fall ceiling too. |
| **Light** | **Yes — sight** | Buys the dodge: scales down hit *probability* on falls/gas/cave-ins (`light_darkness_mult`). Barely helps vs lava (it glows). |
| **Fuel** | **Emergent only** | A fall drops you deeper → longer climb → more of 0003's round-trip budget spent. No designed hazard-fuel knob; it falls out of the geometry. |
| **Drill** | **No** | Drill = dig speed (0005/0006 contract). Deliberately *not* a survival stat — keeps the danger model legible and the calibration independent of drill level. |
| **Cargo** | **No** | No greed-punishing coupling — avoids double-punishing (lose the run *and* it was the cargo's fault), which edges toward the death-spiral 0003 designed out. |

**Net:** the shop's danger answer is exactly two tracks — **Hull to survive the
hit, Light to avoid it** — which is the clean pair 0006 already priced. Everything
else about hazards is emergent or out.

## 5. Godot learning notes (continuing the 0001/0004/0005/0006 path)

Hazard-relevant Godot APIs, for a web dev new to the engine. Three of the four
hazards need **no** physics volume; only lava does.

- **`Area2D` = a hazard volume (lava).** An `Area2D` is a non-solid region that
  *detects* overlap without colliding. Give it a `CollisionShape2D`, connect
  `body_entered(body)` / `body_exited(body)` to track whether the player is inside,
  and apply damage on a `Timer` tick (or accumulate in `_physics_process`) while
  inside. This "volume + damage-over-time" shape is the reusable pattern for *any*
  future contact hazard.
- **Collision layers vs masks (the thing that confuses web devs).** Every
  `CollisionObject2D` has **layers** ("what am I") and a **mask** ("what do I scan
  for"). Put hazards on a dedicated *hazards* layer and the player on a *player*
  layer; set the hazard `Area2D`'s **mask** to include the player layer so it
  detects the player (and set `monitoring = true`). Getting layer/mask backwards is
  the classic "my Area2D never fires" bug. Keep a tiny table of your layer bits
  (1 = world, 2 = player, 3 = hazards…) in a comment or an autoload constant.
- **Damage-over-time & i-frames.** A single lava contact shouldn't apply damage
  every physics frame (240+/s) — gate it to `lava_tick_interval` with a `Timer`, and
  consider a short invulnerability window after any spike (falls/gas) so one event
  = one hit, not a stutter of them. This is the web-game "hit cooldown" idea, native
  in Godot as a one-shot `Timer` or an accumulated delta.
- **Tile-flag hazards need no node at all (gas, cave-in instability).** A TileSet
  **custom data layer** (0001/0005) carrying `hazard_type` lets the dig routine
  check a tile's danger the instant before `erase_cell` — zero per-frame cost, and
  it regenerates deterministically from the seed exactly like `hardness`/`gem_type`
  (0005 §5). Prefer this over Area2Ds for anything that triggers *on dig* rather
  than *on contact*.
- **Falls read velocity, not a volume.** On the player `CharacterBody2D`, detect
  the landing via the `is_on_floor()` false→true transition and read `velocity.y`;
  convert impact speed to fall height to damage. "Did the player brace?" = were they
  applying up-thrust beforehand, which is only *reactable* if the drop was within
  the lit view radius — tying fall mitigation to the same darkness system as the
  rest.
- **Telegraphs are a rendering rule, not a mechanic.** "Light lets you dodge" is
  implemented by only drawing a hazard's tell (gas discolour, cave-in cracks) when
  the tile is inside the current view radius (0005's darkness curve). No separate
  "detection" system — the darkness renderer *is* the dodge mechanic.
- **`@export` every knob (§6).** Fold them into the `EconomyConfig` `Resource`
  (0006) or a sibling `HazardConfig` `.tres`, so the whole roster tunes in the
  Inspector by feel — same discipline as every prior ticket.

## 6. Named tunable parameters (the knobs, in one place)

All `@export`-able Inspector values (a `HazardConfig` `Resource`, or added to
0006's `EconomyConfig`). Defaults are a first draft to tune on-device.

**Falls**
- `fall_grace_tiles` — 3 (free drop height).
- `fall_dmg_per_tile` — 4 (hull per tile beyond grace, ~linear).
- `fall_dmg_cap_frac` — 0.45 (cap as a fraction of *current* Hull).
- `fall_light_brace_factor` — 0.4 (damage multiplier when the drop was seen/braced).

**Gas pockets**
- `gas_burst_dmg[band]` — `{Clay 8, Sandstone 14, Granite 18, Bedrock 22}`.
- `gas_encounter_rate[band]` — rare (Clay tail) → common (Sandstone+); primary
  mid-band knob for the §1 expected curve.

**Cave-ins**
- `cavein_dmg[band]` — `{Granite 15, Bedrock 25}`.
- `cavein_encounter_rate[band]` — Granite+ only.

**Lava / heat**
- `lava_tick_dmg` — 5 (per tick).
- `lava_tick_interval` — 0.2 s.
- `lava_glow_radius` — wider than normal reveal (the darkness exception; cf. 0005's
  `prize_glint_radius`).
- `lava_encounter_rate` — Bedrock only.

**Darkness coupling (avoidance)**
- Reuses 0006's `light_darkness_mult` `{1.0,0.68,0.42,0.25}` — now interpreted as a
  scale on hazard **hit probability** (falls/gas/cave-ins), not on damage size.
- `hazard_hit_frac_dark[band]` — base hit chance at L0 per band, rising with depth
  as 0005's view radius shrinks; `light_darkness_mult` multiplies it down.

**Calibration anchors (from 0006, retained as the target — not a live drain)**
- `hazard_base_per_tile` — 0.02, and `hazard_depth_gain` — 4.0: no longer a damage
  *model*, kept as the **expected-dmg/tile curve the encounter rates are tuned
  against** (§1), so 0006's Hull/Light pricing rationale stays traceable.

**Untouched (0006's, listed to be explicit they don't move)**
- `hull_capacity[0..4]` `{100,150,220,320,450}`, `hull_price[1..4]`
  `{90,260,700,1750}`, `light_darkness_mult[0..3]`, `light_price[1..3]`
  `{150,450,1200}`. 0007 changes **none** of these.

## 7. What this clears / hands off

- **0008 (art & audio) inherits the hazard terrain to dress.** Each hazard needs a
  readable *tell* and an impact: gas discolour/bubble + burst, cave-in cracks/dust +
  collapse, lava glow + heat shimmer, fall impact (shake/particles). The
  "telegraph is rendered only when lit" rule (§2/§5) is an art-and-darkness
  interaction 0008 should honour. 0008 was already unblocked, so this *feeds* it,
  it doesn't unblock it.
- **Meta-progression & retention fog gains landmarks.** The **3 danger acts**
  (Learning / The Squeeze / The Deep) are natural milestone pins alongside 0006's
  economy landmarks — "survived first Bedrock lava," "first cave-in dodged,"
  "reached Act III." When that fog graduates to a ticket, the acts are ready-made
  achievement anchors.
- **The 0006 placeholder is now concrete.** `hazard_base_per_tile` /
  `hazard_depth_gain` are re-cast from a live drain into the calibration target for
  a real, spiky, four-hazard roster — so the Hull and Light ladders 0006 priced
  finally buy something real, with **no price or capacity moved**.
- **No numbered ticket is unblocked and no new ticket is surfaced** — 0007 fills a
  placeholder and dresses two fog patches; the danger layer raised no new *open
  decision* that isn't already ticketed (0008) or fogged (meta-progression).

## Sources & basis

- Inherited constraints: [0003 core-loop asset](0003-core-loop.md) (one "run
  lost", darkness = Hull risk-multiplier not a fourth bar, no death-spiral, Fuel is
  a round-trip budget), [0005 worldgen asset](0005-worldgen.md) (caves exist &
  placed here — `cave_frequency`/`cave_size_distribution`; 5 bands; darkness base
  curve; the `prize_glint_radius` self-lit-reveal trick reused for lava),
  [0006 economy asset](0006-economy-upgrades.md) (Hull/Light *prices* fixed; the
  `hazard_base × (1+4·depth_frac) × darkness_mult` placeholder this note replaces),
  [0004 dig-feel asset](0004-dig-feel-controls.md) (floaty movement → a "fall" is a
  thrust-arrestable drop), [0001 foundations](0001-godot-foundations-learning-path.md)
  (`CharacterBody2D`, TileSet custom data layers, autoloads).
- Godot APIs: `Area2D` (`body_entered`/`body_exited`, `monitoring`), collision
  layers/masks, `Timer`, `CharacterBody2D` (`is_on_floor`, `velocity`), TileSet
  custom data layers — official Godot 4 docs (`docs.godotengine.org`), consistent
  with the 4.3+ floor from 0001.
- Reached by a `/grilling` session with Fiachra (breadth-then-depth: danger model →
  act count → roster → hazard-to-band mapping → darkness coupling → track
  interactions → fall character → converge on defaults). Every number is a default
  to tune on-device, per the standing "name knobs, don't over-specify curves"
  preference; the named-knob list (§6) is the load-bearing output, the numbers its
  first draft.
