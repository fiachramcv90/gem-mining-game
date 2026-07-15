class_name Worldgen
extends RefCounted
## Deterministic world generation (spec §3): a chunk's undug content is a
## PURE FUNCTION of (world_seed, chunk coords) — seeded FastNoiseLite for
## caves plus integer hashing for veins. Never runtime randf(); every
## RandomNumberGenerator below is seeded from (world_seed, coords) so the
## same tile always generates the same way.

## Tile kinds. AIR tiles are never stored in the TileMapLayer.
enum Kind { AIR, ROCK, HALO, GEM, PRIZE, BEDROCK, GAS, UNSTABLE, LAVA }

## Sentinel "tier" for the prize gem (T1..T5 are 1..5).
const PRIZE_TIER := 6

const DIRS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

## Per-hazard salts for _hash01_tile. GAS_SALT is session 3's original value
## — changing it would reshuffle gas in every existing mine.
const GAS_SALT := 0x9E3779B9
const CAVEIN_SALT := 0xC0FFEE55

var config: WorldgenConfig
## Gas placement rates live in HazardConfig (Appendix A's hazards section)
## but placement itself is worldgen — pure of (world_seed, coords).
var hazards: HazardConfig
var world_seed: int
var _cave_noise: FastNoiseLite
var _lava_noise: FastNoiseLite


func _init(cfg: WorldgenConfig, hazard_cfg: HazardConfig, seed_value: int) -> void:
	config = cfg
	hazards = hazard_cfg
	world_seed = seed_value
	_cave_noise = FastNoiseLite.new()
	_cave_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_cave_noise.seed = (seed_value ^ 0x51F0CAFE) & 0x7FFFFFFF
	_cave_noise.frequency = config.cave_noise_frequency
	# Lava pockets carve from their own seeded channel (spec §3/§5), so they
	# reload identically too.
	_lava_noise = FastNoiseLite.new()
	_lava_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_lava_noise.seed = (seed_value ^ 0x6C617661) & 0x7FFFFFFF
	_lava_noise.frequency = hazards.lava_noise_frequency


# --- tile codes: kind<<8 | aux (aux = band for rock/halo, tier for gems) ----


static func make_code(kind: int, aux: int = 0) -> int:
	return (kind << 8) | aux


static func kind_of(code: int) -> int:
	return code >> 8


static func aux_of(code: int) -> int:
	return code & 0xFF


func band_index(depth: int) -> int:
	## 0..4 = Topsoil / Clay / Sandstone / Granite / Bedrock band.
	var edges := config.band_edges
	for i in range(edges.size() - 2, 0, -1):
		if depth >= edges[i]:
			return i
	return 0


func hardness_at(y: int, code: int) -> float:
	## Per-tile dig resistance (spec §3): band baseline, +1 in a vein halo,
	## +2 on the prize nodule; bedrock is unbreakable.
	var band := band_index(y)
	var base := float(config.baseline_hardness[band])
	match kind_of(code):
		Kind.AIR:
			return 0.0
		Kind.HALO:
			return base + config.halo_hardness_bonus
		Kind.PRIZE:
			return base + config.prize_hardness_bonus
		Kind.BEDROCK:
			return INF
		Kind.LAVA:
			return INF  # molten — routed around, never drilled
	return base  # gas and cracked/unstable rock drill like band baseline


# --- chunk generation --------------------------------------------------------


func chunk_cells(cc: Vector2i) -> Dictionary:
	## All non-air tiles of a chunk: {Vector2i world tile -> code}.
	## Pure function of (world_seed, cc) — safe to free and regenerate.
	var cs := config.chunk_size
	var base := cc * cs
	var out := {}
	var shaft_half := config.shaft_width / 2
	if base.y + cs <= 0 and base.x >= -shaft_half and base.x + cs <= shaft_half:
		return out  # above the surface AND inside the shaft: open sky

	# Veins are laid out on a deterministic vein-cell grid. A vein (and its
	# halo) can reach 2 tiles past its cell, so gather every cell whose
	# reach overlaps this chunk.
	var vc := config.vein_cell_size
	var gems := {}
	var halos := {}
	var v0 := Vector2i(fdiv(base.x - 2, vc), fdiv(base.y - 2, vc))
	var v1 := Vector2i(fdiv(base.x + cs + 1, vc), fdiv(base.y + cs + 1, vc))
	for vy in range(v0.y, v1.y + 1):
		for vx in range(v0.x, v1.x + 1):
			var vein := _vein_for_cell(vx, vy)
			if not vein.is_empty():
				gems.merge(vein["gems"])
				halos.merge(vein["halo"])

	for ly in range(cs):
		var y := base.y + ly
		for lx in range(cs):
			var x := base.x + lx
			if y < 0:
				# Above the surface line only the side walls exist — and they
				# are UNBOUNDED: every above-surface row outside the shaft is
				# bedrock, so the mine is a pit between two cliffs that can
				# never be flown over (on-device feedback #2: a finite rim
				# was just a ledge to hop).
				if x < -shaft_half or x >= shaft_half:
					out[Vector2i(x, y)] = make_code(Kind.BEDROCK)
				continue
			var code := _code_at(x, y, gems, halos)
			if kind_of(code) != Kind.AIR:
				out[Vector2i(x, y)] = code
	return out


