class_name Mine
extends Node2D
## The single persistent mine, chunk-streamed inside the bounded resident
## window (spec §12 — THE non-negotiable): resident = camera view + a
## resident_margin ring of chunks; everything beyond it is freed (tiles,
## collision, pickups) and regenerated from the seed + dug/collected deltas
## on re-entry. Resident count is constant with depth. Generation is
## incremental (chunks_per_frame_budget) — single-threaded web.

# Atlas columns: 0-4 band rock, 5-9 band halo, 10-14 gems T1-T5,
# 15 prize, 16 bedrock, 17-20 gas tell for bands Clay-Bedrock,
# 21-22 cracked/unstable tell for Granite-Bedrock, 23 lava.
# Painted by TileArt on the Resurrect-64 palette (spec §7).
const ATLAS_TILES := 24
const LAVA_COLUMN := 23

var player: Node2D
var worldgen: Worldgen

var _source_id := -1
## chunk -> {tile -> code}: the resident window's tile codes (hardness/gem
## lookups for the drill). Freed with the chunk — this map IS the window.
var _chunk_codes := {}
var _chunk_pickups := {}
var _gen_queue: Array[Vector2i] = []
## Resident undug prize tiles (tile -> true): the darkness renderer draws
## their glint — the self-lit exception that pierces the dark (spec §6).
var _prize_tiles := {}
## chunk -> Array[Vector2] of resident lava tile centres (world px): the
## darkness renderer's second self-lit exception, lava's glow (spec §6).
var _chunk_lava := {}
## chunk -> Array[CollisionShape2D] inside the one lava Area2D.
var _chunk_lava_shapes := {}
## The single Area2D contact volume for all resident lava tiles (spec §5).
var _lava_volume: Area2D
var _lava_accum := 0.0

@onready var rock: TileMapLayer = $Rock
@onready var pickups_root: Node2D = $Pickups


func _ready() -> void:
	rock.tile_set = _build_tile_set()
	_lava_volume = Area2D.new()
	_lava_volume.collision_layer = 0
	_lava_volume.collision_mask = 1  # scans for the digger's body layer
	_lava_volume.monitoring = true
	add_child(_lava_volume)


func setup(gen: Worldgen) -> void:
	worldgen = gen


func warm_start() -> void:
	## Generate the initial window synchronously so the player never spawns
	## over ungenerated world.
	for cc in _desired_chunks().keys():
		if not _chunk_codes.has(cc):
			_generate_chunk(cc)


func _physics_process(delta: float) -> void:
	if worldgen == null or player == null:
		return
	_tick_lava(delta)
	var desired := _desired_chunks()
	for cc in _chunk_codes.keys():
		if not desired.has(cc):
			_free_chunk(cc)
	for cc in desired.keys():
		if not _chunk_codes.has(cc) and not _gen_queue.has(cc):
			_gen_queue.append(cc)
	if _gen_queue.is_empty():
		return
	# Nearest chunks first: the player must never outrun generation.
	var cs := worldgen.config.chunk_size * worldgen.config.tile_px
	var pc := player.global_position / float(cs)
	_gen_queue.sort_custom(
		func(a: Vector2i, b: Vector2i) -> bool:
			return (Vector2(a) - pc).length_squared() < (Vector2(b) - pc).length_squared()
	)
	var budget := worldgen.config.chunks_per_frame_budget
	while budget > 0 and not _gen_queue.is_empty():
		var cc: Vector2i = _gen_queue.pop_front()
		if not _chunk_codes.has(cc) and desired.has(cc):
			_generate_chunk(cc)
			budget -= 1


func _desired_chunks() -> Dictionary:
	var cfg := worldgen.config
	var cam := player.get_node("Camera2D") as Camera2D
	var half_view := get_viewport_rect().size * 0.5 / cam.zoom.x
	var chunk_px := float(cfg.chunk_size * cfg.tile_px)
	var margin := cfg.resident_margin
	var center := player.global_position
	var c0 := Vector2i(
		Worldgen.fdiv(int(floor(center.x - half_view.x)), int(chunk_px)) - margin,
		Worldgen.fdiv(int(floor(center.y - half_view.y)), int(chunk_px)) - margin
	)
	var c1 := Vector2i(
		Worldgen.fdiv(int(floor(center.x + half_view.x)), int(chunk_px)) + margin,
		Worldgen.fdiv(int(floor(center.y + half_view.y)), int(chunk_px)) + margin
	)
	var out := {}
	for cy in range(c0.y, c1.y + 1):
		for cx in range(c0.x, c1.x + 1):
			out[Vector2i(cx, cy)] = true
	return out


