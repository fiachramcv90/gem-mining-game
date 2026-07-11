---
id: 0006
title: "Economy & upgrade curve"
type: prototype
status: closed
assignee: fiachramcv90
blocked-by: [0003]
---

## Question

Design the money loop: gem values by depth, the 3–4 upgrade tracks (drill, fuel, cargo, hull) and their price/benefit curves, and the pacing of the first hour. Prototype as a spreadsheet/simulation, not code — simulate 20 runs and react to the curve.

## Resolution

**The first-draft numbers ship as launch defaults, and every one stays a named,
`@export`-able knob** — re-balancing later is a slider drag, not a code change.
That named-knob discipline (continuing 0004/0005) is the load-bearing decision;
the numbers are the first draft it was validated against, by building a throwaway
simulation and reacting to the curve.

- **Gem values by tier:** T1 8 · T2 15 · T3 28 · T4 52 · T5 95 · prize **900**
  (off the tier curve). Deeper pays via *tier*, not density (0005 keeps density
  flat). Expected value/dug-tile rises **~7× Topsoil→Bedrock**, monotonic and
  gentle; ~1.8× per *minute* once round-trips are counted, so shallow farming stays
  viable-but-inferior.
- **Six tracks:** **Drill** `power {0.31,0.62,0.93,1.24,1.55}` — holds 0005's
  drill-time-band contract (`hardness × 0.34 / power`, one band at the ~1.1 s
  frontier per level; between-band step is a soft cliff = frontier-resistance;
  halo/prize spikes above the ceiling are deliberate). **Fuel** `cap
  {80,180,380,650,1050}` (round-trip gate, ascent 1.0 / descent 0.4 per tile).
  **Cargo** `slots {12,20,32,50,75}` (greed cap; late-game limiter). **Hull**
  `{100,150,220,320,450}` and **Light** `darkness ×{1,0.68,0.42,0.25}` — prices are
  real 0006 knobs, but their *damage/darkness benefit* is a flagged placeholder
  handed to **0007**. **Hoist** (aspirational fast-travel) — 5000, halves ascent.
  Prices climb ~2.5×/level (self-funding ratchet).
- **First hour:** first upgrade ~run 3 (~4½ min), steady to mid-Sandstone by 60 min
  (~17 runs), Bedrock ~run 19, the 700 t bottom **unreached in 20 runs** — it stays
  the one-more-run goal (0003).
- **Inherited & held:** refuel/repair free but modelled cost-pinned-to-zero (0003);
  no per-run cash sink → no death-spiral. Worldgen positions/tiers untouched (0005).

**Design note:** [`assets/0006-economy-upgrades.md`](../assets/0006-economy-upgrades.md)
— every value/curve named, the full knob list, Godot wiring notes.
**Simulation:** [interactive console](https://claude.ai/code/artifact/8b0a93aa-b680-4b11-9a92-217037ae2469)
· [`economy-sim/`](../../economy-sim/) (`node economy-sim/run.js`).

**Clears:** unblocks **0010 (monetization)** — the economy it was waiting on now
exists. The **meta-progression/retention** fog's blocker (core loop + economy) is
now cleared; it can graduate at the next charting pass. Hands Hull/Light damage
placeholders to **0007**. Creates no new tickets.
