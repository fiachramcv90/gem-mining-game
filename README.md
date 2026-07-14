# gem-mining-game

Gem Miner — a Motherload-style gem-digging game for the web (Godot 4.3+,
single-threaded HTML5, installable PWA).

- **`game/`** — the real game (vertical slice in progress). Deployed at the
  root of the Pages site.
- **`wayfinder/`** — the completed planning map; the binding spec is
  [`wayfinder/assets/0014-final-spec.md`](wayfinder/assets/0014-final-spec.md).
- **`CONTEXT.md`** — the domain glossary (ubiquitous language).
- **`prototype/`** — throwaway 0004 dig-feel prototype (served at
  `/prototype/`); the reference implementation the game's controls were
  ported from.
- **`smoke-test/`** — throwaway 0011 iOS Safari smoke test (served at
  `/smoke/`); kept until spec §16's memory profiling no longer needs it.
- **`economy-sim/`** — the throwaway 0006 economy simulation
  (`node economy-sim/run.js`).

CI (`.github/workflows/deploy-prototype.yml`) builds all web exports on every
listed branch push, gates on a headless run (script errors fail the build),
and deploys to GitHub Pages from `main`.