func _generate_chunk(cc: Vector2i) -> void:
	var cells := worldgen.chunk_cells(cc)
	var codes := {}
	for tile in cells.keys():
		var code: int = cells[tile]
		if GameState.is_dug(tile):
			# Re-apply deltas (spec §12): dug rock stays open; a dug but
			# uncollected gem returns as a pickup (spec §1: full-hold gems
			# stay in the ground).
			var kind := Worldgen.kind_of(code)
			if (
				(kind == Worldgen.Kind.GEM or kind == Worldgen.Kind.PRIZE)
				and not GameState.is_collected(tile)
			):
				_spawn_pickup(cc, tile, Worldgen.aux_of(code))
			continue
		codes[tile] = code
		if Worldgen.kind_of(code) == Worldgen.Kind.PRIZE:
			_prize_tiles[tile] = true
		if Worldgen.kind_of(code) == Worldgen.Kind.LAVA:
			_add_lava_tile(cc, tile)
		rock.set_cell(tile, _source_id, _atlas_for_code(code))
	_chunk_codes[cc] = codes


func _add_lava_tile(cc: Vector2i, tile: Vector2i) -> void:
	# One rect shape per lava tile inside the single Area2D volume; freed
	# with the chunk, so the physics footprint stays inside the resident
	# window (spec §12).
	var px := worldgen.config.tile_px
	var center := Vector2(tile) * px + Vector2(px, px) * 0.5
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(px, px)
	shape.shape = rect
	shape.position = center
	_lava_volume.add_child(shape)
	if not _chunk_lava.has(cc):
		_chunk_lava[cc] = []
		_chunk_lava_shapes[cc] = []
	_chunk_lava[cc].append(center)
	_chunk_lava_shapes[cc].append(shape)


func _free_chunk(cc: Vector2i) -> void:
	for tile in _chunk_codes[cc].keys():
		rock.erase_cell(tile)
		_prize_tiles.erase(tile)
	_chunk_codes.erase(cc)
	if _chunk_lava.has(cc):
		for shape in _chunk_lava_shapes[cc]:
			if is_instance_valid(shape):
				shape.queue_free()
		_chunk_lava.erase(cc)
		_chunk_lava_shapes.erase(cc)
	if _chunk_pickups.has(cc):
		for p in _chunk_pickups[cc]:
			if is_instance_valid(p):
				p.queue_free()
		_chunk_pickups.erase(cc)


# --- drill-facing API ---------------------------------------------------------


func code_at(tile: Vector2i) -> int:
	var cc := GameState.chunk_of(tile)
	if not _chunk_codes.has(cc):
		return Worldgen.make_code(Worldgen.Kind.BEDROCK)  # not resident: treat as solid
	return _chunk_codes[cc].get(tile, Worldgen.make_code(Worldgen.Kind.AIR))


func is_solid(tile: Vector2i) -> bool:
	return Worldgen.kind_of(code_at(tile)) != Worldgen.Kind.AIR


func is_breakable(tile: Vector2i) -> bool:
	var kind := Worldgen.kind_of(code_at(tile))
	return (
		kind != Worldgen.Kind.AIR and kind != Worldgen.Kind.BEDROCK and kind != Worldgen.Kind.LAVA
	)


func hardness(tile: Vector2i) -> float:
	return worldgen.hardness_at(tile.y, code_at(tile))


