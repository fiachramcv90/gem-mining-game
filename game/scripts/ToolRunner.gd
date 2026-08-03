class_name ToolRunner
extends Node2D
## The in-run home of EP1 consumable EFFECTS (spec C3/C4). The HUD's three
## corner buttons call activate(tool); this applies the effect against the
## live run (player/mine/darkness) and, on success, spends the charge through
## Loadout. State lives in the Loadout autoload — this is the per-scene
## actuator, created by Main like the Garage.
##
## Activation is one tap for every tool (spec C3): instant items fire
## immediately; dynamite drops at the digger with a lit fuse (flee before it
## blows — the retreat gamble); the scout auto-leads to the nearest qualifying
## gem; the hauler leaves with the current cargo. A refusal (no lead, no
## haulable cargo, a drone already out) returns a short reason and spends
## nothing — a scarce charge is never wasted.

var player: Player
var mine: Mine
var darkness: DarknessOverlay

var _hauler_busy := false
var _scout_busy := false


func _cfg() -> ConsumablesConfig:
	return Loadout.config


func activate(tool: String) -> String:
	## Returns "" on success (charge spent), else a short refusal reason.
	if not Loadout.can_use(tool):
		return "no charges"
	var reason := ""
	match tool:
		"flare":
			_use_flare()
		"fuel_cell":
			_use_fuel_cell()
		"repair_kit":
			_use_repair()
		"dynamite":
			_use_dynamite()
		"scout":
			reason = _try_scout()
		"hauler":
			reason = _try_hauler()
		_:
			reason = "unknown tool"
	if reason.is_empty():
		Loadout.consume(tool)
	return reason


# --- instant relief (spec C4/EP1-10) -----------------------------------------


func _use_flare() -> void:
	var lead := player.facing.normalized() * _cfg().flare_lead * player.tile_px()
	darkness.add_flare(player.global_position + lead, _cfg().flare_radius, _cfg().flare_duration)
	Juice.flash(Palette.PRIZE_GLINT, 0.12)
	Sfx.play("upgrade")


func _use_fuel_cell() -> void:
	GameState.add_pressure(_cfg().fuel_cell_frac * float(Upgrades.fuel_capacity()), 0.0)
	Juice.flash(Palette.UI_FUEL, 0.10)
	Sfx.play("sell")


func _use_repair() -> void:
	GameState.add_pressure(0.0, _cfg().repair_frac * float(Upgrades.hull_capacity()))
	Juice.flash(Palette.UI_GOOD, 0.10)
	Sfx.play("sell")


# --- dynamite (spec C4/EP1-08) -----------------------------------------------


func _use_dynamite() -> void:
	var charge := Dynamite.new()
	charge.player = player
	charge.mine = mine
	charge.blast_tile = _tile_of(player.global_position) + Vector2i.DOWN
	charge.position = mine.world_center(charge.blast_tile)
	mine.add_child(charge)


# --- scout drone (spec C4/EP1-09) --------------------------------------------


func _try_scout() -> String:
	if _scout_busy:
		return "scout still out"
	var target: Variant = _find_scout_target()
	if target == null:
		return "no leads here"
	_launch_scout(target)
	return ""


func _try_hauler() -> String:
	if _hauler_busy:
		return "drone still out"
	var value := GameState.take_haulable_cargo()
	if value <= 0:
		return "no cargo to haul"
	_launch_hauler(value)
	return ""


func _find_scout_target() -> Variant:
	return mine.worldgen.find_scout_target(
		_tile_of(player.global_position), int(_cfg().scout_radius), int(_cfg().scout_min_tier)
	)


func _launch_scout(target: Vector2i) -> void:
	var drone := ScoutDrone.new()
	drone.mine = mine
	drone.start_tile = _tile_of(player.global_position)
	drone.target_tile = target
	drone.tiles_per_sec = _cfg().scout_tunnel_tiles_per_sec
	drone.finished.connect(func() -> void: _scout_busy = false)
	mine.add_child(drone)
	_scout_busy = true
	Sfx.play("click")


# --- hauler drone (spec C4/EP1-09) -------------------------------------------


func _launch_hauler(value: int) -> void:
	var drone := HaulerDrone.new()
	drone.value = value
	drone.trip_time = (
		_cfg().haul_trip_time_base + _cfg().haul_trip_time_per_depth * float(GameState.depth)
	)
	drone.start_pos = player.global_position
	drone.finished.connect(func() -> void: _hauler_busy = false)
	mine.add_child(drone)
	_hauler_busy = true
	Sfx.play("click")


func _tile_of(pos: Vector2) -> Vector2i:
	var px := player.tile_px()
	return Vector2i(int(floor(pos.x / px)), int(floor(pos.y / px)))
