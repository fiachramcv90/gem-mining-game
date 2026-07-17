# Gem Miner — the game

The real Godot 4.3+ project, built to
[`wayfinder/assets/0014-final-spec.md`](../wayfinder/assets/0014-final-spec.md)
(the binding spec) using the terms of [`CONTEXT.md`](../CONTEXT.md).

## Vertical slice status (session 7)

NEW in session 7 — instrumentation & hardening (spec §16's prerequisite,
§13's `run` field, the shop's storefront pass, the Hoist payoff):

- **Web memory instrumentation (the §16 prerequisite, fixed for real):**
  the Safari-safe heap probe is live. 0011's `WebAssembly.Memory`
  monkey-patch could never fire — with `thread_support=false` the
  Emscripten module *defines* its own memory and exports it
  (`instance.exports.memory`); JS never constructs it. The new
  `html/head_include` shim (readable source: `web/head_include.html`)
  wraps `WebAssembly.instantiate(Streaming)` and stashes the exported
  memory; `DebugOverlay` (autoload) reads `buffer.byteLength` via
  JavaScriptBridge. For the same reason the old **512 MB clamp was dead
  config and is removed** — the wasm maximum is baked into the export
  templates at build time; no head shim can lower it. The overlay (FPS,
  WASM heap + peak, static mem, node/object counts, resident chunks +
  gen queue + pickups + lava shapes + prize tiles, depth, resize count,
  context-lost flag) hides behind **5 quick taps in the top-left corner
  of the tap-to-start screen** — never a hub census item, session-only,
  zero cost while hidden. The profiling protocol is in FEEDBACK.md;
  `smoke-test/` is deleted (spec §14 — the overlay supersedes it).
- **Mid-run save (spec §13, best-effort):** the `run` field is live —
  position/fuel/hull/cargo captured on the existing snapshot cadence
  whenever the digger is below the surface (the `visibilitychange` flush
  is the one that matters), `save_version` 3→4 through the migrate chain
  (key guaranteed, only ever added). Restore only when the field is
  complete and sane (`SaveManager._sane_run`: inside the shaft, above the
  designed bottom, pressures within the loaded caps, cargo legal and
  fitting) — anything less starts at the surface exactly as before;
  restores are stationary so they can never land as a mid-fall hit.
