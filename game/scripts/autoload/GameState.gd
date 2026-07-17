extends Node
## Autoload: cross-run state — the three pressures (Fuel, Cargo, Hull), the
## world seed, and the persistent mine's dug/collected deltas (spec §1, §3,
## §13). Signals up, calls down: gameplay nodes mutate state through these
## methods; the HUD listens to the signals.

signal fuel_changed(value: float, cap: float)
signal hull_changed(value: float, cap: float)
signal cargo_changed(count: int, slots: int)
signal depth_changed(depth: int)
signal cargo_sold(value: int)
signal run_lost(reason: String, cargo_lost: int)
## The moment-of-the-event signals the Miner's Log counts on (spec §8):
## every one already existed as a game event — no new detection systems.
signal tile_dug(tile: Vector2i)
signal gem_collected(tier: int)
signal prizes_banked(count: int)
## Emitted when a hazard lands damage and the hull HOLDS — the "survived
## your first X" family pins here (kind = one of the HAZARD_* consts).
signal hazard_survived(kind: String, amount: float)

## Hazard kind tags for apply_hazard_damage / hazard_survived — one per
## trigger mechanism (spec §5).
const HAZARD_FALL := "fall"
const HAZARD_GAS := "gas"
const HAZARD_CAVEIN := "cavein"
const HAZARD_LAVA := "lava"

## The three config resources (Appendix A). Loaded once; every derived value
## (drill time, capacities) is computed from (config, upgrades, depth) —
## never stored (spec §10).
var economy: EconomyConfig = preload("res://config/economy.tres")
var world: WorldgenConfig = preload("res://config/worldgen.tres")
var hazards: HazardConfig = preload("res://config/hazards.tres")

## Per-player seed, fixed at new-game (spec §3). The one sanctioned use of
## runtime randomness: generating the seed itself. SaveManager persists it
## (later session); everything under it is a pure function of the seed.
var world_seed: int = 0

# --- run state (the three pressures) ----------------------------------------
var fuel: float = 0.0
var hull: float = 0.0
var cargo: Array[int] = []  # carried gem tiers; 1 gem = 1 slot, any tier
var depth: int = 0  # player depth in tiles below the surface

# --- persistent-mine deltas (spec §13): the save stores only these ----------
## Vector2i chunk coords -> PackedByteArray dug bitmask (1 bit per tile).
var dug: Dictionary = {}
## Vector2i tile coords -> true, for gems taken out of the ground.
## Dug != collected: full-hold gems stay in the ground (spec §1).
var collected: Dictionary = {}


func new_game() -> void:
	randomize()
	world_seed = randi() & 0x7FFFFFFF
	dug.clear()
	collected.clear()
	cargo.clear()
	top_up()
	set_depth(0)


func top_up() -> void:
	## Free refuel/repair at the surface (costs pinned to zero, spec §1).
	fuel = float(Upgrades.fuel_capacity())
	hull = float(Upgrades.hull_capacity())
	fuel_changed.emit(fuel, float(Upgrades.fuel_capacity()))
	hull_changed.emit(hull, float(Upgrades.hull_capacity()))


func restore_run(fuel_in: float, hull_in: float, cargo_in: Array[int]) -> void:
	## Mid-run restore (spec §13 `run`, best-effort): SaveManager has already
	## validated the values against the loaded upgrades' caps; this just
	## makes them live and tells the HUD.
	fuel = clampf(fuel_in, 0.0, float(Upgrades.fuel_capacity()))
	hull = clampf(hull_in, 0.0, float(Upgrades.hull_capacity()))
	cargo.clear()
	for tier in cargo_in:
		cargo.append(tier)
	fuel_changed.emit(fuel, float(Upgrades.fuel_capacity()))
	hull_changed.emit(hull, float(Upgrades.hull_capacity()))
	cargo_changed.emit(cargo.size(), Upgrades.cargo_slots())


func set_depth(d: int) -> void:
	if d == depth:
		return
	depth = d
	depth_changed.emit(depth)


func drain_fuel(amount: float) -> void:
	if amount <= 0.0:
		return
	fuel = maxf(0.0, fuel - amount)
	fuel_changed.emit(fuel, float(Upgrades.fuel_capacity()))
	if fuel <= 0.0 and depth > 0:
		lose_run("ran dry below ground — the climb home costs fuel too")


func apply_hazard_damage(amount: float, kind: String = "") -> void:
	## The single hazard entry point (spec §5): every hazard lands its hull
	## damage here, tagged with its HAZARD_* kind. Damage the hull absorbs
	## emits hazard_survived — the event the survival milestones pin to
	## (spec §8); damage it doesn't is the one run-lost outcome.
	hull = maxf(0.0, hull - amount)
	hull_changed.emit(hull, float(Upgrades.hull_capacity()))
	if hull <= 0.0:
		lose_run("hull breached")
	elif amount > 0.0 and kind != "":
		hazard_survived.emit(kind, amount)


