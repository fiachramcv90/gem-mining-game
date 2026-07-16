class_name GasBurstFlash
extends Node2D
## One-shot grey-box gas-burst pop: an expanding, fading double ring at the
## burst tile (visual-first juice, spec §7 — the real particle/shake pass is
## a later session). Frees itself when the tween ends. Lives in world space,
## so the darkness overlay applies — a burst is always adjacent to the
## digger and therefore always inside the lit radius.

var radius := 4.0
var alpha := 0.9


func _ready() -> void:
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(self, "radius", 22.0, 0.35).set_ease(Tween.EASE_OUT)
	t.tween_property(self, "alpha", 0.0, 0.35)
	t.chain().tween_callback(queue_free)


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var wisp := Palette.GAS_DEEP
	var pale := Palette.GAS_WISP
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, Color(wisp.r, wisp.g, wisp.b, alpha), 2.5)
	draw_arc(
		Vector2.ZERO, radius * 0.6, 0.0, TAU, 20, Color(pale.r, pale.g, pale.b, alpha * 0.7), 1.5
	)
