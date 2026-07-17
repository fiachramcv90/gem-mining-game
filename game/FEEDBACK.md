# On-device feedback log

Raw play feedback from the deployed build, each item assessed against the
binding spec ([`0014-final-spec.md`](../wayfinder/assets/0014-final-spec.md))
with its owning knob/section and a recommended action. This is the build
log the spec's §17 playtesting plan feeds — NOT a decision document: where
an item touches a closed decision, the decision stays closed and the entry
says so.

## 2026-07-17 — session-7 build (instrumentation & hardening)

### OWNER VERDICT applied: the UPGRADES menu read raw — reworked

The shop is now the ratchet's storefront (presentation only — every price,
effect, and the Hoist reveal rule still comes from Upgrades/EconomyConfig;
0006 stays closed): each track is a card with its name, its job in plain
words ("FUEL — how deep a round trip reaches"), a level pip strip
(filled/empty per level), a current → next effect line, and a price button
with three at-arm's-length states (gold-rimmed affordable / dim priced
can't-afford / green MAX-OWNED). The bought row pops through the existing
tween idiom; Juice's screen-wide upgrade beat is unchanged. All through
UITheme + Palette (row_box / style_price_button extensions), default font.
**Judge on-device:** can you tell what to buy next and what you can afford
without reading every row? Do the pips and disabled states survive the
440-wide portrait viewport (cards are 372 wide + panel margins)?

### The §16 profiling protocol — READ THESE OFF A REAL IPHONE

The prerequisite is met: the WASM heap is now measurable on Safari. The
0011 shim's capture never fired because with thread_support=false the
Emscripten module DEFINES its own memory (exported as
`instance.exports.memory`, never JS-constructed) — the new head_include
shim (`game/web/head_include.html`) wraps
`WebAssembly.instantiate(Streaming)` and stashes the exported memory for
`DebugOverlay` to read via `buffer.byteLength`. For the same reason the
512 MB "clamp" could never apply (the maximum is baked into the wasm at
template build time) — it was dead config and is REMOVED, not carried.
There is no browser-side max-memory lever in 4.3 short of rebuilding the
templates; the real ceiling is Safari's per-tab limit, and §16's job is
to measure how far below it we sit.

**The overlay toggle (keep it secret): 5 quick taps in the top-left
corner square of the tap-to-start screen.** Never a hub item; session-only;
5 more taps at next boot hides it. Corner taps don't start the game.

Checklist — note each line as a feedback entry next session:

1. **At the surface, fresh boot:** WASM heap MB (the baseline), static MB,
   nodes, chunks (expect the ~5×5 window ≈ 25).
2. **Depth ~300 (Granite):** WASM heap + peak, chunks (must still be ~25 —
   the §12 window is depth-constant), pickups, FPS while digging.
3. **Depth ~600 (Bedrock):** same numbers + lava shapes; FPS during a
   lava-glow + shake moment.
4. **After a long dig session (~20+ min, several runs):** peak WASM heap vs
   the baseline — a steadily climbing peak with flat chunk counts is a leak
   smell; flat peak confirms the bounded window holds in practice.
5. **After backgrounding:** switch apps for a minute, return — heap number,
   context-lost line (should stay absent), and does the mid-run restore
   land sanely if Safari killed the tab?
6. **Rotate the phone a few times:** resize count up, heap stable, no
   context lost (the 0002 §4 canvas-resize hazard).

The numbers land here as a session-8 feedback entry; only then do the §12
tunables (chunk_size 32 / resident_margin 1 / shaft_width 96) get judged —
instrumentation observes the window, it never changes it.

### §17 playtesting plan (drafted now that a handable build exists)

- **Who:** 3–5 people off the deployed URL
  (fiachramcv90.github.io/gem-mining-game/) — at least one non-gamer, at
  least one on an older iPhone; the owner plus one repeat tester replay
  each later build (fresh eyes for onboarding, repeat eyes for pacing).
- **How:** send the URL, say NOTHING about controls (the §9 arrangement
  claims it teaches itself) — watch or ask after the first session.