func apply_fall_damage(tiles_fallen: float, brace_held: bool) -> void:
	## Falls (spec §5, Act I): grace <= fall_grace_tiles free, then
	## fall_dmg_per_tile per tile ~linear, capped at fall_dmg_cap_frac of
	## CURRENT hull (scales with upgrades — serious but survivable, never a
	## one-shot). A thrust-brace cuts damage x fall_light_brace_factor, but
	## only when the drop was SEEN in the light (§6: darkness scales hazard
	## hit probability; the lit view radius is the dodge).
	var over := tiles_fallen - float(hazards.fall_grace_tiles)
	if over <= 0.0:
		return
	var dmg := minf(over * hazards.fall_dmg_per_tile, hazards.fall_dmg_cap_frac * hull)
	if brace_held and tiles_fallen <= lit_view_radius():
		dmg *= hazards.fall_light_brace_factor
	apply_hazard_damage(dmg, HAZARD_FALL)


func lit_view_radius() -> float:
	## The darkness base curve (spec §6) x the Light track, in tiles: a pure
	## function of (config, upgrades, depth). The darkness renderer draws
	## exactly this disc — buying Light visibly pushes the dark back — and
	## falls consume it too: a brace only counts if the landing was inside
	## the lit radius.
	var shrink := world.shrink_rate_per_depth * float(depth) * Upgrades.light_mult()
	return maxf(world.min_floor_radius, world.surface_view_radius - shrink)


func lose_run(reason: String) -> void:
	## The single "run lost" outcome (spec §1): forfeit only carried cargo,
	## keep Wallet and upgrades, respawn topped up for free. The forfeited
	## value rides the signal — the cargo_value_lost stat's moment (spec §8).
	var lost := cargo_value()
	cargo.clear()
	cargo_changed.emit(0, Upgrades.cargo_slots())
	top_up()
	run_lost.emit(reason, lost)


func try_collect(tier: int) -> bool:
	## Full hold is a soft fail: the gem is simply not collected (spec §1).
	if cargo.size() >= Upgrades.cargo_slots():
		return false
	cargo.append(tier)
	cargo_changed.emit(cargo.size(), Upgrades.cargo_slots())
	gem_collected.emit(tier)
	return true


func cargo_value() -> int:
	var total := 0
	for tier in cargo:
		if tier == Worldgen.PRIZE_TIER:
			total += economy.prize_value
		else:
			total += economy.gem_value[tier - 1]
	return total


func sell_cargo() -> void:
	## Selling converts cargo to banked Wallet money and empties the hold —
	## the ratchet's fuel (CONTEXT.md). A surface event: SaveManager snapshots
	## on cargo_sold (spec §13).
	var value := cargo_value()
	var prizes := 0
	for tier in cargo:
		if tier == Worldgen.PRIZE_TIER:
			prizes += 1
	Wallet.add(value)
	cargo.clear()
	cargo_changed.emit(0, Upgrades.cargo_slots())
	cargo_sold.emit(value)
	if prizes > 0:
		# Banked, not merely carried — the run home was part of it (spec §8).
		prizes_banked.emit(prizes)


func refuel_repair() -> void:
	## Cost is plumbed but pinned to zero (spec §1) — a per-run sink could be
	## switched on later without a refactor.
	var cost := int(
		ceil(
			(
				(Upgrades.fuel_capacity() - fuel) * economy.refuel_cost_per_unit
				+ (Upgrades.hull_capacity() - hull) * economy.repair_cost_per_hp
			)
		)
	)
	if Wallet.try_spend(cost):
		top_up()


# --- dug/collected deltas ----------------------------------------------------


func chunk_of(tile: Vector2i) -> Vector2i:
	var cs := world.chunk_size
	return Vector2i((tile.x - posmod(tile.x, cs)) / cs, (tile.y - posmod(tile.y, cs)) / cs)


func _bit_of(tile: Vector2i) -> int:
	var cs := world.chunk_size
	return posmod(tile.y, cs) * cs + posmod(tile.x, cs)


func mark_dug(tile: Vector2i, player_dug: bool = true) -> void:
	## player_dug distinguishes the drill breaking a tile (the tiles_dug
	## stat's moment, spec §8) from rock a cave-in let go of — both persist
	## as the same ordinary dug delta.
	var cc := chunk_of(tile)
	if not dug.has(cc):
		var mask := PackedByteArray()
		mask.resize(world.chunk_size * world.chunk_size / 8)
		dug[cc] = mask
	var bit := _bit_of(tile)
	var mask: PackedByteArray = dug[cc]
	mask[bit >> 3] = mask[bit >> 3] | (1 << (bit & 7))
	dug[cc] = mask
	if player_dug:
		tile_dug.emit(tile)


func is_dug(tile: Vector2i) -> bool:
	var cc := chunk_of(tile)
	if not dug.has(cc):
		return false
	var bit := _bit_of(tile)
	var mask: PackedByteArray = dug[cc]
	return (mask[bit >> 3] & (1 << (bit & 7))) != 0


func mark_collected(tile: Vector2i) -> void:
	collected[tile] = true


func is_collected(tile: Vector2i) -> bool:
	return collected.has(tile)
