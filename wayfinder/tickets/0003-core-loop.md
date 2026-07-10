---
id: 0003
title: "Core loop & failure states"
type: grilling
status: closed
assignee: fiachramcv
blocked-by: []
---

## Question

Pin down the moment-to-moment loop: what resources constrain a dig run (fuel? hull? cargo?), what happens when each runs out (death penalty, rescue cost, lost cargo?), what pulls the player back to the surface, and what makes 'one more run' compelling. Output: a written core-loop definition.

## Resolution

Full definition: [core-loop asset](../assets/0003-core-loop.md).

**Three pressures gate a run**, each with a distinct job:
- **Fuel** — the clock, and the **round-trip budget**: ascent spends fuel too, so
  every tile down must be paid to climb back. This is the master resource and the
  source of the turn-back decision.
- **Cargo** — the greed cap. Full hold = **soft fail** (stop collecting, drive
  home), not a death.
- **Hull** — the risk cap, depleted by hazards (0007).

**Darkness** is a **risk multiplier on hull**, not a fourth bar or fourth death:
deeper = darker = can't see hazards = more hull damage, bought back down by a
**Light** upgrade (0006).

**Failure:** fuel-empty and hull-zero collapse into **one "run lost"** outcome —
forfeit *only the carried cargo*, keep wallet + all upgrades, respawn topped up
for free. No rescue fee (avoids a death-spiral). Banked money is never at risk;
carried cargo always is — that asymmetry is the greed-vs-safety tension.

**Return:** self-powered ascent that shares the fuel budget; no free return
button (fast-travel deferred to an optional 0006 upgrade). Surface is a minimal
sell / refuel / upgrade / descend hub. Refuel/repair is free, modelled as a cost
*pinned to zero* so a per-run fuel sink can be switched on later without a
refactor. Economy lives entirely in permanent upgrades.

**Persistent mine** (chosen over regenerating runs): one continuous excavation,
tunnels persist between runs. **"One more run" compulsion** comes from the carved
shaft as visible progress, runs ending on a near-miss or glimpsed-prize hook, and
the upgrade ratchet as secondary engine.

**Graduated fog / sharpened tickets:** 0002 (chunk-stream + free tiles now a hard
requirement), 0005 (mandatory streaming, darkness curve, glimpsed-prize
placement), 0006 (Light + fast-travel upgrade tracks, refuel-cost knob), 0007
(single run-lost outcome + darkness-as-multiplier frame), 0009 (must persist
dug-tile state, not just wallet/upgrades).
