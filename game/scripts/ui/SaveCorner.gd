class_name SaveCorner
extends Control
## The permanent 💾 save-safety corner (spec §9/§13): the forever home of
## everything that protects the save — the Add-to-Home-Screen how-to and
## save export/import. A quiet fixture of the surface hub, never a
## dismissable nudge (import can't live behind something that stops
## showing). Button text is "SAVE" because the default font has no emoji
## glyph — the 💾 is the corner's identity, not a literal glyph.
##
## The A2HS NUDGE (spec §9) is a temporary callout label on this permanent
## glyph: it appears once the save holds something worth protecting (first
## sell or first run lost), persists passively until installed or
## dismissed, re-shows once after a later run lost, and is suppressed when
## already running standalone — all judged by Nudges.a2hs_callout_active().

var _corner_button: Button
var _callout: Label
var _callout_dismiss: Button
var _panel: Control
var _confirm: Control
var _status: Label
var _paused_here := false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_corner_button = Button.new()
	_corner_button.text = "SAVE"
	_corner_button.custom_minimum_size = Vector2(64, 44)
	_corner_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_corner_button.position = Vector2(12, -56)
	_corner_button.pressed.connect(_open)
	add_child(_corner_button)

	# The callout rides beside the glyph; tapping it opens the same panel
	# ("tap for how"), the small X dismisses the nudge but never the corner.
	# A tappable Label, not a Button: it must wrap to two quiet lines.
	_callout = Label.new()
	_callout.text = "add to Home Screen so your mine survives — tap for how"
	_callout.custom_minimum_size = Vector2(230, 44)
	_callout.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_callout.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_callout.add_theme_font_size_override("font_size", 11)
	_callout.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_callout.position = Vector2(84, -56)
	_callout.modulate = Color(1.0, 0.9, 0.55)
	_callout.mouse_filter = Control.MOUSE_FILTER_STOP
	_callout.gui_input.connect(_on_callout_input)
	add_child(_callout)

	_callout_dismiss = Button.new()
	_callout_dismiss.text = "X"
	_callout_dismiss.custom_minimum_size = Vector2(32, 44)
	_callout_dismiss.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_callout_dismiss.position = Vector2(318, -56)
	_callout_dismiss.pressed.connect(_on_callout_dismissed)
	add_child(_callout_dismiss)

	_panel = _wrap_center(_build_panel())
	add_child(_panel)
	_confirm = _wrap_center(_build_confirm())
	add_child(_confirm)

	SaveManager.import_failed.connect(_on_import_failed)


func _process(_delta: float) -> void:
	# Permanent at the surface hub; hazards keep it out of the mine.
	_corner_button.visible = GameState.depth == 0 and not _panel.visible and not _confirm.visible
	var callout_on := _corner_button.visible and Nudges.a2hs_callout_active()
	_callout.visible = callout_on
	_callout_dismiss.visible = callout_on


func _wrap_center(panel: Control) -> Control:
	var wrap := CenterContainer.new()
	# Fill the viewport so the panel truly centres (see HUD._center_wrap).
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wrap.visible = false
	wrap.add_child(panel)
	return wrap


func _build_panel() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "SAVE SAFETY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var blurb := Label.new()
	blurb.text = "keep a copy of your mine — browsers can evict saves"
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.add_theme_font_size_override("font_size", 12)
	vbox.add_child(blurb)

	# The A2HS how-to (spec §9): iOS has no install-prompt API, so the nudge
	# explains the manual two steps. Installed saves are exempt from the
	# 7-day eviction cap (spec §13) — the strongest durability lever.
	var howto := Label.new()
	howto.text = (
		"safest: add to Home Screen — in Safari tap Share,"
		+ " then 'Add to Home Screen'. The installed app keeps its own save."
	)
	howto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	howto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	howto.add_theme_font_size_override("font_size", 12)
	howto.modulate = Color(1.0, 0.9, 0.55)
	vbox.add_child(howto)

	_status = Label.new()
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.add_theme_font_size_override("font_size", 12)
	_status.visible = false
	vbox.add_child(_status)

	vbox.add_child(_action("EXPORT SAVE (download)", _on_export))
	vbox.add_child(_action("IMPORT SAVE…", _on_import_pressed))
	vbox.add_child(_action("CLOSE", _close))
	return panel


func _build_confirm() -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(300, 0)
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	var warning := Label.new()
	warning.text = "Importing a save file REPLACES your current progress."
	warning.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	warning.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(warning)

	vbox.add_child(_action("IMPORT — REPLACE PROGRESS", _on_import_confirmed))
	vbox.add_child(_action("CANCEL", _cancel_confirm))
	return panel


func _action(label: String, handler: Callable) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = Vector2(0, 48)
	button.pressed.connect(handler)
	return button


func _open() -> void:
	_status.visible = false
	_panel.visible = true
	# Only pause/unpause when this panel is the reason the tree is paused
	# (the hub panel may already hold the pause).
	_paused_here = not get_tree().paused
	if _paused_here:
		get_tree().paused = true


func _close() -> void:
	_panel.visible = false
	_confirm.visible = false
	if _paused_here:
		get_tree().paused = false


func _on_export() -> void:
	SaveManager.export_save()
	_show_status("save exported — keep the file somewhere safe")


func _on_import_pressed() -> void:
	_panel.visible = false
	_confirm.visible = true


func _cancel_confirm() -> void:
	_confirm.visible = false
	_panel.visible = true


func _on_import_confirmed() -> void:
	# The button press is the user gesture the browser file picker needs.
	# On success SaveManager reboots the scene; this whole layer reloads.
	_confirm.visible = false
	_panel.visible = true
	SaveManager.request_import()


func _on_callout_input(event: InputEvent) -> void:
	# Mouse arrives as a touch too (emulate_touch_from_mouse) — one path.
	if event is InputEventScreenTouch and event.pressed:
		_open()


func _on_callout_dismissed() -> void:
	# The dismissal persists (spec §9): 0 -> 1 (sleeps until a later run
	# lost re-shows it once), 1 -> 2 (retired for good).
	Nudges.dismiss_a2hs()
	SaveManager.save_now()


func _on_import_failed(reason: String) -> void:
	_panel.visible = true
	_confirm.visible = false
	_show_status("import failed: %s" % reason)


func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = true
