---
id: 0005
title: "World generation design"
type: grilling
status: closed
assignee: fiachramcv
blocked-by: [0003]
---

## Question

How is the mine generated? Layer strata and their depth bands, gem distribution curves by depth, cave/pocket generation, deterministic seed vs pure random, chunk size and whether the world streams as the player descends. Output: a worldgen design note with tunable parameters named.

> **Inherited from [0004](0004-dig-feel-controls.md):** hardness is the primary
> *texture* of the dig, and hold-to-drill time ∝ hardness (~0.34 s/unit felt
> good). Design strata as a **hardness curve by depth** that keeps per-tile drill
> time in a satisfying band (~0.3–1.5 s at the relevant upgrade level) — that band,
> not raw depth, is the real knob. Place gems *inside* harder pockets so
> resistance and reward coincide. See the [0004 decision asset](../assets/0004-dig-feel-controls.md).

## Resolution

Resolved by a `/grilling` session (11 questions, breadth-then-depth). Full design
in the **[worldgen design note](../assets/0005-worldgen.md)** (+ illustrative
[cross-section](../assets/0005-worldgen-crosssection.svg)). In brief:

- **Extent:** bounded designed bottom (~700 tiles) for the slice, but
  hardness/gem distribution are **functions of depth** so going deeper later is
  tuning, not redesign. Bounded **~96-tile-wide** shaft.
- **Strata:** 5 **identity bands** — Topsoil / Clay / Sandstone / Granite /
  Bedrock — baseline hardness 1→5 across depths 0/40/120/260/450/700.
- **Hardness feel (frontier-resistance):** the hardness-by-depth function is
  0005's; it **declares the target effective drill-time band** (frontier
  ~1.0–1.3 s, conquered rock ~0.3–0.5 s) as a **requirement 0006's drill-power
  curve must hold**.
- **Gems:** overlapping tiers with a moving peak + tails; seated in **2–5-tile
  veins wrapped in a +1-hardness halo** (the telegraph); base density **~8%**,
  roughly flat with depth (deeper pays via *tier*, not count).
- **Prize gem (= glimpsed-prize hook):** one seeded top-value gem, hard singleton
  nodule (+2), glint that reveals wider through the dark.
- **Caves:** sparse voids, more common/larger with depth — terrain for fall-damage
  and hazards (rules → 0007).
- **Determinism:** per-player `world_seed` saved at new-game; chunk = pure function
  of `(seed, x, y)` via `FastNoiseLite` + hashing; save stores only dug/collected
  **deltas** (format → 0009).
- **Streaming:** 16 px tiles · **32×32** chunks · **resident = camera + 1-chunk
  margin, everything else freed** · regenerate-from-seed on re-entry · incremental
  gen · resident footprint tens of MB. The bounded-window rule is the
  non-negotiable per 0002/0003; the specific numbers are on-device tunables.
- **Darkness:** linear view-radius shrink to a non-zero floor (knobs: surface
  radius, shrink rate, floor); prize glint reveals wider.

All numbers are named defaults to tune on-device (see the note's §9 parameter
list). Creates no new tickets; tightens the Performance-budget fog and feeds
0006/0007/0008/0009.
