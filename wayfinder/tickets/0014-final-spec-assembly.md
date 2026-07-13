---
id: 0014
title: "Final spec assembly"
type: task
status: open
assignee:
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
