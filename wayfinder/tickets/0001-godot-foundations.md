---
id: 0001
title: "Godot 4 foundations for a 2D tile-digging game"
type: research
status: closed
assignee: fiachramcv (Claude session)
blocked-by: []
---

## Question

What are the core Godot 4 building blocks for this game, and what is the learning path for a TypeScript/web developer? Specifically: TileMapLayer for a destructible tile world, CharacterBody2D movement, camera follow, touch/pointer input, scene/node architecture conventions, and GDScript idioms coming from TS. Output: a linked markdown learning-path summary with recommended tutorials and the project's initial node architecture sketch.

## Resolution

Learning-path + building-blocks summary written and linked as an asset:
[Godot 4 foundations & learning path](../assets/0001-godot-foundations-learning-path.md).

Key decisions/findings captured there:

- **Engine:** target latest stable Godot 4.x; hard floor **4.3** — the release that
  introduced `TileMapLayer` and deprecated the old `TileMap` node.
- **Destructible world:** one or more `TileMapLayer` nodes over a shared `TileSet`;
  dig = `erase_cell()`; per-tile **hardness / gem_type** stored as TileSet **custom
  data layers**, read via `get_cell_tile_data().get_custom_data()`.
- **Player:** `CharacterBody2D` + `move_and_slide()` (motion mode grounded-vs-floating
  is left to 0004; the node choice is settled). `Camera2D` child with
  `position_smoothing` for the descent.
- **Input:** named Input-Map actions + `InputEventScreenTouch`/`ScreenDrag`; build the
  touch path first, mouse falls out free on the web export.
- **Architecture:** autoload singletons (`GameState`, `Wallet`, `SaveManager`) for
  cross-run state; `Main → Mine(TileMapLayers) + Player(+DigController+Camera) + HUD
  (CanvasLayer)`; signals up, calls down. Full tree sketch in the asset.
- **GDScript-from-TS** idiom table + web-dev gotchas (freed nodes aren't null, int
  division, `_physics_process` vs `_process`, shared Resource references).
- **Learning path:** official "Your first 2D game" → GDScript ref → TileMapLayer/TileSet
  → CharacterBody2D → Camera/Input/Web export; GDQuest & HeartBeast for video, only
  4.3+ material.

No new tickets surfaced; primarily unblocks **0004 (dig-feel prototype)** once **0002**
(web-export viability) also closes. The "Performance budget" fog stays fogged (needs
0005 worldgen + 0002).
