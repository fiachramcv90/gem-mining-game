class_name SupportCorner
extends Control
## The permanent ♥ Support corner of the surface hub (spec §9 census /
## §15): the single quiet "also on itch.io" link. Sits bottom-right,
## opposite the 💾 save-safety corner; visible only at the surface. Button
## text is plain words because the default font has no emoji glyph — the ♥
## is the corner's identity, not a literal glyph. While the support_url
## knob is empty the link says so instead of opening anything.

const RESET_SECS := 2.0

var _button: Button


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_button = Button.new()
	_button.flat = true
	_button.text = "also on itch.io"
	_button.custom_minimum_size = Vector2(130, 44)
	_button.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_button.position = Vector2(-142, -56)
	_button.modulate = Color(1, 1, 1, 0.65)
	_button.pressed.connect(_on_pressed)
	add_child(_button)


func _process(_delta: float) -> void:
	# A hub fixture, like the 💾 corner: surface only, never mid-run.
	_button.visible = GameState.depth == 0


func _on_pressed() -> void:
	var url: String = GameState.economy.support_url
	if url.is_empty():
		_button.text = "itch.io — coming soon"
		get_tree().create_timer(RESET_SECS).timeout.connect(
			func() -> void: _button.text = "also on itch.io"
		)
		return
	OS.shell_open(url)
