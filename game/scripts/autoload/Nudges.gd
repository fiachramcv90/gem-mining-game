extends Node
## Autoload: nudge state (spec §9, CONTEXT.md "Nudge") — temporary,
## non-blocking prompts for actions outside the game loop. Exactly two
## persisted fields (the whole 0013 save-schema cost): the silent-switch
## caption's shown-once flag and the Add-to-Home-Screen dismissal counter.
## Everything else about the nudges is DERIVED — the A2HS trigger from
## stats the Log already counts, standalone from display-mode.

signal nudges_changed

var audio_hint_shown := false
## 0 = never dismissed, 1 = dismissed once (one re-show after a later run
## lost), 2 = re-shown and dismissed again — retired for good.
var a2hs_dismissed := 0

## Transient re-arm: set when a run is lost while a2hs_dismissed == 1 — the
## one re-show, at the moment "losing things" is emotionally live (0013).
var _a2hs_reshown := false
## Detected once at boot: the installed PWA already protects the save, so
## the nudge is suppressed entirely.
var _standalone := false


func _ready() -> void:
	if OS.has_feature("web"):
		_standalone = bool(
			JavaScriptBridge.eval(
				(
					"window.matchMedia('(display-mode: standalone)').matches"
					+ " || window.navigator.standalone === true"
				),
				true
			)
		)
	GameState.run_lost.connect(_on_run_lost)


func load_state(nudges_in: Dictionary) -> void:
	## Load defensively (spec §13): missing or mistyped key -> default.
	audio_hint_shown = bool(nudges_in.get("audio_hint_shown", false))
	var d: Variant = nudges_in.get("a2hs_dismissed", 0)
	if d is int:
		a2hs_dismissed = clampi(d, 0, 2)
	elif d is float:
		a2hs_dismissed = clampi(int(d), 0, 2)
	else:
		a2hs_dismissed = 0
	_a2hs_reshown = false
	nudges_changed.emit()


func mark_audio_hint_shown() -> void:
	## Called by the game-starting tap — the caption is dismissed by the act
	## of starting, no interaction of its own (spec §9).
	audio_hint_shown = true


func a2hs_callout_active() -> bool:
	## The 💾 corner's temporary callout label shows only while every 0013
	## condition holds: web, not installed, not retired, not sleeping after
	## a first dismissal, and the save finally contains something a player
	## would miss (first sell OR first run lost — derived from the stats).
	if not OS.has_feature("web") or _standalone:
		return false
	if a2hs_dismissed >= 2:
		return false
	if a2hs_dismissed == 1 and not _a2hs_reshown:
		return false
	return int(MinersLog.stats["money_banked"]) > 0 or int(MinersLog.stats["runs_lost"]) > 0


func dismiss_a2hs() -> void:
	a2hs_dismissed = 1 if a2hs_dismissed == 0 else 2
	nudges_changed.emit()


func _on_run_lost(_reason: String, _cargo_lost: int) -> void:
	if a2hs_dismissed == 1 and not _a2hs_reshown:
		_a2hs_reshown = true
		nudges_changed.emit()
