class_name Player
extends CharacterBody2D
## The digger. Ports the 0004 prototype's validated feel (spec §2): virtual
## stick intent -> floaty jetpack-in-dirt thrust, and hold-to-drill into the
## cell the stick presses against, over
## time = hardness * dig_constant / drill_power (the §3 drill-time contract).
## Collision (move_and_slide against the TileMapLayer) holds the digger
## against undug rock until the cell breaks — no separate dig button.

# Floaty feel knobs (0004's constants, rescaled from the prototype's 44 px
# grey-box cell to the real 16 px tile).
@export var thrust := 550.0
@export var gravity_accel := 73.0
@export var glide_damp := 4.0
@export var max_speed := 190.0
## Intent magnitude below which we neither steer nor drill.
@export var intent_threshold := 0.15

var mine: Mine
var stick: VirtualStick
var spawn_position := Vector2.ZERO

var facing := Vector2(0.0, 1.0)

var _drill_cell := Vector2i(-9999, -9999)
var _drill_progress := 0.0
var _prev_y_tiles := 0.0

# Fall tracking (spec §5): anchor y where the drop began, whether an upward
# thrust-brace was held at any point during it.
var _falling := false
var _braced := false
var _fall_start_y := 0.0


func _ready() -> void:
	add_to_group("digger")


func respawn() -> void:
	global_position = spawn_position
	velocity = Vector2.ZERO
	_prev_y_tiles = spawn_position.y / tile_px()
	_falling = false
	_reset_drill()
	if stick != null:
		stick.reset()


func tile_px() -> float:
	return float(GameState.world.tile_px)


func _physics_process(delta: float) -> void:
	var intent := _current_intent()
	if intent.length() > intent_threshold:
		facing = intent.normalized()

	# Floaty (spec §2): thrust in the stick direction, light gravity,
	# slight glide damping — descent and the self-powered climb home are
	# one continuous flying verb.
	velocity += intent * thrust * delta
	velocity.y += gravity_accel * delta
	velocity -= velocity * glide_damp * delta
	velocity = velocity.limit_length(max_speed)
	move_and_slide()

	_track_fall(intent)
	_do_dig(intent, delta)
	_account_fuel()
	queue_redraw()


func _current_intent() -> Vector2:
	# Keyboard falls out free on desktop (spec §2) and overrides touch.
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if kb.length() > 0.1:
		return kb.limit_length(1.0)
	if stick != null:
		return stick.intent()
	return Vector2.ZERO


# --- falls (spec §5, Act I): drill into a cave and drop -----------------------


func _track_fall(intent: Vector2) -> void:
	## Distance-based fall damage: a fall runs from the y where support was
	## lost to the landing. Thrusting up mid-fall is the brace; fully
	## arresting the drop (velocity turns upward) escapes it damage-free.
	## Runs AFTER move_and_slide so landings are read from this frame's
	## collisions (a landing zeroes velocity.y — the landed check must win).
	var landed := false
	for i in range(get_slide_collision_count()):
		if get_slide_collision(i).get_normal().y < -0.7:
			landed = true
	if _falling:
		if intent.y < -intent_threshold:
			_braced = true
		if landed:
			var tiles := (global_position.y - _fall_start_y) / tile_px()
			# Hazards live in the mine (spec §5) — landing on the surface
			# ground (depth 0) is safe, so hub bounces never chip the hull.
			if global_position.y > 0.0:
				GameState.apply_fall_damage(tiles, _braced)
			_falling = false
		elif velocity.y <= 0.0:
			_falling = false
	elif not landed and velocity.y / tile_px() > GameState.hazards.fall_min_speed_tiles:
		_falling = true
		_braced = false
		_fall_start_y = global_position.y


# --- hold-to-drill ------------------------------------------------------------


func _do_dig(intent: Vector2, delta: float) -> void:
	if mine == null or intent.length() < intent_threshold:
		_reset_drill()
		return
	# The cell the stick presses into: orthogonally adjacent, dominant axis.
	var pc := _tile_of(global_position)
	var dir := Vector2i.ZERO
	if absf(intent.x) >= absf(intent.y):
		dir = Vector2i(int(signf(intent.x)), 0)
	else:
		dir = Vector2i(0, int(signf(intent.y)))
	var target := pc + dir
	if not mine.is_breakable(target):
		_reset_drill()
		return
	if target != _drill_cell:
		_drill_cell = target
		_drill_progress = 0.0
	var need := drill_time_for(target)
	_drill_progress += delta
	if _drill_progress >= need:
		mine.dig(target)
		# Hover-while-drilling fuel (spec §4), charged per tile dug.
		if target.y >= 0:
			GameState.drain_fuel(GameState.economy.fuel_hover_per_tile)
		_reset_drill()


func drill_time_for(tile: Vector2i) -> float:
	## The reconciled drill-time contract (spec §3):
	## effective_drill_time = hardness * dig_constant / drill_power.
	return mine.hardness(tile) * GameState.economy.dig_constant / Upgrades.drill_power()


func _reset_drill() -> void:
	_drill_cell = Vector2i(-9999, -9999)
	_drill_progress = 0.0


func _tile_of(pos: Vector2) -> Vector2i:
	return Vector2i(int(floor(pos.x / tile_px())), int(floor(pos.y / tile_px())))


# --- fuel: the round-trip budget (spec §1/§4) ---------------------------------


func _account_fuel() -> void:
	var y_tiles := global_position.y / tile_px()
	# Only movement below the surface line (y=0) burns fuel; descent and
	# ascent are charged per tile at their asymmetric rates.
	var below_now := maxf(0.0, y_tiles)
	var below_prev := maxf(0.0, _prev_y_tiles)
	var eco := GameState.economy
	if below_now > below_prev:
		GameState.drain_fuel((below_now - below_prev) * eco.fuel_descent_per_tile)
	elif below_prev > below_now:
		GameState.drain_fuel(
			(below_prev - below_now) * eco.fuel_ascent_per_tile * Upgrades.ascent_factor()
		)
	_prev_y_tiles = y_tiles
	GameState.set_depth(int(floor(maxf(0.0, y_tiles))))


# --- grey-box drawing ---------------------------------------------------------


func _draw() -> void:
	var px := tile_px()
	# Drill target highlight + progress ring (spec §2).
	if mine != null and mine.is_breakable(_drill_cell):
		var center := Vector2(_drill_cell) * px + Vector2(px, px) * 0.5 - global_position
		draw_rect(
			Rect2(center - Vector2(px, px) * 0.5, Vector2(px, px)), Color(1, 1, 1, 0.16), true
		)
		var need := drill_time_for(_drill_cell)
		if need > 0.0:
			var frac := clampf(_drill_progress / need, 0.0, 1.0)
			draw_arc(
				center, px * 0.42, -PI / 2, -PI / 2 + TAU * frac, 20, Color(1.0, 0.85, 0.3), 2.0
			)
	# Body + facing nose.
	draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), Color(0.92, 0.76, 0.26), true)
	draw_rect(Rect2(Vector2(-6, -6), Vector2(12, 12)), Color(0.2, 0.15, 0.05), false, 1.5)
	draw_line(Vector2.ZERO, facing * 8.0, Color(0.15, 0.1, 0.0), 2.0)
