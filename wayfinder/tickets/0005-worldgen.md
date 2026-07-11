---
id: 0005
title: "World generation design"
type: grilling
status: open
assignee:
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
