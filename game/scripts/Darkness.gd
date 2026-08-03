class_name DarknessOverlay
extends ColorRect
## The darkness renderer (spec §6): a full-screen ColorRect on a CanvasLayer
## between the world and the HUD, running the one reused darkness/glint
## shader (§7). Per frame it only updates a handful of uniforms — light
## centre, GameState.lit_view_radius(), and up to MAX_GLINTS prize glints —
## never CPU pixel work, so the single-threaded web export holds 60 FPS.
##
## The rendering rule IS the dodge mechanic: beyond the lit radius the
## overlay is opaque, so a hazard's tell simply is not drawn (darkness
## scales hit probability, never damage size). Two self-lit exceptions
## pierce the dark by design (spec §6): the prize glint, visible out to
## prize_glint_radius — wider than any lit radius, catchable at the edge of
## vision (the glimpsed-prize hook) — and lava's glow, which cuts the
## overlay open out to lava_glow_radius so Bedrock's headline threat can't
## cheap-shot.

const MAX_GLINTS := 4
const MAX_LAVA_GLOWS := 8
const MAX_FLARES := 4

var player: Node2D
var mine: Mine

## Active EP1 flares (spec C4/EP1-10): each {pos: world Vector2, radius: world
## px, born: sec, dies: sec}. Dropped by the ToolRunner, fade over their life,
## self-remove on expiry — a scarce, placed, temporary reveal.
var _flares: Array[Dictionary] = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://shaders/darkness.gdshader")
	material = mat


func _process(_delta: float) -> void:
	if player == null or mine == null:
		return
	var mat := material as ShaderMaterial
	var ct := get_viewport().get_canvas_transform()
	var px_per_world := ct.get_scale().x  # camera zoom + stretch scale
	var tile_px := float(GameState.world.tile_px)
	var world := GameState.world

	mat.set_shader_parameter("view_size", size)
	mat.set_shader_parameter("light_pos", ct * player.global_position)
	mat.set_shader_parameter("lit_radius", GameState.lit_view_radius() * tile_px * px_per_world)
	mat.set_shader_parameter("edge_softness", world.darkness_edge_softness * tile_px * px_per_world)
	mat.set_shader_parameter("max_alpha", world.darkness_max_alpha)

	# Prize glints within prize_glint_radius of the player, faded out near
	# the edge of that reach. Prizes are singleton-rare, so first-found
	# rather than nearest-sorted is fine for the MAX_GLINTS cap.
	var positions := PackedVector2Array()
	positions.resize(MAX_GLINTS)
	var strengths := PackedFloat32Array()
	strengths.resize(MAX_GLINTS)
	var count := 0
	var glint_reach := world.prize_glint_radius * tile_px  # world px
	for wp in mine.prize_glint_positions():
		if count >= MAX_GLINTS:
			break
		var d: float = (wp - player.global_position).length()
		if d > glint_reach:
			continue
		positions[count] = ct * wp
		strengths[count] = 1.0 - smoothstep(0.75, 1.0, d / glint_reach)
		count += 1
	mat.set_shader_parameter("glint_pos", positions)
	mat.set_shader_parameter("glint_strength", strengths)
	mat.set_shader_parameter("glint_count", count)

	# Lava glow points (the second self-lit exception): the nearest resident
	# lava tiles whose glow disc could touch the screen — half the view
	# diagonal plus the glow radius, all in world px.
	var glow_px := GameState.hazards.lava_glow_radius * tile_px
	var reach := (size * 0.5 / px_per_world).length() + glow_px
	var lava_screen := PackedVector2Array()
	lava_screen.resize(MAX_LAVA_GLOWS)
	var lava_points := mine.lava_glow_points(player.global_position, reach, MAX_LAVA_GLOWS)
	for i in range(lava_points.size()):
		lava_screen[i] = ct * lava_points[i]
	mat.set_shader_parameter("lava_pos", lava_screen)
	mat.set_shader_parameter("lava_count", lava_points.size())
	mat.set_shader_parameter("lava_radius", glow_px * px_per_world)

	_update_flares(mat, ct, px_per_world)


func add_flare(world_pos: Vector2, radius_tiles: float, duration: float) -> void:
	## The ToolRunner drops a flare here (spec C4/EP1-10). Over MAX_FLARES the
	## oldest is displaced so a fresh drop always lights.
	var now := Time.get_ticks_msec() * 0.001
	var tile_px := float(GameState.world.tile_px)
	if _flares.size() >= MAX_FLARES:
		_flares.pop_front()
	_flares.append(
		{"pos": world_pos, "radius": radius_tiles * tile_px, "born": now, "dies": now + duration}
	)


func _update_flares(mat: ShaderMaterial, ct: Transform2D, px_per_world: float) -> void:
	var now := Time.get_ticks_msec() * 0.001
	var i := 0
	while i < _flares.size():
		if now >= float(_flares[i]["dies"]):
			_flares.remove_at(i)
		else:
			i += 1
	var pos := PackedVector2Array()
	pos.resize(MAX_FLARES)
	var radii := PackedFloat32Array()
	radii.resize(MAX_FLARES)
	var strengths := PackedFloat32Array()
	strengths.resize(MAX_FLARES)
	for j in range(mini(_flares.size(), MAX_FLARES)):
		var f := _flares[j]
		pos[j] = ct * Vector2(f["pos"])
		radii[j] = float(f["radius"]) * px_per_world
		# Quick ignite, hold, then fade over the last ~2s of the flare's life.
		var age := now - float(f["born"])
		var remaining := float(f["dies"]) - now
		strengths[j] = clampf(minf(age * 4.0, remaining * 0.5), 0.0, 1.0)
	mat.set_shader_parameter("flare_pos", pos)
	mat.set_shader_parameter("flare_radius", radii)
	mat.set_shader_parameter("flare_strength", strengths)
	mat.set_shader_parameter("flare_count", mini(_flares.size(), MAX_FLARES))
