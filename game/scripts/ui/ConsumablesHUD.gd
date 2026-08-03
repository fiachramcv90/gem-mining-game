class_name ConsumablesHUD
extends Control
## The EP1 consumables control surface (spec C3): three slot buttons stacked
## in the TOP-RIGHT corner — opposite the roaming trailing stick, reachable
## with the off-hand thumb, off the stick's territory so the two thumbs stay
## independent (no mis-taps). Every tool is one tap (instant items fire,
## dynamite drops-and-flees, drones dispatch). The buttons appear only once a
## loadout is equipped and only in the mine (depth > 0); a refusal (no lead,
## no cargo) shows a brief reason and spends nothing.
##
## Also carries the two consumable onboarding ghost lines (spec C5/EP1-11):
## the first-descent "your gear — tap to use" corner line and dynamite's
## one-shot "GET CLEAR!" (the lit fuse is the permanent teacher). Both are
## one-shots riding the existing nudges dict.

const SLOT_SIZE := Vector2(78, 46)
const SLOT_GAP := 8.0
const SLOT_TOP := 12.0
const REFUSAL_SECS := 1.6

## Short button captions (the default font has no emoji; words are the tell).
const SHORT_LABELS := {
	"flare": "FLARE",
	"fuel_cell": "FUEL",
	"dynamite": "DYNAMITE",
	"repair_kit": "REPAIR",
	"scout": "SCOUT",
	"hauler": "HAULER",
}

var tools: ToolRunner

var _slots: VBoxContainer
var _buttons := {}
var _refusal: Label
var _refusal_clock := 0.0
var _gear_ghost: Label
var _dynamite_ghost: Label
var _dynamite_ghost_clock := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", int(SLOT_GAP))
	_slots.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_slots.position = Vector2(-SLOT_SIZE.x - 12.0, SLOT_TOP)
	add_child(_slots)

	_refusal = Label.new()
	_refusal.add_theme_font_size_override("font_size", 12)
	_refusal.add_theme_color_override("font_color", Palette.UI_DANGER)
	_refusal.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_refusal.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_refusal.position = Vector2(-230.0, SLOT_TOP + 2.0)
	_refusal.custom_minimum_size = Vector2(210, 0)
	_refusal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_refusal.modulate = Color(1, 1, 1, 0)
	add_child(_refusal)

	_gear_ghost = _build_ghost("your gear — tap to use", 210.0)
	_dynamite_ghost = _build_ghost("GET CLEAR!", 260.0)

	Loadout.loadout_changed.connect(_rebuild)
	Loadout.stock_changed.connect(_on_stock_changed)
	Loadout.tool_used.connect(_on_tool_used)
	_rebuild()


func _build_ghost(text: String, top: float) -> Label:
	var ghost := Label.new()
	ghost.text = text
	ghost.set_anchors_preset(Control.PRESET_TOP_WIDE)
	ghost.offset_top = top
	ghost.offset_bottom = top + 34.0
	ghost.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ghost.add_theme_font_size_override("font_size", 15)
	ghost.add_theme_color_override("font_color", Palette.UI_GOLD)
	ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ghost.modulate = Color(1, 1, 1, 0)
	add_child(ghost)
	return ghost


func _rebuild() -> void:
	for child in _slots.get_children():
		child.queue_free()
	_buttons.clear()
	for tool in Loadout.active_tools():
		var button := Button.new()
		button.custom_minimum_size = SLOT_SIZE
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_on_slot_pressed.bind(tool))
		_slots.add_child(button)
		_buttons[tool] = button
	_refresh_counts()


func _refresh_counts() -> void:
	for tool: String in _buttons.keys():
		var button: Button = _buttons[tool]
		var n := Loadout.charges(tool)
		button.text = "%s\n×%d" % [SHORT_LABELS.get(tool, tool), n]
		button.disabled = n <= 0


func _on_stock_changed(_tool: String, _count: int) -> void:
	_refresh_counts()


func _on_slot_pressed(tool: String) -> void:
	if tools == null:
		return
	var reason := tools.activate(tool)
	if reason.is_empty():
		_dismiss_gear_ghost()
	else:
		_show_refusal(reason)
	_refresh_counts()


func _on_tool_used(tool: String) -> void:
	# Dynamite's one-shot teach fires on first use; the lit fuse teaches the
	# rest (the retreat) permanently.
	if tool == "dynamite" and not Nudges.dynamite_taught:
		Nudges.mark_nudge("dynamite_taught")
		_dynamite_ghost_clock = 0.0
		_tween_alpha(_dynamite_ghost, 0.9, 0.25)


func _show_refusal(reason: String) -> void:
	_refusal.text = reason
	_refusal_clock = REFUSAL_SECS
	_tween_alpha(_refusal, 1.0, 0.12)


func _process(delta: float) -> void:
	# Corner buttons: only with gear equipped, only in the mine (spec C3/C5).
	var showing := GameState.depth > 0 and Loadout.has_equipped_gear()
	_slots.visible = showing
	_tick_refusal(delta)
	_tick_gear_ghost(showing)
	_tick_dynamite_ghost(delta)


func _tick_refusal(delta: float) -> void:
	if _refusal_clock <= 0.0:
		return
	_refusal_clock -= delta
	if _refusal_clock <= 0.0:
		_tween_alpha(_refusal, 0.0, 0.4)


func _tick_gear_ghost(showing: bool) -> void:
	# First descent with gear: point at the corner, self-dismiss on first use
	# (or when leaving the mine).
	if showing and not Nudges.hud_gear_shown and _gear_ghost.modulate.a < 0.05:
		Nudges.mark_nudge("hud_gear_shown")
		_tween_alpha(_gear_ghost, 0.85, 0.4)
	if not showing and _gear_ghost.modulate.a > 0.05:
		_dismiss_gear_ghost()


func _tick_dynamite_ghost(delta: float) -> void:
	if _dynamite_ghost.modulate.a <= 0.05:
		return
	_dynamite_ghost_clock += delta
	if _dynamite_ghost_clock >= 1.4:
		_tween_alpha(_dynamite_ghost, 0.0, 0.5)


func _dismiss_gear_ghost() -> void:
	if _gear_ghost.modulate.a > 0.05:
		_tween_alpha(_gear_ghost, 0.0, 0.4)


func _tween_alpha(node: CanvasItem, target: float, secs: float) -> void:
	create_tween().tween_property(node, "modulate:a", target, secs)
