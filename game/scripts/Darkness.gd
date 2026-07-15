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
## scales hit probability, never damage size). The prize glint is the
## self-lit exception, visible out to prize_glint_radius — wider than any
## lit radius, catchable at the edge of vision (the glimpsed-prize hook).

const MAX_GLINTS := 4

var player: Node2D
var mine: Mine


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
