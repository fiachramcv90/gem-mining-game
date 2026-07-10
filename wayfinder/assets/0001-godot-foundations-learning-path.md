# Godot 4 foundations & learning path — for a 2D tile-digging game

> Research asset for ticket **0001 — Godot 4 foundations for a 2D tile-digging game**.
> Audience: Fiachra — strong TypeScript/web background, new to Godot.
> Scope: the *building blocks* and a *learning path*, plus an initial node
> architecture sketch. Deliberately not deciding dig-feel or worldgen — those are
> their own tickets (0004, 0005).

## TL;DR

- **Engine version:** target the **latest stable Godot 4.x**. Hard floor is **4.3**
  — that's the release (Aug 2024) that introduced `TileMapLayer` and deprecated the
  monolithic `TileMap` node. Use `TileMapLayer`, not `TileMap`, for all new work.
- **World:** a `TileMapLayer` (one node per visual layer, sharing one `TileSet`) is
  the destructible grid. Digging = `erase_cell()`. Rock hardness / gem type = a
  **custom data layer** on each tile, read with `get_cell_tile_data().get_custom_data()`.
- **Player:** `CharacterBody2D` + `move_and_slide()`. Motion mode *floating* suits a
  jetpack-in-dirt feel; *grounded* suits a walk-and-fall feel — that's a 0004 decision,
  the node is the same either way.
- **Camera:** `Camera2D` with `position_smoothing` on, parented to the player.
- **Input:** map actions in Project Settings → Input Map; read touch via
  `InputEventScreenTouch` / `InputEventScreenDrag`, mouse via `InputEventMouseButton`.
  Web export delivers both — design the touch path first, mouse falls out for free.
- **Mental model shift from web:** no DOM/React re-render. It's a **retained scene
  tree** you mutate directly each frame in `_process`/`_physics_process`. Nodes are
  long-lived objects, not virtual descriptions.

---

## 1. The core building blocks

### Scene tree & nodes (the biggest mental shift)

A Godot game is a **tree of nodes**. A *scene* is a reusable subtree saved to a
`.tscn` file (Player.tscn, Gem.tscn, Mine.tscn). You compose the game by
**instancing** scenes into other scenes — the equivalent of composing React
components, except the instances are *live, stateful objects* that persist across
frames. There is no re-render: you change a node's properties and the change is
simply there next frame.

Every node has lifecycle callbacks you override:

| Callback | Fires | Web analogy |
|---|---|---|
| `_ready()` | once, when the node enters the tree | `useEffect(() => …, [])` / `connectedCallback` |
| `_process(delta)` | every rendered frame | `requestAnimationFrame` loop |
| `_physics_process(delta)` | every physics tick (fixed 60 Hz default) | fixed-step update loop |
| `_input(event)` / `_unhandled_input(event)` | on input events | DOM event listener |

`delta` is seconds since last tick — multiply movement by it so speed is
framerate-independent (`position += velocity * delta`).

**Signals** are Godot's event system — a node `emit`s a signal, others `connect` to
it. This is your decoupling tool, like an event emitter or a pub/sub bus. Prefer
signals over having nodes reach across the tree to poke each other.

**Autoloads (singletons):** scripts registered in Project Settings → Autoload become
globally-accessible singletons that live for the whole game. This is where the run
state, the economy/wallet, and the save manager live — the rough equivalent of a
global store (Zustand/Redux) in a web app.

### `TileMapLayer` — the destructible world

This is the heart of a digging game. Since 4.3 you use **`TileMapLayer`** nodes (one
per visual layer — e.g. `Terrain`, `Background`, `Ore`), each pointing at a shared
`TileSet` resource. The old all-in-one `TileMap` node is deprecated; don't start on it.

Key script API (all coordinates are `Vector2i` cell coords, not pixels):

- `set_cell(coords, source_id, atlas_coords, alternative_tile)` — place a tile.
- `erase_cell(coords)` — **remove a tile — this is "dig".**
- `get_cell_source_id(coords)` — `-1` means empty; cheap "is there dirt here?" test.
- `get_cell_tile_data(coords)` → `TileData`, from which
  `get_custom_data("hardness")` / `get_custom_data("gem_type")` reads per-tile
  metadata you author in the TileSet editor via **custom data layers**.
