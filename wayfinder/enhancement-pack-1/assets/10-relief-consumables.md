# EP1-10 — Relief consumables (fuel cell · repair kit · flare)

_Resolves [EP1-10: Relief consumables](https://github.com/fiachramcv90/gem-mining-game/issues/47). The three simplest of the six-tool roster, one per remaining run pressure. Sits inside the [#42](https://github.com/fiachramcv90/gem-mining-game/issues/42) loadout; all values `@export` knobs._

All three are **instant, one-tap** items (per [#44](https://github.com/fiachramcv90/gem-mining-game/issues/44)'s activation model — no aiming). Each insures one pressure the other three tools don't, making the 3-slot loadout a real "which pressure do I hedge?" choice. All honour the guardrail: discretionary relief, never mandatory.

## ⛽ Fuel cell → Fuel

- **One-tap top-up of ~40% of *max* fuel capacity** (`fuel_cell_frac ≈ 0.40`) — scales with Fuel upgrades so it stays relevant in the deep game.
- **Extends the greed gamble, doesn't remove the gate:** pop it when the round-trip gauge gets scary to push a little deeper/longer — but you still must reserve for ascent, and it's capped at **3 charges**. It buys "I can risk a bit more," not "the fuel gate is gone."

## 🔧 Repair kit → Hull

- **One-tap heal of ~40% of *max* hull** (`repair_frac ≈ 0.40`) — scales with Hull upgrades. Patches you after a [0007](../../tickets/0007-hazards-depth.md) hazard hit.
- **Scarcity keeps The Deep meaningful:** 3 charges, unlocking mid-Granite (340). You can steady yourself a couple of times, never facetank the danger act.

## 🔆 Flare → Darkness

- **One-tap; drops just ahead of the digger** and lights a **generous local area (radius larger than your personal Light bubble)** for **~10s** (`flare_radius`, `flare_duration ≈ 10s`), then fades — revealing hazard tells + veins in a dark room *before* you commit.
- **Complements, never replaces, the Light upgrade:** Light is *permanent + personal* (your constant bubble, moving with you); flare is *scarce + placed + temporary* (a burst you drop to peek ahead). Different jobs → Light stays essential (the collision the ticket flagged is avoided).

## Downstream

No shipped-spec amendment — additive relief. With the full roster now specced (dynamite [#45](https://github.com/fiachramcv90/gem-mining-game/issues/45), drones [#46](https://github.com/fiachramcv90/gem-mining-game/issues/46), relief here) and both UIs settled ([#41](https://github.com/fiachramcv90/gem-mining-game/issues/41), [#44](https://github.com/fiachramcv90/gem-mining-game/issues/44)), the **onboarding / nudges fog is now specifiable and graduates into its own ticket**. [#48](https://github.com/fiachramcv90/gem-mining-game/issues/48) folds the relief specs into the EP1 spec.
