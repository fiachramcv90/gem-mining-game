class_name ScoutDrone
extends Node2D
## The scout drone (spec C4/EP1-09): tunnels a thin path from the digger
## toward the nearest qualifying gem (queried from worldgen), clearing plain
## rock along the way but LEAVING gems standing so you still mine the find
## yourself — it bypasses the finding, never the mining. Reveals nothing else
## (no hazard tells, no map). Emits `finished` when it reaches the target so
## the ToolRunner frees the "one drone out" latch.

signal finished

var mine: Mine
var start_tile := Vector2i.ZERO
var target_tile := Vector2i.ZERO
var tiles_per_sec := 14.0

var _path: Array[Vector2i] = []
var _progress := 0.0


func _ready() -> void:
	z_index = 6
	_path = _line(start_tile, target_tile)
	position = mine.world_center(start_tile)


func _process(delta: float) -> void:
	_progress += tiles_per_sec * delta
	var reach := mini(int(_progress), _path.size() - 1)
	for i in range(reach + 1):
		# The final tile is the target gem — leave it for the player to mine.
		if _path[i] == target_tile:
			continue
		mine.tunnel_clear(_path[i])
	position = mine.world_center(_path[reach])
	queue_redraw()
	if reach >= _path.size() - 1:
		finished.emit()
		queue_free()


func _line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	## Integer Bresenham line of tiles from a to b (inclusive).
	var pts: Array[Vector2i] = []
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	var cur := a
	while true:
		pts.append(cur)
		if cur == b:
			break
		var e2 := 2 * err
		if e2 >= dy:
			err += dy
			cur.x += sx
		if e2 <= dx:
			err += dx
			cur.y += sy
	return pts


func _draw() -> void:
	# A small teal scout body (draw_arc rim) with a blinking sensor eye.
	draw_circle(Vector2.ZERO, 3.0, Palette.gem_deep(2))
	draw_arc(Vector2.ZERO, 3.0, 0.0, TAU, 16, Color.WHITE, 1.0)
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.012)
	draw_circle(Vector2.ZERO, 1.4, Palette.gem_light(2).lerp(Color.WHITE, blink))
