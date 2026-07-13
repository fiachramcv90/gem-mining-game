---
id: 0012
title: "Meta-progression & retention"
type: grilling
status: closed
assignee: fiachramcv90
blocked-by: [0003, 0006, 0007, 0008]
---

## Question

What is the meta-progression & retention layer — the reasons to come back
across days and weeks, beyond the moment-to-moment loop? Decide its **forms**
(milestones/achievements? lifetime stats screen? depth records? daily hooks?),
its **milestone set**, and its **reward language** — or decide deliberately
that the persistent mine + upgrade ratchet already carry retention and the
layer stays thin.

The landmarks to pin milestones to are now concrete:

- **Economy landmarks** ([0006](0006-economy-upgrades.md)): first upgrade
  (~run 3), first Bedrock (~run 19), first prize gem (900, off-curve),
  affording the 5000 Hoist, reaching the ~700-tile designed bottom
  ([0005](0005-worldgen.md)) — the standing "one-more-run" goal.
- **Danger acts** ([0007](0007-hazards-depth.md)): survived first Bedrock
  lava, first cave-in dodged, reached "The Deep".
- **Visual hooks** ([0008](0008-art-audio.md)): first prize-gem glint, first
  Bedrock, surviving lava — rewards should lean on these existing hooks
  (palette, glint shader, screen-shake+flash juice), not new art.
- **The mine itself** ([0003](0003-core-loop.md)): the persistent carved
  shaft *is* visible lifetime progress — decide what this already covers
  before adding systems on top.

Sub-questions to settle:

- Which forms fit a **solo-dev, web-first, no-server** game? Daily hooks have
  no backend and no accounts — anything time-based must be client-side and
  cheat-tolerant (or rejected for that reason).
- What state does each form persist, as fields in
  [0009](0009-save-system.md)'s plain-Dictionary save (versioned)?
- Where do milestones surface (hub screen? title screen?) given
  [0010](0010-monetization.md) already claims one quiet corner of the hub?

**Hard constraints (locked — flag, don't break):** no cash sink and no soft
currency (would collide with 0006's no-death-spiral economy); no new art
beyond 0008's existing hooks; no server/accounts; small scope (solo dev,
evenings/weekends). If a retention idea would force reopening a closed
decision, record it as a flagged consequence — do not silently break the
decision.

## Resolution

**The persistent mine + upgrade ratchet are affirmed as the primary retention
engine; one thin honorific layer — the Miner's Log — sits on top. Daily hooks
are rejected on the record.** Full detail in the
[design note](../assets/0012-meta-progression.md).

- **Thickness:** thin-but-not-zero. Lifetime stats + a curated milestone set;
  nothing heavier. The layer *celebrates* beats the core already produces
  (carved shaft, run-ending hooks, the ratchet, the unreached 700-tile
  bottom) — it is not a second engine.
- **Daily hooks: rejected**, not deferred — (a) nothing legal to pay out
  (0006 bans cash/soft currency, 0008 bans new art, client clock is
  cheatable), (b) streak guilt is tonally opposite the no-death-spiral
  design and 0010's no-engagement-farming stance, (c) the persistent mine
  *is* the reason to return tomorrow.
- **Milestone set: 14 badges in three families** — Depth 5 (first Clay /
  Sandstone / Granite / Bedrock + the ~700-tile bottom capstone), Wealth 4
  (first sell, first upgrade, first prize gem *banked*, the 5000 Hoist),
  Survival 5 (one per 0007 hazard mechanism + first lost run as a
  rite-of-passage badge). **Ground rule:** every milestone pins to an event
  the game already detects — no new detection systems. Names/count are
  launch content; families + pin rule are the decision. No cumulative grind
  badges (those are stats).
- **Reward language: honorific-only is a hard line** — a badge that grants
  +anything becomes a shadow currency and reopens 0006. Celebration = 0008's
  existing shake+flash plus a one-line terse miner-voiced banner
  (*"BEDROCK. Few dig this deep."*); fire-at-the-moment (never a modal
  mid-run), honored fully in the Log at the hub. The flavour lives in the
  copy — 14 lines of it are the whole content cost.
- **Surfacing: one Miner's Log screen** (stats + checklist together) behind
  **exactly one new hub button**; title screen untouched; 0010's support
  corner unencroached; unearned badges show as "???" silhouettes.
- **Persistence (0009):** two new save-Dictionary fields under the existing
  `save_version` — `stats` (8 int counters: deepest_depth, tiles_dug,
  gems_collected, money_banked, prize_gems_banked, runs_completed,
  runs_lost, cargo_value_lost) and `milestones` (string-id → true, no
  timestamps). Stat-derivable badges **self-heal at load**; event-only
  survival badges are simply earnable going forward. No playtime tracking.
- **Flagged consequences — nothing reopened:** 0006 untouched (because of
  the honorific hard line), 0008's no-new-art honored, 0009 gains two
  fields under existing versioning, 0003's hub gains one button.
