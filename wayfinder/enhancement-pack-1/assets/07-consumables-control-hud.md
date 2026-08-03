# EP1-07 — Consumables control & HUD

_Resolves [EP1-07: Consumables control & HUD](https://github.com/fiachramcv90/gem-mining-game/issues/44). Chosen by thumb on a real iPhone (iOS Safari, full-screen) against a live grey-box. Prototype: [`07-hud-greybox.html`](./07-hud-greybox.html)._

## How it was tested

An HTML/JS grey-box (not the Godot export — see the caveat at the end) deployed to a Vercel preview and thumb-tested on a real iPhone. It reproduced the load-bearing input reality: a **dynamic trailing virtual stick** ([0004](../../tickets/0004-dig-feel-controls.md) model — floating origin, base trails the thumb, ~16% dead zone) driving the digger through rock, so the steering thumb was genuinely occupied while the other thumb worked the HUD. Layout, aim mode, and slot cap were live-togglable to compare on the device.

## Locked decisions

- **HUD layout → corners.** The 3 slot buttons stack in the **top-right corner** (opposite the roaming stick). Every slot is reachable with the off-hand thumb without a grip change, and it never crowds the stick's area or the drill zone. (Side-strip and bottom-row layouts were tried and rejected on the device.)
- **Slot cap → 3 confirmed ergonomic.** Three buttons do not crowd the screen in the corner. No feedback to [#42](https://github.com/fiachramcv90/gem-mining-game/issues/42) — the 3-slot model holds.
- **Two thumbs are independent — no mis-taps.** Jabbing a slot button mid-steer never dropped or fumbled the stick. The scarcest resource (input real-estate) survives adding the loadout, because the buttons sit off the stick's territory.
- **Instant items (flare, fuel cell, repair kit) → one tap, no aim.** Fire immediately on tap with zero interruption to steering or hold-to-drill.
- **Scout → tap-target (directional lead).** Tap a point; the scout heads that way. Reads cleanly and doesn't fight the movement stick. (Drag-aim was the rejected alternative.)
- **Dynamite → drops at the digger, then flee (place-and-retreat preserved).** The key finding: **tap-target placement *removed* dynamite's whole risk** — tapping a spot away from yourself means you're already clear, so detonation is trivially safe ("it detonated immediately"). That guts [#42](https://github.com/fiachramcv90/gem-mining-game/issues/42)/[#45](https://github.com/fiachramcv90/gem-mining-game/issues/45)'s *"too slow to leave the blast radius and you eat the damage yourself"* design. So dynamite is **not** tap-targeted: the charge **drops on/just below the digger**, and you must **thrust clear with the stick before it blows** — a DETONATE control reachable only *after* you've moved (or a short fuse). Linger in the radius → self-damage. This is the input sequence [#45](https://github.com/fiachramcv90/gem-mining-game/issues/45) inherits.

## The input sequence handed to #45 (dynamite)

1. Tap the armed dynamite slot → charge **drops at the digger** (no aiming).
2. **Retreat** — steer away with the stick; the armed state persists through the move.
3. **Detonate** — a DETONATE control (reachable post-move) or a short auto-fuse fires the blast.
4. **Self-damage** if the digger is still inside the blast radius at detonation — the gamble #42 wants.

#45 owns the concrete numbers (blast shape/size, fuse timing vs manual detonate, self-damage calibration against [0007](../../tickets/0007-hazards-depth.md) bands, hardness cap, gem handling).

## Confirm-during-build (carried, not an open decision)

The ergonomic calls above were settled on an **HTML grey-box**, not the Godot single-threaded web export. The button geography, reach, mis-tap independence, aim gesture, and place-retreat model transfer directly (and the dig-*feel* itself is already locked by 0004). What remains is a **build-phase confirmation** that the real Godot HUD, over the actual stick, still feels right — an execution-time check (0011-style), not a reopened decision.

## Downstream

Unblocks **[#45](https://github.com/fiachramcv90/gem-mining-game/issues/45)** (dynamite mechanics) with the place-at-digger/retreat/detonate input model. No shipped-spec amendment (the HUD is additive). [#48](https://github.com/fiachramcv90/gem-mining-game/issues/48) folds the HUD layout + activation model into the EP1 spec; the leaderboard onboarding fog is unaffected.
