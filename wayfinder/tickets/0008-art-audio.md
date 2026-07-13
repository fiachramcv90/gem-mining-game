---
id: 0008
title: "Art & audio direction"
type: grilling
status: closed
assignee: fiachramcv90
blocked-by: []
---

## Question

What does the game look and sound like, and where do assets come from? Pixel art tile size (16px? 32px?), palette, animation budget for a solo dev, free/paid asset packs vs hand-made, audio/SFX sourcing, and the 'juice' checklist (particles, shake, haptics-equivalent on web). Output: a direction note + asset source list.

## Resolution

**Make everything, spend nothing — direction set; all decisions within the fixed
16 px / capped-particle / dry-bus / silent-switch frame.**

- **Look:** 16 px, one fixed master palette — **Resurrect-64** — with the
  load-bearing **reserve-saturation** rule (rock desaturated; gems/lava/prize
  glint own the saturated hues, so bright pixels read as "not-rock" at the edge
  of a shrinking view radius). Bands = hue+value shift of a shared rock ramp
  (Topsoil warm/light → Bedrock cold/dark). **Halo telegraph = a darker,
  tighter-grained ring** around a vein. Prize = a gold cross-glint (shader) that
  pierces darkness. Lava self-lit; gas/cave-in get legible tells (art owns 0007's
  telegraphs). Endesga-32 considered and rejected (too tight, too saturated).
- **Make vs buy:** **all free / hand-made** — **Pixelorama** (tiles/gems/player/
  hazards), procedural noise-dither for rock variation. AI/Claude scoped to
  **palette + reference + procedural code-gen only**, *not* final sprites (general
  image models fail true-16 px on a fixed palette + bespoke legibility; paid
  pixel-AI tools ruled out by zero budget).
- **Animation budget:** **near-zero hand-drawn frames** — motion via Godot
  `Tween`s (player/drill), **capped pooled particles** (impacts/pickups), and
  **one reused CanvasItem shader** (glint/glow/shimmer). 2-frame hand anim is a
  last-resort fallback only.
- **Sound (bonus layer, never load-bearing):** warm/chunky lo-fi. SFX ~10–12
  one-shots + 2–3 loops via **jsfxr/ChipTone** (CC0) + **foley for the dig thud**;
  key reframe — *"no bus effects" is runtime-only, so bake reverb/EQ into samples
  offline in Audacity*. Music = **self-composed depth-crossfaded ambient loops in
  Bosca Ceoil** (~3–4 loops).
- **Juice — visual-first:** because the iOS silent switch mutes audio and web
  vibration is unreliable, **every feedback beat lands with sound off**; audio +
  best-effort `navigator.vibrate` are additive only. "Haptics-equivalent" =
  screen-shake + flash. Full moment→visual→audio checklist in the note. Ship a
  **reduce-motion/shake toggle** (`prefers-reduced-motion`); particles pooled +
  capped.
- **Fog sharpened (handed to the map):** onboarding gains a one-time non-blocking
  **silent-switch nudge**; meta-progression gains concrete **visual hooks** (first
  prize glint, first Bedrock, surviving lava) — without reopening either.
  Monetization (0010) untouched.

**Direction note:** [`assets/0008-art-audio.md`](../assets/0008-art-audio.md) ·
**moodboard:** [`assets/0008-palette-moodboard.html`](../assets/0008-palette-moodboard.html)
([published](https://claude.ai/code/artifact/0a01effe-24ea-4f1d-82aa-98b0b29ccbdf)).