func dig(tile: Vector2i) -> void:
	var code := code_at(tile)
	var kind := Worldgen.kind_of(code)
	if kind == Worldgen.Kind.AIR or kind == Worldgen.Kind.BEDROCK or kind == Worldgen.Kind.LAVA:
		return
	# The dig beat (spec §7): debris burst + micro-shake + thud; a halo or
	# gem break-through pops slightly bigger — the telegraph's payoff.
	var px_f := float(worldgen.config.tile_px)
	Juice.dig_beat(
		Vector2(tile) * px_f + Vector2(px_f, px_f) * 0.5, worldgen.band_index(tile.y), kind
	)
	GameState.mark_dug(tile)
	rock.erase_cell(tile)
	var cc := GameState.chunk_of(tile)
	if _chunk_codes.has(cc):
		_chunk_codes[cc].erase(tile)
	_prize_tiles.erase(tile)
	if kind == Worldgen.Kind.GAS:
		_burst_gas(tile, Worldgen.aux_of(code))
	if kind == Worldgen.Kind.GEM or kind == Worldgen.Kind.PRIZE:
		_spawn_pickup(cc, tile, Worldgen.aux_of(code))
	_check_undermined(tile)


# --- cave-ins (spec §5, Act II): undermining cracked rock drops it ------------


func _check_undermined(dug_tile: Vector2i) -> void:
	## The support check, kept simple and legible (spec §5): an unstable tile
	## falls when the tile DIRECTLY UNDER it is dug out. A vertical run of
	## cracked rock comes down as one column. Each dropped tile is marked dug
	## the moment it lets go, so a reload reproduces the outcome from the
	## ordinary dug delta — the fallen rock shatters, it never resettles.
	var above := dug_tile + Vector2i.UP
	while Worldgen.kind_of(code_at(above)) == Worldgen.Kind.UNSTABLE:
		var band := Worldgen.aux_of(code_at(above))
		GameState.mark_dug(above, false)
		rock.erase_cell(above)
		var cc := GameState.chunk_of(above)
		if _chunk_codes.has(cc):
			_chunk_codes[cc].erase(above)
		var drop := CaveInRock.new()
		drop.mine = self
		drop.band = band
		var px := worldgen.config.tile_px
		drop.position = Vector2(above) * px + Vector2(px, px) * 0.5
		add_child(drop)
		above += Vector2i.UP


# --- lava (spec §5, Act III): contact volume + damage over time ---------------


func _tick_lava(delta: float) -> void:
	## lava_tick_dmg per lava_tick_interval while the digger overlaps the
	## lava volume; the accumulator resets on exit, so every breach starts a
	## fresh grace of one interval — a clean route-around costs nothing.
	if _lava_volume == null or not _lava_volume.overlaps_body(player):
		_lava_accum = 0.0
		return
	var hz: HazardConfig = GameState.hazards
	_lava_accum += delta
	while _lava_accum >= hz.lava_tick_interval:
		_lava_accum -= hz.lava_tick_interval
		GameState.apply_hazard_damage(hz.lava_tick_dmg, GameState.HAZARD_LAVA)


func _burst_gas(tile: Vector2i, band: int) -> void:
	## Gas burst (spec §5): dig-triggered, damage by band through the single
	## hazard entry point. Darkness scales whether the tell was SEEN, never
	## the damage size (§6) — drilling a gas tile always bursts it.
	GameState.apply_hazard_damage(
		float(GameState.hazards.gas_burst_dmg[band - 1]), GameState.HAZARD_GAS
	)
	var px := worldgen.config.tile_px
	var flash := GasBurstFlash.new()
	flash.position = Vector2(tile) * px + Vector2(px, px) * 0.5
	add_child(flash)


func prize_glint_positions() -> Array[Vector2]:
	## World positions whose glint pierces the darkness (spec §6): resident
	## undug prize nodules plus freed-but-uncollected prize pickups.
	var px := float(worldgen.config.tile_px)
	var out: Array[Vector2] = []
	for tile in _prize_tiles.keys():
		out.append(Vector2(tile) * px + Vector2(px, px) * 0.5)
	for pickup in pickups_root.get_children():
		if pickup is GemPickup and pickup.tier == Worldgen.PRIZE_TIER:
			out.append(pickup.global_position)
	return out


func lava_glow_points(from: Vector2, reach: float, cap: int) -> Array[Vector2]:
	## The nearest resident lava tile centres within reach of `from` (world
	## px), for the darkness renderer's glow — the second self-lit exception
	## (spec §6). Scans per-chunk lists and prunes whole chunks by distance,
	## so the per-frame cost tracks the local pocket, not the window.
	var candidates: Array = []
	var chunk_px := float(worldgen.config.chunk_size * worldgen.config.tile_px)
	for cc: Vector2i in _chunk_lava.keys():
		var chunk_center := (Vector2(cc) + Vector2(0.5, 0.5)) * chunk_px
		if (chunk_center - from).length() > reach + chunk_px * 0.75:
			continue
		for center: Vector2 in _chunk_lava[cc]:
			var d := (center - from).length()
			if d <= reach:
				candidates.append([d, center])
	candidates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var out: Array[Vector2] = []
	for i in range(mini(cap, candidates.size())):
		out.append(candidates[i][1])
	return out