- `local_to_map(pos)` / `map_to_local(coords)` — convert between world pixels and
  cell coords (e.g. "which tile did the player tap?").

So a dig is: figure out the target cell → read its `TileData` for hardness → run the
dig timer/health → on break, `erase_cell()` and, if `gem_type` is set, spawn a pickup
and credit the wallet. Physics collision on the layer updates automatically when you
erase, so the player falls into the freshly-dug space with no extra work.

> **Gotcha (from the field):** with *terrain autotiling* / *scene tiles*, erasing one
> cell doesn't re-bake its neighbours' autotile edges, and `erase_cell` has known
> quirks with scene-collection tiles. For a Motherload-style solid-dirt field this
> mostly doesn't bite — plain atlas tiles erase cleanly. Note it and avoid leaning on
> autotile terrain for the dig surface until 0004 proves the approach.

### `CharacterBody2D` — the player

The right body type for a directly-controlled character. You set `velocity`, call
`move_and_slide()`, and Godot resolves collisions against the tilemap and world.

- **`RigidBody2D`** = fully physics-simulated (you push it with forces; the engine owns
  position). Wrong for a responsive player — you want direct control.
- **`AnimatableBody2D`** = you move it by script, it pushes other bodies (moving
  platforms). Not the player.
- **`CharacterBody2D`** = you own the velocity, engine does collision/sliding. **This
  is the player**, and also good for anything you want tight control over.

`motion_mode` toggles *grounded* (has a floor/gravity notion, `is_on_floor()`,
`is_on_wall()`) vs *floating* (free 2D movement — top-down / jetpack). The dig-feel
prototype (0004) decides which; the node choice is settled here.

### `Camera2D` — following the descent

Add a `Camera2D` as a child of the player, mark it `enabled`, and turn on
`position_smoothing` for a slight lag so the descent feels weighty rather than glued.
`limit_*` properties clamp it so you never scroll past the world edges. `zoom`
controls how much of the mine is on screen — a real feel lever for a small phone
viewport.

### Input — touch first, mouse for free

1. Define **named actions** in Project Settings → Input Map (`dig_left`, `dig_down`,
   etc.). Read them anywhere with `Input.is_action_pressed("dig_down")`. This
   abstracts over keyboard/mouse/touch so gameplay code never hard-codes a device.
2. For raw touch, handle `InputEventScreenTouch` (press/release + position) and
   `InputEventScreenDrag` (movement) in `_unhandled_input`. Mouse arrives as
   `InputEventMouseButton` / `InputEventMouseMotion`.
3. **Enable "Emulate Touch From Mouse"** (and its inverse) in Project Settings so you
   can develop the touch path on desktop and have it work on device.
4. `get_viewport().get_mouse_position()` + `TileMapLayer.local_to_map()` gives you the
   tapped cell.

Because the web export receives both event families, building the **touch** control
scheme first means the mouse scheme is essentially free — the opposite order is not
true. (Actual scheme — tap-adjacent vs drag vs virtual stick — is 0004.)

---

## 2. GDScript idioms coming from TypeScript

GDScript is Python-flavoured, indentation-scoped, and optionally typed. The typing is
worth using — it catches errors and speeds the engine up.

