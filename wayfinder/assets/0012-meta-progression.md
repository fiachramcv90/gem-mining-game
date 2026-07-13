# Meta-progression & retention — the Miner's Log

> Design asset for [ticket 0012 — Meta-progression & retention](../tickets/0012-meta-progression.md).
> Audience: Fiachra — solo dev, evenings/weekends, no deadline; bias toward
> small scope and steady momentum.
> Scope: the retention layer *above* the moment-to-moment loop — its forms,
> the milestone set, the reward language, where it surfaces, and what it
> persists. **Not** the loop itself ([0003](../tickets/0003-core-loop.md)),
> the economy numbers ([0006](../tickets/0006-economy-upgrades.md)), or any
> new art ([0008](../tickets/0008-art-audio.md)).

## The decision in one line

**The persistent mine + upgrade ratchet are affirmed as the primary retention
engine; one thin honorific layer — the Miner's Log — is added on top: 8
lifetime stats + 14 hidden-until-earned milestones on a single hub screen,
celebrated through 0008's existing juice, paying nothing but recognition.
Daily hooks are rejected on the record.**

## What the core already carries (and why the layer stays thin)

Retention was never this ticket's to invent — [0003](../tickets/0003-core-loop.md)
already built it:

1. **The carved shaft is lifetime progress made physical** — the strongest
   come-back hook in the genre, visible every time you descend.
2. **Runs end on hooks** — near-miss or glimpsed prize — not on a whimper.
3. **The ratchet only turns forward** — every run banks permanent capability.
4. **The ~700-tile designed bottom** ([0005](../tickets/0005-worldgen.md)) is a
   standing "one-more-run" goal, unreached even after the first hour
   ([0006](../tickets/0006-economy-upgrades.md)).

The Miner's Log exists to *celebrate* the beats this core already produces —
the landmarks other tickets made concrete — not to add a second engine.
Anything heavier would be scope spent re-solving a solved problem.

## Daily hooks — rejected, with reasons

Not deferred; **rejected**, so it doesn't creep back during the build:

- **Nothing legal to pay out.** No server/accounts means client-clock-only,
  trivially cheatable — which only matters if the reward is worth cheating
  for. But [0006](../tickets/0006-economy-upgrades.md) bans cash sinks and
  soft currency, and [0008](../tickets/0008-art-audio.md) bans new art, so a
  daily hook could pay nothing but bragging text anyway.
- **Streaks punish absence.** A broken-streak guilt mechanic is tonally
  opposite to the no-death-spiral, no-momentum-killer economy — the same
  engagement-farming flavour [0010](../tickets/0010-monetization.md) already
  rejected.
- **The mine is the daily hook.** Your shaft is exactly where you left it,
  one tile from the glint you saw. That returns players without date math,
  timezone edge cases, or a cheat-tolerance story.

## The milestone set — 14, in three families

**Ground rule (the load-bearing part):** a milestone must be pinned to an
event the game already detects — band entered, gem collected/banked, upgrade
bought, hazard resolved, run lost. **No new detection systems are built to
award a badge.** The names/count below are launch content, tweakable during
build; the three families and the pin rule are the decision.

| Family | Milestones | Pinned to |
| --- | --- | --- |
| **Depth** (5) | First reach of Clay, Sandstone, Granite, Bedrock; reach the ~700-tile designed bottom | [0005](../tickets/0005-worldgen.md)'s band boundaries; the bottom is the capstone |
| **Wealth** (4) | First cargo sold; first upgrade bought (~run 3); first **prize gem banked** (900, off-curve — *banked*, so the run home is part of it); buying the 5000 Hoist | [0006](../tickets/0006-economy-upgrades.md)'s economy landmarks |
| **Survival** (5) | Surviving your first big fall, gas pocket, cave-in, and lava contact (one per hazard mechanism); **first lost run** | [0007](../tickets/0007-hazards-depth.md)'s roster; [0003](../tickets/0003-core-loop.md)'s run-lost outcome |

The **first-lost-run badge** ("Every miner loses a load") is deliberate tone:
it reframes the game's one sting as a rite of passage, reinforcing 0003's
no-death-spiral ethos.

Deliberately excluded: cumulative grind badges ("dig 10,000 tiles") — those
numbers live as stats; turning them into badges invites checklist-brain.

## Reward language — honorific-only (the hard line)

