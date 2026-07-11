class_name DiggerPlayer
extends Node2D
## The grey-box digger. THROWAWAY. In the real game this is a CharacterBody2D
## (ticket 0001); here it is a plain Node2D with hand-rolled AABB-vs-grid
## collision so the whole prototype is a couple of self-contained files with no
## TileSet/scene authoring. The point is FEEL, not architecture.

# --- control schemes -------------------------------------------------------
enum Scheme { TAP, DRAG, STICK }
# --- movement modes --------------------------------------------------------
enum Move { FLOATY, GROUNDED }
# --- dig timing ------------------------------------------------------------
enum Dig { DRILL, INSTANT }

const HALF := Vector2(16, 16)          # player is 32px in a 44px cell -> fits 1-wide tunnels

# floaty (jetpack-in-dirt) tuning
const F_THRUST := 1500.0
const F_GRAVITY := 200.0
const F_DAMP := 4.0
const F_VMAX := 520.0

# grounded (drive + jetpack-to-climb) tuning
const G_GRAVITY := 1100.0
const G_DRIVE := 2600.0
const G_FRICTION := 2400.0
const G_UPTHRUST := 2100.0
const G_VMAX_H := 360.0
const G_VMAX_V := 760.0

const DRILL_PER_HARD := 0.34           # seconds of drilling per unit hardness

# fuel = round-trip budget (ticket 0003): ascent is self-powered and costs fuel
const FUEL_MAX := 100.0
const F_DRAIN := 7.0
const G_UP_DRAIN := 16.0
const G_DRIVE_DRAIN := 2.0
const REFILL := 60.0

# input geometry
const STICK_RADIUS := 70.0
const DRAG_FULL := 90.0
const DRAG_DEAD := 14.0

var grid: DigGrid                       # the grey-box mine
var main: PrototypeMain                 # reads live settings each frame

var velocity := Vector2.ZERO
var fuel := FUEL_MAX
var facing := Vector2(0, 1)
var gems := 0
var runs_lost := 0

var _drill_cell := Vector2i(-999, -999)
var _drill_progress := 0.0

# per-scheme touch state
var _stick_active := false
var _stick_center := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _drag_active := false
var _drag_origin := Vector2.ZERO
var _drag_cur := Vector2.ZERO
var _tap_target := Vector2i(-999, -999)
var _has_tap := false

func _ready() -> void:
	respawn()

func respawn() -> void:
	position = grid.cell_center(4, 1)   # in the open sky at the surface
	velocity = Vector2.ZERO
	fuel = FUEL_MAX
	_reset_drill()
	reset_input()

func reset_input() -> void:
	_stick_active = false
	_drag_active = false
	_has_tap = false

func _reset_drill() -> void:
	_drill_cell = Vector2i(-999, -999)
	_drill_progress = 0.0

# ---------------------------------------------------------------------------
# input -> intent  (a desired thrust/dig direction, length 0..1)
# ---------------------------------------------------------------------------
func _current_intent() -> Vector2:
	# keyboard/arrows always work as a web fallback and override touch
	var kb := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	if kb.length() > 0.1:
		return kb.limit_length(1.0)

	match main.scheme:
		Scheme.STICK:
			if _stick_active:
				return ((_stick_knob - _stick_center) / STICK_RADIUS).limit_length(1.0)
		Scheme.DRAG:
			if _drag_active:
				var off := _drag_cur - _drag_origin
				if off.length() > DRAG_DEAD:
					return (off / DRAG_FULL).limit_length(1.0)
		Scheme.TAP:
			if _has_tap:
				var desired := grid.cell_center(_tap_target.x, _tap_target.y) - position
				if desired.length() < 11.0 and not grid.is_solid(_tap_target.x, _tap_target.y):
					_has_tap = false        # arrived in the (now dug) cell
					return Vector2.ZERO
				return desired.normalized()
	return Vector2.ZERO