| You know (TS) | You write (GDScript) | Notes |
|---|---|---|
| `const N = 5` | `const N := 5` | `const` is compile-time constant |
| `let x: number = 5` | `var x: int = 5` or `var x := 5` | `:=` infers the type |
| `x: number` (float) | `float` | GDScript splits `int` / `float` |
| `string`/template literal | `String`, `"depth %d" % d` | `%` formatting, or `str()` |
| `x: Foo[]` | `var xs: Array[Foo]` | typed arrays exist |
| `Record<string,number>` | `Dictionary` | not statically keyed |
| `{x,y}` | `Vector2(x, y)` / `Vector2i` | first-class math types |
| `function f(a: number): void` | `func f(a: int) -> void:` | `->` return type |
| `class Foo {}` | `class_name Foo` at top of a `.gd` | one main class per file |
| `extends`/`implements` | `extends CharacterBody2D` | single inheritance |
| `this` | `self` (usually implicit) | |
| `null` | `null`; `is_instance_valid(x)` | freed nodes aren't `null` — see gotcha |
| `?.` optional chain | no equivalent | guard with `if x:` or `is_instance_valid` |
| `async/await` | `await sig` / `await f()` | awaits a **signal** or coroutine, not a Promise |
| `interface` | none | use duck typing / `has_method()` |
| `enum E { A }` | `enum E { A }` | same idea |
| `@decorator` | `@export`, `@onready` | annotations, below |

Two annotations you'll use constantly:

- `@export var speed: float = 120.0` — surfaces the variable in the Inspector so you
  (or a designer-you) can tune it without editing code. This is huge for a
  balancing-heavy game: fuel, dig speed, gem values all become Inspector knobs.
- `@onready var camera := $Camera2D` — defers the assignment until the node is ready,
  so `$NodePath` lookups don't run before the tree exists. `$Foo` is shorthand for
  `get_node("Foo")`.

**Gotchas that will bite a web dev:**

- **Freed nodes are not `null`.** After `queue_free()`, a reference isn't null — it's a
  freed object, and touching it errors. Guard with `is_instance_valid(node)`.
- **`_physics_process` vs `_process`.** Movement/collision goes in
  `_physics_process` (fixed step); pure visuals/UI can go in `_process`.
- **Integer division.** `5 / 2 == 2` if both are ints (like C, unlike JS). Use a float.
- **No hot module reload of state** — but the editor *does* hot-reload scripts; scene
  state resets on run.
- **Resources are shared references.** A `TileSet`/`Resource` assigned to two nodes is
  the *same object* unless you make it `local_to_scene` or duplicate it. Handy for the
  shared TileSet; a footgun if you mutate one expecting the other untouched.

---

## 3. Initial node architecture sketch

A first-cut tree for the vertical slice. Names are suggestions; the point is the
*shape* — scenes compose, autoloads hold cross-cutting state.

```
Autoloads (global singletons, Project Settings → Autoload)
├── GameState        # current run: depth, fuel, hull, cargo; emits run_started/ended
├── Wallet           # money + owned upgrades; emits balance_changed
└── SaveManager      # serialize GameState/Wallet ↔ user:// (see ticket 0009)

Main.tscn  (the entry scene)
└── Main (Node2D)          — root; wires the run, listens for death/surface signals
    ├── Mine (Node2D)                       # the world; instanced Mine.tscn
    │   ├── Background (TileMapLayer)        # non-colliding backdrop strata
    │   ├── Terrain (TileMapLayer)           # the DESTRUCTIBLE dirt/rock — has collision
    │   │                                    #   custom data layers: hardness, gem_type
    │   ├── Ore (TileMapLayer)               # optional overlay for gem visuals
    │   ├── Pickups (Node2D)                 # spawned gem/pickup instances
    │   └── Hazards (Node2D)                 # gas/lava/etc. spawned here (ticket 0007)
    │
    ├── Player.tscn (CharacterBody2D)        # instanced
    │   ├── Sprite2D / AnimatedSprite2D
    │   ├── CollisionShape2D
    │   ├── Camera2D                         # follows the descent, smoothing on
    │   └── DigController (Node)             # reads input, resolves target cell,
    │                                        #   runs dig timer, calls Terrain.erase_cell
    │
    └── HUD.tscn (CanvasLayer)               # fuel/cargo/depth/money; touch buttons
        └── Control … (fuel bar, depth, cash, virtual controls if 0004 picks them)
```

**Why this shape:**

- **`CanvasLayer` for HUD** keeps UI fixed to the screen while the `Camera2D` scrolls
  the world — the standard split. UI lives in `Control` nodes (Godot's flexbox-ish
  layout system: containers, anchors, size flags — conceptually close to CSS flexbox).
