# Core loop & failure states — Gem Miner

> Design asset for ticket **0003 — Core loop & failure states**.
> Audience: Fiachra — solo dev, evenings/weekends, no deadline; bias toward
> small scope and steady momentum.
> Scope: the *skeleton* of the moment-to-moment loop — which resources gate a
> run, what depletion does, how the player returns to the surface, and what
> makes "one more run" compelling. **Not** the tuning numbers (gem values,
> upgrade curves → 0006), the dig *feel*/controls (→ 0004), worldgen shape
> (→ 0005), or the hazard roster (→ 0007). This defines the frame those
> tickets fill in.

## The loop in one view

1. **Descend** from the surface hub into the **persistent mine**, digging through
   tiles.
2. Manage **three pressures** (below).
3. Every few seconds, make the core decision: **"one more tile, or do I have
   just enough fuel to get home?"**
4. **Ascend under your own power** (ascent also costs fuel — see round-trip
   budget).
5. At the **surface hub**: sell cargo → wallet, refuel & repair, buy permanent
   upgrades.
6. Go deeper next time. Repeat.

## The three pressures

Each pressure does a genuinely different job. Cutting or merging one tends to
collapse the others into a single flat pressure, which is why all three stay.

| Pressure | Role | Restored | Fail shape |
| --- | --- | --- | --- |
| **Fuel** | The clock / **round-trip budget** | At surface (free) | Empty → **run lost** |
| **Cargo** | The greed cap | Emptied by selling at surface | Full → **soft fail** (stop collecting) |
| **Hull** | The risk cap | At surface (free) | Zero → **run lost** |

- **Fuel is the master resource.** Because ascent also spends fuel, every tile
  down is a tile you must pay to climb back out of. Fuel is a *round-trip
  budget*, never a one-way timer — that shared budget is what creates the
  turn-back decision that is the beating heart of the loop. Fuel and hull
  deplete only during a run and are only restored at the surface.
- **Cargo is a soft fail, not a death.** When the hold is full, new gems simply
  aren't collected (they stay in the ground); you're free to keep driving, but
  there's no reason to — so a full hold *pulls* you home rather than punishing
  you. It's the "greed satisfied, go bank it" nudge.
- **Hull is the risk cap.** Depleted by hazards (roster owned by 0007).

## Darkness — a risk multiplier, not a fourth resource

Darkness scales with depth: the deeper you go, the smaller your view radius,
until you buy the **Light** upgrade (an upgrade track owned by 0006) that pushes
it back out.

Crucially, darkness is **not** a fourth bar and **not** a fourth way to die. It
is a *multiplier on the hull (risk) pressure*: in the dark you can't see hazards
coming, so digging blind means more hull damage — falls and unseen dangers you'd
have dodged in the light. Darkness makes the risk you already have sharper; the
Light upgrade buys that risk back down. This keeps the failure model at three
axes while adding real moment-to-moment tension and a fourth thing for the
economy to sell.

## Failure & recovery

- **Cargo full** → soft fail (stop collecting; drive home when ready).
- **Fuel empty** and **hull zero** → collapse into **one shared "run lost"
  outcome.** The *cause* differs (a clock vs a risk); the *consequence* is
  identical, and players don't parse the difference in the moment. Building,
  tuning, and teaching two death penalties is scope we don't need.

**What a lost run costs:** *only the carried cargo* — the unsold gems in the
hold. You keep your **wallet** and **every upgrade**, and respawn at the surface
with fuel and hull topped up **for free**. The forfeited haul is the entire
punishment, and it already stings (a great run can evaporate a few tiles from
daylight).

**No death-spiral, by design.** A rescue fee on top of the lost cargo could
leave a player unable to afford the next descent — a momentum-killer for a
no-deadline hobby game. So recovery is free.

**The safe/exposed asymmetry is the greed-vs-safety tension:** money banked at
the surface (the `wallet` autoload) is *never* at risk; cargo carried in the
hold is *always* exposed. That asymmetry is what makes the turn-back decision
matter.

## Return to the surface

- **Self-powered ascent that shares the fuel budget.** No free "return to
  surface" button, no teleport in the base loop — that single rule is what makes
  fuel a round-trip budget and keeps the turn-back moment alive across the whole
  early game.
