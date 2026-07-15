# On-device feedback log

Raw play feedback from the deployed build, each item assessed against the
binding spec ([`0014-final-spec.md`](../wayfinder/assets/0014-final-spec.md))
with its owning knob/section and a recommended action. This is the build
log the spec's §17 playtesting plan feeds — NOT a decision document: where
an item touches a closed decision, the decision stays closed and the entry
says so.

## 2026-07-15 — session-4 build (cave-ins, lava, walls, ascent step)

### Item #2 (side walls) — APPLIED

The unbreakable side walls now continue `surface_wall_height` (default 4)
tiles above the surface line — one new WorldgenConfig knob, deterministic
worldgen (the wall tiles are plain bedrock codes from `chunk_cells`). The
shaft reads as a walled pit from above; sideways flight at the surface now
has a boundary. You can still fly OVER the wall top and land on the bedrock
plain outside the shaft — harmless, and the pit still reads. Judge the
height on-device.

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
