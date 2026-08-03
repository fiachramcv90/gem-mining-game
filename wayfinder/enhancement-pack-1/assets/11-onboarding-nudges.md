# EP1-12 — Onboarding & nudges for the new tools + board

_Resolves [EP1-12: Onboarding & nudges](https://github.com/fiachramcv90/gem-mining-game/issues/51). Graduated from the map's onboarding fog once the roster (#45/#46/#47) and both UIs (#41/#44) settled. Follows the shipped [0013](../../tickets/0013-tutorial-onboarding.md) discipline: ghost lines that self-dismiss on first success, diegetic tells, **no modals, nothing gates play**._

## Consumables onboarding

- **Loadout (garage):** first time a tool is buyable (Flare at Sandstone 120), a one-shot **ghost line on the loadout slots** — *"Equip up to 3 — tap a slot"* — self-dismissing once the first tool is equipped. Piggybacks on the shop [#42](https://github.com/fiachramcv90/gem-mining-game/issues/42)/[#44](https://github.com/fiachramcv90/gem-mining-game/issues/44) already built. Flag `nudges.loadout_shown`.
- **HUD buttons:** the corner slot buttons only appear once a loadout is equipped; first descent-with-gear, a one-shot ghost line points at the corner (*"your gear — tap to use"*), self-dismissing on first use.
- **Dynamite (the one dangerous new verb):** a one-shot diegetic **"GET CLEAR!"** ghost line on first use — but **the lit fuse itself is the permanent teacher** (a burning countdown says "move" better than text). The ghost line self-dismisses after the first successful retreat. Flag `nudges.dynamite_taught`.
- **Drones + relief → no dedicated teach.** The *feedback is the teaching*: hauler's "banked remotely +$X" float (reuses [0008](../../tickets/0008-art-audio.md)'s banked-gold pop), scout's "no leads here" refusal (explains itself), relief items instant + obvious. Nothing added — minimal, in the 0013 spirit.

## Leaderboard onboarding

- **Nickname:** no first-run modal (locked in [#41](https://github.com/fiachramcv90/gem-mining-game/issues/41)/[#39](https://github.com/fiachramcv90/gem-mining-game/issues/39)). One gentle **one-shot line on the first board view** — *"You're 'Prospector' — tap to rename"* — self-dismissing; renaming stays available anytime from the Log, so zero pressure.
- **Groups:** folded into that **same first-board-view moment** (a *"join a group to play with friends"* affordance on the Groups tab, surfaced once) — one gentle moment, not two. Single flag `nudges.board_intro_shown`.

## Save fields — no new migration

All onboarding flags (`loadout_shown`, `dynamite_taught`, `board_intro_shown`) fold into the **existing `nudges` dictionary** 0013 already established in the save. Absent key = "not yet shown" → self-heals on load, exactly like 0013's nudges. **Onboarding adds zero save-envelope changes** beyond [#40](https://github.com/fiachramcv90/gem-mining-game/issues/40)'s `save_version` 5 — the flags just ride in the dict that's already there.

## Downstream

No shipped-spec amendment (additive, and it reuses 0013's existing `nudges` machinery). **Clears the map's onboarding fog entirely.** Last decision before [#48](https://github.com/fiachramcv90/gem-mining-game/issues/48) assembly.
