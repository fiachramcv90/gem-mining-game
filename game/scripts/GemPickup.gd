class_name GemPickup
extends Area2D
## A gem freed from its tile, waiting to be collected. If the hold is full it
## simply stays in the ground (spec §1) — it persists as a dug-but-uncollected
## delta and respawns with its chunk.
##
## Colours come from Palette (Resurrect-64): saturated hues are reserved for
## gems/prize — the reserve-saturation rule, spec §7.

var tier := 1  # 1..5, or Worldgen.PRIZE_TIER
var tile := Vector2i.ZERO

var _bob_phase := 0.0


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)
	# Deterministic-looking desync without randf: phase from the tile coords.
	_bob_phase = float((tile.x * 7 + tile.y * 13) % 628) * 0.01


func _process(_delta: float) -> void:
	queue_redraw()


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("digger"):
		return
	if GameState.try_collect(tier):
		GameState.mark_collected(tile)
		# The collect beat (spec §7): sparkle burst + chime; the prize sings.
		Juice.gem_beat(global_position, tier)
		queue_free()


func _draw() -> void:
	var deep := Palette.gem_deep(tier)
	var light := Palette.gem_light(tier)
	# A freed gem hovers with a slight bob and a slow facet twinkle — cheap
	# immediate-mode motion, no frames (spec §7 animation budget).
	var t := Time.get_ticks_msec() * 0.001 + _bob_phase
	var bob := Vector2(0.0, sin(t * 2.4) * 1.2)
	var pts := PackedVector2Array(
		[bob + Vector2(0, -5), bob + Vector2(5, 0), bob + Vector2(0, 5), bob + Vector2(-5, 0)]
	)
	draw_colored_polygon(pts, deep)
	# Upper-left facet catches the light.
	draw_colored_polygon(
		PackedVector2Array([bob + Vector2(0, -5), bob + Vector2(-5, 0), bob + Vector2(0, 0)]), light
	)
	draw_polyline(pts + PackedVector2Array([pts[0]]), deep.darkened(0.35), 1.0)
	var twinkle := 0.5 + 0.5 * sin(t * 3.1)
	draw_circle(bob + Vector2(-1, -2), 1.0, Color.WHITE.lerp(light, 0.4 + 0.4 * twinkle))
