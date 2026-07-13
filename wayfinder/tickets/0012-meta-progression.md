---
id: 0012
title: "Meta-progression & retention"
type: grilling
status: open
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
