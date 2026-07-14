class_name VirtualStick
extends Control
## The dynamic, trailing virtual stick — the single most important feel
## detail of 0004, ported behaviour-for-behaviour (spec §2): floating origin
## (appears where the thumb touches), base follows the thumb past the ring so
## reversing thrust is instant, dead zone rescaled so intent eases in from 0.
## Listens on _unhandled_input so HUD buttons win the touch first.

@export var throw_radius := 64.0
## Fraction of the throw radius ignored, then rescaled — no drift, no jump.
@export var dead_zone := 0.16
## The trailing base — must survive into the real game (spec §2).
@export var trailing := true

var _active := false
var _touch_index := -1
var _center := Vector2.ZERO
var _knob := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var touch := event as InputEventScreenTouch
		if touch.pressed and not _active:
			_active = true
			_touch_index = touch.index
			_center = touch.position
			_knob = touch.position
		elif not touch.pressed and touch.index == _touch_index:
			reset()
	elif event is InputEventScreenDrag:
		var drag := event as InputEventScreenDrag
		if _active and drag.index == _touch_index:
			_knob = drag.position
			if trailing:
				var off := _knob - _center
				if off.length() > throw_radius:
					_center = _knob - off.normalized() * throw_radius
	queue_redraw()


func reset() -> void:
	_active = false
	_touch_index = -1
	queue_redraw()


func intent() -> Vector2:
	if not _active:
		return Vector2.ZERO
	var raw := (_knob - _center) / throw_radius
	var mag := raw.length()
	if mag < dead_zone:
		return Vector2.ZERO
	var scaled := (mag - dead_zone) / (1.0 - dead_zone)
	return raw.normalized() * minf(scaled, 1.0)


func _draw() -> void:
	if not _active:
		return
	draw_circle(_center, throw_radius, Color(1, 1, 1, 0.07))
	draw_arc(_center, throw_radius, 0, TAU, 32, Color(1, 1, 1, 0.32), 2.0)
	draw_circle(_knob, 22.0, Color(1, 1, 1, 0.45))