- **What they're watching for (the two 0013 assumptions + the standing
  list):**
  - Did the ghost line ever matter, or was the scheme grasped before it
    faded (0004's "grasped near-instantly" generalising)?
  - Did the round-trip pulse teach the fuel budget before the first
    ran-dry death, without crying wolf (`roundtrip_pulse_threshold` 1.3)?
  - First-session arc: how many runs before the first upgrade (~3 is the
    0006 sim's answer), and did they come back for a second session (the
    persistent-shaft hook)?
  - Does the reworked shop read at arm's length (what to buy next)?
  - Any run lost that felt UNFAIR (vs. greedy) — which hazard, what depth.
- **When:** after this session's build deploys; before the real-audio/art
  asset session locks in tone.

### Mid-run save + Hoist payoff (hardening, judge on-device)

- The §13 `run` field is live (save_version 4): position/fuel/hull/cargo
  persist on the existing snapshot cadence (the visibilitychange flush is
  the one that matters) and restore only when complete and sane — else
  surface start exactly as before. Restores are stationary (never
  mid-fall). **Watch:** does a restore ever land somewhere unfair (fresh
  darkness, beside a lava pocket)? The validation is in
  `SaveManager._sane_run`.
- The Hoist now pays its TIME half (spec §4 ×0.5): an ascent thrust/speed
  assist gated on ownership, `Player.hoist_ascent_boost` 1.9 (≈ halves the
  floaty climb's terminal-speed time; non-owners keep 0004's constants
  bit-for-bit). **Watch (needs a 5000-wallet save):** does the boosted
  climb still feel floaty or does it read as a different vehicle? Tune the
  knob, never thrust/gravity/damp.

### Session-6 watch list — carried, still pending a phone

No display in this build environment again, so nothing was re-judged
blind. Standing: title centring, ghost line lifetime, roundtrip pulse 1.3,
`cavein_telegraph_secs` 0.45, `lava_glow_radius` 6, fall knobs 4/3, garage
doorway feel, shake/flash sizing, the reserve-saturation read, and the
placeholder-audio wiring (beat timing + depth crossfade, not the sounds).

## 2026-07-16 — session-6 build (the §7 art & juice pass)

### Items #3, #4, #6 — APPLIED (garage hub, layout/typography, digger robot)

All three standing art items shipped this session; see the README's
session-6 block for what landed. Judgments to make on-device:

- **#3 garage:** does flying into the doorway read as "go home", and does
  the arm/disarm latch ever misfire (hub popping open when skimming the
  surface, or refusing to open on a slow entry)? The trigger geometry is
  `Garage.DOOR_RECT` — a constant, not a knob, widen it there if entry
  feels finicky. The census is untouched; DESCEND still exits.
- **#6 robot:** does the drill read as *drilling* (scrolling chevrons +
  jab) at 3× zoom on a phone, and does the landing squash land as feel
  rather than glitch? All motion constants are code-side by design
  (spec §7 near-zero-frames budget) — flag anything that needs to become
  a knob.
- **#4 typography:** default font at themed sizes — if it reads cheap on
  device, the next asset call is a pixel font, not more theme tuning.

### Session-4 danger knobs + §17 onboarding items — STILL PENDING ON-DEVICE

This session's verification was again headless + CI only (no display in
the build environment), so the standing on-device watch list carries over
unchanged, now on a build where the juice IS live as required:
`cavein_telegraph_secs` 0.45, the lava glow look (`lava_glow_radius` 6),
the feedback-#1 falls note (`fall_dmg_per_tile` 4 / `fall_grace_tiles`
3), the ghost line's lifetime, the round-trip pulse at
`roundtrip_pulse_threshold` 1.3, and the session-5 title-screen centring
fix. No knobs were changed this session — nothing was re-judged blind.

### New session-6 watch items (art & juice, tune by eye)

- Shake/flash sizing: `JuiceConfig` knobs (`shake_*`, `flash_*`). The
  hazard beat treats ≤6 damage as the small beat so lava ticks never
  strobe — if Bedrock still flickers red, that threshold is in
  `Juice._on_hazard_survived` (make it a knob if it needs tuning).
- The reserve-saturation read: do gems/gas/lava pop against the rock at
  the edge of the lit radius, and do the five band ramps read as one
  descent? All swatches live in `Palette.gd`.
- Placeholder audio: synth stand-ins only — judge the *wiring* (does the
  dig thud land on the beat, does the ambient crossfade track depth,
  does the silent switch story hold), not the sounds themselves.

## 2026-07-16 — session-5 build (Miner's Log, onboarding, hub census)

### Item #3 (hub as a physical garage) — judged: stays for the art session

