# EP1-09 — Drone mechanics (hauler + scout)

_Resolves [EP1-09: Drone mechanics](https://github.com/fiachramcv90/gem-mining-game/issues/46). Sits inside the [#42](https://github.com/fiachramcv90/gem-mining-game/issues/42) loadout; both are the loop-benders scarcity keeps in check. All values `@export` knobs._

Both drones are purchased consumables (charges = trips/goes), **not** upgrades. Auto-digger stays rejected (browser-tab throttling kills idle-digging — hard constraint). Each is capped at **2 charges** (`maxCharges` 2) — the map's *"scarcity is the balancing mechanism"* principle is where these two live or die.

## Hauler drone (charges = trips)

- **What it does:** dispatch with your **current cargo**; it flies to the surface, **auto-sells the load** (money → wallet; feeds `best_haul` / `total_banked` — the mid-descent banking [#40](https://github.com/fiachramcv90/gem-mining-game/issues/40)'s per-run accumulator was built to expect), and returns empty. You keep digging throughout.
- **Trip capacity:** one full hold per trip (up to your cargo cap).
- **Duration:** a round-trip flight time that **scales with depth** (deeper = longer); one drone, sequential — can't re-send mid-flight. `@export haul_trip_time`.
- **Fuel:** **self-powered — does not draw your fuel tank.** Keeps the round-trip fuel gate purely about *your* ascent; the drone's cost is its charge ($80) + the 2-trip cap.
- **Prize gem:** **refuses the prize.** The marquee nodule must be hauled home by *you* on a real ascent (consistent with 0003 and [#45](https://github.com/fiachramcv90/gem-mining-game/issues/45)'s prize-immunity). It banks everything except the prize.
- **Why it doesn't dissolve the loop:** 2 trips buys two "bank-and-push-deeper" reprieves — it *extends* the greed gamble ("I've locked this load in, I can risk lower") but you still must physically ascend for fuel and for the prize, and the trips run out.

## Scout drone (charges = goes)

- **What it does:** on release, scans for the nearest **high-value gem (tier ≥ T4, or the prize)** within a detection radius, then tunnels a **thin 1-tile path toward it** that you follow and mine yourself. It bypasses the **finding**, never the **mining** — so 0004/0005's resistance-is-the-pleasure stays mostly intact.
- **Only fires if a qualifying gem is in range** — no target nearby → it **refuses and keeps the charge** ("no leads here"), so a go is never wasted into empty rock.
- **Detection radius / range:** a **generously wide local scan** (`@export scout_radius`, tuned up during play) — deliberately widened so each scarce go is likely to surface a lead — but **still bounded, not a whole-mine treasure map**. The tunnel reaches only as far as the found target.
- **Reveals nothing else:** no hazard tells, no map reveal — purely a path to one gem. Hazard-sight stays the Light upgrade / flare's job.
- **Worldgen lookup:** queries [0005](../../tickets/0005-worldgen.md)'s deterministic gem positions (chunk = pure fn of `seed,x,y`) within the radius — cheap; positions are computable without simulating.
- **Why it's not a solved run:** 2 goes, points only at *already-nearby* high-value gems, tunnels-toward (you still dig it out), reveals nothing else. "A couple of opt-in hot leads," per the ticket.

## Downstream

Hauler banking is consistent with #40's `best_haul` accumulator (mid-descent banking events). No shipped-spec amendment — additive loop-benders whose scarcity keeps the shipped core loop intact. [#48](https://github.com/fiachramcv90/gem-mining-game/issues/48) folds both into the EP1 spec.
