# Gem Miner — the game

The real Godot 4.3+ project, built to
[`wayfinder/assets/0014-final-spec.md`](../wayfinder/assets/0014-final-spec.md)
(the binding spec) using the terms of [`CONTEXT.md`](../CONTEXT.md).

## Vertical slice status (session 2)

**Running:** seeded deterministic worldgen (5 bands, hardness(depth),
veins + halos, sparse caves) streamed in 32×32 chunks inside the bounded
resident window (spec §12); the ported 0004 stick/floaty/drill feel
(dynamic trailing stick); the three pressures + the single run-lost outcome;
iOS-safe single-threaded web export (spec §11). NEW in session 2: the save
system per §13 (`user://save.dat` snapshots on surface events / run lost /
`visibilitychange→hidden`, `navigator.storage.persist()`, load-on-boot with
world_seed-absent ⇒ new game, `save_version` + migrate-chain skeleton, and
the export/import safety hatch in the permanent 💾 save-safety corner); the
full six-track upgrade shop off `Upgrades.buy()` (Hoist surfaces only once
Drill/Fuel/Cargo are deep); hazards Act I — FALLS (grace / ~4 hull per tile /
45%-of-current-hull cap / lit thrust-brace ×0.4) through
`GameState.apply_hazard_damage`, knobs in `HazardConfig`; the sell
celebration (banked-total flash).

**Stubbed seams (later sessions):** darkness renderer (§6 knobs live in
`WorldgenConfig`; `GameState.lit_view_radius()` is the curve, already
consumed by the fall brace), the prize gem (spawn-chance knobs default 0),
gas pockets / cave-ins / lava (knobs stubbed in `HazardConfig`), best-effort
mid-run save state (`run` stays `null` — every load starts at the surface),
`stats`/`milestones` save fields + Miner's Log (0012), onboarding nudges
(0013), art/audio (§7).

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
  never runtime `randf()`.
- `scripts/Mine.gd` — chunk streaming + the resident window; runtime
  grey-box TileSet.
- `scenes/Main.tscn` — `Main → Mine + Player + HUD` (spec §10).

Desktop dev: arrows/WASD-equivalent (ui_* actions) drive the digger; mouse
emulates the touch stick.