- **The shop is the ratchet's storefront** (owner feedback: it read raw):
  each track a card — name, its job in plain words, a code-drawn level
  pip strip, a current → next effect line, and a price button with three
  glance-distinct states (gold-rimmed affordable / dim priced
  can't-afford / green MAX–OWNED) via the new
  `UITheme.style_price_button`/`row_box` extensions. The bought row pops
  (same tween idiom as the banked-gold beat); Juice's screen-wide upgrade
  flash unchanged. **Presentation only — 0006's prices, effects, and the
  Hoist reveal rule are untouched.**
- **The Hoist pays its time half** (spec §4 "ascent fuel & time ×0.5"; the
  fuel half was already `ascent_factor`): an ascent thrust/speed assist
  gated on `Upgrades.hoist` — `Player.hoist_ascent_boost` (1.9) lifts the
  floaty climb's terminal speed ≈2× only while thrusting up below the
  surface. Non-owners run the 0004 constants bit-for-bit.

## Vertical slice status (session 6)

NEW in session 6 — the §7 art & juice pass (make everything, spend
nothing):

- **Real tiles** (replacing the grey-box TileSet paint): 16 px tiles
  generated procedurally in code (`TileArt.gd`) on the fixed
  **Resurrect-64** master palette (`Palette.gd` — every colour a canonical
  swatch, named by role). The load-bearing **reserve-saturation** rule is
  encoded: rock ramps desaturated/earthy, gems/lava/prize own the
  saturated hues. Bands are hue+value shifts of one shared rock ramp
  (Topsoil warm/light → Bedrock cold/dark); halo = the same rock darker
  with a tighter grain + darkest flecks; gas wisps, cave-in cracks, lava
  blooms, chiselled bedrock walls. Procedural code-gen is the sanctioned
  AI lane (spec §7) — the tiles are deliberately cheap and swappable, so a
  hand-drawn Pixelorama atlas can replace `TileArt.gd` wholesale.
- **The digger robot** (feedback #6): drawn in immediate mode from the
  palette — hull, cab dome + glass, headlamp, skid plates — with all
  motion in code (spec §7 animation budget): hover bob, flickering
  thruster flame, a drill arm pointing along facing whose chevrons scroll
  while drilling (reads as spin), a jabbing bit, and a landing
  squash-and-recover tween. Zero hand-drawn frames.
- **Juice, visual-first** (`Juice.gd` + every knob in
  `config/JuiceConfig.gd`/`juice.tres`): short sharp screen-shake
  (camera-offset noise, fast decay) + a one-rect flash on the beats — dig
  thud, halo/gem break-through payoff, gem collect, hazard hit (lava
  ticks get the small beat), sell, run lost, upgrade buy, and the §8
  milestone banner (the SAME beat — 0008's shake+flash IS the
  celebration). Bursts are pooled `CPUParticles2D`, 4–8 per burst, every
  burst clamped to the existing `particle_cap` knob. `navigator.vibrate`
  fires best-effort, additive only. A **reduce-motion toggle** (Settings
  autoload, surfaced on the tap-to-start screen) honours
  `prefers-reduced-motion` on auto and kills the shake; it persists via
  the new `settings` save key — `save_version` 2→3 through the migrate
  chain, key only added.
- **The garage hub** (feedback #3 + #4): the hub is now a PLACE — a
  warm-lit garage on the surface beside the spawn point (`Garage.gd`,
  code-drawn from the palette, pulsing doorway lamp + GARAGE sign).
  Flying into the doorway opens the hub panel, replacing the SURFACE HUB
  button as the trigger; an arm/disarm latch means closing the hub never
  instantly reopens it. The §9 census is UNCHANGED (4 actions + MINER'S
  LOG + ♥ + 💾) and the hub still teaches itself. All panels (hub, shop,
  Log, run-lost, title, corners) share one code-built Theme
  (`UITheme.gd`): palette panels/buttons, gold headers, separators —
  feedback #4's layout/typography pass. Still default-font; a pixel font
  is a later asset call.
- **Sound, wired but placeholder** (`Sfx.gd`): the full §11-safe playback
  architecture — Sample playback only, every sound an `AudioStreamWAV`,
  no `AudioStreamGenerator`, no runtime bus effects; the tap-to-start tap
  is the unlock gesture and starts the loops. 13 one-shots (dig thud,
  halo break, gem/prize, sell, upgrade, milestone, hull hit, gas hiss,
  cave-in rumble, fuel warning, run-lost sting, UI click), an engine-hum
  loop that follows the stick, and **3 depth-crossfaded ambient loops**
  (volume crossfade between depth anchors — playback, not a bus effect).
  **Every sample is a code-synthesized stand-in** generated at boot: the
  architecture is real, the assets are not. The real palette
  (jsfxr/ChipTone + Audacity foley thud + Bosca Ceoil looped-OGG music)
  drops into the same names later.

## Vertical slice status (session 5)

NEW in session 5 — the Miner's Log + onboarding (specs §8/§9), and the hub
census is complete: the 8 lifetime stats as plain int counters incremented
at the moment of the event, and the 14 milestones (Depth 5 / Wealth 4 /
Survival 5), every one pinned to an event the game already signalled —
honorific-only, celebrated with a one-line terse banner mid-run (never a
modal) and honoured fully in the single Log screen behind the one new hub
button (unearned = "???"); stat-derivable badges self-heal at load; NO
daily hooks (rejected on the record). The save envelope stepped to
`save_version` 2 through the migrate chain — the `stats` / `milestones` /
`nudges` keys are live; v1 saves load clean and start counting from zero.
Onboarding per §9, all four elements: the controls ghost line ("push to
fly · hold into rock to dig", first descent only, derived from an empty
dug delta — no flag; first dig or the `ghost_line_backstop_secs` backstop
dismisses it); the round-trip fuel pulse (already live, threshold knob
`roundtrip_pulse_threshold`) + the permanent death-reason line on the
run-lost screen; the A2HS nudge as a temporary callout on the permanent 💾
corner (from first sell or first run lost, `nudges.a2hs_dismissed` 0–2,
one re-show after a later run lost, suppressed when standalone; the 💾
panel now carries the install how-to); and the tap-to-start screen with
the silent-switch caption (`nudges.audio_hint_shown` — the game-starting
tap dismisses it and is the Web Audio unlock gesture's home). The hub is
finally the full §9 census: 4 core actions + MINER'S LOG + the ♥ Support
corner (§15 — `support_url` knob, "coming soon" while empty) + the 💾
save-safety corner. Nothing else claims hub space.

## Vertical slice status (through session 4)

**Running:** seeded deterministic worldgen (5 bands, hardness(depth),
veins + halos, sparse caves) streamed in 32×32 chunks inside the bounded
resident window (spec §12); the ported 0004 stick/floaty/drill feel
(dynamic trailing stick); the three pressures + the single run-lost outcome;
iOS-safe single-threaded web export (spec §11); the save system per §13
(`user://save.dat` snapshots, `navigator.storage.persist()`, migrate-chain
skeleton, export/import in the 💾 save-safety corner); the full six-track
upgrade shop; the darkness renderer per §6 (a hazard's tell renders only in
the light; buying Light visibly pushes the dark back); the prize gem per §3
(gold cross-glint piercing to `prize_glint_radius`); gas pockets per §5;
the sell celebration. NEW in session 4 — the danger model is complete
(Acts II/III): cave-ins per §5 (Granite+ cracked/unstable rock, a pure
per-tile hash of `(world_seed, coords)` like gas, cracks-and-chips tell
drawn only in the light; the support check is simple and legible — an
unstable tile falls when the tile directly under it is dug out, a vertical
run comes down as one column — with a tremble telegraph
(`cavein_telegraph_secs`) before the drop; band damage {15,25} through
`GameState.apply_hazard_damage`; the fallen rock shatters, its origin cell
marked dug, so persistence is the ordinary dug delta — no new save keys);
lava per §5 (Bedrock molten pockets from a second seeded noise channel,
one `Area2D` contact volume with per-chunk shapes freed with the resident
window, `lava_tick_dmg` per `lava_tick_interval` while inside; lava GLOWS —
the second self-lit §6 exception, the darkness shader's glint path
generalised to cut the overlay open out to `lava_glow_radius`); the
unbreakable side walls now continue above the surface line — unbounded, so
the shaft is a pit between two cliffs that can never be flown over
(feedback #2, retuned after on-device play found a finite rim hoppable);
ascent fuel stepped down 1.0 → 0.7 (feedback #5, owner decision).

**Stubbed seams (later sessions):** the itch.io page itself (`support_url`
stays the empty placeholder knob), real audio assets (§7/§11 — the playback
architecture, crossfade and unlock gesture are live in `Sfx.gd`, but every
sample is a code-synthesized placeholder; the hand-made
jsfxr/foley/Bosca-Ceoil palette replaces them by name), a hand-drawn tile
atlas (the procedural `TileArt.gd` tiles are first-draft, swappable
wholesale), a real pixel font (all UI is themed default-font), and the §16
on-device READING itself — the instrumentation is live (session 7), the
numbers still have to be read off a real iPhone (protocol in FEEDBACK.md)
before the §12 tunables can be judged.

## Layout

- `config/` — `EconomyConfig` / `WorldgenConfig` / `HazardConfig` /
  `JuiceConfig` resources: every Appendix A (and §7 juice/audio) knob as a
  named `@export` default. Re-balancing is a slider drag.
- `scripts/autoload/` — `GameState`, `Wallet`, `Upgrades`, `MinersLog`
  (the §8 stats + milestones, event-pinned, self-healing), `Nudges` (the
  §9 nudge state), `Settings` (the §7 reduce-motion toggle,
  prefers-reduced-motion-aware), `SaveManager` (the §13 envelope, the
  SaveBlob seam, the migrate chain — v1→v2→v3→v4 — snapshot triggers, and the
  browser hooks), `Juice` (the §7 shake/flash/pooled-particle/vibrate
  beats — also the §8 milestone celebration), `Sfx` (the §11-safe sound
  layer: sample pool, engine hum, depth-crossfaded ambient; placeholder
  synth samples).
- `scripts/ui/` — `UpgradeShop` (the §4 ratchet storefront: track cards,
  pip strips, three-state price buttons — presentation only, 0006 closed),
  `DebugOverlay` (the §16 readout autoload behind the hidden title-screen
  corner-tap toggle), `MinersLogScreen`
  (the single §8 Log screen), `SaveCorner` (the permanent 💾 save-safety
  corner + the A2HS callout nudge), `SupportCorner` (the quiet ♥ §15
  link), `TitleScreen` (tap-to-start + the silent-switch caption + the
  motion toggle), and `UITheme` (the one shared §7 panel theme).
- `scripts/Palette.gd` + `scripts/TileArt.gd` — the Resurrect-64 master
  palette (named roles, reserve-saturation encoded) and the procedural
  16 px tile painter (deliberately swappable for a hand-drawn atlas).
- `scripts/Garage.gd` — the physical surface hub (feedback #3): doorway
  trigger with an arm/disarm latch; the census panel itself is the HUD's.
- `scripts/Worldgen.gd` — pure function of `(world_seed, chunk coords)`;
  never runtime `randf()` (gas + cave-in placement included: per-tile
  hashes with distinct salts; lava: its own seeded noise channel).
- `scripts/Mine.gd` — chunk streaming + the resident window; runtime
  grey-box TileSet; gas bursts; the cave-in support check; the lava
  contact volume + tick damage; resident prize-glint / lava-glow tracking.
- `scripts/CaveInRock.gd` — one undermined tile coming down: tremble
  telegraph → fall → shatter (never resettles — dug-delta persistence).
- `scripts/Darkness.gd` + `shaders/darkness.gdshader` — the §6 renderer:
  per-frame uniform updates only, no CPU pixel work; the lit disc plus
  both self-lit exceptions (prize glint, lava glow).
- `scenes/Main.tscn` — `Main → Mine + Player + DarknessLayer + HUD`
  (spec §10; darkness sits between the world and the HUD).

Desktop dev: arrows/WASD-equivalent (ui_* actions) drive the digger; mouse
emulates the touch stick.
