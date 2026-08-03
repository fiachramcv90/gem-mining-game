class_name HaulerDrone
extends Node2D
## The hauler drone (spec C4/EP1-09): dispatched with the current cargo (the
## ToolRunner already pulled it from the hold via take_haulable_cargo), it
## flies to the surface, auto-sells the load — banking it through the same
## cargo_sold event a surface sale fires, so best_haul / total_banked / the
## save all fold it in — then returns empty. Self-powered (never draws the
## fuel tank); a round-trip time that scales with depth; refuses the prize
## (it stayed in the hold). 2 trips buy two "bank-and-push-deeper" reprieves.

signal finished

var value := 0
var trip_time := 3.0
var start_pos := Vector2.ZERO

var _clock := 0.0
var _banked := false
var _surface_pos := Vector2.ZERO


func _ready() -> void:
	z_index = 6
	_surface_pos = Vector2(start_pos.x, -float(GameState.world.tile_px))
	position = start_pos


func _process(delta: float) -> void:
	_clock += delta
	var half := trip_time * 0.5
	if _clock <= half:
		# Outbound to the surface.
		position = start_pos.lerp(_surface_pos, clampf(_clock / half, 0.0, 1.0))
	else:
		if not _banked:
			_bank()
		# Return leg, empty.
		position = _surface_pos.lerp(start_pos, clampf((_clock - half) / half, 0.0, 1.0))
	if _clock >= trip_time:
		finished.emit()
		queue_free()
	queue_redraw()


func _bank() -> void:
	## The mid-descent banking event: money → wallet, then the shared
	## cargo_sold signal (MinersLog.money_banked, leaderboard best_haul, the
	## save snapshot, and the sell juice all ride it).
	_banked = true
	Wallet.add(value)
	GameState.cargo_sold.emit(value)


func _draw() -> void:
	# A yellow hauler with a small cargo pod (full on the way up, empty back).
	draw_rect(Rect2(-4, -3, 8, 6), Palette.DIGGER_BODY, true)
	draw_rect(Rect2(-4, -3, 8, 6), Palette.DIGGER_DARK, false, 1.0)
	if not _banked:
		draw_rect(Rect2(-2, 3, 4, 3), Palette.PRIZE_DEEP, true)
	# The "banked remotely +$X" float (reuses the banked-gold read, spec C5),
	# rising and fading through the return leg.
	if _banked:
		var age := _clock - trip_time * 0.5
		var rise := -8.0 - age * 14.0
		var fade := clampf(1.0 - age / (trip_time * 0.5), 0.0, 1.0)
		var gold := Palette.UI_GOLD
		gold.a = fade
		draw_string(
			ThemeDB.fallback_font,
			Vector2(-30, rise),
			"banked +$%d" % value,
			HORIZONTAL_ALIGNMENT_CENTER,
			60,
			11,
			gold
		)
