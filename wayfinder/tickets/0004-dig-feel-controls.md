---
id: 0004
title: "Dig feel & touch controls prototype"
type: prototype
status: closed
assignee: fiachramcv (claude session claude/gem-miner-dig-feel-0004-f2wuc8)
blocked-by: [0001, 0002]
---

## Question

How should digging feel and be controlled on a touchscreen (and mouse for web)? Tap-adjacent-tile vs drag-direction vs virtual stick; dig speed vs rock hardness; movement physics (floaty jetpack vs grounded). Build the cheapest possible Godot prototype — grey boxes, one screen — and react to it. This is the make-or-break feel question.

## Resolution

**Virtual stick + floaty movement + hold-to-drill (dig time ∝ rock hardness).**
Decided by feel-testing a grey-box prototype on a real iPhone, not from code —
all three axes were switchable live to compare thumb-to-thumb.

- **Virtual stick** (a *dynamic, trailing* stick — floating origin, base follows
  the thumb past the ring so reversing thrust is instant, ~16% dead zone). Beat
  **tap-adjacent** (stop-start, discrete) and **drag-direction** (no persistent
  neutral anchor). The trailing behaviour is what took the stick from "best of
  these but not right" to genuinely good — it must survive into the real game.
- **Floaty** jetpack-in-dirt beat **grounded**: it makes descent and the
  self-powered climb home (0003) one continuous flying verb rather than two modes.
- **Hold-to-drill** (~0.34 s per hardness unit) beat **instant**: feeling harder
  rock as resistance is the core tactile pleasure; instant made the world feel
  like paper.

Consistent with 0001 (direct-control body, per-cell hardness, touch-first),
0002 (shipped as the single-threaded WebGL2 web export — how it was felt on
iPhone), and 0003 (floaty ascent burns the shared round-trip fuel budget).

**Asset:** [Dig feel & touch controls — the decision](../assets/0004-dig-feel-controls.md)
(full rationale, discarded options, dig-time constant for 0005, onboarding
implications, and Godot learning notes).
**Prototype:** [`prototype/`](../../prototype/) · live build
(single-threaded web export, deployed from `main`):
**https://fiachramcv90.github.io/gem-mining-game/** · built via PRs #4 and #5.
