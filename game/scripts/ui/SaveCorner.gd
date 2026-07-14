class_name SaveCorner
extends Control
## The permanent 💾 save-safety corner (spec §9/§13): the forever home of
## save export/import — a quiet fixture of the surface hub, never a
## dismissable nudge (import can't live behind something that stops
## showing). The Add-to-Home-Screen how-to joins it in a later session
## (0013). Button text is "SAVE" because the default font has no emoji
## glyph — the 💾 is the corner's identity, not a literal glyph.

var _corner_button: Button
var _panel: Control
var _confirm: Control
var _status: Label
var _paused_here := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_corner_button = Button.new()
	_corner_button.text = "SAVE"
	_corner_button.custom_minimum_size = Vector2(64, 44)
	_corner_button.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_corner_button.position = Vector2(12, -56)
	_corner_button.pressed.connect(_open)
	add_child(_corner_button)

	_panel = _wrap_center(_build_panel())
	add_child(_panel)
	_confirm = _wrap_center(_build_confirm())
	add_child(_confirm)

	SaveManager.import_failed.connect(_on_import_failed)


func _process(_delta: float) -> void:
	# Permanent at the surface hub; hazards keep it out of the mine.
	_corner_button.visible = GameState.depth == 0 and not _panel.visible and not _confirm.visible


func _wrap_center(panel: Control) -> Control:
	var wrap := CenterContainer.new()
	wrap.set_anchors_preset(Control.PRESET_FULL_RECT)
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


func _on_import_failed(reason: String) -> void:
	_panel.visible = true
	_confirm.visible = false
	_show_status("import failed: %s" % reason)


func _show_status(text: String) -> void:
	_status.text = text
	_status.visible = true
