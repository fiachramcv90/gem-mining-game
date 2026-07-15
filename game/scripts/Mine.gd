class_name Mine
extends Node2D
## The single persistent mine, chunk-streamed inside the bounded resident
## window (spec §12 — THE non-negotiable): resident = camera view + a
## resident_margin ring of chunks; everything beyond it is freed (tiles,
## collision, pickups) and regenerated from the seed + dug/collected deltas
## on re-entry. Resident count is constant with depth. Generation is
## incremental (chunks_per_frame_budget) — single-threaded web.

# Atlas columns: 0-4 band rock, 5-9 band halo, 10-14 gems T1-T5,
# 15 prize, 16 bedrock, 17-20 gas tell for bands Clay-Bedrock.
# Grey-box colours; real art direction is spec §7.
const ATLAS_TILES := 21
const BAND_COLORS: Array[Color] = [
	Color8(152, 112, 72),  # Topsoil — warm/light
	Color8(138, 92, 66),  # Clay
	Color8(120, 98, 74),  # Sandstone
	Color8(96, 88, 86),  # Granite
	Color8(70, 72, 84),  # Bedrock band — cold/dark
]
const BEDROCK_COLOR := Color8(34, 32, 40)

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

@onready var rock: TileMapLayer = $Rock
@onready var pickups_root: Node2D = $Pickups


func _ready() -> void:
	rock.tile_set = _build_tile_set()


func setup(gen: Worldgen) -> void:
	worldgen = gen


func warm_start() -> void:
	## Generate the initial window synchronously so the player never spawns
	## over ungenerated world.
	for cc in _desired_chunks().keys():
		if not _chunk_codes.has(cc):
			_generate_chunk(cc)


func _physics_process(_delta: float) -> void:
	if worldgen == null or player == null:
		return
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
		rock.set_cell(tile, _source_id, _atlas_for_code(code))
	_chunk_codes[cc] = codes


func _free_chunk(cc: Vector2i) -> void:
	for tile in _chunk_codes[cc].keys():
		rock.erase_cell(tile)
		_prize_tiles.erase(tile)
	_chunk_codes.erase(cc)
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
	return kind != Worldgen.Kind.AIR and kind != Worldgen.Kind.BEDROCK


func hardness(tile: Vector2i) -> float:
	return worldgen.hardness_at(tile.y, code_at(tile))


func dig(tile: Vector2i) -> void:
	var code := code_at(tile)
	var kind := Worldgen.kind_of(code)
	if kind == Worldgen.Kind.AIR or kind == Worldgen.Kind.BEDROCK:
		return
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


func _burst_gas(tile: Vector2i, band: int) -> void:
	## Gas burst (spec §5): dig-triggered, damage by band through the single
	## hazard entry point. Darkness scales whether the tell was SEEN, never
	## the damage size (§6) — drilling a gas tile always bursts it.
	GameState.apply_hazard_damage(float(GameState.hazards.gas_burst_dmg[band - 1]))
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


# --- runtime grey-box TileSet -------------------------------------------------


func _build_tile_set() -> TileSet:
	var px: int = GameState.world.tile_px
	var img := Image.create(ATLAS_TILES * px, px, false, Image.FORMAT_RGBA8)
	for i in range(5):
		_paint_rock(img, i, px, BAND_COLORS[i], false)
		_paint_rock(img, 5 + i, px, BAND_COLORS[i].darkened(0.28), true)
	for i in range(5):
		_paint_gem(img, 10 + i, px, GemPickup.GEM_COLORS[i])
	_paint_gem(img, 15, px, GemPickup.PRIZE_COLOR)
	_paint_rock(img, 16, px, BEDROCK_COLOR, false)
	for i in range(1, 5):
		_paint_gas(img, 16 + i, px, BAND_COLORS[i])

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
		var td := src.get_tile_data(Vector2i(i, 0), 0)
		td.add_collision_polygon(0)
		td.set_collision_polygon_points(0, 0, full_rect)
	return ts


func _paint_rock(img: Image, col: int, px: int, color: Color, tight_grain: bool) -> void:
	# Flat colour + a deterministic speckle so tiles don't read as one slab;
	# halo rock gets a tighter, darker grain (its telegraph look, spec §7).
	for y in range(px):
		for x in range(px):
			var c := color
			var speckle := (x * 31 + y * 17 + col * 7) % (3 if tight_grain else 5)
			if speckle == 0:
				c = color.darkened(0.18)
			elif speckle == 1:
				c = color.lightened(0.08)
			img.set_pixel(col * px + x, y, c)


func _paint_gas(img: Image, col: int, px: int, base: Color) -> void:
	# The gas tell (spec §5/§7): band rock veined with a sickly green
	# shimmer tint — reads as not-rock at a glance. The darkness overlay
	# hides it beyond the lit radius: the tell renders only in the light.
	var tint := Color8(120, 210, 130)
	for y in range(px):
		for x in range(px):
			var c := base
			var speckle := (x * 13 + y * 29 + col * 7) % 4
			if speckle == 0:
				c = base.lerp(tint, 0.75)
			elif speckle == 2:
				c = base.lerp(tint, 0.35).lightened(0.05)
			img.set_pixel(col * px + x, y, c)


func _paint_gem(img: Image, col: int, px: int, color: Color) -> void:
	var dark := Color8(52, 48, 46)
	var mid := px / 2
	for y in range(px):
		for x in range(px):
			var c := dark
			var d := absi(x - mid) + absi(y - mid)
			if d <= px / 3:
				c = color.lightened(0.25) if d <= 1 else color
			img.set_pixel(col * px + x, y, c)


func _atlas_for_code(code: int) -> Vector2i:
	var aux := Worldgen.aux_of(code)
	match Worldgen.kind_of(code):
		Worldgen.Kind.ROCK:
			return Vector2i(aux, 0)
		Worldgen.Kind.HALO:
			return Vector2i(5 + aux, 0)
		Worldgen.Kind.GEM:
			return Vector2i(9 + aux, 0)  # tier 1..5 -> cols 10..14
		Worldgen.Kind.PRIZE:
			return Vector2i(15, 0)
		Worldgen.Kind.GAS:
			return Vector2i(16 + aux, 0)  # band 1..4 -> cols 17..20
	return Vector2i(16, 0)
