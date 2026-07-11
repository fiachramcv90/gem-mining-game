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

## Band (strata)

A depth range of the mine with its own identity — a name, a baseline **hardness**,
and a signature gem tier. The mine is a stack of bands from the surface down (e.g.
Topsoil → Bedrock). "Deeper" means "a harder band with better gems."

## Hardness

The per-tile resistance to digging: drill time is proportional to it. The
**primary texture of the dig**. Rises with depth (by band) and is raised further
inside gem pockets.

## Vein & halo

A **vein** is a small cluster of same-tier gem tiles. Its **halo** is the ring of
harder-than-baseline rock around it — the resistance spike that *telegraphs* a
find: you feel the rock harden before you break through to the gem.

## Prize gem

The single rarest, highest-value gem — seated deep in a hard singleton pocket and
glinting further through the **darkness** than anything else. Catching that glint
at the edge of vision is the **glimpsed-prize** hook that ends a run on "I'm going
back for it."

## World seed

The per-player number, fixed at new-game, from which the entire mine is generated.
The same seed always produces the same mine, so the **persistent mine** reloads
identically without storing every tile.

## Chunk & resident window

A **chunk** is a fixed square block of tiles — the unit the mine loads and frees
in. The **resident window** is the bounded set of chunks kept in memory around the
player (the view plus a margin); chunks outside it are freed and regenerated from
the **world seed** on return. This is what keeps memory bounded as the mine deepens.

## Darkness curve

The rule mapping depth to view radius: the deeper you are, the smaller you can see,
down to a non-zero floor. It is the concrete form of **darkness** (the hull risk
multiplier), pushed back out by the Light upgrade.