func debug_counts() -> Dictionary:
	## Live §12 resident-window counters for the §16 debug overlay — read
	## only, the window itself is never touched by instrumentation.
	var lava_shapes := 0
	for cc: Vector2i in _chunk_lava_shapes.keys():
		lava_shapes += _chunk_lava_shapes[cc].size()
	return {
		"chunks": _chunk_codes.size(),
		"queued": _gen_queue.size(),
		"pickups": pickups_root.get_child_count(),
		"lava_shapes": lava_shapes,
		"prize_tiles": _prize_tiles.size(),
	}


func _spawn_pickup(cc: Vector2i, tile: Vector2i, tier: int) -> void:
	# Capped, not pooled yet (spec §12): over the cap the gem simply stays
	# a delta and reappears on a later chunk load.
	if pickups_root.get_child_count() >= worldgen.config.pickup_cap:
		return
	var pickup := GemPickup.new()
	pickup.tier = tier
	pickup.tile = tile
	var px := worldgen.config.tile_px
	pickup.position = Vector2(tile) * px + Vector2(px, px) * 0.5
	pickups_root.add_child(pickup)
	if not _chunk_pickups.has(cc):
		_chunk_pickups[cc] = []
	_chunk_pickups[cc].append(pickup)


# --- the runtime TileSet, painted by TileArt (spec §7) -------------------------


func _build_tile_set() -> TileSet:
	var px: int = GameState.world.tile_px
	var img := Image.create(ATLAS_TILES * px, px, false, Image.FORMAT_RGBA8)
	for i in range(5):
		TileArt.paint_rock(img, i, px, i, false)
		TileArt.paint_rock(img, 5 + i, px, i, true)
	for i in range(5):
		TileArt.paint_gem(img, 10 + i, px, i + 1)
	TileArt.paint_prize(img, 15, px)
	TileArt.paint_wall(img, 16, px)
	for i in range(1, 5):
		TileArt.paint_gas(img, 16 + i, px, i)
	for i in range(3, 5):
		TileArt.paint_unstable(img, 18 + i, px, i)
	TileArt.paint_lava(img, LAVA_COLUMN, px)

	var ts := TileSet.new()
	ts.tile_size = Vector2i(px, px)
	ts.add_physics_layer()
	ts.set_physics_layer_collision_layer(0, 1)
	var src := TileSetAtlasSource.new()
	src.texture = ImageTexture.create_from_image(img)
	src.texture_region_size = Vector2i(px, px)
	# The source must be added to the TileSet BEFORE tiles get collision:
	# TileData only knows the set's physics layers once the source is bound.
	_source_id = ts.add_source(src)
	var half := px * 0.5
	var full_rect := PackedVector2Array(
		[Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]
	)
	for i in range(ATLAS_TILES):
		src.create_tile(Vector2i(i, 0))
		if i == LAVA_COLUMN:
			continue  # lava never blocks movement — you fly INTO it (spec §5)
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full_rect)
	return ts


func _atlas_for_code(code: int) -> Vector2i:
	var aux := Worldgen.aux_of(code)
	var col := 16  # bedrock fallback
	match Worldgen.kind_of(code):
		Worldgen.Kind.ROCK:
			col = aux
		Worldgen.Kind.HALO:
			col = 5 + aux
		Worldgen.Kind.GEM:
			col = 9 + aux  # tier 1..5 -> cols 10..14
		Worldgen.Kind.PRIZE:
			col = 15
		Worldgen.Kind.GAS:
			col = 16 + aux  # band 1..4 -> cols 17..20
		Worldgen.Kind.UNSTABLE:
			col = 18 + aux  # band 3..4 -> cols 21..22
		Worldgen.Kind.LAVA:
			col = LAVA_COLUMN
	return Vector2i(col, 0)
