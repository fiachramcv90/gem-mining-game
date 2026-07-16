class_name TitleScreen
extends Control
## The tap-to-start screen (spec §9): title + tap prompt + the silent-switch
## caption (first session only, nudges.audio_hint_shown) + the quiet
## ♥ Support link (spec §15). The screen shows every boot because the
## game-starting tap IS the Web Audio unlock gesture (§11) — the caption is
## dismissed by the act of starting, no interaction of its own. The tree
## stays paused underneath, so nothing gates play beyond the one tap the
## platform needs anyway.

var _caption: Label
var _support: Button


func _ready() -> void:
	# Fill the viewport: ..._and_offsets_preset resets the offsets to the
	# preset, so the rect actually spans the parent. Plain set_anchors_preset
	# keeps the (0x0) current rect — which collapses the background and pins
	# the centred content into the top-left corner.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.06, 0.09)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	# Full-rect + centre alignment centres the stack without depending on the
	# parent size being known at this instant (the CENTER preset did, and lost).
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	vbox.add_theme_constant_override("separation", 18)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(vbox)
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var title := Label.new()
	title.text = "GEM MINER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	title.modulate = Color(1.0, 0.85, 0.4)
	vbox.add_child(title)

	var prompt := Label.new()
	prompt.text = "tap to start"
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 16)
	vbox.add_child(prompt)

	# The 🔊 caption (spec §9) — plain text: the fallback font has no emoji
	# glyph, and the words carry the nudge.
	_caption = Label.new()
	_caption.text = "flip your phone off silent for sound"
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 12)
	_caption.modulate = Color(1, 1, 1, 0.6)
	_caption.visible = false
	vbox.add_child(_caption)

	# The ♥ Support link (spec §15): quiet, cornered, never a modal.
	_support = Button.new()
	_support.flat = true
	_support.text = "also on itch.io"
	_support.custom_minimum_size = Vector2(150, 44)
	_support.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_support.position = Vector2(-162, -56)
	_support.modulate = Color(1, 1, 1, 0.65)
	_support.pressed.connect(_on_support)
	add_child(_support)

	get_tree().paused = true


func _process(_delta: float) -> void:
	# Evaluated per frame while visible: the save (and with it
	# nudges.audio_hint_shown) loads in Main._ready, AFTER this _ready.
	if visible:
		_caption.visible = not Nudges.audio_hint_shown


func _gui_input(event: InputEvent) -> void:
	# Mouse arrives as a touch too (emulate_touch_from_mouse) — one path.
	if event is InputEventScreenTouch and event.pressed:
		_start()


func _start() -> void:
	if not visible:
		return
	visible = false
	Nudges.mark_audio_hint_shown()
	SaveManager.save_now()
	get_tree().paused = false


func _on_support() -> void:
	var url: String = GameState.economy.support_url
	if url.is_empty():
		_support.text = "itch.io — coming soon"
		return
	OS.shell_open(url)
