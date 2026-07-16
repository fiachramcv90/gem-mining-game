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

# Robot motion state (spec §7: motion = tweens + code, no hand frames).
## Vertical squash factor, tweened on landing (1 = rest).
var _squash := 1.0
## Drill-spin phase; advances only while drilling.
var _spin := 0.0
var _drilling := false
var _last_intent := Vector2.ZERO

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
	_last_intent = intent
	if intent.length() > intent_threshold:
		facing = intent.normalized()
	if _drilling:
		_spin += delta * 26.0
	Sfx.set_thrust(intent.length())

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
			_play_land_squash(tiles)
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
	_drilling = false
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
	_drilling = true
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


# --- the digger robot (feedback #6, spec §7) -----------------------------------
# A small robot with a drill, on screen 100% of the time — drawn in
# immediate mode from the Palette, animated by code (hover bob, thruster
# flame, spinning drill, landing squash tween): near-zero hand-drawn frames.


func _play_land_squash(tiles_fallen: float) -> void:
	## Landing squash-and-recover, scaled a little by how far we dropped.
	if tiles_fallen < 0.5:
		return
	_squash = maxf(0.55, 0.8 - tiles_fallen * 0.03)
	var t := create_tween()
	t.tween_property(self, "_squash", 1.0, 0.35).set_trans(Tween.TRANS_ELASTIC).set_ease(
		Tween.EASE_OUT
	)


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
			var ring := Palette.UI_GOLD
			draw_arc(center, px * 0.42, -PI / 2, -PI / 2 + TAU * frac, 20, ring, 2.0)
	_draw_robot()


func _draw_robot() -> void:
	var t := Time.get_ticks_msec() * 0.001
	var thrusting := _last_intent.length() > intent_threshold
	# Hover bob: gentle at idle, tighter under thrust.
	var bob := Vector2(0.0, sin(t * 3.2) * (1.2 if not thrusting else 0.5))
	# Landing squash: wider and shorter, recovering elastically.
	var squash_scale := Vector2(1.0 + (1.0 - _squash) * 0.6, _squash)

	# Thruster flame (under the body, before the squash transform so it
	# stretches with the hull): flickers, longer under thrust. (Floating
	# motion mode never reports a floor, so the flame keys off intent.)
	if thrusting:
		var flame_len := 3.0 + sin(t * 31.0) * 1.2 + _last_intent.length() * 3.0
		var base_y := bob.y + 6.0 * _squash
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(-2.5, base_y),
					Vector2(2.5, base_y),
					Vector2(0.0, base_y + flame_len),
				]
			),
			Palette.FLAME_MID
		)
		draw_colored_polygon(
			PackedVector2Array(
				[
					Vector2(-1.2, base_y),
					Vector2(1.2, base_y),
					Vector2(0.0, base_y + flame_len * 0.55),
				]
			),
			Palette.FLAME_HOT
		)

	draw_set_transform(bob, 0.0, squash_scale)
	# Skid plates + feet.
	draw_rect(Rect2(-6, 4, 12, 2), Palette.DIGGER_METAL_DARK, true)
	draw_rect(Rect2(-6, 5, 3, 2), Palette.DIGGER_DARK, true)
	draw_rect(Rect2(3, 5, 3, 2), Palette.DIGGER_DARK, true)
	# Hull.
	draw_rect(Rect2(-5, -3, 10, 7), Palette.DIGGER_BODY, true)
	draw_rect(Rect2(-5, 2, 10, 2), Palette.DIGGER_SHADE, true)
	draw_rect(Rect2(-5, -3, 10, 7), Palette.DIGGER_DARK, false, 1.0)
	# Rivets.
	draw_rect(Rect2(-4, -2, 1, 1), Palette.DIGGER_DARK, true)
	draw_rect(Rect2(3, -2, 1, 1), Palette.DIGGER_DARK, true)
	# Cab dome + glass.
	draw_rect(Rect2(-3, -6, 6, 3), Palette.DIGGER_BODY, true)
	draw_rect(Rect2(-3, -6, 6, 3), Palette.DIGGER_DARK, false, 1.0)
	draw_rect(Rect2(-2, -5, 4, 2), Palette.DIGGER_GLASS, true)
	draw_rect(Rect2(-2, -5, 1, 1), Color.WHITE, true)
	# Headlamp: a warm pixel on the facing side of the dome (the Light track
	# made visible on the machine).
	var lamp := Vector2(signf(facing.x) * 3.0 if absf(facing.x) > 0.3 else 0.0, -4.0)
	draw_rect(Rect2(lamp - Vector2(0.5, 0.5), Vector2(1.5, 1.5)), Palette.PRIZE_GLINT, true)

	# The drill arm, pointing along facing; the bit's chevrons scroll while
	# drilling so it reads as spinning — code motion, not frames.
	draw_set_transform(bob + facing * 5.0, facing.angle(), squash_scale)
	draw_rect(Rect2(-1, -2.5, 3, 5), Palette.DIGGER_METAL_DARK, true)
	var jab := 0.0
	if _drilling:
		jab = absf(sin(_spin * 2.0)) * 1.2
	var tip := Vector2(7.0 + jab, 0.0)
	draw_colored_polygon(
		PackedVector2Array([Vector2(2, -2.5), Vector2(2, 2.5), tip]), Palette.DIGGER_METAL
	)
	for i in range(2):
		var phase := fposmod(_spin + float(i) * 2.6, 5.2) / 5.2
		var cx := 2.0 + phase * 4.0
		var half_h := 2.5 * (1.0 - phase * 0.8)
		draw_line(Vector2(cx, -half_h), Vector2(cx + 0.8, half_h), Palette.DIGGER_METAL_DARK, 1.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
