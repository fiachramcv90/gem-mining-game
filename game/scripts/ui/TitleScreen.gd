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
var _motion: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	theme = UITheme.build()

	# A top-level Control added to a CanvasLayer at runtime is NOT auto-sized
	# to the viewport until the first resize fires — and the title is the one
	# screen shown AT BOOT, inside that zero-size window. A zero-size root
	# renders its centred content jammed into the top-left corner (cut off)
	# and, worse, gives the tap-to-start gesture a zero-area target, so the
	# game can't be started at all. Drive our own rect from the viewport and
	# keep it synced, rather than trusting anchors to deliver a size.
	_fit_to_viewport()
	get_viewport().size_changed.connect(_fit_to_viewport)

	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.07, 0.06, 0.09)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)

	# Centre the content with a full-rect CenterContainer (the same robust
	# pattern HUD._center_wrap uses for every other panel) instead of hand
	# anchoring, so it stays centred at any viewport size.
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 18)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(vbox)

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
	# Explicit anchors AND offsets: correct whatever size the parent has at
	# this moment (the session-5 layout lesson, applied to corners too).
	_support = Button.new()
	_support.flat = true
	_support.text = "also on itch.io"
	_support.custom_minimum_size = Vector2(150, 44)
	_corner_layout(_support, true)
	_support.modulate = Color(1, 1, 1, 0.65)
	_support.pressed.connect(_on_support)
	add_child(_support)

	# The §7 reduce-motion/shake toggle's settings surface: quiet, cornered,
	# outside the closed hub census; honours prefers-reduced-motion on auto
	# and persists via the save's `settings` key (save_version 3).
	_motion = Button.new()
	_motion.flat = true
	_motion.custom_minimum_size = Vector2(170, 44)
	_corner_layout(_motion, false)
	_motion.modulate = Color(1, 1, 1, 0.65)
	_motion.pressed.connect(_on_motion_toggle)
	add_child(_motion)
	_refresh_motion_label()
	Settings.settings_changed.connect(_refresh_motion_label)

	get_tree().paused = true


func _corner_layout(button: Button, right: bool) -> void:
	## Pin a corner button to the bottom edge with a 12 px margin, via
	## explicit anchors + offsets (never position-after-preset).
	var w := button.custom_minimum_size.x
	button.anchor_left = 1.0 if right else 0.0
	button.anchor_right = 1.0 if right else 0.0
	button.anchor_top = 1.0
	button.anchor_bottom = 1.0
	button.offset_left = -12.0 - w if right else 12.0
	button.offset_right = -12.0 if right else 12.0 + w
	button.offset_top = -56.0
	button.offset_bottom = -12.0


func _fit_to_viewport() -> void:
	# TOP_LEFT-anchored (the default) so this explicit rect is authoritative;
	# the full-rect children then fill the real viewport size.
	var rect := get_viewport().get_visible_rect()
	position = Vector2.ZERO
	size = rect.size


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
	# This tap IS the Web Audio unlock gesture (spec §11) — the sound layer
	# starts its loops here and nowhere earlier.
	Sfx.unlock()
	get_tree().paused = false


func _on_motion_toggle() -> void:
	Settings.cycle_motion()
	SaveManager.save_now()


func _refresh_motion_label() -> void:
	_motion.text = Settings.motion_label()


func _on_support() -> void:
	var url: String = GameState.economy.support_url
	if url.is_empty():
		_support.text = "itch.io — coming soon"
		return
	OS.shell_open(url)