Re-judged now that the hub census is complete on this build. The census
(§9, closed) is fully occupied — 4 actions + MINER'S LOG + ♥ + 💾 — and
the two constraints both survive a garage presentation (the census says
nothing about form; 0013's "the hub teaches itself" is about content, not
geometry). But building a fly-in garage is layout/art work with zero new
mechanics, exactly the §7 session's material — and doing it grey-box now
would mean doing it twice. **Decision: not shipped here; first item of the
art session's hub-layout work, alongside #4 and #6.** The trigger swap
(garage volume replaces the SURFACE HUB button) must keep every census
element reachable and nothing else.

### Session-4 danger knobs — standing, not re-tuned (no on-device pass yet)

This session's verification was headless + desktop; the danger *feel*
knobs flagged for on-device judgment are deliberately untouched, so the
next phone session judges them on a build where the Log banners and the
fuel pulse are also live: `cavein_telegraph_secs` 0.45 (is the tremble
readable at thumb speed?), the lava glow look (`lava_glow_radius` 6), and
the standing feedback-#1 falls note (`fall_dmg_per_tile` 4 /
`fall_grace_tiles` 3 — raise toward 5 / drop to 2 only if the full danger
model still reads toothless). Knobs only, never structure.

### New §17 watch items now live on-device

The two onboarding assumptions 0013 flags for playtesting are now in the
build: does the ghost line ever show long enough to matter (it should
almost never — 0004 says the scheme is grasped near-instantly), and does
the round-trip pulse at 1.3× ascent cost fire early enough to teach
without crying wolf (`roundtrip_pulse_threshold`, EconomyConfig). Log
verdicts here after the next phone session.

## 2026-07-15 — session-4 on-device report (wall rim hoppable)

### Item #2 again: "I can just fly up and over the edges"

Confirmed on-device with a screenshot: the first fix's finite
`surface_wall_height` (4) was not a wall — because everything outside the
shaft is already solid bedrock, raising it 4 tiles just made a raised RIM
the digger can hop onto and cross. The "harmless" call in the entry below
was wrong on-device. **Applied fix:** the side walls above the surface are
now UNBOUNDED — every above-surface row outside the shaft is bedrock in
`Worldgen.chunk_cells`, so the mine is a pit between two cliffs that can
never be flown over, however high you climb. The `surface_wall_height`
knob is removed: the boundary is geometry, not a tunable (noted in
WorldgenConfig where the knob lived). Still deterministic worldgen; the
resident window stays bounded (above-surface wall chunks cost the same as
any underground chunk). The grey-box sky rect in `Main._draw` widened so
the cliff tops read against blue, not the clear colour.

## 2026-07-15 — session-4 build (cave-ins, lava, walls, ascent step)

### Item #2 (side walls) — APPLIED, superseded by the entry above

The unbreakable side walls now continue `surface_wall_height` (default 4)
tiles above the surface line — one new WorldgenConfig knob, deterministic
worldgen (the wall tiles are plain bedrock codes from `chunk_cells`). The
shaft reads as a walled pit from above; sideways flight at the surface now
has a boundary. You can still fly OVER the wall top and land on the bedrock
plain outside the shaft — harmless, and the pit still reads. Judge the
height on-device. *(On-device verdict: not harmless — see the report
above; the walls are now unbounded and the knob is gone.)*

### Item #5 (ascent fuel) — APPLIED, stepped not halved

`fuel_ascent_per_tile` 1.0 → 0.7 (one EconomyConfig knob), the log's
recommended gentle step rather than the suggested 0.5 — the round-trip
squeeze must stay a real decision. Knock-ons to re-check against the §4
pacing targets on-device:

- **Safe round-trip depth per Fuel level rises ~27%** (round-trip cost per
  tile of depth falls 1.4 → 1.1 + hover): L0's 80 fuel now round-trips to
  ~64 tiles (was ~50), reaching well into Clay; each later level
  over-reaches its band floor by the same factor.
- **The Hoist's ×0.5 relief narrows**: it now saves 0.35 fuel/tile of
  ascent instead of 0.5 — the 5000 price buys a smaller (but still
  band-scale) margin. Acceptable while the Hoist stays aspirational;
  re-judge if it ever feels pointless.
- If the climb still feels punitive after upgrades flow, the next stop is
  0.6 — never straight to 0.5.

### Item #1 (fall hull pressure) — re-judged, fall knobs left untouched

