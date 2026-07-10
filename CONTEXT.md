# Gem Miner — Domain Glossary

> Ubiquitous language for the game's design and code. Glossary only — no
> implementation details, no decisions (those live in wayfinder tickets/assets).

## Run

One `surface → descend → dig → return → surface` cycle. A run **ends** when the
player is back at the surface, or when the run is **lost**.

## Mine

The single **persistent** excavation — the same world across every run. Tunnels
the player digs stay dug between runs.

## Surface hub

The minimal above-ground area: sell cargo, refuel/repair, buy upgrades, descend.
No town, no NPCs.

## Wallet

The player's banked money. **Never at risk** — untouched by a lost run.

## Cargo

Unsold gems carried in the hold during a run. **Always at risk** — forfeited on a
lost run. Selling cargo at the surface converts it to Wallet money and empties
the hold.

## The three pressures

The resources that gate a run:

- **Fuel** — the clock and **round-trip budget**; ascent spends it too, so it
  must cover the descent *and* the climb home.
- **Cargo capacity** — the greed cap; a full hold stops collection.
- **Hull** — the risk cap; depleted by hazards.

## Darkness

A depth-scaled reduction of the player's view radius. Not a resource and not a
failure state — a **risk multiplier** on Hull (unseen hazards do more damage),
countered by the Light upgrade.

## Run lost

The single failure outcome triggered by fuel-empty or hull-zero: the player
forfeits carried Cargo, keeps Wallet and all upgrades, and respawns at the
surface topped up. There is no separate death penalty for fuel vs hull.

## Round-trip budget

A property of Fuel: it must cover both descent and ascent, because ascending
consumes fuel. This is what turns Fuel from a one-way timer into the game's
central "do I have enough to get home?" decision.
