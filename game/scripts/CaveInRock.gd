class_name CaveInRock
extends Node2D
## One undermined cracked-rock tile coming down (spec §5, cave-ins). Three
## legible beats: TREMBLE in place for cavein_telegraph_secs (the telegraph —
## drawn in world space, so the darkness overlay applies and the warning
## renders only in the light, §6), then FALL down the open shaft damaging
## the digger on contact (cavein_dmg by band, once), then SHATTER on the
## first solid tile. The rock never settles as a new tile: its origin cell
## was marked dug when it was undermined, so persistence is the ordinary
## dug delta — no new save keys.

enum Phase { TREMBLE, FALL, SHATTER }

var mine: Mine
var band := 3  # 3 Granite / 4 Bedrock — indexes cavein_dmg[band - 3]

var _phase := Phase.TREMBLE
var _clock := 0.0
var _hit_player := false
var _shatter_radius := 3.0
var _shatter_alpha := 0.9


func _physics_process(delta: float) -> void:
	var hz: HazardConfig = GameState.hazards
	var px := float(GameState.world.tile_px)
	_clock += delta
	match _phase:
		Phase.TREMBLE:
			if _clock >= hz.cavein_telegraph_secs:
				_phase = Phase.FALL
		Phase.FALL:
			position.y += hz.cavein_fall_speed_tiles * px * delta
			_check_player_hit(px)
			# Land on the first non-air tile under the rock's leading edge
			# (lava counts: rock sinking into a molten pocket just shatters).
			var below := Vector2i(
				int(floor(position.x / px)), int(floor((position.y + px * 0.5) / px))
			)
			if _phase == Phase.FALL and Worldgen.kind_of(mine.code_at(below)) != Worldgen.Kind.AIR:
				position.y = float(below.y) * px - px * 0.5
				_shatter()
		Phase.SHATTER:
			pass  # tween-driven; frees itself
	queue_redraw()


func _check_player_hit(px: float) -> void:
	var player := mine.player
	if player == null or _hit_player:
		return
	var d := player.global_position - global_position
	# Player body is a 12 px square; rock is a full tile.
	if absf(d.x) < px * 0.5 + 6.0 and absf(d.y) < px * 0.5 + 6.0:
		_hit_player = true
		GameState.apply_hazard_damage(float(GameState.hazards.cavein_dmg[band - 3]))
		_shatter()


func _shatter() -> void:
	_phase = Phase.SHATTER
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "_shatter_radius", 16.0, 0.25).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "_shatter_alpha", 0.0, 0.25)
	t.chain().tween_callback(queue_free)


func _draw() -> void:
	var px := float(GameState.world.tile_px)
	if _phase == Phase.SHATTER:
		var dust := Color(0.62, 0.58, 0.55, _shatter_alpha)
		draw_arc(Vector2.ZERO, _shatter_radius, 0.0, TAU, 20, dust, 2.5)
		draw_arc(Vector2.ZERO, _shatter_radius * 0.55, 0.0, TAU, 16, dust.lightened(0.2), 1.5)
		return
	# The rock itself: band-coloured block with dark cracks, matching the
	# unstable tile's atlas tell; a sideways tremble sells "about to drop".
	var wobble := Vector2.ZERO
	if _phase == Phase.TREMBLE:
		wobble.x = sin(_clock * 46.0) * 1.4
	var base: Color = Mine.BAND_COLORS[band]
	var half := px * 0.5
	draw_rect(Rect2(wobble - Vector2(half, half), Vector2(px, px)), base, true)
	var crack := base.darkened(0.55)
	draw_line(wobble + Vector2(-2, -half), wobble + Vector2(1, half), crack, 1.0)
	draw_line(wobble + Vector2(1, 0), wobble + Vector2(half, 3), crack, 1.0)
	draw_rect(Rect2(wobble - Vector2(half, half), Vector2(px, px)), crack, false, 1.0)
