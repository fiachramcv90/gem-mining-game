# Gem Miner — the game

The real Godot 4.3+ project, built to
[`wayfinder/assets/0014-final-spec.md`](../wayfinder/assets/0014-final-spec.md)
(the binding spec) using the terms of [`CONTEXT.md`](../CONTEXT.md).

## Vertical slice status (session 3)

**Running:** seeded deterministic worldgen (5 bands, hardness(depth),
veins + halos, sparse caves) streamed in 32×32 chunks inside the bounded
resident window (spec §12); the ported 0004 stick/floaty/drill feel
(dynamic trailing stick); the three pressures + the single run-lost outcome;
iOS-safe single-threaded web export (spec §11); the save system per §13
(`user://save.dat` snapshots, `navigator.storage.persist()`, migrate-chain
skeleton, export/import in the 💾 save-safety corner); the full six-track
upgrade shop; hazards Act I FALLS; the sell celebration. NEW in session 3:
the darkness renderer per §6 (`scripts/Darkness.gd` + the one reused
`shaders/darkness.gdshader` — a full-screen overlay drawing
`GameState.lit_view_radius()` as the lit disc, opaque beyond it, so a
hazard's tell renders only in the light and buying Light visibly pushes the
dark back); the prize gem per §3 (spawn-chance knobs live with real
defaults, ~2–3 nodules seeded per mine, its gold cross-glint pierces the
darkness out to `prize_glint_radius` — the glimpsed-prize hook); gas
pockets per §5 (dig-triggered burst tiles with a green tint tell, placement
a pure per-tile hash of `(world_seed, coords)`, rare in Clay / common
Sandstone+, band damage {8,14,18,22} through
`GameState.apply_hazard_damage`, dug gas persists via the ordinary dug
delta).

**Stubbed seams (later sessions):** cave-ins / lava (knobs stubbed in
`HazardConfig`; lava's glow is the second self-lit §6 exception when it
ships), Hoist ascent payoff polish, best-effort mid-run save state (`run`
stays `null` — every load starts at the surface), `stats`/`milestones`
save fields + Miner's Log (0012), onboarding nudges (0013), art/audio (§7 —
darkness/glint shader is in; tiles stay grey-box).

## Layout

- `config/` — `EconomyConfig` / `WorldgenConfig` / `HazardConfig` resources:
  every Appendix A knob as a named `@export` default. Re-balancing is a
  slider drag.
- `scripts/autoload/` — `GameState`, `Wallet`, `Upgrades`, `SaveManager`
  (the §13 envelope, the SaveBlob seam, snapshot triggers, and the browser
  hooks — `visibilitychange` flush, `storage.persist()`, download/file-input
  hatch).
- `scripts/ui/` — `UpgradeShop` (the §4 ratchet UI) and `SaveCorner`
  (the permanent 💾 save-safety corner).
- `scripts/Worldgen.gd` — pure function of `(world_seed, chunk coords)`;
  never runtime `randf()` (gas placement included: a per-tile hash).
- `scripts/Mine.gd` — chunk streaming + the resident window; runtime
  grey-box TileSet; gas bursts; resident prize-glint tracking.
- `scripts/Darkness.gd` + `shaders/darkness.gdshader` — the §6 renderer:
  per-frame uniform updates only, no CPU pixel work.
- `scenes/Main.tscn` — `Main → Mine + Player + DarknessLayer + HUD`
  (spec §10; darkness sits between the world and the HUD).

Desktop dev: arrows/WASD-equivalent (ui_* actions) drive the digger; mouse
emulates the touch stick.
