class_name GemPickup
extends Area2D
## A gem freed from its tile, waiting to be collected. If the hold is full it
## simply stays in the ground (spec §1) — it persists as a dug-but-uncollected
## delta and respawns with its chunk.
##
## Owns the gem palette (saturated hues are reserved for gems/prize — the
## reserve-saturation rule, spec §7); Mine paints its atlas from these.

const GEM_COLORS: Array[Color] = [
	Color8(90, 200, 120),   # T1
	Color8(80, 190, 220),   # T2
	Color8(95, 120, 235),   # T3
	Color8(175, 95, 230),   # T4
	Color8(240, 90, 120),   # T5
]
const PRIZE_COLOR := Color8(255, 205, 70)

var tier := 1  # 1..5, or Worldgen.PRIZE_TIER
var tile := Vector2i.ZERO


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 7.0
	shape.shape = circle
	add_child(shape)
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group("digger"):
		return
	if GameState.try_collect(tier):
		GameState.mark_collected(tile)
		queue_free()


func _draw() -> void:
	var color := PRIZE_COLOR if tier == Worldgen.PRIZE_TIER else GEM_COLORS[tier - 1]
	var pts := PackedVector2Array([
		Vector2(0, -5), Vector2(5, 0), Vector2(0, 5), Vector2(-5, 0)])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([Vector2(0, -5)]), color.lightened(0.4), 1.0)
