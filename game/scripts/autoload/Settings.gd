extends Node
## Autoload: player-facing settings. Exactly one so far — the §7
## reduce-motion/shake toggle, honouring the platform's
## prefers-reduced-motion by default. Its surface is the tap-to-start
## screen (the one place every session passes through that isn't the closed
## §9 hub census); it persists in the save's `settings` key, added via the
## migrate chain (save_version 3) — keys only ever added, never reshaped.

signal settings_changed

## AUTO follows prefers-reduced-motion; REDUCED/FULL are explicit overrides.
enum Motion { AUTO, REDUCED, FULL }

var motion_mode: int = Motion.AUTO

## Read once at boot from the platform (web matchMedia; false elsewhere).
var _prefers_reduced := false


func _ready() -> void:
	if OS.has_feature("web"):
		_prefers_reduced = bool(
			JavaScriptBridge.eval(
				"window.matchMedia('(prefers-reduced-motion: reduce)').matches", true
			)
		)


func reduce_motion() -> bool:
	## What the juice layer asks before shaking the camera.
	if motion_mode == Motion.REDUCED:
		return true
	return motion_mode == Motion.AUTO and _prefers_reduced


func cycle_motion() -> void:
	motion_mode = (motion_mode + 1) % 3
	settings_changed.emit()


func motion_label() -> String:
	match motion_mode:
		Motion.REDUCED:
			return "motion: reduced"
		Motion.FULL:
			return "motion: full"
	return "motion: auto (%s)" % ("reduced" if _prefers_reduced else "full")


func load_state(settings_in: Dictionary) -> void:
	## Load defensively (spec §13): missing or mistyped key -> default.
	var m: Variant = settings_in.get("motion_mode", Motion.AUTO)
	if m is int:
		motion_mode = clampi(m, 0, 2)
	elif m is float:
		motion_mode = clampi(int(m), 0, 2)
	else:
		motion_mode = Motion.AUTO
	settings_changed.emit()
