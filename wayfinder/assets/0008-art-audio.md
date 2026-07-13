# Art & audio direction — the direction note

> Design asset for ticket **0008 — Art & audio direction**.
> Audience: Fiachra — solo dev, evenings/weekends, no deadline; new to Godot,
> strong web/TS. Reached by grilling, not decided for him.
> Scope: what the game **looks and sounds like**, the **animation budget** a solo
> dev can actually hold, where **assets come from** (all free / hand-made — zero
> budget), and the **'juice' checklist**. This ticket sets **direction**, not
> deliverable art: no real art pipeline, no vertical-slice art pass, no final
> assets. **Fixed upstream** (not relitigated): 16 px tiles · 32×32 chunks ·
> capped particles/pickups (0005 + Performance fog / 0002 §4); 5 bands
> Topsoil→Bedrock, gem tiers T1–T5 + off-scale prize, 2–5-tile veins in a
> +1-hardness halo, prize glints through darkness (0005/0006/0003); darkness =
> shrinking view radius (0003); hazards telegraph, lava glows (0007); audio =
> Sample one-shots + looped music, **no runtime bus effects** (0002 §3, confirmed
> 0011); iOS silent switch mutes Web Audio, no reliable web vibration (0011).
> **Owned downstream / out of scope here**: monetization (0010), the real art
> pipeline, on-device performance profiling.

## TL;DR

- **Make everything, spend nothing.** Zero budget → all art hand-made in a free
  editor (**Pixelorama**); all SFX generated free (**jsfxr/ChipTone**) + a little
  foley; all music self-composed free (**Bosca Ceoil**). AI/Claude is scoped to
  **palette, reference mockups, and procedural/code-gen tile variation** — *not*
  final legibility-critical sprites (general image models can't hit true 16 px on
  a fixed palette with a bespoke legibility system; dedicated pixel-AI tools cost
  money).
- **16 px, one fixed master palette: Resurrect-64.** The spine of legibility is
  **reserve saturation** — rock stays desaturated/earthy; **gems, lava, and the
  prize glint own the saturated hues**, so a handful of bright pixels still read
  as "not-rock" at the edge of a shrinking view radius. Bands differentiate by
  **hue+value shift of a shared rock ramp** (Topsoil warm/light → Bedrock
  cold/dark), reinforcing the darkness curve. The **+1-hardness halo = a darker,
  tighter-grained ring** around a vein — you *see* the rock harden a beat before
  you break through.
- **Near-zero hand-drawn frames.** Motion is **code + particles + one shared
  shader library**, playing to the TS/code strength and away from the
  pixel-animation time-sink. Player/drill driven by Godot `Tween`s (bob, drill
  spin, squash-on-impact); impacts/pickups by capped particles + tween pops;
  gem glint / lava glow / prize shimmer by **one reused CanvasItem shader**. Hand
  frames only as a last-resort 2-frame fallback.
- **Sound is warm, chunky, lo-fi — and a bonus, never load-bearing.** SFX =
  ~10–12 one-shots + 2–3 loops, synth-generated primary, **foley for the dig
  thud** (the core verb needs to feel like rock). Key reframe: *"no bus effects"
  is a **runtime** constraint* — you can **bake reverb/EQ/compression into the
  sample offline** in Audacity, so one-shots can sound rich despite a dry bus.
  Music = **self-composed ambient loops, depth-crossfaded** (Bosca Ceoil), ~3–4
  loops.
- **Visual-first juice.** Because the iOS silent switch can mute all audio and
  there's no reliable web vibration, **every feedback beat fully lands with the
  sound off**; audio + best-effort `navigator.vibrate` are additive layers only.
  "Haptics-equivalent" = a short sharp **screen-shake + flash**. All effects stay
  inside the capped particle/memory budget (pooled, small counts, fast decay).
  Ship a **reduce-motion/shake toggle** (`prefers-reduced-motion`).

---

## 0. What's fixed, what 0008 owns

