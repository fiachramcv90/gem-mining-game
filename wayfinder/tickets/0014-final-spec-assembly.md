---
id: 0014
title: "Final spec assembly"
type: task
status: closed
assignee: fiachramcv90
blocked-by: [0012, 0013]
---

## Question

Assemble the **destination document**: one complete design + technical spec,
compiled from every closed ticket's Resolution and linked asset, structured
so Fiachra can open Godot 4.3+ and start building with **no open
decisions**. This is the terminal ticket — it closes the map.

Scope of the assembly (compile and reconcile, don't re-decide):

- **Design:** core loop & failure states (0003), dig feel & touch controls
  (0004), worldgen (0005), economy & six upgrade tracks (0006), hazards &
  danger acts (0007), art & audio direction (0008), meta-progression (0012),
  tutorial & onboarding (0013).
- **Technical:** Godot foundations (0001), single-threaded web export &
  iOS-Safari constraints (0002, confirmed by 0011), save system &
  IndexedDB/PWA durability (0009), chunk-streaming/bounded-resident-window
  memory rules (0002+0005).
- **Release:** monetization & distribution — GitHub Pages canonical + itch.io
  PWYW (0010).
- **Carry-forward items:** the two remaining fog patches (on-device memory
  profiling — with its 0011 prerequisite of getting web memory
  instrumentation working — and the playtesting plan) are execution-phase
  work gated on a build existing. The spec records them as explicit
  **"confirm during build"** items with their known prerequisites, not as
  open decisions.

Output = a single spec asset in `assets/` linked from this ticket, with the
map's Decisions-so-far as the index into it. Cross-check that no closed
decision is contradicted; where two tickets touch the same knob (e.g. 0005's
drill-time band vs 0006's drill curve), the spec states the reconciled
contract once.

## Resolution

**The destination document is assembled:
[Gem Miner — Final Design & Technical Specification](../assets/0014-final-spec.md).**
One complete design + technical spec compiled from tickets 0001–0013's
Resolutions and every linked asset, structured **Design / Technical /
Release / Confirm-during-build**, with a master `@export`-knob appendix and a
per-ticket asset index. Every section links its owning ticket; the spec
compiles, it does not re-decide.

**Cross-check: no closed decision is contradicted.** Every shared knob
reconciles cleanly, and each reconciled contract is stated exactly once in
the spec (marked ⟲), with links back to the owners:

- **Drill-time contract (0005 × 0006)** — 0005's declared band (frontier
  ~1.0–1.3 s, conquered ~0.3–0.5 s, baseline 0.3–1.5 s) is held exactly by
  0006's `drill_power` curve (`hardness × 0.34 / power` ≈ 1.1 s per band at
  the matching level); the between-band soft cliff and halo/prize spikes are
  features of the contract, not breaches. Spec §3.
- **Hazard calibration (0006 × 0007)** — `hazard_base`/`depth_gain` re-cast
  from a placeholder drain into the expected-damage target the roster's
  encounter rates are tuned against; no 0006 price or capacity moved. Spec §5.
- **Darkness (0003 × 0005 × 0006 × 0007)** — risk multiplier on Hull; 0005
  owns the base curve, 0006 the Light prices/ladder, 0007 the meaning
  (hit probability, tells rendered only when lit; prize glint and lava glow
  the two self-lit exceptions). Spec §6.
- **Hub census (0003 × 0010 × 0012 × 0013)** — 4 core actions + Miner's Log
  button + ♥ Support corner + 💾 save-safety corner; nothing else. Spec §9.
- **Save envelope (0009 + 0012 + 0013)** — one reconciled `save.dat`
  Dictionary: 0009's schema plus `stats`/`milestones` (0012) and `nudges`
  (0013), all under the same `save_version` migration. Spec §13.
- **Memory budget (0002 × 0003 × 0005)** — iOS ceiling + persistent mine ⇒
  the bounded-resident-window rule with 0005's concrete numbers. Spec §12.

**Carry-forward items (per this ticket):** the two fog patches enter the
spec as explicit confirm-during-build items, not open decisions —
**on-device memory profiling** (spec §16, with 0011's prerequisite: real web
memory instrumentation first, since `MEMORY_STATIC` reads 0 on web and the
`WebAssembly.Memory` capture never fired) and the **playtesting plan** (spec
§17, prerequisite: a build worth handing out; includes 0013's two
watch-items).

**Locked constraints honoured:** nothing reopened, no game code written,
out-of-scope items restated verbatim (native stores, multiplayer,
story/NPCs, >~8 gem types — shipping 6). CONTEXT.md untouched — assembly
crystallised no new canonical term.

**This closes the map.** The frontier is empty: tickets 0001–0014 are all
closed, no fog remains outside the spec's confirm-during-build section, and
the way to the destination is clear — open Godot 4.3+ and build.
