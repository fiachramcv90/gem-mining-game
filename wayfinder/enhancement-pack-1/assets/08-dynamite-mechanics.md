# EP1-08 — Dynamite mechanics

_Resolves [EP1-08: Dynamite mechanics](https://github.com/fiachramcv90/gem-mining-game/issues/45). Inherits the input model from [#44](https://github.com/fiachramcv90/gem-mining-game/issues/44); sits inside the [#42](https://github.com/fiachramcv90/gem-mining-game/issues/42) loadout system._

Dynamite is a **traversal convenience with a self-danger gamble** — punch a chunk of rock fast, but drop it at your feet and flee before it blows. All numbers below are named `@export` knobs.

## 1. Input model (from #44)

The charge **drops on the digger** (no aiming — tap-target was rejected in #44 because placing away from yourself removed all risk). Sequence: tap the armed dynamite slot → charge drops with a **lit fuse** → thrust clear with the stick → it detonates on the fuse → **self-damage if still in the blast**.

## 2. Blast shape & size

- **Downward-biased teardrop**, scaled to a **~3-tile radius** (~3 tiles below the drop point, ~2 up/wide, tapering upward). Clears roughly 8–10 tiles.
- The downward bias suits digging *down* and makes the **flee vector upward/sideways** — out of the deep lobe.
- Knobs: `blast_down`, `blast_up`, `blast_wide` (or a single `blast_radius` + `down_bias`).

## 3. Hardness interaction — ignore hardness, no cap

- Dynamite **clears whatever is in the teardrop, any stratum including Bedrock**. No hardness cap.
- **Guardrail holds** (the ticket's load-bearing rule): the drill, fully upgraded, can clear every stratum too, so dynamite is **never the sole way through anything** ("drill ⊇ dynamite"). A broke player is never stuck.
- **Scarcity is the tamer** (the map's standing principle): `maxCharges` 4, $40/charge, unlocking only at Granite (260) — you can't spam it to skip the drill ratchet; it's an occasional "punch through this patch."
- **It does not extend reach** — fuel (round-trip) and hull still gate how deep you can go and get home. Dynamite speeds *effort*, never bypasses the *survival* gates.
- A hardness cap was rejected: it would make dynamite quit working one stratum after you unlock it, inverting its value curve.

## 4. Gem & vein interaction — destroy, prize immune

- Gems caught in the teardrop are **destroyed (lost), not collected.** This gives dynamite a clean identity as a **traversal tool, not a harvest tool**: blasting a vein *wastes* it, so you dynamite barren rock and still hand-drill rich veins — **preserving the "resistance is the pleasure" mining** (0004/0005) and sidestepping all cargo-cap/overflow edge cases.
- **The prize gem is immune to the blast.** You can clear the rock *around* the prize nodule, but it survives and must still be **drilled out and hauled home** — honouring #44/#45's "dynamite can't be the thing that clears a prize" and protecting the marquee glimpsed-prize hook.

## 5. Self-damage & fuse — the retreat gamble

- **Short auto-fuse (~1.3s), not a manual DETONATE button.** The gamble *is* time pressure ([#42](https://github.com/fiachramcv90/gem-mining-game/issues/42): "too slow to leave the blast radius and you eat the damage"). A fuse creates it directly; a manual detonate would let you dawdle to safety then tap — silently removing the risk (the exact failure mode #44 caught). A fuse also keeps the corners HUD clean (no temporary button competing for the thumb).
- **Self-damage: proximity-scaled, capped at ~40% of *current* hull.** Calibrated to read as *your own risk*, not a new hazard type — same currency as [0007](../../tickets/0007-hazards-depth.md)'s falls (a fraction of **current** hull; falls cap at 45%). Full at the blast centre, tapering to 0 at the self-damage radius (~3 tiles). **Never an instakill** — a punishing-but-survivable hit that taxes greed.
- Knobs: `fuse_time` (~1.3s), `self_dmg_frac` (~0.40 of current hull), `self_dmg_radius` (~3 tiles).

## Downstream

Consumes #44's input model; no shipped-spec amendment (dynamite is additive, and its self-damage is calibrated to sit *within* 0007's existing hazard budget, not to move Hull/Light prices). [#48](https://github.com/fiachramcv90/gem-mining-game/issues/48) folds the dynamite spec + knob list into the EP1 spec.