func _code_at(x: int, y: int, gems: Dictionary, halos: Dictionary) -> int:
	var half := config.shaft_width / 2
	if x < -half or x >= half or y >= config.designed_bottom_depth:
		return make_code(Kind.BEDROCK)
	var tile := Vector2i(x, y)
	if gems.has(tile):
		var tier: int = gems[tile]
		return make_code(Kind.PRIZE if tier == PRIZE_TIER else Kind.GEM, tier)
	if _is_cave(x, y):
		return make_code(Kind.AIR)
	return _solid_code_at(x, y, halos.has(tile))


func _solid_code_at(x: int, y: int, in_halo: bool) -> int:
	## Which solid tile fills a non-void, non-gem cell — lava wins (molten
	## pockets cut through everything), then the vein halo, then the hazard
	## channels, then plain band rock.
	var band := band_index(y)
	if _is_lava(x, y, band):
		return make_code(Kind.LAVA, band)
	if in_halo:
		return make_code(Kind.HALO, band)
	if _is_gas(x, y, band):
		return make_code(Kind.GAS, band)
	if _is_unstable(x, y, band):
		return make_code(Kind.UNSTABLE, band)
	return make_code(Kind.ROCK, band)


func _is_gas(x: int, y: int, band: int) -> bool:
	## Gas pockets (spec §5): dig-triggered burst tiles — rare in Clay,
	## common Sandstone+, none in Topsoil (band 0). Placement is a pure
	## function of (world_seed, tile) — a per-tile avalanche hash against
	## gas_encounter_rate[band - 1], never runtime randf(). A dug gas tile
	## persists through the ordinary dug-bitmask delta: it never regrows,
	## burst or not.
	if band < 1:
		return false
	var rate := hazards.gas_encounter_rate[band - 1]
	if rate <= 0.0:
		return false
	return _hash01_tile(x, y, GAS_SALT) < rate


func _is_unstable(x: int, y: int, band: int) -> bool:
	## Cave-ins (spec §5, Granite+ only): cracked/unstable rock that drops
	## when the tile under it is dug out. Placement is a pure per-tile hash
	## of (world_seed, tile) against cavein_encounter_rate[band - 3] — same
	## discipline as gas, never runtime randf(). A tile whose support is a
	## cave void at generation time is skipped: cracked rock that could never
	## be undermined is a tell that lies.
	if band < 3:
		return false
	var rate := hazards.cavein_encounter_rate[band - 3]
	if rate <= 0.0:
		return false
	if _hash01_tile(x, y, CAVEIN_SALT) >= rate:
		return false
	return not _is_cave(x, y + 1)


