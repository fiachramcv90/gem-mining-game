# Economy & upgrade curve — the design note

> Design asset for ticket **0006 — Economy & upgrade curve**.
> Audience: Fiachra — solo dev, evenings/weekends, no deadline; new to Godot,
> strong web/TS. Reached by building a simulation and reacting to the curve, not
> decided in the abstract.
> Scope: the *money loop* — gem values, the upgrade tracks and their
> price/benefit curves, and first-hour pacing. **Fixed by 0005** (not 0006's to
> move): band edges, baseline hardness, gem tier structure & positions, ~8%
> density, `dig_constant` 0.34 s, halo +1 / prize +2. **Owned by 0007** (modelled
> here only as a flagged placeholder): the hazard roster, so the *benefit* tuning
> of Hull and Light. **Settled by 0003** (not relitigated here): refuel/repair is
> free, modelled as cost-pinned-to-zero; a lost run costs only carried cargo (no
> death-spiral).

## TL;DR

- **The verdict is "these are good launch defaults — keep them all configurable."**
  Every number below ships as a starting value and stays a named, `@export`-able
  Inspector knob (continuing 0004/0005's discipline). Re-balancing later is a
  slider drag, never a code change. **That principle is the real decision;** the
  specific numbers are the first draft it was validated against.
- **Gem values rise by tier**, not by density (0005 keeps density flat): T1 **8**,
  T2 **15**, T3 **28**, T4 **52**, T5 **95**, prize **900** (off the tier curve).
- **Expected value per dug tile rises ~7× from Topsoil to Bedrock** — a gentle,
  monotonic pull downward. Shallow farming stays *viable-but-inferior* (deep pays
  ~1.8× per **minute**, not 7×, once the longer round-trip is counted).
- **Five upgrade tracks + one luxury:** Drill, Fuel, Cargo, Hull, Light, and an
  aspirational **Hoist** (fast-travel). Each is a short ladder of ~4–5 levels with
  a roughly-geometric price curve.
- **The Drill track holds 0005's contract:** its power curve keeps baseline
  effective drill-time inside 0.3–1.5 s across the whole descent, one band parked
  at the ~1.1 s frontier per level.
- **First hour:** first upgrade ~run 3 (~4½ min), steady ratchet to mid-Sandstone
  by 60 min, Bedrock ~run 19, the 700 t bottom **still unreached after 20 runs** —
  it stays the aspirational goal (0003's one-more-run hook).
- **Validated by a throwaway simulation**, not by intuition — see
  [the interactive console](https://claude.ai/code/artifact/8b0a93aa-b680-4b11-9a92-217037ae2469)
  and [`economy-sim/`](../../economy-sim/).

---

## 0. The governing principle — every value is a knob

The standing constraint ("name knobs, don't over-specify curves") and 0005's
precedent (all worldgen numbers are on-device tunables) carry straight through:
**0006 fixes the *shape* of each curve and the *coupling* between them, and ships
first-draft numbers as defaults — but every number is exposed for tuning by
feel.** Fiachra reacted to the simulated curve, judged the defaults good enough
to build against, and asked that they all remain configurable. So the deliverable
is two things: (a) a coherent set of default values that make the ratchet turn at
a pleasant pace, and (b) the named-knob list (§8) that makes re-tuning cheap.

Nothing below is a commitment to a *number*; it's a commitment to a *structure*
with a sensible default in it.

## 1. Gem values — by tier, off-curve prize

Gem tier structure and positions are 0005's; 0006 assigns the **values**. Deeper
pays more through *tier*, never density (0005 holds density ~flat, or cargo
pressure collapses).

| Gem | Tier 1 | Tier 2 | Tier 3 | Tier 4 | Tier 5 | **Prize** |
|---|---|---|---|---|---|---|
| **Default value** | 8 | 15 | 28 | 52 | 95 | **900** |

- The tier-to-tier ratio is ~1.8×. Gentle enough that a lucky low-tier-deep or
  first-sighting-of-a-high-tier find (0005's tails) is a pleasant surprise, not a
  jackpot that breaks the curve.
- **The prize gem sits off the tier curve at ~900** — ~9.5× a Tier-5 gem, ~10× a
  whole ordinary hold early on. Rare, depth-scaled (0005), a single nodule. It is
  the glimpsed-prize lottery: one prize can nearly triple a run's haul (seen at
  sim runs 16 & 18). Knob: `prize_value`.

### 1a. Expected value per dug tile (the curve Fiachra reacted to)

EV/tile = density × Σ(tier_weight(band) × value). With 0005's moving-peak tier
weights and 8% density, the default values give:

| Band | Topsoil | Clay | Sandstone | Granite | Bedrock |
|---|---|---|---|---|---|
| **$ / dug tile** | 0.77 | 1.10 | 1.92 | 3.35 | 5.45 |

- **~7.1× Topsoil→Bedrock, rising monotonically** — 0005 asked for "rises gently";
  7× over the *whole* 700-tile descent reads as gentle in play (≈+2% per 10 tiles
  of depth on average). Accepted as default; `gem_value[tier]` is the knob if it
  ever feels too greedy.
- **It's a staircase** (flat within a band, stepping between) because the tier
  weights are per-band. This is deliberate and fine: within a band your incentive
  to push deeper is the *next band's* jump plus the rising prize chance, not a
  within-band ramp. If a smoother within-band ramp is ever wanted, it's a tweak to
  0005's `tier_weight(tier, depth)` (0005's knob), not a 0006 change.

### 1b. Shallow-farming check — viable but inferior

Per **minute** (not per tile — the honest metric, since deep runs are longer
round-trips), the default economy yields roughly: Topsoil ~26, Clay ~27,
Sandstone ~32, Granite ~39, Bedrock ~46 $/min. Deep is ~1.8× shallow per minute —
**the pull down is real without making shallow farming pointless** (0005's ask).
The 7× per-tile gap compresses to ~1.8× per-minute once fuel/travel time is paid.

## 2. The upgrade tracks

Each track is a short ladder. Levels are **L0 (starting kit, free) → L4** except
Light (**L0 → L3**). Prices climb ~2.5×/level: the ratchet asks for a couple of
runs at your current depth to afford the next capability, which then opens the
next-deeper band that pays for the one after — the self-funding loop 0003 wants.

### 2a. Drill — the contract-holding track

Drill power is a **divisor**: `effective_drill_time = hardness × 0.34 / power`.
The curve is tuned so each level parks one band's baseline at the ~1.1 s frontier.

| Level | L0 | L1 | L2 | L3 | L4 |
|---|---|---|---|---|---|
| **`drill_power`** | 0.31 | 0.62 | 0.93 | 1.24 | 1.55 |
| **Price** | — | 100 | 280 | 750 | 1900 |
| Frontier band @ ~1.1 s | Topsoil | Clay | Sandstone | Granite | Bedrock |

**This track holds 0005's drill-time-band contract.** Baseline rock across the
descent stays in 0.3–1.5 s, with the band you're currently pushing at ~1.0–1.3 s
and shallower conquered rock faster. Two deliberate consequences to keep, not
"fix":

- **The between-band step is a soft cliff, not a slope.** At a given drill level,
  the *next* band's baseline is well over the 1.5 s ceiling (Clay is 2.19 s at L0).
  You don't grind a band early — you buy the drill that opens it. This *is*
  frontier-resistance (0005): resistance lives at the frontier, and the drill
  upgrade is what moves your frontier. It also makes Drill the primary depth-gate,
  which keeps the ratchet legible ("I need a better drill to go deeper").
- **Halo/prize tiles poke above the ceiling on purpose.** A +1 halo tile at your
  frontier runs ~1.6–2.2 s; a +2 prize nodule ~2–2.7 s. These are the *telegraph*
  and the *grind-for-the-prize* (0005/0004) — intentional resistance spikes on
  1-few tiles, not a contract breach. The contract governs **baseline** rock.
  (Shallow halos are punchiest — a +1 in Topsoil doubles the time — which nicely
  makes early veins feel like a real event.)

Knobs: `drill_power[level]`, `drill_price[level]`.

### 2b. Fuel — the round-trip / depth-reach gate

Fuel is the round-trip budget (0003). It co-gates depth with Drill: Drill decides
whether you *can dig* the rock at depth; Fuel decides whether you can *get home*.

| Level | L0 | L1 | L2 | L3 | L4 |
|---|---|---|---|---|---|
| **`fuel_capacity`** | 80 | 180 | 380 | 650 | 1050 |
| **Price** | — | 80 | 240 | 640 | 1600 |

- Consumption (knobs): descent **0.4** /tile, **ascent 1.0** /tile (climbing costs
  more — that asymmetry is what makes ascent a real budget line), hover-while-
  drilling **0.15** /tile-dug. Reserve margin **12%** kept spare.
- Capacities are tuned so each level's safe round-trip reaches roughly the next
  band's floor, keeping Fuel and Drill in step. When they drift apart the sim's
  "why home" column shows `fuel` or `drill` as the limiter — the greedy player buys
  to relieve whichever bites.

### 2c. Cargo — the greed cap

Cargo is measured in **slots** (one gem = one slot, any tier). Full hold = soft
fail (0003): collection stops, pulling you home with a full, valuable hold.

| Level | L0 | L1 | L2 | L3 | L4 |
|---|---|---|---|---|---|
| **`cargo_slots`** | 12 | 20 | 32 | 50 | 75 |
| **Price** | — | 120 | 320 | 800 | 2000 |

- Deliberately **not** the early limiter — early runs are short (fuel/drill-bound)
  and don't fill 12 slots. Cargo becomes the binding pressure once you can reach
  deep, where gems are valuable and the hold fills before the reserve line — the
  "greedy but I must bank this" pull (sim runs 6, 17, 20 turn back on `cargo`).

### 2d. Hull — the risk cap  *(benefit tuning = 0007's placeholder)*

Hull is depleted by hazards. **0007 owns the hazard roster**, so the damage model
here is a flagged placeholder that exists only so Hull and Light have a shape to
price against.

| Level | L0 | L1 | L2 | L3 | L4 |
|---|---|---|---|---|---|
| **`hull_capacity`** | 100 | 150 | 220 | 320 | 450 |
| **Price** | — | 90 | 260 | 700 | 1750 |

- Placeholder damage model (0007 will replace): expected hull dmg/tile ≈
  `hazard_base(0.02) × (1 + 4 × depth_fraction) × darkness_multiplier`. The
  *prices/capacities* are real 0006 knobs; the *damage curve* is a stand-in.

### 2e. Light — buys back darkness  *(benefit tuning = 0007's placeholder)*

Light pushes 0005's darkness curve back out; here it lowers the darkness multiplier
on hull damage (0003: darkness is a risk multiplier, not a fourth bar).

| Level | L0 (none) | L1 | L2 | L3 |
|---|---|---|---|---|
| **`light_darkness_mult`** | 1.00 | 0.68 | 0.42 | 0.25 |
| **Price** | — | 150 | 450 | 1200 |

- Only a shorter L0→L3 ladder — darkness is one axis, not a whole reach curve.
  Same placeholder caveat as Hull: prices are real, the darkness→damage coupling is
  0007's to make concrete.

### 2f. Hoist — the aspirational luxury

0003 named a fast-travel/hoist as a *deferred upgrade*, not base loop. Modelled as
a single big-ticket sink:

- **`hoist_price` = 5000** (≈ the whole early game's savings) — a genuine
  aspirational goal, the thing a fat wallet finally buys.
- Benefit: **halves ascent fuel and ascent time** (`hoist_ascent_factor = 0.5`) —
  it makes the climb home from a beaten shaft cheap, without touching the descent
  or the turn-back tension of the frontier. Only surfaces in the shop once Drill,
  Fuel and Cargo are deep (it's a late luxury, not an early skip).

## 3. Pacing — how the ratchet turns (the first hour)

The simulation runs a **transparent greedy miner** (relieve the limiter, keep
Drill+Fuel in step, buy Cargo when the hold keeps filling, Hull/Light for
survival) — deliberately *not* a clever optimiser, so the pace you see is the
economy's, not an AI's. Against the defaults (fixed luck seed):

- **First upgrade at run 3 (~4½ min).** ~2–3 short Topsoil runs fund the first
  Drill — the ratchet starts turning almost immediately.
- **Steady climb:** Clay by run ~5, Sandstone by run ~13, **mid-Sandstone (243 t)
  by the 60-minute mark** across ~17 runs.
- **Granite at run 18, first Bedrock at run 19.**
- **The 700 t bottom is *not* reached in 20 runs** — it stays the long goal, and
  the prize gem stays mostly below the frontier. This is 0003's "glimpsed prize /
  one more run" landing in the numbers.
- **Early runs are short (1½–3 min), deep runs longer (10–15 min).** Accepted as
  the intended rhythm — quick satisfying loops early, meatier committed descents
  late. `surface_hub_seconds`, fuel/cargo caps, and prices are the knobs if the
  early cadence ever feels too choppy.

Master pacing knob for later: scale all `*_price` arrays together (the sim exposes
this as "All prices ×") to slow or quicken the whole ratchet without touching
relative balance.

## 4. The refuel-cost-pinned-to-zero knob (inherited from 0003)

0003 requires refuel/repair to be **free**, but modelled as a cost *currently
pinned to zero* so a Motherload-style per-run fuel sink is a later tuning change,
not a refactor. 0006 keeps that: `refuel_cost_per_unit = 0`, `repair_cost_per_hp =
0` exist as knobs, unused. 0006's recommendation is to **leave them at zero** —
the whole economy already lives in the permanent-upgrade ratchet (0003), and a
per-run cash drain risks the death-spiral 0003 designed out. They stay as plumbing,
not a planned feature.

## 5. Named knobs, in one place

Everything a future balancing pass touches (defaults in §1–2). All are
`@export`-able Inspector values or economy-config `Resource` fields.

**Gems**
- `gem_value[tier]` — `{8, 15, 28, 52, 95}` (§1).
- `prize_value` — `900` (§1).

**Drill**  — `drill_power[0..4]` `{0.31,0.62,0.93,1.24,1.55}`; `drill_price[1..4]`
`{100,280,750,1900}` (§2a). Holds 0005's band via `hardness × 0.34 / power`.

**Fuel** — `fuel_capacity[0..4]` `{80,180,380,650,1050}`; `fuel_price[1..4]`
`{80,240,640,1600}`; `fuel_descent_per_tile` 0.4; `fuel_ascent_per_tile` 1.0;
`fuel_hover_per_tile` 0.15; `fuel_reserve_margin` 0.12 (§2b).

**Cargo** — `cargo_slots[0..4]` `{12,20,32,50,75}`; `cargo_price[1..4]`
`{120,320,800,2000}` (§2c).

**Hull** *(dmg model = 0007)* — `hull_capacity[0..4]` `{100,150,220,320,450}`;
`hull_price[1..4]` `{90,260,700,1750}`; `hazard_base_per_tile` 0.02*;
`hazard_depth_gain` 4.0* (*placeholder) (§2d).

**Light** *(benefit = 0007)* — `light_darkness_mult[0..3]` `{1.0,0.68,0.42,0.25}`;
`light_price[1..3]` `{150,450,1200}` (§2e).

**Hoist** — `hoist_price` 5000; `hoist_ascent_factor` 0.5 (§2f).

**Inherited-from-0003 plumbing** — `refuel_cost_per_unit` 0; `repair_cost_per_hp` 0
(§4).

**Pacing helpers** — a global `price_scale` multiplier over all price arrays;
`surface_hub_seconds` 15 (§3).

## 6. Godot learning notes (continuing the 0001/0004/0005 path)

How this note becomes an implementation, for a web dev new to Godot:

- **Economy config as a `Resource`, not scattered constants.** Make an
  `EconomyConfig` custom `Resource` (`class_name EconomyConfig`) with all §5 fields
  as `@export` vars/arrays. A single `.tres` file holds the live defaults; the
  Inspector edits them by feel (0004's lesson), and swapping `.tres` files gives
  you A/B balance sets for free. This is the Godot-native form of "everything is a
  knob."
- **Wallet & upgrades are autoload singletons (0001).** `Wallet` (banked money,
  never at risk) and an `Upgrades` autoload holding the current level per track;
  `drill_power()` etc. read `EconomyConfig.drill_power[Upgrades.drill]`. The shop UI
  mutates `Upgrades` and debits `Wallet`.
- **Derive, don't store, effective values.** Effective drill time, reachable depth,
  and EV/tile are pure functions of `(EconomyConfig, Upgrades, depth)` — compute on
  demand, exactly as the sim does. Keeps save data tiny (0009 saves *levels + wallet
  + world deltas*, never derived numbers).
- **The simulation is throwaway, but its model isn't.** `economy-sim/economy-model.js`
  is the reference implementation of every formula here (drill-time, EV/tile,
  reach-limits, the greedy policy). When porting to GDScript, port the *formulas*;
  the JS/HTML console itself is disposable tuning scaffolding, not shipped code.
- **On-device tuning beats spreadsheet tuning (0004's lesson) — but a spreadsheet
  beats guessing.** The console answered "does the ratchet turn at a nice pace?"
  cheaply, before any Godot economy code exists. The *final* feel still wants an
  Inspector pass on a real build; the sim just gets the defaults into the right
  ballpark first.

## 7. The simulation (this asset's artifact)

- **Interactive console (react-to-the-curve tool):**
  <https://claude.ai/code/artifact/8b0a93aa-b680-4b11-9a92-217037ae2469> — live
  knobs, the drill-time contract grid (shaded against 0005's band), the EV/tile
  curve, $/min-by-band, and the 20-run table. Mobile-safe (iOS Safari text-inflation
  and a sticky-overlap bug found and fixed on-device — same class of iOS quirk 0002
  flagged).
- **Source (single source of truth + node runner):**
  [`economy-sim/`](../../economy-sim/) — `economy-model.js` (the model + defaults),
  `run.js` (`node economy-sim/run.js` prints the grid/curve/table/pacing),
  `shell.html`+`ui.js`+`build-artifact.js` (the console, built by inlining the model
  so it can't drift from the node-verified numbers).

## 8. What this clears / hands off

- **0010 (monetization) is now unblocked** — its whole premise ("decide *after* the
  economy exists, since the answer shapes / is shaped by the upgrade curve") is now
  satisfiable. It inherits a concrete picture: a permanent-upgrade ratchet with
  no per-run cash sink, a genuine long-tail money sink (Hoist at 5000 + deep upgrade
  tiers), and a first hour that reaches mid-game in ~17 runs — a shape a free/
  premium/ads call can now be reasoned about against.
- **Meta-progression & retention fog** — its stated blocker was "the core loop and
  economy decisions." Both (0003, 0006) are now closed, so this fog's dependency is
  cleared; it can graduate to a ticket when a charting session next runs (achievements
  /milestones can now be pinned to real economy landmarks — first Bedrock, first
  prize, the Hoist).
- **0007 (hazards) inherits** the Hull and Light *price/capacity* ladders (real) and
  a placeholder damage/darkness coupling to replace with the real roster. Nothing in
  0007 needs to change 0006's prices; it fills in what a point of hull damage *means*.
- **No worldgen leakage:** 0006 assigned only values; every position, tier weight,
  hardness, and density stayed 0005's. The one place a "smoother EV" wish would land
  (within-band tier ramps) is explicitly flagged back to 0005's `tier_weight`, not
  taken here.

This resolution creates no new tickets (meta-progression graduates via a future
charting pass); it unblocks 0010 and hands placeholders to 0007.

## Sources & basis

- Inherited constraints: [0005 worldgen asset](0005-worldgen.md) (fixed tiers,
  positions, density, `dig_constant`, the drill-time-band contract 0006 must hold,
  halo/prize hardness, the aspirational-hoist + Light tracks),
  [0004 dig-feel asset](0004-dig-feel-controls.md) (0.34 s/hardness, resistance is
  the pleasure), [0003 core-loop asset](0003-core-loop.md) (economy lives in the
  ratchet, free refuel pinned-to-zero, no death-spiral, four+Light tracks,
  glimpsed-prize hook), [0002 web-export asset](0002-web-export-ios-safari.md)
  (iOS-Safari quirks — informed the sim's own mobile fixes).
- Method: a **prototype** ticket driven with the /prototype skill — a throwaway
  simulation built, 20 runs surfaced, Fiachra reacted to the curve and set the
  defaults. Every number is a default to tune, per the standing "name knobs, don't
  over-specify curves" preference; the named-knob list (§5) is the load-bearing
  output, the numbers are its first draft.
