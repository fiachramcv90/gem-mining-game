class_name DigGrid
extends Node2D
## The grey-box "mine": a plain 2D array of cells, drawn with _draw().
## THROWAWAY. The real game uses a TileMapLayer + erase_cell() with hardness /
## gem_type as TileSet custom data (ticket 0001). Here a code array is cheaper
## and answers the same feel question: hardness -> dig time, tunnels persist.

const CELL := 44
const COLS := 9
const ROWS := 18
const SURFACE_ROWS := 3          # open sky at the top; player spawns + refuels here
const ORIGIN := Vector2(22, 96)  # top-left of the grid in screen space

# Per-cell state. solid[y][x] = hardness (0 = dug/empty, >0 = rock hardness).
# gem[y][x] = true if the cell hides a "gem" (just a coloured dig target here;
# gem VALUES / economy are out of scope for 0004 -> ticket 0006).
var _hardness: Array = []
var _gem: Array = []

func setup() -> void:
	_hardness.clear()
	_gem.clear()
	for y in range(ROWS):
		var hrow: Array = []
		var grow: Array = []
		for x in range(COLS):
			var h := 0
			if y >= SURFACE_ROWS:
				# hardness grows with depth: 1..4. Deterministic so every reset
				# gives the same mine (persistent-mine spirit, ticket 0003).
				var depth := y - SURFACE_ROWS
				h = 1 + int(depth / 4)
				h = clampi(h, 1, 4)
			hrow.append(h)
			# sprinkle a few gems as coloured dig targets at fixed spots
			grow.append(y >= SURFACE_ROWS + 2 and ((x * 7 + y * 3) % 11 == 0))
		_hardness.append(hrow)
		_gem.append(grow)
	queue_redraw()

func in_bounds(cx: int, cy: int) -> bool:
	return cx >= 0 and cx < COLS and cy >= 0 and cy < ROWS

func is_solid(cx: int, cy: int) -> bool:
	# Out-of-bounds sides/bottom are treated as solid walls so the player can't
	# leave the mine; above the top is open.
	if cy < 0:
		return false
	if cx < 0 or cx >= COLS or cy >= ROWS:
		return true
	return _hardness[cy][cx] > 0

func hardness(cx: int, cy: int) -> int:
	if not in_bounds(cx, cy):
		return 1
	return _hardness[cy][cx]

func has_gem(cx: int, cy: int) -> bool:
	return in_bounds(cx, cy) and _gem[cy][cx]

func dig(cx: int, cy: int) -> void:
	if in_bounds(cx, cy):
		_hardness[cy][cx] = 0
		_gem[cy][cx] = false
		queue_redraw()

func is_surface_world_y(world_y: float) -> bool:
	var cy := int(floor((world_y - ORIGIN.y) / CELL))
	return cy < SURFACE_ROWS

func cell_center(cx: int, cy: int) -> Vector2:
	return ORIGIN + Vector2((cx + 0.5) * CELL, (cy + 0.5) * CELL)

func world_to_cell(world_pos: Vector2) -> Vector2i:
	return Vector2i(
		int(floor((world_pos.x - ORIGIN.x) / CELL)),
		int(floor((world_pos.y - ORIGIN.y) / CELL)))

func play_rect() -> Rect2:
	return Rect2(ORIGIN, Vector2(COLS * CELL, ROWS * CELL))

func _draw() -> void:
	var w := COLS * CELL
	var h := ROWS * CELL
	# background (dug tunnels show through as this dark fill)
	draw_rect(Rect2(ORIGIN, Vector2(w, h)), Color(0.09, 0.09, 0.11), true)
	# open sky above the rock
	draw_rect(Rect2(ORIGIN, Vector2(w, SURFACE_ROWS * CELL)), Color(0.16, 0.20, 0.30), true)
	# rock cells, grey by hardness
	for y in range(ROWS):
		for x in range(COLS):
			var hh: int = _hardness[y][x]
			if hh <= 0:
				continue
			var shade := 0.58 - float(hh - 1) * 0.10   # harder = darker
			var pos := ORIGIN + Vector2(x * CELL, y * CELL)
			var cell_rect := Rect2(pos + Vector2(1, 1), Vector2(CELL - 2, CELL - 2))
			draw_rect(cell_rect, Color(shade, shade * 0.95, shade * 0.9), true)
			# gem hint: a small coloured square inside the rock
			if _gem[y][x]:
				var g := pos + Vector2(CELL * 0.5, CELL * 0.5)
				draw_rect(Rect2(g - Vector2(7, 7), Vector2(14, 14)), Color(0.36, 0.85, 0.95), true)
	# faint frame around the mine
	draw_rect(Rect2(ORIGIN, Vector2(w, h)), Color(0.4, 0.4, 0.45, 0.5), false, 2.0)