func _unhandled_input(event: InputEvent) -> void:
	# emulate_touch_from_mouse is on, so mouse arrives here as touch events too.
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		var p := touch.position
		if touch.pressed:
			match main.scheme:
				Scheme.STICK:
					_stick_active = true
					_stick_center = p
					_stick_knob = p
				Scheme.DRAG:
					_drag_active = true
					_drag_origin = p
					_drag_cur = p
				Scheme.TAP:
					var c := grid.world_to_cell(p)
					var pc := grid.world_to_cell(position)
					# only accept a cell within one step of the player (tap-ADJACENT)
					if maxi(absi(c.x - pc.x), absi(c.y - pc.y)) <= 1 and grid.in_bounds(c.x, c.y):
						_tap_target = c
						_has_tap = true
		else:
			_stick_active = false
			_drag_active = false
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if main.scheme == Scheme.STICK and _stick_active:
			_stick_knob = drag.position
		elif main.scheme == Scheme.DRAG and _drag_active:
			_drag_cur = drag.position

# ---------------------------------------------------------------------------
# simulation
# ---------------------------------------------------------------------------
func _physics_process(delta: float) -> void:
	var intent := _current_intent()
	if intent.length() > 0.15:
		facing = intent.normalized()

	if main.move_mode == Move.FLOATY:
		_step_floaty(intent, delta)
	else:
		_step_grounded(intent, delta)

	# collide, resolving each axis against solid rock
	_move_axis(0, velocity.x * delta)
	_move_axis(1, velocity.y * delta)

	_do_dig(intent, delta)
	_do_fuel(intent, delta)
	queue_redraw()

func _step_floaty(intent: Vector2, delta: float) -> void:
	velocity += intent * F_THRUST * delta
	velocity.y += F_GRAVITY * delta
	velocity -= velocity * F_DAMP * delta
	velocity = velocity.limit_length(F_VMAX)

func _step_grounded(intent: Vector2, delta: float) -> void:
	# horizontal: drive toward intent.x, friction otherwise
	if absf(intent.x) > 0.15:
		velocity.x += intent.x * G_DRIVE * delta
	else:
		velocity.x = move_toward(velocity.x, 0.0, G_FRICTION * delta)
	velocity.x = clampf(velocity.x, -G_VMAX_H, G_VMAX_H)
	# vertical: gravity, unless jetpacking up (self-powered ascent)
	velocity.y += G_GRAVITY * delta
	if intent.y < -0.3 and fuel > 0.0:
		velocity.y -= G_UPTHRUST * delta
	velocity.y = clampf(velocity.y, -G_VMAX_V, G_VMAX_V)

func _move_axis(axis: int, motion: float) -> void:
	if axis == 0:
		position.x += motion
	else:
		position.y += motion
	var left := position.x - HALF.x
	var right := position.x + HALF.x
	var top := position.y - HALF.y
	var bottom := position.y + HALF.y
	var cell: int = grid.CELL
	var origin: Vector2 = grid.ORIGIN
	var c_min := grid.world_to_cell(Vector2(left + 0.01, top + 0.01))
	var c_max := grid.world_to_cell(Vector2(right - 0.01, bottom - 0.01))
	for cy in range(c_min.y, c_max.y + 1):
		for cx in range(c_min.x, c_max.x + 1):
			if grid.is_solid(cx, cy):
				var solid_left := origin.x + cx * cell
				var solid_top := origin.y + cy * cell
				if axis == 0:
					if motion > 0:
						position.x = solid_left - HALF.x
						velocity.x = 0.0
					elif motion < 0:
						position.x = solid_left + cell + HALF.x
						velocity.x = 0.0
				else:
					if motion > 0:
						position.y = solid_top - HALF.y
						velocity.y = 0.0
					elif motion < 0:
						position.y = solid_top + cell + HALF.y
						velocity.y = 0.0