- **Fast-travel is a deferred luxury.** A teleporter/hoist that skips the climb
  can exist as an *upgrade* in 0006 (a money sink buying convenience and an
  aspirational late-game item) — but the base loop assumes you fly yourself home.

## The surface hub

Deliberately minimal — a menu with a floor, no town, no NPCs (out of scope):

- **Sell cargo → wallet.**
- **Refuel & repair** (see extensibility note).
- **Buy permanent upgrades** (the shop; tracks and curves owned by 0006).
- **Descend** again.

## The economy principle (frame only; numbers → 0006)

- **The entire economy lives in the permanent-upgrade ratchet.** Selling cargo
  funds upgrades; upgrades visibly extend your reach into the shaft you already
  know.
- **Refuel/repair at the surface is free** — fuel is purely a spatial/time
  budget ("how deep can you go and still get back"), never a cash cost.
- **Extensibility hook:** model refuel/repair as a cost that is *currently
  pinned to zero*. The plumbing to make it non-zero exists from day one, so
  adding a Motherload-style per-run fuel sink later is a tuning change, not a
  refactor. 0006 owns the decision of whether to ever switch it on.

## Persistent mine

When you descend again, it is the **same** mine you were carving — one
continuous excavation whose tunnels persist between runs. You fly down your own
shaft, go a bit deeper, come back.

This is chosen over regenerating (roguelike) runs because it gives the richest
compulsion loop for free (see below). The cost is that it commits the project to
infrastructure the map already anticipates — it does not invent new systems, it
turns anticipated ones into hard requirements (see *Downstream consequences*).

## What makes "one more run" compelling

Three reinforcing sources, in order of weight:

1. **The persistent shaft is progress made physical.** The tunnel network you've
   carved is a visible, permanent record of how far you've come — the strongest
   "one more run" hook in the genre.
2. **Runs end on a hook, not a whimper.** Either a **near-miss** ("barely made
   it back with a full hold") or a **glimpsed prize** ("a rare gem was glinting
   just below where my fuel ran out — I'm going back for it"). Both fall out of
   the fuel/cargo/darkness tension naturally; the glimpsed prize is the single
   most compelling dopamine beat in a digger.
3. **The upgrade ratchet** is the secondary engine: each run funds a permanent
   capability (deeper reach, bigger hold, tougher hull, brighter light) that
   visibly extends what the next run can reach.

## Downstream consequences (fog this clears)

Committing to a persistent mine + this failure model sharpens several tickets:

- **0002 / performance budget** — confirms chunk-streaming **and** freeing
  off-screen tiles as a *hard* requirement, not a "maybe later": a persistent
  mine grows without bound.
- **0005 worldgen** — inherits: chunk-streaming is mandatory; a darkness
  view-radius-by-depth curve; deliberate glimpsed-prize placement so runs end on
  a hook.
- **0006 economy & upgrades** — inherits four upgrade tracks including **Light**
  and an aspirational **fast-travel/hoist** item; and the "refuel cost = 0 for
  now, switchable later" knob.
- **0007 hazards & depth** — inherits the single "run lost" outcome and
  darkness-as-risk-multiplier as the frame to build the hazard roster against.
- **0009 save system** — inherits a hard new requirement: **persist dug-tile
  state**, not just wallet + upgrades. The carved shaft must survive a reload.

## Glossary (domain terms established)

- **Run** — one surface → descend → dig → return → surface cycle. Ends when the
  player is back at the surface, or when the run is lost.
- **Mine** — the single persistent excavation; the same world across all runs.
- **Surface hub** — the minimal above-ground menu: sell, refuel/repair, upgrade,
  descend.
- **Wallet** — banked money (the autoload from 0001); never at risk.
- **Cargo** — unsold gems carried in the hold during a run; forfeited on a lost
  run.
- **Run lost** — the single failure outcome from fuel-empty or hull-zero:
  forfeit carried cargo, keep wallet + upgrades, respawn topped up for free.
- **Round-trip budget** — the property of fuel: it must cover descent *and*
  ascent, because ascent spends it too.
