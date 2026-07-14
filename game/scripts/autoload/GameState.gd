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
signal run_lost(reason: String)

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


func apply_hazard_damage(amount: float) -> void:
	## The single hazard entry point (spec §5): every hazard lands its hull
	## damage here. Falls are live (Act I); gas/cave-ins/lava are later acts.
	hull = maxf(0.0, hull - amount)
	hull_changed.emit(hull, float(Upgrades.hull_capacity()))
	if hull <= 0.0:
		lose_run("hull breached")


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
	apply_hazard_damage(dmg)


func lit_view_radius() -> float:
	## The darkness base curve (spec §6) x the Light track, in tiles: a pure
	## function of (config, upgrades, depth). The darkness renderer (later
	## session) will draw exactly this; falls consume it now — a brace only
	## counts if the landing was inside the lit radius.
	var shrink := world.shrink_rate_per_depth * float(depth) * Upgrades.light_mult()
	return maxf(world.min_floor_radius, world.surface_view_radius - shrink)


func lose_run(reason: String) -> void:
	## The single "run lost" outcome (spec §1): forfeit only carried cargo,
	## keep Wallet and upgrades, respawn topped up for free.
	cargo.clear()
	cargo_changed.emit(0, Upgrades.cargo_slots())
	top_up()
	run_lost.emit(reason)


func try_collect(tier: int) -> bool:
	## Full hold is a soft fail: the gem is simply not collected (spec §1).
	if cargo.size() >= Upgrades.cargo_slots():
		return false
	cargo.append(tier)
	cargo_changed.emit(cargo.size(), Upgrades.cargo_slots())
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
	Wallet.add(value)
	cargo.clear()
	cargo_changed.emit(0, Upgrades.cargo_slots())
	cargo_sold.emit(value)


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


func mark_dug(tile: Vector2i) -> void:
	var cc := chunk_of(tile)
	if not dug.has(cc):
		var mask := PackedByteArray()
		mask.resize(world.chunk_size * world.chunk_size / 8)
		dug[cc] = mask
	var bit := _bit_of(tile)
	var mask: PackedByteArray = dug[cc]
	mask[bit >> 3] = mask[bit >> 3] | (1 << (bit & 7))
	dug[cc] = mask


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
