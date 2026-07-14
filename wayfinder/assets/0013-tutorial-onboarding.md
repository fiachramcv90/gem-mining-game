# Tutorial & onboarding — the arrangement

> Design asset for ticket **0013 — Tutorial & onboarding**.
> Audience: Fiachra — solo dev, evenings/weekends; all-Apple devices, web build.
> Reached by grilling, not decided for him.
> Scope: the **arrangement** of the four already-decided teach moments / nudges —
> surface, timing/order, form, dismissal. The elements themselves were decided
> upstream: controls near-instant ([0004](0004-dig-feel-controls.md)),
> round-trip fuel the one killer rule ([0003](0003-core-loop.md)),
> Add-to-Home-Screen protects the save ([0009](0009-save-system.md)),
> silent-switch nudge on tap-to-start ([0008](0008-art-audio.md) /
> [0011](0011-ios-smoke-test-notes.md)).
> **Hard constraints honoured:** nothing gates play — no forced tutorial, no
> modal sequence; every beat lands with sound off; no new art beyond 0008's
> hooks; no server/accounts; small scope.

## TL;DR

Onboarding is **two text lines, one gauge behaviour, and two nudges** — total
save-schema cost: **one `nudges` key with two fields**. Nothing is a modal,
nothing gates play, nothing needs new art.

| Element | Surface | Timing | Form | Dismissal |
|---|---|---|---|---|
| **Controls hint** | Contextual, mid-run | First descent only | One ghost line: *"push to fly · hold into rock to dig"* | Self-dismisses on first dig (or ~10 s); first-run **derived** from an empty dug-delta — **no save flag** |
| **Round-trip fuel lesson** | Contextual, mid-run + run-lost screen | Every run, forever (diegetic) | **Round-trip-aware gauge pulse** + edge flash; permanent death-reason line on the run-lost screen | None — permanent UI, not a nudge; **no save flag** |
| **Add-to-Home-Screen** | Hub (💾 save-safety corner) | From first sell **or** first run lost | Temporary callout label on a permanent glyph; expands to install how-to + export/import | `nudges.a2hs_dismissed` counter (0–2); suppressed when standalone |
| **Silent-switch nudge** | Tap-to-start screen | First session only | Static caption under the tap prompt: *"🔊 flip off silent for sound"* | `nudges.audio_hint_shown` boolean |

---

## 1. The first 10 seconds (first session)

The [0004 prototype](../prototype/) /
[live build](https://fiachramcv90.github.io/gem-mining-game/) is the reference
for what these seconds feel like. The sequence:

1. **Tap-to-start screen** — title, tap prompt, the 🔊 silent-switch caption
   (first session only), and [0010](../tickets/0010-monetization.md)'s quiet
   ♥ Support corner. The tap that starts the game is the same tap that unlocks
   Web Audio ([0002](0002-web-export-ios-safari.md)/0011) — the caption is
   *dismissed by the act of starting*, no interaction of its own.
2. **Surface hub** — the four core actions (sell, refuel/repair, upgrade,
   descend) + [0012](0012-meta-progression.md)'s Miner's Log button + ♥ corner
   + 💾 save-safety corner. **No onboarding content here on first run** — the
   hub teaches itself by being four buttons.
3. **First descent** — the ghost line fades in: *"push to fly · hold into rock
   to dig."* It disappears the moment the player first digs a tile (backstop:
   ~10 s fade). 0004 showed the scheme is grasped near-instantly; this is
   cheap insurance for the one player who freezes on a blank screen, invisible
   to everyone else.

**The no-flag trick:** "first run" is derived from the save itself — show the
ghost line only when the save contains no dug-tile delta. The first dig *is*
the persisted event, so the line self-dismisses and self-persists for free.
Zero save-schema cost.

## 2. The round-trip fuel lesson (the one rule that kills)

[0003](0003-core-loop.md): ascent costs fuel — reserve enough to climb home.
Taught **diegetically, permanently, with zero tutorial text mid-run**:

- **The gauge is the teacher.** 0008's juice table already has "low fuel /
  round-trip → pulsing fuel gauge + edge flash". This ticket pins the
  threshold: the pulse is **round-trip aware** — it fires when remaining fuel
  approaches the **estimated ascent cost from the player's current depth**,
  not when the tank is nearly empty. It warns *before* the mistake, every run,
  forever, wordlessly. The exact threshold multiplier (e.g. pulse at
  1.3× ascent cost) is a named `@export` knob in
  [0006](0006-economy-upgrades.md)'s style — tuning, not design.
- **The run-lost screen closes the loop.** The screen's death-reason line is
  permanent UI copy (not a tutorial): the fuel variant reads
  *"ran dry below ground — the climb home costs fuel too."* A fuel death is
  the one moment this lesson is guaranteed full attention.