Re-judged against the danger model rather than falls alone (an on-device
feel pass on THIS build should confirm): the session-2 complaint predated
gas, darkness, cave-ins and lava. Since then, every band from Clay down
gained damage that flight cannot dodge — only sight can (gas bursts,
undermined cave-ins), darkness now encroaches from ~150, and Bedrock adds
lava ticks. Hull pressure no longer rests on falls, so `fall_dmg_per_tile`
4 / `fall_grace_tiles` 3 stay as specced. If the session-4 build still
reads toothless on-device, raise `fall_dmg_per_tile` toward 5 or drop
`fall_grace_tiles` to 2 (HazardConfig knobs) — never touch gravity; the
0004 floaty feel is validated-by-thumb.

## 2026-07-15 — session-3 tuning (darkness curve)

### Darkness encroaches too deep (~230); wanted ~150

**Applied.** `shrink_rate_per_depth` 0.016 → 0.025 (one WorldgenConfig
knob). First visible corner-darkening now lands ~depth 150 (faint hints
from ~90 via the soft edge). Knock-on, both acceptable: the lit radius
reaches its 2.5-tile floor at ~depth 460 (start of Bedrock) instead of
never quite reaching it, so all of Bedrock plays at max darkness; and
Light L3 now yields a ~9.6-tile radius at the bottom instead of ~11.2 —
the Light payoff reads even stronger against the darker baseline.

## 2026-07-15 — session-2 build (falls, shop, save; pre-darkness/gas)

### 1. Floaty flight makes hull damage easy to avoid

**Re-judged in session 4** (fall knobs untouched) — see the session-4
entry. Partly by design — §5 wants danger *telegraphed and dodgeable*, and a
thrust-arrest escaping a fall damage-free is the intended skill expression.
But if Hull never feels at risk, the Hull track and the danger acts lose
their teeth. **Assessment:** session 3's gas pockets add dig-triggered
spikes that flight cannot dodge (only sight can), which should change this
feel substantially — re-judge on the session-3 build before touching
anything. If falls still feel toothless after that: raise
`fall_dmg_per_tile` / lower `fall_grace_tiles` (HazardConfig knobs) rather
than touching gravity — the 0004 floaty feel is validated-by-thumb and
should not be re-tuned to fix a hazard problem.

### 2. You can fly left/right past the mine boundary on the surface

**Applied in session 4** — see the session-4 entry. Real gap, not a knob. The unbreakable bedrock walls only exist from y = 0
down (`Worldgen._code_at` returns early for above-surface rows), so at the
surface nothing stops sideways flight into empty sky. **Recommended fix
(small, session 4):** extend the side walls a few tiles above the surface
line in worldgen so the shaft reads as a walled pit from above too —
deterministic, no new knobs beyond a `surface_wall_height`.

### 3. Should the surface hub be a physical location/garage?

Idea logged. The §9 hub *census* is closed (4 actions + Miner's Log button
+ ♥ and 💾 corners — nothing else), but the census says nothing about
presentation: a grey-box garage the digger flies into, replacing the
placeholder SURFACE HUB button as the trigger, would keep the census
intact and make "home" a place rather than a menu. Candidate for the
session that does onboarding/hub polish; must keep 0013's "the hub teaches
itself" property.

### 4. The hub menu could be more polished

Agreed and deliberate — all UI is grey-box until the §7 art/juice pass.
Logged so the art session includes hub layout/typography, not just tiles.

### 5. Ascent fuel feels too expensive (suggestion: halve it)

**Applied in session 4** (stepped to 0.7, not halved) — see the session-4
entry. The 0.4 descent / 1.0 ascent asymmetry is a **closed 0006 decision** and
load-bearing: the climb-home cost IS the round-trip budget, the game's
central turn-back decision (§1/§4), and the first-hour pacing was
simulated against these numbers. Halving ascent to 0.5 would roughly
double safe depth per Fuel level and defuse that tension — not a
recommended jump. **Recommended path:** the designed relief valves are the
Fuel track (each level's safe round-trip reaches ~the next band's floor)
and the late-game Hoist (ascent ×0.5 — the suggestion, as a purchase). If
the squeeze still feels punitive on the session-3 build once upgrades are
flowing, step `fuel_ascent_per_tile` down gently (0.85 → 0.7) — one
EconomyConfig knob — and re-check the §4 pacing targets rather than going
straight to 0.5.

### 6. The digger should look like a small robot with a drill

§7 art pass (hand-made in Pixelorama, 16 px, Resurrect-64) — the current
yellow rect is a grey-box placeholder. Logged as the priority subject for
the first sprite session: the digger is on screen 100% of the time.
