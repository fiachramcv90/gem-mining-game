---
id: 0013
title: "Tutorial & onboarding"
type: grilling
status: open
assignee: fiachramcv90
blocked-by: [0003, 0004, 0008, 0009]
---

## Question

Design the **minimal** onboarding: for each first-run teach moment and nudge,
decide its **surface** (tap-to-start screen, hub, contextual mid-run),
**timing/order**, **form** (text line, animation, diegetic cue), and
**dismissal** (one-time? persisted where in [0009](0009-save-system.md)'s
save Dictionary?). The elements are all decided — this ticket only arranges
them:

- **Controls need almost nothing** — [0004](0004-dig-feel-controls.md) showed
  the dynamic/trailing virtual stick is grasped near-instantly ("push to fly,
  hold into rock to dig"). Decide whether it gets a one-line hint or nothing.
- **Round-trip fuel** ([0003](0003-core-loop.md)) is the one rule a new
  player can genuinely lose a run to (ascent costs fuel — reserve enough to
  climb home). Decide how it's taught without a text wall: first-run fuel
  warning? A gauge affordance? A cheap first lesson (early runs are shallow,
  so the first fuel-out is low-stakes by design)?
- **"Add to Home Screen first" nudge** ([0009](0009-save-system.md)) — the
  installed PWA dodges iOS Safari's 7-day storage-eviction cap, so this
  protects the player's save. When and how hard to nudge without nagging?
- **One-time, non-blocking silent-switch nudge**
  ([0008](0008-art-audio.md) / [0011](0011-ios-smoke-test.md)) — "🔊 flip off
  silent for sound" on the tap-to-start screen that already unlocks Web
  Audio.

**Hard constraints (locked):** nothing gates play — no forced tutorial, no
modal sequence; audio is a bonus layer and every juice beat already lands
with sound off (0008), so onboarding must assume silent players; bias small
(solo dev). The [0004 prototype](../prototype/) /
[live build](https://fiachramcv90.github.io/gem-mining-game/) is the
reference for what the first 10 seconds actually feel like.
