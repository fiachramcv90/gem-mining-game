---
id: 0013
title: "Tutorial & onboarding"
type: grilling
status: closed
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

## Resolution

Onboarding is **two text lines, one gauge behaviour, and two nudges** —
nothing gates play, zero modals, every beat lands silent, no new art, and the
whole thing costs **one `nudges` save key with two fields**. Full arrangement
in the [design note](../assets/0013-tutorial-onboarding.md).

- **Controls** ([0004](0004-dig-feel-controls.md)) — one **ghost line** on the
  first descent (*"push to fly · hold into rock to dig"*), self-dismissing on
  the first dig (~10 s backstop). First-run is **derived** from an empty
  dug-delta in the save — no dismissal flag.
- **Round-trip fuel** ([0003](0003-core-loop.md)) — taught diegetically,
  permanently: the fuel-gauge pulse (0008's juice table) is pinned
  **round-trip aware** — it fires when remaining fuel approaches the estimated
  ascent cost from current depth (threshold multiplier = an `@export` knob),
  plus a permanent **death-reason line** on the run-lost screen (*"ran dry
  below ground — the climb home costs fuel too"*). No mid-run tutorial text;
  the cheap first lesson (shallow early runs) does the rest. No save flag.
- **Add-to-Home-Screen** ([0009](0009-save-system.md)) — a new permanent
  **💾 save-safety corner** in the hub (opposite [0010](0010-monetization.md)'s
  ♥ corner) opens a non-blocking panel: install how-to + 0009's save
  export/import (their permanent home). The **nudge** is a temporary callout
  label on that glyph, triggered the first time the save holds something worth
  missing (**first sell or first run lost**), persisting until installed or
  dismissed, re-shown **once** after a later run lost, suppressed when
  standalone. Persisted as `nudges.a2hs_dismissed` (int 0–2).
- **Silent-switch** ([0008](0008-art-audio.md) /
  [0011](0011-ios-smoke-test.md)) — static caption under the tap prompt,
  **first session only** (strict reading of 0008's "shown once"), retired by
  `nudges.audio_hint_shown: true`; the game-starting tap dismisses it.

**Final hub census** (complete, for 0014): sell · refuel/repair · upgrade ·
descend + Miner's Log button + ♥ Support corner + 💾 save-safety corner.
