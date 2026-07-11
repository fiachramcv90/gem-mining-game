---
id: 0007
title: "Hazards & depth progression"
type: grilling
status: closed
assignee: fiachramcv90
blocked-by: [0005]
---

## Question

What dangers appear as depth increases (gas pockets, lava, cave-ins, temperature?) and how do they interact with upgrades and the failure states from the core loop? How many distinct depth 'acts' exist at launch? Output: a depth-progression table.

## Resolution

**Design note:** [Hazards & depth progression — the design note](../assets/0007-hazards-depth.md).

Danger is **discrete, telegraphed, dodgeable events** (not a smooth drain); their
*expected* hull cost per tile is calibrated to reproduce 0006's placeholder curve,
so Hull/Light **prices/capacities are untouched** — the felt danger is variance
(a bad blind moment), not a steady tax.

- **Roster — four hazards, one per trigger mechanism:** **Falls** (kinetic drop
  into 0005's caves), **Gas pockets** (dig-triggered burst), **Cave-ins**
  (structural/reactive), **Lava/heat** (contact-over-time `Area2D` volume).
- **3 danger acts over the 5 bands**, cumulative, one new beat per band:
  **Act I "Learning"** (Topsoil falls → Clay + rare first gas), **Act II "The
  Squeeze"** (Sandstone gas common → Granite + cave-ins), **Act III "The Deep"**
  (Bedrock + lava, all at max). Full band × act × hazards × expected-hull-pressure
  table in the asset §3.
- **Darkness = avoidance, not extra damage:** Light lets you *see the telegraph and
  dodge*; darkness scales **hit probability**. Lava is the fair exception — it
  glows. Same expected value as 0006's `darkness_mult`, better feel.
- **Only Hull (soak) and Light (dodge) mitigate.** Fuel couples *emergently* (a
  fall drops you deeper → more climb fuel); Drill and Cargo stay out.
- **Falls:** 3-tile grace (free), ~linear above it, capped at 45% of *current*
  Hull (so the cap scales with Hull upgrades); thrust-brace in the light.
- **0006's placeholder made concrete:** `hazard_base_per_tile`/`hazard_depth_gain`
  re-cast from a live drain into the calibration *target* for the roster; all
  damage numbers are named `@export` knobs (asset §6). No 0006 price/capacity moved.
- **Godot learning notes** captured (asset §5): `Area2D` hazard volumes, collision
  layers vs masks, damage-over-time + i-frames, tile-custom-data on-dig hazards,
  velocity-based falls, telegraph-as-a-lit-rendering-rule.

**Fog cleared:** feeds hazard terrain to **0008 (art & audio)** to dress (already
unblocked — feeds, doesn't unblock) and the **3 danger acts** to the
meta-progression fog as milestone anchors. No numbered ticket unblocked; no new
ticket surfaced.