0008 doesn't get to reinvent the world — it dresses a frame five earlier tickets
already nailed down. **Fixed:** 16 px tiles, 32×32 chunks, capped particles
(0005/0002 §4); the 5 bands, gem tiers + prize, vein/halo telegraph, prize-glint
(0005/0006/0003); darkness = shrinking radius (0003); hazards telegraph + lava
glows (0007); Sample one-shots + looped music, no runtime bus effects (0002 §3 /
0011); iOS silent switch mutes audio, no reliable vibration (0011).

**0008 owns:** the concrete *look* (palette, band identities, how the telegraphs
and glint read at 16 px), the *animation budget*, the *SFX/music palette and
sourcing*, and the *juice checklist* — plus the **art of the hazard tells** (0007
declared *that* they telegraph; 0008 says *what* that looks like).

---

## 1. The look

### 1.1 Tile size & readability target

16 px is fixed (0005). It's also the friend here: a 16×16 tile is the single most
tractable thing for a beginner to hand-make — a gem is ~10 pixels of decision.
The art carries an unusually heavy legibility load for that size (5 band
identities · 6 gems · a halo telegraph · lava/gas/cave-in tells · a prize glint
legible at the edge of darkness), so **the palette does most of the work.**

### 1.2 Palette: Resurrect-64 + reserve saturation

- **One fixed master palette for the whole game: Resurrect-64** (a popular,
  pre-harmonised 64-colour Lospec palette with strong earthy rock ramps *and*
  vivid accent hues). 64 gives headroom for 5 band ramps + 6 gems + hazards +
  player + UI without hand-tuning harmony — and it's a **one-click import in
  Pixelorama**. Endesga-32 was the considered alternative (punchier/arcade,
  fewer decisions) — rejected as too tight for this many roles and tonally too
  saturated against the naturalistic look.
- **Reserve saturation — the load-bearing rule.** Rock stays low-saturation and
  earthy. Gems, lava, and the prize glint own the saturated end of the spectrum.
  This is what makes a gem, a hazard, or the glint read instantly as "not-rock"
  even as a few bright pixels at the edge of a shrinking view radius — exactly
  what the glimpsed-prize hook and hazard telegraphs need.
- **Bands = hue+value shift of a shared rock ramp.** Topsoil warm/light → Bedrock
  cold/dark, so the world feels like one continuous descent getting deeper and
  darker, directly reinforcing the darkness curve. Each band gets a 3-value ramp
  (dark/mid/light) for shading a 16 px tile.

### 1.3 The telegraphs (art owns these)

- **Vein halo (+1 hardness):** a **darker, tighter-grained ring** of rock hugging
  the vein, optionally a 1 px darkest rim — you *see* the rock harden the instant
  before you feel it and break through. Visual telegraph married to the dig-feel
  resistance spike.
- **Prize glint:** the reused glint shader, tuned brightest, throwing a small
  **gold cross-glint** that pierces the darkness overlay while ordinary gems dim.
  That single readable sparkle at the edge of vision *is* the glimpsed-prize hook.
