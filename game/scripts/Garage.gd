class_name Garage
extends Node2D
## The surface hub as a PLACE (feedback #3): a garage on the surface line
## the digger flies into. Entering the doorway opens the hub panel —
## replacing the old SURFACE HUB button as the trigger and nothing else:
## the §9 census (4 actions + Miner's Log + ♥ + 💾) is untouched, and the
## hub still teaches itself (0013) — the building sits beside the spawn
## point, warm-lit with a GARAGE sign, and is the only structure in view.
##
## Trigger discipline: a simple AABB poll with an arm/disarm latch — the
## doorway re-arms only after the digger leaves it, so closing the hub
## (DESCEND) never instantly reopens it, and the respawn-inside case can't
## fire while the run-lost panel holds the tree paused.

## Doorway interior, world px (tile 16): 2.5 tiles wide, just over 2 tall.
const DOOR_RECT := Rect2(-84.0, -36.0, 40.0, 34.0)
## Building shell, world px.
const BUILD_RECT := Rect2(-96.0, -48.0, 64.0, 48.0)

var player: Node2D
var hud: HUD

var _armed := true


func _physics_process(_delta: float) -> void:
	if player == null or hud == null:
		return
	var inside := DOOR_RECT.has_point(player.global_position)
	if not inside:
		_armed = true
		return
	if _armed and not get_tree().paused and hud.is_idle():
		_armed = false
		hud.open_hub()
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()  # the doorway lamp pulses


func _draw() -> void:
	var t := Time.get_ticks_msec() * 0.001
	# Roof slab, overhanging.
	draw_rect(
		Rect2(BUILD_RECT.position + Vector2(-4, -6), Vector2(BUILD_RECT.size.x + 8, 8)),
		Palette.DIGGER_METAL_DARK,
		true
	)
	draw_rect(
		Rect2(BUILD_RECT.position + Vector2(-4, -6), Vector2(BUILD_RECT.size.x + 8, 2)),
		Palette.DIGGER_METAL,
		true
	)
	# Shell walls.
	draw_rect(BUILD_RECT, Palette.WALL_CHISEL, true)
	# Interior: dark, with a warm glow spilling from the doorway.
	var interior := Rect2(BUILD_RECT.position + Vector2(6, 4), BUILD_RECT.size - Vector2(12, 4))
	draw_rect(interior, Palette.WALL_DARK, true)
	var glow := Palette.UI_GOLD
	for i in range(3):
		var inset := float(i) * 6.0
		draw_rect(
			Rect2(
				interior.position + Vector2(inset, inset),
				interior.size - Vector2(inset * 2.0, inset)
			),
			Color(glow.r, glow.g, glow.b, 0.10 - float(i) * 0.03),
			true
		)
	# Set dressing: a shelf, a fuel barrel, a wall lamp — "home".
	draw_line(
		interior.position + Vector2(4, 12),
		interior.position + Vector2(20, 12),
		Palette.DIGGER_METAL_DARK,
		2.0
	)
	draw_rect(
		Rect2(interior.position + Vector2(6, interior.size.y - 12), Vector2(8, 12)),
		Palette.LAVA_DEEP,
		true
	)
	draw_rect(
		Rect2(interior.position + Vector2(6, interior.size.y - 8), Vector2(8, 2)),
		Palette.DIGGER_METAL,
		true
	)
	# Door posts.
	draw_rect(
		Rect2(DOOR_RECT.position - Vector2(4, 6), Vector2(4, DOOR_RECT.size.y + 8)),
		Palette.band_mid(3),
		true
	)
	draw_rect(
		Rect2(DOOR_RECT.position + Vector2(DOOR_RECT.size.x, -6), Vector2(4, DOOR_RECT.size.y + 8)),
		Palette.band_mid(3),
		true
	)
	# The doorway lamp: a slow warm pulse that says "come in".
	var pulse := 0.55 + 0.35 * sin(t * 2.2)
	var lamp := DOOR_RECT.position + Vector2(DOOR_RECT.size.x * 0.5, -8.0)
	draw_circle(lamp, 2.5, Color(glow.r, glow.g, glow.b, pulse))
	draw_circle(lamp, 6.0, Color(glow.r, glow.g, glow.b, pulse * 0.25))
	# The sign.
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(lamp + Vector2(-26, -18), Vector2(52, 12)), Palette.WALL_DARK, true)
	draw_rect(Rect2(lamp + Vector2(-26, -18), Vector2(52, 12)), Palette.UI_PANEL_BORDER, false, 1.0)
	draw_string(
		font, lamp + Vector2(-22, -8), "GARAGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Palette.UI_GOLD
	)
