class_name ToolIcon
extends Control
## A code-drawn glyph + charge count for one consumable slot button (EP1 C3).
## Immediate-mode like the rest of the game's art (no image assets, the
## default font has no emoji) — each glyph echoes the tool's in-game look so
## the corner buttons read at a glance, mid-action. Drawn on the left; the
## "×N" charge count sits to its right.

var tool := ""
var count := 0


func set_data(tool_id: String, charges: int) -> void:
	tool = tool_id
	count = charges
	queue_redraw()


func _draw() -> void:
	var h := size.y
	var center := Vector2(h * 0.5, h * 0.5)
	var r := h * 0.30
	_draw_glyph(center, r)
	var font := ThemeDB.fallback_font
	draw_string(
		font,
		Vector2(h - 2.0, h * 0.5 + 5.0),
		"x%d" % count,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		15,
		Palette.UI_TEXT
	)


func _draw_glyph(c: Vector2, r: float) -> void:
	match tool:
		"flare":
			_flare(c, r)
		"fuel_cell":
			_fuel_cell(c, r)
		"dynamite":
			_dynamite(c, r)
		"repair_kit":
			_repair(c, r)
		"scout":
			_scout(c, r)
		"hauler":
			_hauler(c, r)


func _flare(c: Vector2, r: float) -> void:
	# A radiating burst with a hot core (the darkness-buster).
	for i in range(8):
		var a := TAU * float(i) / 8.0
		var dir := Vector2(cos(a), sin(a))
		draw_line(c + dir * r * 0.5, c + dir * r * 1.25, Palette.PRIZE_DEEP, 1.5)
	draw_circle(c, r * 0.55, Palette.PRIZE_LIGHT)
	draw_circle(c, r * 0.28, Palette.PRIZE_GLINT)


func _fuel_cell(c: Vector2, r: float) -> void:
	# A jerry can: body + spout, in the fuel blue.
	var body := Rect2(c - Vector2(r * 0.8, r), Vector2(r * 1.5, r * 2.0))
	draw_rect(body, Palette.UI_FUEL, true)
	draw_rect(body, Palette.SKY_HIGH.darkened(0.3), false, 1.0)
	draw_rect(
		Rect2(c + Vector2(r * 0.7, -r * 0.8), Vector2(r * 0.5, r * 0.4)), Palette.UI_FUEL, true
	)
	draw_line(
		c + Vector2(-r * 0.4, -r * 0.3), c + Vector2(r * 0.5, -r * 0.3), Palette.DIGGER_GLASS, 1.5
	)


func _dynamite(c: Vector2, r: float) -> void:
	# A red stick with a lit fuse — the tool's permanent tell.
	var stick := Rect2(c - Vector2(r * 0.55, r), Vector2(r * 1.1, r * 2.0))
	draw_rect(stick, Palette.LAVA_DEEP, true)
	draw_rect(stick, Palette.UI_DANGER, false, 1.0)
	draw_line(c + Vector2(0, -r), c + Vector2(r * 0.7, -r * 1.5), Palette.PRIZE_DEEP, 1.5)
	draw_circle(c + Vector2(r * 0.7, -r * 1.5), r * 0.28, Palette.PRIZE_GLINT)


func _repair(c: Vector2, r: float) -> void:
	# A medkit cross, in the good-green.
	var t := r * 0.42
	draw_rect(Rect2(c - Vector2(t, r), Vector2(t * 2.0, r * 2.0)), Palette.UI_GOOD, true)
	draw_rect(Rect2(c - Vector2(r, t), Vector2(r * 2.0, t * 2.0)), Palette.UI_GOOD, true)


func _scout(c: Vector2, r: float) -> void:
	# The scout drone body + sensor eye (matches ScoutDrone).
	draw_circle(c, r, Palette.gem_deep(2))
	draw_arc(c, r, 0.0, TAU, 16, Color.WHITE, 1.0)
	draw_circle(c, r * 0.4, Palette.gem_light(2))


func _hauler(c: Vector2, r: float) -> void:
	# The hauler drone body + cargo pod (matches HaulerDrone).
	var body := Rect2(c - Vector2(r, r * 0.7), Vector2(r * 2.0, r * 1.4))
	draw_rect(body, Palette.DIGGER_BODY, true)
	draw_rect(body, Palette.DIGGER_DARK, false, 1.0)
	draw_rect(Rect2(c + Vector2(-r * 0.5, r * 0.7), Vector2(r, r * 0.7)), Palette.PRIZE_DEEP, true)
