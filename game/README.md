# Gem Miner — the game

The real Godot 4.3+ project, built to
[`wayfinder/assets/0014-final-spec.md`](../wayfinder/assets/0014-final-spec.md)
(the binding spec) using the terms of [`CONTEXT.md`](../CONTEXT.md).

## Vertical slice status (session 4)

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

**Stubbed seams (later sessions):** Hoist ascent payoff polish, best-effort
mid-run save state (`run` stays `null` — every load starts at the surface),
`stats`/`milestones` save fields + Miner's Log (0012), onboarding nudges
(0013), art/audio (§7 — darkness/glint/glow shader is in; tiles stay
grey-box).

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