- **Milestones pay recognition, never power or money.** The moment a badge
  grants +anything it becomes a shadow currency and reopens
  [0006](../tickets/0006-economy-upgrades.md)'s no-cash-sink economy. This is
  the line never to cross, including during build tuning ("the Bedrock badge
  could give +5 fuel" is how it creeps in).
- **The celebration is [0008](../tickets/0008-art-audio.md)'s existing juice,
  re-aimed:** the screen-shake + flash beat plus a one-line banner in the
  game's terse mining voice (e.g. *"BEDROCK. Few dig this deep."*). No new
  sprites, shaders, or sounds; visual-first, so it lands with the iOS silent
  switch on. Respects the reduce-motion toggle like every other juice beat.
- **Fire at the moment, low-key; honor at the hub, fully.** Mid-run: banner +
  flash only, nothing that interrupts digging (no modal — you may be dodging
  lava). Milestones that complete at the surface (first sell, prize gem
  banked, Hoist bought) celebrate right there in the hub.
- **The flavour lives in the copy.** Terse, dry, miner-voiced badge names and
  one-liners — 14 lines of copy are the entire content cost of this layer.

## Surfacing — one Miner's Log screen, one hub button

- **One screen** holds both lifetime stats and the milestone checklist —
  they're the same psychological object ("my record"), so splitting them is
  UI scope for nothing.
- **Opened by exactly one new button on the surface hub**, sitting with the
  shop. The hub stays [0003](../tickets/0003-core-loop.md)'s "menu with a
  floor"; [0010](../tickets/0010-monetization.md)'s quiet support corner is
  unencroached.
- **Title screen untouched** — the real title-screen progress display is the
  mine itself: you resume at your carved shaft.
- **Unearned milestones show as silhouettes/"???"**, not descriptions — the
  checklist's visible unfilled slots are the meta-layer's own glimpsed prize,
  and the survival badges keep their surprise.

## Persistence — two fields in 0009's save Dictionary

Extends [0009](../tickets/0009-save-system.md)'s plain-Dictionary
`user://save.dat` under the existing `save_version` migration; at 0009's
~8 KB scale the size is a non-issue.

```
stats: {
  deepest_depth: int,        # the record — shown big, in metres/tiles
  tiles_dug: int,            # lifetime "you carved this" — pairs with the shaft
  gems_collected: int,
  money_banked: int,         # lifetime earnings, not current wallet
  prize_gems_banked: int,    # one seeded today; 0005 leaves room
  runs_completed: int,
  runs_lost: int,            # shown as a pair with runs_completed; no shaming ratio
  cargo_value_lost: int      # lifetime forfeits — makes the first-lost-run badge land
}
milestones: { milestone_id: true }   # flat, string-keyed; no timestamps
```

- All stats are **plain int counters incremented at the moment of the
  event**, flushed by 0009's existing sync. String milestone ids so the
  launch set can grow without index collisions; no timestamps (daily-hook
  adjacent data with no consumer).
- **Self-healing rule:** any milestone derivable from stats (the Depth
  family, first sell, first lost run) is re-derived at load if missing — so a
  migration or a post-launch badge back-awards itself with no retro-scan
  machinery. Event-only badges (the survival four) can't be back-derived and
  are simply earnable going forward. With honorific-only rewards, that
  tolerance is all the cheat/corruption story this layer needs.
- Deliberately **not** tracked: playtime (fiddly against the web tab
  lifecycle, and it invites the wrong self-measurement).

## Flagged consequences (nothing reopened)

- **[0006](../tickets/0006-economy-upgrades.md) untouched** — *because of*
  the honorific hard line. No cash, no soft currency, no material payouts.
- **[0008](../tickets/0008-art-audio.md) honored** — zero new art; 14 lines
  of copy are the only new content; celebration reuses existing juice.
- **[0009](../tickets/0009-save-system.md)** gains exactly two fields under
  its existing versioning — a planned extension, not a reopening.
- **[0003](../tickets/0003-core-loop.md)'s hub** gains exactly one button.
- **[0010](../tickets/0010-monetization.md)'s** support corner and
  no-engagement-farming stance are both respected (daily hooks rejected
  partly on the same grounds).

## What this is NOT

Not an implementation. No Godot scenes, autoload code, or badge copy written
here beyond the one example line. This note fixes the layer's shape; building
the Miner's Log screen, the event hooks, and the 14 lines of copy is
downstream execution — and it's small.