- **The cheap first lesson does the rest.** Early runs are shallow by design
  (0006: first upgrade ~run 3), so the first fuel-out forfeits almost nothing.
  The system *is* the tutorial: low-stakes failure → explicit cause → the
  pulse means something next run.

Rejected: a one-time mid-run text line ("flying home burns fuel too") — it
competes with the exact moment the player is busiest, and would cost a
dismissal flag for a lesson the gauge + death screen already teach.

## 3. Add-to-Home-Screen — the save-safety corner

**Why it exists:** the installed PWA is exempt from WebKit's 7-day
storage-eviction cap ([0009](0009-save-system.md)) — installing is the
strongest save-durability lever. On iOS there is **no install-prompt API**;
installing is a manual "Share → Add to Home Screen", so the nudge must
*explain*, not just ask.

**The permanent home: a 💾 save-safety corner in the hub** — a small quiet
glyph opposite 0010's ♥ corner. Tapping it opens a small non-blocking panel:

- the two-step Add-to-Home-Screen instructions;
- 0009's **save export** (download backup file) and **import** (restore).

One surface for everything that protects the save, reachable forever. This
also gives 0009's export/import UI its permanent home (import especially can
never live behind a nudge that stops showing).

**The nudge is a temporary callout label on that permanent glyph** — miner's
voice, e.g. *"⛏ add to Home Screen so your mine survives — tap for how."*
Lifecycle:

- **Trigger:** the first time the save contains something a player would miss —
  **first sell OR first run lost** (a lost run still leaves a carved shaft
  worth protecting). Never on the first tap-to-start: it would protect an
  empty save and crowd the audio nudge.
- **Persistence:** the callout stays across runs until the player installs or
  explicitly dismisses it. A passive line isn't nagging; a re-popping toast is.
- **One re-show:** if dismissed, the callout re-appears once after a
  *subsequent* run lost (the moment "losing things" is emotionally live), then
  never again.
- **Suppression:** never shown when running standalone (display-mode
  detection) — the player already installed.
- **Persisted as** `nudges.a2hs_dismissed: int` (0 = never dismissed,
  1 = dismissed once, 2 = re-shown and dismissed again — retired).

**Final hub census** (handed to 0014 as complete): 4 core actions (sell,
refuel/repair, upgrade, descend) + Miner's Log button (0012) + ♥ Support
corner (0010) + 💾 save-safety corner (0013). Nothing else claims hub space.

## 4. Silent-switch nudge

As 0008 specified, read strictly: a **static caption** under the tap prompt on
the tap-to-start screen — *"🔊 flip off silent for sound"* — **first session
only**, retired by `nudges.audio_hint_shown: true` after first display. No
animation, no interaction; the tap that starts the game dismisses it. The
permanent-caption alternative (show every session, no flag) was considered and
declined to keep 0008's "shown once" intact.

## 5. Save Dictionary delta (0009)

One new envelope key — the **only** onboarding fields:

```gdscript
"nudges": {
  "audio_hint_shown": false,   # bool — silent-switch caption shown once
  "a2hs_dismissed":   0,       # int 0–2 — A2HS callout dismissal counter
}
```

Everything else is **derived** (ghost line ⇐ empty dug-delta; A2HS trigger ⇐
wallet/run-lost state the game already tracks; standalone ⇐ display-mode) or
**permanent UI** (fuel pulse, death-reason line, 💾 panel). Loads defensively
per 0009 §6: missing key → defaults, no version bump needed if added before
first release.

## 6. Constraint check

- **Nothing gates play:** zero modals, zero forced steps; every element is a
  caption, a ghost line, a gauge behaviour, or a dismissible hub label.
- **Silent players:** every beat is visual (text, pulse, flash); audio remains
  a bonus layer.
- **No new art:** text lines + 0008's existing pulse/flash/tween vocabulary;
  the 💾 glyph and panel are UI chrome, not sprites.
- **No server/accounts:** untouched.
- **Nothing reopened:** 0008's "shown once" kept strict; 0012's Log stays
  purely honorific (no utility UI folded into it); 0010's corner untouched;
  0003/0006's mechanics untouched (the pulse threshold is a new knob, not a
  changed rule).

## 7. What this clears / hands off

- **0014 (final spec)** inherits: the complete first-10-seconds sequence, the
  final hub census, the `nudges` save fields, and the round-trip-aware pulse
  threshold as a named `@export` knob. No open onboarding decisions remain.
- **Playtesting fog** (unchanged, but noted): the ghost line and pulse
  threshold are the two onboarding items worth watching in first playtests —
  the arrangement assumes 0004's "grasped near-instantly" generalises beyond
  its author.