func _do_dig(intent: Vector2, delta: float) -> void:
	if intent.length() < 0.15:
		_reset_drill()
		return
	# pick the orthogonally-adjacent cell we are pressing into (dominant axis)
	var pc := grid.world_to_cell(position)
	var tdir := Vector2i.ZERO
	if absf(intent.x) >= absf(intent.y):
		tdir = Vector2i(int(sign(intent.x)), 0)
	else:
		tdir = Vector2i(0, int(sign(intent.y)))
	var target := pc + tdir
	if not grid.is_solid(target.x, target.y) or not grid.in_bounds(target.x, target.y):
		_reset_drill()
		return
	if target != _drill_cell:
		_drill_cell = target
		_drill_progress = 0.0
	var need := 0.0 if main.dig_mode == Dig.INSTANT else grid.hardness(target.x, target.y) * DRILL_PER_HARD
	_drill_progress += delta
	if _drill_progress >= need:
		if grid.has_gem(target.x, target.y):
			gems += 1
		grid.dig(target.x, target.y)
		_reset_drill()

func _do_fuel(intent: Vector2, delta: float) -> void:
	if grid.is_surface_world_y(position.y):
		fuel = minf(FUEL_MAX, fuel + REFILL * delta)
		return
	var drain := 0.0
	if main.move_mode == Move.FLOATY:
		drain = F_DRAIN * intent.length()
	else:
		if intent.y < -0.3:
			drain = G_UP_DRAIN
		elif absf(intent.x) > 0.15:
			drain = G_DRIVE_DRAIN
	fuel -= drain * delta
	if fuel <= 0.0:
		fuel = 0.0
		runs_lost += 1
		main.flash("RUN LOST — ran dry before reaching the surface")
		respawn()

# ---------------------------------------------------------------------------
# drawing: body, drill progress, and the screen-space input overlay
# (no camera in this prototype, so screen coords == world coords; local = world - position)
# ---------------------------------------------------------------------------
func _draw() -> void:
	# drill target highlight + progress arc
	if grid.in_bounds(_drill_cell.x, _drill_cell.y) and grid.is_solid(_drill_cell.x, _drill_cell.y):
		var center := grid.cell_center(_drill_cell.x, _drill_cell.y) - position
		draw_rect(Rect2(center - Vector2(20, 20), Vector2(40, 40)), Color(1, 1, 1, 0.15), true)
		var need := 0.0 if main.dig_mode == Dig.INSTANT else grid.hardness(_drill_cell.x, _drill_cell.y) * DRILL_PER_HARD
		if need > 0.0:
			var frac := clampf(_drill_progress / need, 0.0, 1.0)
			draw_arc(center, 15.0, -PI / 2, -PI / 2 + TAU * frac, 24, Color(1.0, 0.85, 0.3), 4.0)

	# body (grey box) + facing nose
	draw_rect(Rect2(-HALF, HALF * 2.0), Color(0.9, 0.75, 0.25), true)
	draw_rect(Rect2(-HALF, HALF * 2.0), Color(0.2, 0.15, 0.05), false, 2.0)
	draw_line(Vector2.ZERO, facing * 22.0, Color(0.15, 0.1, 0.0), 3.0)

	# input overlay (screen space -> local = point - position)
	if main.scheme == Scheme.STICK and _stick_active:
		draw_circle(_stick_center - position, STICK_RADIUS, Color(1, 1, 1, 0.08))
		draw_arc(_stick_center - position, STICK_RADIUS, 0, TAU, 32, Color(1, 1, 1, 0.35), 2.0)
		draw_circle(_stick_knob - position, 22.0, Color(1, 1, 1, 0.5))
	elif main.scheme == Scheme.DRAG and _drag_active:
		draw_line(_drag_origin - position, _drag_cur - position, Color(1, 1, 1, 0.4), 3.0)
		draw_circle(_drag_cur - position, 10.0, Color(1, 1, 1, 0.5))
	elif main.scheme == Scheme.TAP and _has_tap:
		var tc := grid.cell_center(_tap_target.x, _tap_target.y) - position
		draw_rect(Rect2(tc - Vector2(21, 21), Vector2(42, 42)), Color(0.9, 0.9, 0.3, 0.6), false, 3.0)