- **Hazard tells (0007 → art):** **lava glows** (self-lit; stays bright under the
  heaviest darkness so it can't be hidden); **gas pockets** get a legible
  shimmer/tint tell in the rock before you drill them; **cave-ins** get a
  cracking/dust visual cue. All designed to remain legible at the edge of the
  view radius — Light buys the sight to catch them.

A rendered **moodboard** (both palettes, the full scene — 5 bands, gems, halo,
lava, prize-glint-through-dark) is committed alongside this note:
[`0008-palette-moodboard.html`](0008-palette-moodboard.html)
([published copy](https://claude.ai/code/artifact/0a01effe-24ea-4f1d-82aa-98b0b29ccbdf)).
Hexes there are illustrative recall, to be swapped for canonical Resurrect-64 in
Pixelorama.

---

## 2. Animation budget (the honest solo-dev call)

Hand-animating pixel art is the biggest time-sink in this ticket and the easiest
place to lose months. The plan **dodges it** and leans on code:

- **Player/drill:** no frame animation. Godot `create_tween` for bob-while-
  thrusting, drill-bit rotation, squash-on-impact. Interpolating transforms — the
  TS/web wheelhouse.
- **Dig impacts & pickups:** **capped particles** (4–8 pooled per burst) + a
  tween scale-pop + micro screen-shake. Never frames. Huge juice-per-effort, and
  it lives inside the particle budget already imposed by 0005/0002.
- **Gem glint / lava glow / prize shimmer:** **one small shared CanvasItem shader
  library** — one shader animates every gem/hazard for free instead of 6× hand
  twinkles.
- **Hand-drawn frames: fallback only.** If a shader glint proves fiddly, a 2-frame
  gem twinkle. Cap any frame animation at 2–4 frames, only where nothing cheaper
  works.

---

## 3. The sound

Warm, chunky, **lo-fi underground** — not bleepy-arcade (which would fight the
naturalistic Resurrect-64 look). And, per 0011, **a bonus layer, never load-
bearing**: the game is designed to feel complete with the sound off.

### 3.1 Reframe: "no bus effects" is runtime-only

The 0002/0011 constraint bans *realtime* reverb/doppler/procedural on the audio
bus. It does **not** stop you baking reverb, EQ, and compression **into the
sample offline** (Audacity) and shipping a flat one-shot that plays as a plain
Sample. So SFX can sound spacious and rich despite a dry runtime bus.

### 3.2 SFX palette & sourcing

- **Tool: jsfxr / ChipTone (bfxr family)** — free, browser, CC0, tiny one-shot
  WAV/OGG that map exactly onto Sample-playback. Primary source for UI, pickups,
  alerts, upgrade-buy.
- **Foley for the tactile core:** the **dig thud** is the sound you feel most (the
  core verb); a synth blip won't sell "chunk of rock." Record a knock/crunch in
  Audacity, shape it, bake in a touch of cave reverb offline. Same option for the
  gem-collect.
- **Scoped palette (~10–12 one-shots + 2–3 loops):** dig thud · halo break-through
  (richer thud) · gem chime · pickup · upgrade-buy · hull-hit · gas hiss ·
  cave-in rumble · low-fuel warning · run-lost sting · UI click.
  **Loops:** engine hum · lava sizzle · (optional) deep ambient drone.

### 3.3 Music

- **Self-composed ambient loops in Bosca Ceoil** (free, built for non-musicians;
  LMMS if more control is wanted later). **Don't write a soundtrack — write a few
  loops.**
- **Depth-crossfaded ambient:** a light surface-hub theme + 2–3 low-key descent
  loops that crossfade by depth, reinforcing the band progression and darkness
  curve. Crossfading loop *volumes* is playback, not a runtime bus effect or
  "procedural" — allowed. Total scope **~3–4 loops**.

---

## 4. The 'juice' checklist

**Governing principle — visual-first.** The iOS silent switch can mute all audio
(0011) and there's no reliable web vibration, so **every feedback beat fully
lands with the sound off**. Audio and best-effort haptics are additive only.
"Haptics-equivalent" = a short sharp **screen-shake + flash** doing the tactile
punctuation. Everything stays inside the capped particle/memory budget.

| Moment | Visual (primary) | Audio (bonus) |
|---|---|---|
| **Dig tick / break** | capped debris burst (4–8, pooled) + drill squash + micro-shake | dig thud |
| **Halo break-through** | slightly bigger pop — rewards the telegraph payoff | richer thud |
| **Gem collect** | sparkle + gem tween-pops to the hold + value popup | gem chime |
| **Hazard hit (Hull)** | bigger shake + red edge-flash/vignette + Hull-bar jolt | hull-hit |
| **Prize glimpse** | the glint shader at the edge of vision | faint sting |
| **Low fuel / round-trip** | pulsing fuel gauge + edge flash | warning beep |
| **Upgrade buy** | punchy UI scale-pop + sparkle | buy chime |
| **Run lost / cargo full** | desaturate/fade or icon shake | sting |

**Budget discipline:** pool particles; cap concurrent emitters; tiny per-burst
counts; screen shake via camera-offset noise with fast decay (cheap code).
**Reduce-motion / reduce-shake toggle:** ship it, honouring `prefers-reduced-
motion` (accessibility + shake is polarising). **Best-effort `navigator.vibrate`:**
fire where supported (Android Chrome), silently absent on iOS, never relied on.

---

## 5. Asset-source list (all free / hand-made)

| Asset class | Source | How | Cost |
|---|---|---|---|
| World tiles (5 bands), gems (6), player/drill, hazard tiles | **Hand-made** in **Pixelorama** | 16 px, Resurrect-64, reserve-saturation | £0 |
| Rock texture variation | **Procedural / code-gen** (seeded noise dither) | on-brand with `FastNoiseLite` worldgen; AI/Claude can scaffold the script | £0 |
| Palette / reference / moodboard | **AI (Claude)** | palette definition, swatch/moodboard, reference mockups to copy by hand | £0 |
| Glint / glow / shimmer | **Shader** (hand-written CanvasItem) | one reused shader library | £0 |
| Particles | **Godot nodes** (CPUParticles2D preferred on Compatibility) | pooled, capped | £0 |
| SFX one-shots | **jsfxr / ChipTone** (CC0) + **Audacity** foley | synth primary, foley dig thud, effects baked offline | £0 |
| Music loops | **Bosca Ceoil** (self-composed) | ~3–4 ambient loops, depth-crossfaded | £0 |
| Editors / DAW | Pixelorama · Audacity · Bosca Ceoil / LMMS · jsfxr/ChipTone | all free/open-source | £0 |

**Explicitly *not* used:** paid asset packs, paid pixel-AI tools (PixelLab/Retro
Diffusion — credit/subscription), CC-BY assets with attribution obligations.
General image models (Midjourney/Flux/DALL·E) are **not** a final-sprite source —
they fail true-16 px on a fixed palette and can't hold the bespoke legibility
system.

---

## 6. Godot learning-path notes (new-to-engine gotchas)

- **Crisp pixels:** set texture filtering to **Nearest** (Project Settings →
  Rendering → Textures → *Default Texture Filter = Nearest*, or per-import); use
  the **"2D Pixel" import preset**. Otherwise 16 px art blurs.
- **SFX vs music import:** import short SFX as **WAV → Sample** (one-shot, unlocks
  on first tap per 0002/0011); import music as **OGG Vorbis** with loop enabled
  (compressed — matters for the memory ceiling).
- **Particles on web:** on the **Compatibility/WebGL2** renderer (the only web
  target — 0002), prefer **CPUParticles2D** unless GPUParticles2D is verified
  safe; cap the total to respect 0005/0002's particle budget.
- **Motion without frames:** `create_tween()` for squash/stretch/bob/pops;
  camera-offset noise for screen shake with fast decay.
- **Glint shader:** a small CanvasItem fragment shader sweeping a highlight,
  parameterised per material (gem tier, lava, prize).

---

## 7. Fog this decision sharpens (handed to the map, not ticketed here)

- **Tutorial / onboarding** — adds a **one-time, non-blocking silent-switch
  nudge** ("🔊 flip off silent for sound") on the tap-to-start screen you already
  need to unlock Web Audio. Never a modal, never gates play, shown once. The juice
  layer is now specified, so onboarding can assume the visual-first feedback
  exists.
- **Meta-progression visual hooks** — milestones now have concrete *visual*
  identities to reward (first prize-gem glint, first Bedrock, surviving lava);
  this note gives those hooks their look **without** reopening meta-progression
  (its own future ticket). Monetization (0010) stays out entirely.

---

*Direction, not deliverables: this note fixes the look, the sound, the animation
budget, the juice, and where every asset comes from — so the vertical-slice art
pass and the real pipeline start with no open art/audio decisions.*
