class_name Dynamite
extends Node2D
## An armed dynamite charge (spec C4/EP1-08). Drops at the digger with a lit
## fuse — the burning countdown is the permanent teacher: thrust clear before
## it blows. On the short auto-fuse it clears a downward-biased teardrop
## (ignoring hardness, prize-immune, caught gems destroyed) and deals
## proximity-scaled self-damage if the digger is still inside the radius —
## the retreat gamble. A fuse, not a manual detonate: the time pressure IS
## the gamble (a manual button would let you dawdle to safety then tap).

var player: Player
var mine: Mine
var blast_tile := Vector2i.ZERO

var _clock := 0.0
var _fuse := 1.3
var _blown := false


func _ready() -> void:
	_fuse = Loadout.config.fuse_time
	z_index = 5
	Sfx.play("warning")


func _process(delta: float) -> void:
	_clock += delta
	if not _blown and _clock >= _fuse:
		_detonate()
	queue_redraw()


func _detonate() -> void:
	_blown = true
	var cfg := Loadout.config
	mine.blast(blast_tile, cfg.blast_down, cfg.blast_up, cfg.blast_wide)
	# Proximity-scaled self-damage, capped at self_dmg_frac of CURRENT hull
	# (0007's currency, like falls) — punishing but never an instakill.
	var center := mine.world_center(blast_tile)
	var dist_tiles := (player.global_position - center).length() / player.tile_px()
	if dist_tiles <= cfg.self_dmg_radius:
		var prox := 1.0 - dist_tiles / cfg.self_dmg_radius
		GameState.apply_hazard_damage(
			cfg.self_dmg_frac * GameState.hull * prox, GameState.HAZARD_BLAST
		)
	Juice.shake(0.7)
	Juice.flash(Palette.FLAME_MID, 0.35)
	Juice.burst(center, Palette.LAVA_HOT, 8, 1.6)
	Sfx.play("rumble")
	queue_free()


func _draw() -> void:
	# A stubby red stick with a hissing fuse spark that blinks faster as the
	# fuse runs down — the "move!" tell, no text needed.
	draw_rect(Rect2(-3, -4, 6, 8), Palette.LAVA_DEEP, true)
	draw_rect(Rect2(-3, -4, 6, 8), Palette.UI_DANGER, false, 1.0)
	var frac := clampf(_clock / _fuse, 0.0, 1.0)
	var blink := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.001 * (12.0 + frac * 40.0))
	draw_circle(Vector2(0, -6), 1.6, Palette.PRIZE_GLINT.lerp(Palette.UI_DANGER, blink))
	# A shrinking fuse line drawn atop the stick.
	draw_line(Vector2(0, -4), Vector2(0, -4 - 3.0 * (1.0 - frac)), Palette.PRIZE_DEEP, 1.5)
