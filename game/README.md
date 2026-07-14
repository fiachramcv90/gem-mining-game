# Gem Miner — the game

The real Godot 4.3+ project, built to
[`wayfinder/assets/0014-final-spec.md`](../wayfinder/assets/0014-final-spec.md)
(the binding spec) using the terms of [`CONTEXT.md`](../CONTEXT.md).

## Vertical slice status (session 1)

**Running:** seeded deterministic worldgen (5 bands, hardness(depth),
veins + halos, sparse caves) streamed in 32×32 chunks inside the bounded
resident window (spec §12); the ported 0004 stick/floaty/drill feel
(dynamic trailing stick); the three pressures + the single run-lost outcome;
a placeholder surface hub (sell · refuel/repair · descend); iOS-safe
single-threaded web export (spec §11).

**Stubbed seams (later sessions):** hazards (`GameState.apply_hazard_damage`),
darkness renderer (§6 knobs live in `WorldgenConfig`), the prize gem
(spawn-chance knobs default 0), save system (`SaveManager` holds the §13
envelope + SaveBlob seam, nothing wired), upgrade shop UI (`Upgrades.buy()`
exists), Miner's Log, onboarding, art/audio (§7).

## Layout

- `config/` — `EconomyConfig` / `WorldgenConfig` resources: every Appendix A
  knob as a named `@export` default. Re-balancing is a slider drag.
- `scripts/autoload/` — `GameState`, `Wallet`, `Upgrades`, `SaveManager`.
- `scripts/Worldgen.gd` — pure function of `(world_seed, chunk coords)`;
  never runtime `randf()`.
- `scripts/Mine.gd` — chunk streaming + the resident window; runtime
  grey-box TileSet.
- `scenes/Main.tscn` — `Main → Mine + Player + HUD` (spec §10).

Desktop dev: arrows/WASD-equivalent (ui_* actions) drive the digger; mouse
emulates the touch stick.