func _is_lava(x: int, y: int, band: int) -> bool:
	## Lava pockets (spec §5, Bedrock only): molten tiles from a seeded noise
	## channel, sealed behind rock until breached. lava_encounter_rate gates
	## the noise threshold; 0 disables.
	if band < 4:
		return false
	var rate := hazards.lava_encounter_rate
	if rate <= 0.0:
		return false
	var n := (_lava_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
	return n > 1.0 - rate


func _is_cave(x: int, y: int) -> bool:
	## Second seeded noise channel (spec §3); more/larger caves with depth.
	if y < 2:
		return false
	var depth_frac := clampf(float(y) / config.designed_bottom_depth, 0.0, 1.0)
	var threshold := lerpf(config.cave_threshold_surface, config.cave_threshold_bottom, depth_frac)
	var n := (_cave_noise.get_noise_2d(float(x), float(y)) + 1.0) * 0.5
	return n > threshold


# --- veins (spec §3): 2-5 same-tier tiles wrapped in a +1-hardness halo -----


func _vein_for_cell(vx: int, vy: int) -> Dictionary:
	var vc := config.vein_cell_size
	var mid_y := vy * vc + vc / 2
	var mid_x := vx * vc + vc / 2
	var half := config.shaft_width / 2
	if mid_y < 2 or mid_y >= config.designed_bottom_depth - 1:
		return {}
	if mid_x < -half + 1 or mid_x >= half - 1:
		return {}

	var rng := RandomNumberGenerator.new()
	rng.seed = _hash_cell(vx, vy)

	# Base density ~8% of tiles, flat with depth (spec §3): the chance one
	# cell hosts a find is density * cell_area / mean vein size.
	var mean_size := (config.vein_size_min + config.vein_size_max) * 0.5
	var chance := clampf(config.base_gem_density * vc * vc / mean_size, 0.0, 1.0)
	if rng.randf() > chance:
		return {}

	var depth_frac := clampf(float(mid_y) / config.designed_bottom_depth, 0.0, 1.0)
	var lo := Vector2i(vx * vc - 1, vy * vc - 1)
	var hi := Vector2i(vx * vc + vc, vy * vc + vc)

	# The prize gem (spec §3): a hard singleton nodule (+2 hardness), chance
	# low and rising gently with depth; its glint pierces the darkness
	# (spec §6 — the glimpsed-prize hook).
	var prize_chance := (
		config.prize_spawn_chance_base + config.prize_spawn_chance_depth_gain * depth_frac
	)
	if rng.randf() < prize_chance:
		var pt := Vector2i(
			rng.randi_range(vx * vc + 1, vx * vc + vc - 2),
			rng.randi_range(vy * vc + 1, vy * vc + vc - 2)
		)
		return _with_halo({pt: PRIZE_TIER})

	var tier := _pick_tier(rng, depth_frac)
	var size := rng.randi_range(config.vein_size_min, config.vein_size_max)
	var start := Vector2i(
		rng.randi_range(vx * vc + 1, vx * vc + vc - 2),
		rng.randi_range(vy * vc + 1, vy * vc + vc - 2)
	)
	var tiles := {start: tier}
	var cur := start
	var guard := 0
	while tiles.size() < size and guard < 32:
		guard += 1
		var dir: Vector2i = DIRS[rng.randi_range(0, 3)]
		var next := cur + dir
		# Keep the walk within cell+1 so a vein's reach is bounded (chunk
		# generation only scans neighbouring vein cells).
		if next.x < lo.x or next.x > hi.x or next.y < lo.y or next.y > hi.y:
			continue
		if next.y < 1 or next.y >= config.designed_bottom_depth:
			continue
		cur = next
		tiles[next] = tier
	return _with_halo(tiles)


func _with_halo(tiles: Dictionary) -> Dictionary:
	## Halo = the 8-neighbour ring of harder rock — the telegraph: you feel
	## the rock harden before you break through (spec §3).
	var halo := {}
	for t in tiles.keys():
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				var n: Vector2i = t + Vector2i(dx, dy)
				if not tiles.has(n):
					halo[n] = true
	return {"gems": tiles, "halo": halo}


func _pick_tier(rng: RandomNumberGenerator, depth_frac: float) -> int:
	## tier_weight(tier, depth): overlapping weights with a moving peak +
	## tails (spec §3) — lucky low-tier deep finds, rare early sightings of
	## the next tier up.
	var peak := 1.0 + 4.0 * depth_frac
	var weights: Array[float] = []
	var total := 0.0
	for tier in range(1, 6):
		var w := pow(config.tier_tail_falloff, absf(float(tier) - peak))
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for tier in range(1, 6):
		r -= weights[tier - 1]
		if r <= 0.0:
			return tier
	return 5


# --- deterministic integer hashing -------------------------------------------


static func fdiv(a: int, b: int) -> int:
	return (a - posmod(a, b)) / b


func _hash01_tile(x: int, y: int, salt: int) -> float:
	## Per-tile 32-bit avalanche mix of (world_seed, salt, tile coords)
	## mapped to [0, 1) — a distinct salt per hazard channel (and distinct
	## from _hash_cell) so gas, cave-in and vein placement never correlate.
	var h := (world_seed ^ salt) & 0xFFFFFFFF
	h = (h ^ ((x * 0x85EBCA6B) & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = ((h << 11) | (h >> 21)) & 0xFFFFFFFF
	h = (h ^ ((y * 0xC2B2AE35) & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = (h * 0x27D4EB2F) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	return float(h) / 4294967296.0


func _hash_cell(vx: int, vy: int) -> int:
	## 32-bit avalanche mix of (world_seed, cell coords) — stable across
	## platforms and sessions.
	var h := (world_seed ^ 0xA11CE5) & 0xFFFFFFFF
	h = (h ^ ((vx * 0x85EBCA6B) & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = ((h << 13) | (h >> 19)) & 0xFFFFFFFF
	h = (h ^ ((vy * 0xC2B2AE35) & 0xFFFFFFFF)) & 0xFFFFFFFF
	h = (h * 0x27D4EB2F) & 0xFFFFFFFF
	h = (h ^ (h >> 15)) & 0xFFFFFFFF
	return h