- **`DigController` as a child node** of the player keeps the dig logic isolated and
  swappable while 0004 experiments with control schemes — you can rewrite it without
  touching movement.
- **Autoloads for run/wallet/save** because they must outlive any single scene (you
  reload the Mine scene between runs but keep the money). This is the store-vs-view
  split web devs already have muscle memory for.
- **Signals up, calls down:** the Player/DigController *emit* ("gem_dug", "fuel_empty");
  `Main` and the autoloads listen and react (credit wallet, end run). Avoid nodes
  reaching sideways into siblings.

This sketch is intentionally loose where later tickets own the detail: worldgen (0005)
fills the Terrain layer, economy (0006) drives Wallet, hazards (0007) populate the
Hazards node, save (0009) implements SaveManager.

---

## 4. Recommended learning path (order matters)

Roughly a weekend of ramp-up before touching this project, front-loading the two
concepts a web dev lacks intuition for (the scene tree and fixed-step physics).

1. **Official "Step by step" + "Your first 2D game" (Dodge the Creeps).**
   `docs.godotengine.org` → Getting Started. Do the whole 2D game tutorial hands-on.
   It teaches nodes, scenes, signals, `_process`, input actions, and `CharacterBody2D`
   movement end-to-end — every core concept above, in one sitting. **Start here.**
2. **GDScript reference + "GDScript exports" doc.** Skim after the tutorial so the
   syntax table above clicks. Type your variables from day one.
3. **"Using TileMaps" / TileMapLayer + TileSet docs and a TileMapLayer tutorial.**
   This is the game-specific muscle: authoring a TileSet, custom data layers,
   `set_cell`/`erase_cell`. Build a throwaway scene where clicking a tile erases it —
   that *is* the digging primitive.
4. **`CharacterBody2D` + `move_and_slide` docs**, and a top-down movement mini-tutorial.
   Try both `motion_mode`s so 0004 has an informed starting point.
5. **Camera2D, Input (touch), and "Exporting for the Web" docs.** The web/touch specifics
   overlap ticket 0002 (iOS Safari export viability) — read them together.

**Trusted sources:** the **official docs** (`docs.godotengine.org`) are unusually good —
make them the default. For video: **GDQuest** (idiomatic, current-4.x) and
**HeartBeast** (Action-RPG/2D series) are the standard recommendations; prefer anything
explicitly labelled **Godot 4.3+** so you get `TileMapLayer`, not the deprecated
`TileMap`. Cross-check any pre-4.3 tutorial's tilemap parts against the current docs.

## 5. What this unblocks / hands off

- **Directly unblocks ticket 0004 (Dig feel & touch controls prototype)** once 0002
  (web export viability) also closes — 0004 is `blocked-by: [0001, 0002]`. The
  `TileMapLayer` + `CharacterBody2D` + `DigController` primitives above are exactly its
  starting scaffold.
- No new decisions surfaced that aren't already ticketed or in the map's fog. The
  "Performance budget" fog stays fogged — it needs worldgen (0005) and the web-export
  research (0002) before it can be phrased sharply.

## Sources

- [Godot Tilemap in 2026: TileMapLayer Migration Guide — Ziva](https://ziva.sh/blogs/godot-tilemap)
- [Godot TileMap Replaced with TileMapLayers — GameFromScratch](https://gamefromscratch.com/godot-tilemap-replaced-with-tilelayers/)
- [Getting Started With Godot Tile Maps: TileMapLayer, TileSet, Collisions — knightli.com](https://knightli.com/en/2026/06/20/godot-tilemaplayer-tileset-collision-codex-guide/)
- [Dev snapshot: Godot 4.3 (TileMapLayer introduced) — Godot Engine](https://godotengine.org/article/dev-snapshot-godot-4-3-dev-6/)
- [erase_cell / destructible autotiles discussion — Godot Forum](https://forum.godotengine.org/t/correct-way-to-impliment-destructable-autotiles/112273)
- Official Godot 4 documentation — `docs.godotengine.org` (Getting Started, TileMapLayer, CharacterBody2D, Input, Exporting for Web)
